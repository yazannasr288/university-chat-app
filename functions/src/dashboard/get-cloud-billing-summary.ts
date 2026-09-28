import { onCall, HttpsError } from "firebase-functions/v2/https";
import * as admin from "firebase-admin";

import { assertAdmin0OrThrow } from "../services/dashboard-user.service";
import { mediumCallableOptions } from "../runtime-options";

type BillingScope = "project" | "billing_account";

const MICROS = 1_000_000;
const CACHE_COLLECTION = "adminBillingCache";

function toNumber(value: any): number {
	if (value === null || value === undefined) return 0;
	if (typeof value === "number") return value;
	if (typeof value === "string") return Number(value) || 0;
	if (typeof value.value === "number") return value.value;
	if (typeof value.value === "string") return Number(value.value) || 0;
	return Number(value) || 0;
}

function toStringValue(value: any): string {
	if (value === null || value === undefined) return "";
	if (typeof value === "string") return value;
	if (typeof value.value === "string") return value.value;
	return String(value);
}

function timestampToIso(value: any): string {
	if (!value) return "";
	if (typeof value === "string") return value;
	if (value instanceof Date) return value.toISOString();
	if (value.value) return new Date(value.value).toISOString();
	return String(value);
}

function moneyFromMicros(value: number): number {
	return Math.round(value) / MICROS;
}

function assertId(value: unknown, label: string, pattern: RegExp): string {
	const raw = String(value ?? "").trim();

	if (!raw || !pattern.test(raw)) {
		throw new HttpsError(
			"failed-precondition",
			`إعداد ${label} غير صحيح في systemSettings/cloudBilling`,
		);
	}

	return raw;
}

function readPositiveInt(value: unknown, fallback: number): number {
	const parsed = Number(value ?? fallback);
	return Number.isInteger(parsed) && parsed > 0 ? parsed : fallback;
}

function readScope(value: unknown): BillingScope {
	const raw = String(value ?? "project").trim();

	if (raw === "billing_account") return "billing_account";
	return "project";
}

function readYear(value: unknown): number {
	const now = new Date();
	const parsed = Number(value ?? now.getUTCFullYear());

	if (!Number.isInteger(parsed) || parsed < 2020 || parsed > 2100) {
		throw new HttpsError("invalid-argument", "السنة غير صالحة");
	}

	return parsed;
}

function readMonth(value: unknown): number {
	const now = new Date();
	const parsed = Number(value ?? now.getUTCMonth() + 1);

	if (!Number.isInteger(parsed) || parsed < 1 || parsed > 12) {
		throw new HttpsError("invalid-argument", "الشهر غير صالح");
	}

	return parsed;
}

function invoiceMonth(year: number, month: number): string {
	return `${year}${String(month).padStart(2, "0")}`;
}

async function loadBillingSettings() {
	const doc = await admin
		.firestore()
		.collection("systemSettings")
		.doc("cloudBilling")
		.get();

	if (!doc.exists) {
		throw new HttpsError(
			"failed-precondition",
			"وثيقة systemSettings/cloudBilling غير موجودة",
		);
	}

	const data = doc.data() || {};

	const datasetProjectId = assertId(
		data.datasetProjectId,
		"datasetProjectId",
		/^[A-Za-z0-9_-]+$/,
	);

	const jobProjectId = assertId(
		data.jobProjectId || datasetProjectId,
		"jobProjectId",
		/^[A-Za-z0-9_-]+$/,
	);

	const datasetId = assertId(
		data.datasetId,
		"datasetId",
		/^[A-Za-z_][A-Za-z0-9_]*$/,
	);

	const standardTableId = assertId(
		data.standardTableId,
		"standardTableId",
		/^[A-Za-z0-9_]+$/,
	);

	const appProjectId = String(
		data.appProjectId ||
			process.env.GCLOUD_PROJECT ||
			process.env.GCP_PROJECT ||
			"",
	).trim();

	const scope = readScope(data.scope);

	if (scope === "project" && !appProjectId) {
		throw new HttpsError(
			"failed-precondition",
			"appProjectId مطلوب عند استخدام scope = project",
		);
	}

	return {
		datasetProjectId,
		jobProjectId,
		datasetId,
		standardTableId,
		appProjectId,
		scope,
		datasetLocation: String(data.datasetLocation ?? "US").trim() || "US",
		cacheTtlMinutes: readPositiveInt(data.cacheTtlMinutes, 60),
	};
}

