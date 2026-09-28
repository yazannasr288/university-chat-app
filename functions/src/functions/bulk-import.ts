import { onDocumentCreated } from "firebase-functions/v2/firestore";
import { onCall, HttpsError } from "firebase-functions/v2/https";
import * as logger from "firebase-functions/logger";
import * as admin from "firebase-admin";
import { BULK_IMPORT_CHUNK_SIZE, MAX_BULK_IMPORT_STUDENTS } from "../constants";
import { chunkArray } from "../utils/array";
import {
	createStudentFromBulkJob,
	loadGroupsMap,
	sanitizeStudent,
	validateDuplicatesInsideFile,
} from "../services/bulk-import.service";
import {
	decryptChunkPayload,
	encryptChunkPayload,
} from "../utils/chunk-crypto";
import {
	bulkImportChunkOptions,
	mediumCallableOptions,
} from "../runtime-options";
import { writeDashboardAuditLog } from "../services/dashboard-audit.service";
import { assertActiveUserData } from "../services/account-status.service";
import {
	assertMaxLength,
	INPUT_FIELD_LIMITS,
} from "../utils/user-field-validation";
import { BULK_IMPORT_AES_KEY_B64 } from "../config/runtime-secrets";
export const startBulkRegisterStudents = onCall(
	{
		...mediumCallableOptions,
		secrets: [BULK_IMPORT_AES_KEY_B64],
	},
	async (request) => {
		if (!request.auth) {
			throw new HttpsError("unauthenticated", "يجب تسجيل الدخول");
		}

		const callerUid = request.auth.uid;

		const callerDoc = await admin
			.firestore()
			.collection("users")
			.doc(callerUid)
			.get();

		if (!callerDoc.exists) {
			throw new HttpsError("permission-denied", "المستخدم غير موجود");
		}

		const callerData = callerDoc.data() || {};
		const callerRole = String(callerData.role ?? "");
		if (callerRole !== "admin0") {
			throw new HttpsError("permission-denied", "ليس لديك صلاحية");
		}

		assertActiveUserData(callerData);

		const rawStudents = request.data.students;
		const sourceFileName = String(request.data.sourceFileName ?? "").trim();
		assertMaxLength(
			sourceFileName,
			INPUT_FIELD_LIMITS.sourceFileName,
			"اسم الملف طويل جدًا",
		);
		if (!Array.isArray(rawStudents) || rawStudents.length === 0) {
			throw new HttpsError("invalid-argument", "البيانات غير صالحة");
		}

		if (rawStudents.length > MAX_BULK_IMPORT_STUDENTS) {
			throw new HttpsError(
				"invalid-argument",
				`الحد الأقصى الحالي هو ${MAX_BULK_IMPORT_STUDENTS} طالب`,
			);
		}

		const students = rawStudents.map(sanitizeStudent);
		validateDuplicatesInsideFile(students);

		const chunks = chunkArray(students, BULK_IMPORT_CHUNK_SIZE);
		const jobRef = admin.firestore().collection("bulkImports").doc();

		const batch = admin.firestore().batch();
		batch.set(jobRef, {
			jobId: jobRef.id,
			createdBy: callerUid,
			sourceFileName,
			status: "processing",
			totalStudents: students.length,
			totalChunks: chunks.length,
			processedChunks: 0,
			successCount: 0,
			failCount: 0,
			chunkSize: BULK_IMPORT_CHUNK_SIZE,
			createdAt: admin.firestore.FieldValue.serverTimestamp(),
			startedAt: admin.firestore.FieldValue.serverTimestamp(),
			finishedAt: null,
			lastError: "",
			auditFinishedLogged: false,
			createdByRole: String(callerRole ?? ""),
		});

		for (const [index, studentChunk] of chunks.entries()) {
			const chunkRef = jobRef.collection("chunks").doc(index.toString());
			const encrypted = encryptChunkPayload(studentChunk);

			batch.set(chunkRef, {
				index,
				status: "queued",
				totalStudents: studentChunk.length,
				successCount: 0,
				failCount: 0,
				encryptedStudents: encrypted.ciphertextB64,
				encryptedStudentsIv: encrypted.ivB64,
				encryptedStudentsAuthTag: encrypted.authTagB64,
				createdAt: admin.firestore.FieldValue.serverTimestamp(),
				startedAt: null,
				finishedAt: null,
				error: "",
				results: [],
			});
		}

		await batch.commit();

		await writeDashboardAuditLog({
			actorUid: callerUid,
			actorRole: String(callerRole ?? ""),
			action: "bulk_import.started",
			category: "students",
			level: "info",
			targetType: "system",
			targetId: jobRef.id,
			targetLabel: sourceFileName,
			summary: `started bulk import for ${students.length} students`,
			details: {
				jobId: jobRef.id,
				totalStudents: students.length,
				totalChunks: chunks.length,
				sourceFileName,
			},
		}).catch((error) => {
			logger.warn("Bulk import start audit log failed", {
				jobId: jobRef.id,
				error,
			});
		});

		return {
			success: true,
			jobId: jobRef.id,
			totalStudents: students.length,
			totalChunks: chunks.length,
		};
	},
);

