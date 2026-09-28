part of '../group_repository.dart';

extension GroupRepositoryAttachments on GroupRepository {
  Future<String> getChatAttachmentUrl({
    required String groupId,
    required String storagePath,
  }) async {
    final cleanGroupId = groupId.trim();
    final cleanPath = storagePath.trim().replaceFirst(RegExp(r'^/+'), '');
    if (cleanGroupId.isEmpty || cleanPath.isEmpty) return '';

    try {
      final callable = _functions.httpsCallable('getChatAttachmentUrl');
      final response = await callable.call({
        'groupId': cleanGroupId,
        'storagePath': cleanPath,
      });

      final data = Map<String, dynamic>.from(response.data as Map);
      final url = (data['url'] ?? '').toString().trim();
      if (url.isNotEmpty) return url;
      throw Exception(tr('attachments.open_temp_failed'));
    } on FirebaseFunctionsException catch (e) {
      if (e.code == 'not-found') return '';
      if (e.code == 'permission-denied' || e.code == 'unauthenticated') {
        throw Exception(tr('attachments.open_permission_denied'));
      }
      throw Exception(tr('attachments.open_temp_failed'));
    }
  }


  Future<void> deleteStorageFile(String? storagePath, {String? groupId}) async {
    final path = storagePath?.trim();

    if (path == null || path.isEmpty) return;

    final cleanGroupId = groupId?.trim() ?? '';

    if (cleanGroupId.isNotEmpty) {
      try {
        final callable = _functions.httpsCallable('cleanupUnlinkedChatUpload');
        await callable.call({
          'groupId': cleanGroupId,
          'storagePath': path,
        });
        return;
      } catch (error, stackTrace) {
        AppErrorMonitor.recordHandled(
          error,
          stackTrace,
          context: 'cleanup_unlinked_chat_upload',
        );
        return;
      }
    }

    try {
      await _storage.ref().child(path).delete();
    } on FirebaseException catch (e) {
      if (e.code == 'object-not-found' ||
          e.code == 'unauthorized' ||
          e.code == 'permission-denied') {
        return;
      }
      rethrow;
    } catch (error, stackTrace) {
      AppErrorMonitor.recordHandled(
        error,
        stackTrace,
        context: 'delete_storage_file',
      );
    }
  }


  Future<UploadedFileInfo> uploadFile({
    required File file,
    required String groupId,
    required String folder,
    String? fileName,
    UploadProgressCallback? onProgress,
    bool createDownloadUrl = true,
  }) async {
    final cleanFileName = fileName?.trim();
    if (cleanFileName != null && cleanFileName.length > 120) {
      throw Exception(tr('attachments.upload_file_name_too_long'));
    }

    final generatedName = _buildStorageFileName(file, fileName: cleanFileName);
    final storagePath = '$folder/$groupId/$generatedName';
    final ref = _storage.ref().child(storagePath);

    StreamSubscription<TaskSnapshot>? progressSub;

    try {
      final contentType = AppFileMetadata.contentTypeFor(
        file: file,
        folder: folder,
        fileName: cleanFileName,
      );

      await _validateUpload(
        file: file,
        folder: folder,
        contentType: contentType,
      );

      final metadata = SettableMetadata(
        contentType: contentType,
        customMetadata: {
          'groupId': groupId,
          'folder': folder,
        },
      );

      final uploadTask = ref.putFile(file, metadata);

      if (onProgress != null) {
        progressSub = uploadTask.snapshotEvents.listen((snapshot) {
          final totalBytes = snapshot.totalBytes;

          if (totalBytes <= 0) return;

          final progress = snapshot.bytesTransferred / totalBytes;
          onProgress(progress.clamp(0, 1).toDouble());
        });
      }

      final snapshot = await uploadTask;
      onProgress?.call(1);

      final url = createDownloadUrl ? await snapshot.ref.getDownloadURL() : '';

      return UploadedFileInfo(
        url: url,
        storagePath: storagePath,
      );
    } on FirebaseException catch (e) {
      if (e.code == 'unauthorized' ||
          e.code == 'permission-denied' ||
          e.code == 'unauthenticated') {
        throw ChatOperationException(
          'attachments.upload_permission_denied',
          code: e.code,
          retryable: false,
        );
      }
      if (e.code == 'canceled') {
        throw ChatOperationException(
          'attachments.upload_canceled',
          code: e.code,
          retryable: false,
        );
      }
      if (e.code == 'invalid-argument' || e.code == 'object-not-found') {
        throw ChatOperationException(
          'attachments.upload_failed',
          code: e.code,
          retryable: false,
        );
      }

      throw ChatOperationException(
        'attachments.upload_failed',
        code: e.code,
        retryable: true,
      );
    } finally {
      await progressSub?.cancel();
    }
  }
}