function addToAggregate(
	map: Map<string, any>,
	key: string,
	patch: {
		name: string;
		grossMicros: number;
		creditsMicros: number;
		netMicros: number;
		lineCount: number;
	},
) {
	const current = map.get(key) || {
		name: patch.name,
		grossMicros: 0,
		creditsMicros: 0,
		netMicros: 0,
		lineCount: 0,
	};

	current.grossMicros += patch.grossMicros;
	current.creditsMicros += patch.creditsMicros;
	current.netMicros += patch.netMicros;
	current.lineCount += patch.lineCount;

	map.set(key, current);
}

function aggregateToList(map: Map<string, any>) {
	return Array.from(map.values())
		.map((item) => ({
			name: item.name,
			grossCost: moneyFromMicros(item.grossMicros),
			credits: moneyFromMicros(item.creditsMicros),
			totalCost: moneyFromMicros(item.netMicros),
			lineCount: item.lineCount,
		}))
		.sort((a, b) => Math.abs(b.totalCost) - Math.abs(a.totalCost));
}
type CostCategoryKey =
	| "auth"
	| "database"
	| "storage"
	| "functions_runtime"
	| "messaging"
	| "hosting"
	| "billing_analytics"
	| "deploy_build"
	| "logs_monitoring"
	| "network"
	| "tax_adjustments"
	| "other";

const COST_CATEGORY_ORDER: CostCategoryKey[] = [
	"auth",
	"database",
	"storage",
	"functions_runtime",
	"messaging",
	"hosting",
	"billing_analytics",
	"deploy_build",
	"logs_monitoring",
	"network",
	"tax_adjustments",
	"other",
];

const CORE_CATEGORY_KEYS = new Set<CostCategoryKey>([
	"auth",
	"database",
	"storage",
	"functions_runtime",
	"messaging",
	"hosting",
]);

function createEmptyCategory(key: CostCategoryKey) {
	return {
		key,
		grossMicros: 0,
		creditsMicros: 0,
		netMicros: 0,
		lineCount: 0,
		skuCount: 0,
		services: new Set<string>(),
	};
}

function seedCostCategories() {
	const map = new Map<CostCategoryKey, any>();

	for (const key of COST_CATEGORY_ORDER) {
		map.set(key, createEmptyCategory(key));
	}

	return map;
}

function detectCostCategory(
	serviceName: string,
	skuName: string,
	costType: string,
): CostCategoryKey {
	const service = serviceName.toLowerCase();
	const sku = skuName.toLowerCase();
	const type = costType.toLowerCase();

	if (type === "tax" || type === "adjustment" || type === "rounding_error") {
		return "tax_adjustments";
	}

	if (
		service.includes("firebase authentication") ||
		service.includes("identity platform") ||
		service.includes("cloud identity") ||
		sku.includes("phone auth") ||
		sku.includes("sms") ||
		sku.includes("verification")
	) {
		return "auth";
	}

	if (
		service.includes("cloud firestore") ||
		service.includes("firestore") ||
		service.includes("realtime database") ||
		service.includes("firebase database") ||
		service.includes("cloud datastore")
	) {
		return "database";
	}

	if (
		service.includes("cloud storage") ||
		service.includes("firebase storage")
	) {
		return "storage";
	}

	if (
		service.includes("cloud functions") ||
		service.includes("cloud run") ||
		service.includes("eventarc") ||
		service.includes("cloud scheduler") ||
		service.includes("cloud tasks") ||
		service.includes("pub/sub")
	) {
		return "functions_runtime";
	}

	if (
		service.includes("firebase cloud messaging") ||
		service.includes("cloud messaging") ||
		service.includes("firebase notifications")
	) {
		return "messaging";
	}

	if (
		service.includes("firebase hosting") ||
		service.includes("cloud hosting")
	) {
		return "hosting";
	}

	if (service.includes("bigquery")) {
		return "billing_analytics";
	}

	if (
		service.includes("cloud build") ||
		service.includes("artifact registry") ||
		service.includes("container registry")
	) {
		return "deploy_build";
	}

	if (
		service.includes("cloud logging") ||
		service.includes("cloud monitoring") ||
		service.includes("operations") ||
		service.includes("error reporting") ||
		service.includes("cloud trace")
	) {
		return "logs_monitoring";
	}

	if (
		service.includes("network") ||
		service.includes("vpc") ||
		service.includes("cloud cdn") ||
		service.includes("load balancing") ||
		sku.includes("egress")
	) {
		return "network";
	}

	return "other";
}