async function finalizeBulkImportChunk({
	chunkRef,
	jobRef,
	chunkPatch,
	successCount,
	failCount,
	lastError = "",
}: {
	chunkRef: FirebaseFirestore.DocumentReference;
	jobRef: FirebaseFirestore.DocumentReference;
	chunkPatch: Record<string, any>;
	successCount: number;
	failCount: number;
	lastError?: string;
}): Promise<{
	finalStatus: string;
	finalSuccessCount: number;
	finalFailCount: number;
	totalStudents: number;
	totalChunks: number;
	callerUid: string;
	callerRole: string;
	sourceFileName: string;
} | null> {
	return admin.firestore().runTransaction(async (transaction) => {
		const [chunkDocument, jobDocument] = await transaction.getAll(
			chunkRef,
			jobRef,
		);
		if (!chunkDocument?.exists || !jobDocument?.exists) {
			throw new Error("وظيفة الاستيراد أو الجزء غير موجود");
		}

		const status = String(chunkDocument.data()?.status ?? "");
		if (status === "done" || status === "failed") return null;
		if (status !== "processing") {
			throw new Error(`حالة جزء الاستيراد غير متوقعة: ${status}`);
		}

		const jobData = jobDocument.data() || {};
		const nextProcessedChunks = Number(jobData.processedChunks ?? 0) + 1;
		const nextSuccessCount = Number(jobData.successCount ?? 0) + successCount;
		const nextFailCount = Number(jobData.failCount ?? 0) + failCount;
		const totalChunks = Number(jobData.totalChunks ?? 0);
		const isFinalChunk = totalChunks > 0 && nextProcessedChunks >= totalChunks;
		const finalStatus =
			nextFailCount > 0
				? nextSuccessCount > 0
					? "partial_failed"
					: "failed"
				: "done";

		transaction.update(chunkRef, chunkPatch);
		transaction.update(jobRef, {
			processedChunks: nextProcessedChunks,
			successCount: nextSuccessCount,
			failCount: nextFailCount,
			...(lastError ? { lastError } : {}),
			...(isFinalChunk
				? {
						status: finalStatus,
						finishedAt: admin.firestore.FieldValue.serverTimestamp(),
						auditFinishedLogged: true,
					}
				: {}),
		});

		if (!isFinalChunk || jobData.auditFinishedLogged === true) return null;
		return {
			finalStatus,
			finalSuccessCount: nextSuccessCount,
			finalFailCount: nextFailCount,
			totalStudents: Number(jobData.totalStudents ?? 0),
			totalChunks,
			callerUid: String(jobData.createdBy ?? ""),
			callerRole: String(jobData.createdByRole ?? ""),
			sourceFileName: String(jobData.sourceFileName ?? ""),
		};
	});
}