function addToCostCategory(
	map: Map<CostCategoryKey, any>,
	key: CostCategoryKey,
	patch: {
		serviceName: string;
		grossMicros: number;
		creditsMicros: number;
		netMicros: number;
		lineCount: number;
	},
) {
	const current = map.get(key) || createEmptyCategory(key);

	current.grossMicros += patch.grossMicros;
	current.creditsMicros += patch.creditsMicros;
	current.netMicros += patch.netMicros;
	current.lineCount += patch.lineCount;
	current.skuCount += 1;

	if (patch.serviceName.trim()) {
		current.services.add(patch.serviceName.trim());
	}

	map.set(key, current);
}

function costCategoriesToList(map: Map<CostCategoryKey, any>) {
	return Array.from(map.values())
		.filter((item) => {
			const isCore = CORE_CATEGORY_KEYS.has(item.key);
			const hasCost =
				Math.abs(item.grossMicros) > 0 ||
				Math.abs(item.creditsMicros) > 0 ||
				Math.abs(item.netMicros) > 0;

			return isCore || hasCost;
		})
		.map((item) => ({
			key: item.key,
			grossCost: moneyFromMicros(item.grossMicros),
			credits: moneyFromMicros(item.creditsMicros),
			totalCost: moneyFromMicros(item.netMicros),
			lineCount: item.lineCount,
			skuCount: item.skuCount,
			services: Array.from(item.services).sort(),
		}))
		.sort((a, b) => {
			const aAbs = Math.abs(a.totalCost);
			const bAbs = Math.abs(b.totalCost);

			if (aAbs !== bAbs) return bAbs - aAbs;

			return (
				COST_CATEGORY_ORDER.indexOf(a.key as CostCategoryKey) -
				COST_CATEGORY_ORDER.indexOf(b.key as CostCategoryKey)
			);
		});
}

export const getCloudBillingSummary = onCall(
	mediumCallableOptions,
	async (request) => {
		if (!request.auth) {
			throw new HttpsError("unauthenticated", "يجب تسجيل الدخول");
		}

		await assertAdmin0OrThrow(request.auth.uid);

		const year = readYear(request.data.year);
		const month = readMonth(request.data.month);
		const invoice = invoiceMonth(year, month);
		const forceRefresh = request.data.forceRefresh === true;

		const settings = await loadBillingSettings();

		const cacheId = [
			settings.scope,
			settings.appProjectId || "all",
			invoice,
		].join("_");

		const cacheRef = admin
			.firestore()
			.collection(CACHE_COLLECTION)
			.doc(cacheId);

		if (!forceRefresh) {
			const cached = await cacheRef.get();

			if (cached.exists) {
				const data = cached.data() || {};
				const cachedAtMs = Number(data.cachedAtMs ?? 0);
				const ageMs = Date.now() - cachedAtMs;
				const ttlMs = settings.cacheTtlMinutes * 60 * 1000;

				if (cachedAtMs > 0 && ageMs < ttlMs && data.summary) {
					return {
						success: true,
						fromCache: true,
						summary: data.summary,
					};
				}
			}
		}

		const tablePath =
			`${settings.datasetProjectId}.` +
			`${settings.datasetId}.` +
			`${settings.standardTableId}`;

		const projectFilter =
			settings.scope === "project" ? "AND project.id = @appProjectId" : "";

		const query = `
      SELECT
        COALESCE(service.description, 'غير مصنف') AS serviceName,
        COALESCE(sku.description, 'غير مصنف') AS skuName,
        COALESCE(cost_type, 'regular') AS costType,
        ANY_VALUE(currency) AS currency,

        SUM(CAST(cost * 1000000 AS INT64)) AS grossMicros,

        SUM(
          IFNULL(
            (
              SELECT SUM(CAST(c.amount * 1000000 AS INT64))
              FROM UNNEST(credits) AS c
            ),
            0
          )
        ) AS creditsMicros,

        SUM(CAST(cost * 1000000 AS INT64))
        +
        SUM(
          IFNULL(
            (
              SELECT SUM(CAST(c.amount * 1000000 AS INT64))
              FROM UNNEST(credits) AS c
            ),
            0
          )
        ) AS netMicros,

        COUNT(1) AS lineCount,
        MAX(export_time) AS lastExportTime
      FROM \`${tablePath}\`
      WHERE invoice.month = @invoiceMonth
      ${projectFilter}
      GROUP BY serviceName, skuName, costType
      ORDER BY ABS(netMicros) DESC
    `;

		// BigQuery is only needed on an uncached billing request. Loading it here
		// keeps the heavy client out of the cold-start path of every exported
		// Firebase function in this bundle.
		const { BigQuery } = await import("@google-cloud/bigquery");
		const bigquery = new BigQuery({
			projectId: settings.jobProjectId,
		});

		const [rows] = await bigquery.query({
			query,
			location: settings.datasetLocation,
			params: {
				invoiceMonth: invoice,
				appProjectId: settings.appProjectId,
			},
		});

		const services = new Map<string, any>();
		const costTypes = new Map<string, any>();
		const categories = seedCostCategories();
		let grossMicros = 0;
		let creditsMicros = 0;
		let netMicros = 0;
		let lineCount = 0;
		let currency = "";
		let lastExportTime = "";

		const skuItems = rows.map((row: any) => {
			const serviceName = toStringValue(row.serviceName) || "غير مصنف";
			const skuName = toStringValue(row.skuName) || "غير مصنف";
			const costType = toStringValue(row.costType) || "regular";
			const rowCurrency = toStringValue(row.currency);

			const rowGrossMicros = toNumber(row.grossMicros);
			const rowCreditsMicros = toNumber(row.creditsMicros);
			const rowNetMicros = toNumber(row.netMicros);
			const rowLineCount = toNumber(row.lineCount);

			if (!currency && rowCurrency) currency = rowCurrency;

			const rowLastExportTime = timestampToIso(row.lastExportTime);
			if (rowLastExportTime && rowLastExportTime > lastExportTime) {
				lastExportTime = rowLastExportTime;
			}

			grossMicros += rowGrossMicros;
			creditsMicros += rowCreditsMicros;
			netMicros += rowNetMicros;
			lineCount += rowLineCount;

			addToAggregate(services, serviceName, {
				name: serviceName,
				grossMicros: rowGrossMicros,
				creditsMicros: rowCreditsMicros,
				netMicros: rowNetMicros,
				lineCount: rowLineCount,
			});

			addToAggregate(costTypes, costType, {
				name: costType,
				grossMicros: rowGrossMicros,
				creditsMicros: rowCreditsMicros,
				netMicros: rowNetMicros,
				lineCount: rowLineCount,
			});
			const categoryKey = detectCostCategory(serviceName, skuName, costType);

			addToCostCategory(categories, categoryKey, {
				serviceName,
				grossMicros: rowGrossMicros,
				creditsMicros: rowCreditsMicros,
				netMicros: rowNetMicros,
				lineCount: rowLineCount,
			});

			return {
				serviceName,
				skuName,
				costType,
				currency: rowCurrency,
				grossCost: moneyFromMicros(rowGrossMicros),
				credits: moneyFromMicros(rowCreditsMicros),
				totalCost: moneyFromMicros(rowNetMicros),
				lineCount: rowLineCount,
			};
		});

		const summary = {
			year,
			month,
			invoiceMonth: invoice,

			scope: settings.scope,
			appProjectId: settings.appProjectId,
			currency: currency || "USD",

			grossCost: moneyFromMicros(grossMicros),
			credits: moneyFromMicros(creditsMicros),
			totalCost: moneyFromMicros(netMicros),

			lineCount,
			lastExportTime,
			generatedAtMs: Date.now(),

			categories: costCategoriesToList(categories),
			services: aggregateToList(services),
			costTypes: aggregateToList(costTypes),
			skus: skuItems,
		};

		await cacheRef.set(
			{
				summary,
				cachedAtMs: Date.now(),
				createdBy: request.auth.uid,
			},
			{ merge: true },
		);

		return {
			success: true,
			fromCache: false,
			summary,
		};
	},
);