export const processBulkImportChunk = onDocumentCreated(
	{
		...bulkImportChunkOptions,
		document: "bulkImports/{jobId}/chunks/{chunkId}",
		retry: true,
		secrets: [BULK_IMPORT_AES_KEY_B64],
	},
	async (event) => {
		const snapshot = event.data;
		if (!snapshot) return;

		const chunkRef = snapshot.ref;
		const jobId = event.params.jobId;
		const jobRef = admin.firestore().collection("bulkImports").doc(jobId);
		const claim = await admin
			.firestore()
			.runTransaction(async (transaction) => {
				const current = await transaction.get(chunkRef);
				if (!current.exists) return null;

				const data = current.data() || {};
				const status = String(data.status ?? "queued");
				if (status === "done" || status === "failed") return null;

				const processingStartedAt = data.processingStartedAt;
				const processingStartedAtMs =
					processingStartedAt instanceof admin.firestore.Timestamp
						? processingStartedAt.toMillis()
						: 0;
				if (
					status === "processing" &&
					Date.now() - processingStartedAtMs < 10 * 60 * 1000
				) {
					return { state: "busy" as const, data: {} };
				}

				transaction.update(chunkRef, {
					status: "processing",
					startedAt:
						data.startedAt ?? admin.firestore.FieldValue.serverTimestamp(),
					processingStartedAt: admin.firestore.FieldValue.serverTimestamp(),
					attempts: admin.firestore.FieldValue.increment(1),
					error: "",
				});
				return { state: "claimed" as const, data };
			});

		if (!claim) return;
		if (claim.state === "busy") {
			throw new Error(
				`Bulk import chunk ${event.params.chunkId} is still leased`,
			);
		}
		const chunkData = claim.data;
		const jobSnap = await jobRef.get();

		if (!jobSnap.exists) {
			await chunkRef.update({
				status: "failed",
				error: "وظيفة الاستيراد غير موجودة",
				finishedAt: admin.firestore.FieldValue.serverTimestamp(),
				encryptedStudents: admin.firestore.FieldValue.delete(),
				encryptedStudentsIv: admin.firestore.FieldValue.delete(),
				encryptedStudentsAuthTag: admin.firestore.FieldValue.delete(),
			});
			return;
		}

		const jobData = jobSnap.data() || {};
		const callerUid = String(jobData.createdBy ?? "");

		let rawStudents: any[] = [];
		let totalStudents = Math.max(0, Number(chunkData.totalStudents ?? 0) || 0);
		let finalSuccessCount = 0;
		let finalFailCount = 0;
		let processingError = "";
		let finalResults: Array<{
			userId: string;
			success: boolean;
			error?: string;
		}> = [];

		try {
			const encryptedStudents = String(chunkData.encryptedStudents ?? "");
			const encryptedStudentsIv = String(chunkData.encryptedStudentsIv ?? "");
			const encryptedStudentsAuthTag = String(
				chunkData.encryptedStudentsAuthTag ?? "",
			);

			if (
				!encryptedStudents ||
				!encryptedStudentsIv ||
				!encryptedStudentsAuthTag
			) {
				throw new Error("بيانات chunk غير مكتملة");
			}

			rawStudents = decryptChunkPayload<any[]>(
				encryptedStudents,
				encryptedStudentsIv,
				encryptedStudentsAuthTag,
			);

			totalStudents = rawStudents.length;

			const groupsMap = await loadGroupsMap();

			let successCount = 0;
			let failCount = 0;

			const results: Array<{
				userId: string;
				success: boolean;
				error?: string;
			}> = [];

			for (const studentBatch of chunkArray(rawStudents, 4)) {
				const outcomes = await Promise.all(
					studentBatch.map(async (rawStudent) => {
						const student = sanitizeStudent(rawStudent);
						try {
							await createStudentFromBulkJob({
								student,
								callerUid,
								jobId,
								groupsMap,
							});
							return { userId: student.userId, success: true as const };
						} catch (error: any) {
							return {
								userId: student.userId,
								success: false as const,
								error: error?.message || String(error),
							};
						}
					}),
				);

				for (const outcome of outcomes) {
					if (outcome.success) {
						successCount++;
					} else {
						failCount++;
					}
					results.push(outcome);
				}
			}

			finalSuccessCount = successCount;
			finalFailCount = failCount;
			finalResults = results;
		} catch (e: any) {
			processingError = e?.message || String(e);
			finalFailCount = totalStudents;
		}

		const finalAudit = await finalizeBulkImportChunk({
			chunkRef,
			jobRef,
			successCount: finalSuccessCount,
			failCount: finalFailCount,
			lastError: processingError,
			chunkPatch: {
				status: processingError ? "failed" : "done",
				successCount: finalSuccessCount,
				failCount: finalFailCount,
				results: finalResults,
				error: processingError,
				finishedAt: admin.firestore.FieldValue.serverTimestamp(),
				encryptedStudents: admin.firestore.FieldValue.delete(),
				encryptedStudentsIv: admin.firestore.FieldValue.delete(),
				encryptedStudentsAuthTag: admin.firestore.FieldValue.delete(),
			},
		});

		if (finalAudit) {
			await writeDashboardAuditLog({
				actorUid: finalAudit.callerUid,
				actorRole: finalAudit.callerRole,
				action: "bulk_import.finished",
				category: "students",
				level: finalAudit.finalFailCount > 0 ? "warning" : "info",
				targetType: "system",
				targetId: jobId,
				targetLabel: finalAudit.sourceFileName,
				summary: `finished bulk import with ${finalAudit.finalSuccessCount} successes and ${finalAudit.finalFailCount} failures`,
				details: {
					jobId,
					status: finalAudit.finalStatus,
					totalStudents: finalAudit.totalStudents,
					totalChunks: finalAudit.totalChunks,
					successCount: finalAudit.finalSuccessCount,
					failCount: finalAudit.finalFailCount,
					sourceFileName: finalAudit.sourceFileName,
				},
			}).catch((error) => {
				logger.warn("Bulk import completion audit log failed", {
					jobId,
					error,
				});
			});
		}
	},
);
