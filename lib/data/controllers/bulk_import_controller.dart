import 'dart:async';

import 'package:easy_localization/easy_localization.dart';

import '../../core/utils/error_message.dart';
import '../repositories/bulk_import_repository.dart';

class BulkImportController {
  final BulkImportRepository _repository = BulkImportRepository();

  bool isLoading = false;
  bool isJobRunning = false;

  String selectedFileName = '';
  String sourceFileName = '';
  String activeJobId = '';
  String jobStatus = '';

  int totalStudents = 0;
  int totalChunks = 0;
  int processedChunks = 0;
  int successCount = 0;
  int failCount = 0;

  List<Map<String, dynamic>> parsedStudents = [];

  StreamSubscription<Map<String, dynamic>?>? _jobSub;


  double get progressValue {
    if (totalStudents <= 0) return 0;
    final processed = successCount + failCount;
    return (processed / totalStudents).clamp(0.0, 1.0);
  }

  String get statusText {
    switch (jobStatus) {
      case 'queued':
        return tr('auth.bulk_import.upload_job_ready');
      case 'processing':
        return tr('auth.bulk_import.uploading_students');
      case 'done':
        return tr('auth.bulk_import.upload_completed');
      case 'partial_failed':
        return tr('auth.bulk_import.upload_completed_some_errors');
      case 'failed':
        return tr('auth.bulk_import.upload_failed');
      default:
        return tr('auth.bulk_import.no_active_operation');
    }
  }

  String _cleanError(Object error) {
    return cleanErrorMessage(
      error,
      fallback: tr('auth.bulk_import.could_not_complete_import_try_again'),
    );
  }

  Future<String?> pickFile() async {
    try {
      isLoading = true;

      parsedStudents = [];
      selectedFileName = '';
      activeJobId = '';
      jobStatus = '';
      totalStudents = 0;
      totalChunks = 0;
      processedChunks = 0;
      successCount = 0;
      failCount = 0;

      final data = await _repository.pickAndParseFile();

      parsedStudents = data;
      selectedFileName = tr('auth.bulk_import.value_records_loaded', args: ['${data.length}']);
      sourceFileName = _repository.lastPickedFileName;
      isLoading = false;
      return null;
    } catch (e) {
      parsedStudents = [];
      selectedFileName = '';
      sourceFileName = '';
      activeJobId = '';
      jobStatus = '';
      totalStudents = 0;
      totalChunks = 0;
      processedChunks = 0;
      successCount = 0;
      failCount = 0;

      isLoading = false;
      return _cleanError(e);
    }
  }

  Future<String?> uploadStudents({
    required void Function() onChanged,
  }) async {
    try {
      if (parsedStudents.isEmpty) {
        return tr('auth.bulk_import.choose_file_first');
      }

      isLoading = true;
      onChanged();

      final result = await _repository.startBulkImport(
        parsedStudents,
        sourceFileName: sourceFileName.isNotEmpty ? sourceFileName : selectedFileName,
      );

      activeJobId = (result['jobId'] ?? '').toString();
      totalStudents = (result['totalStudents'] ?? parsedStudents.length) as int;
      totalChunks = (result['totalChunks'] ?? 0) as int;
      processedChunks = 0;
      successCount = 0;
      failCount = 0;
      jobStatus = 'queued';
      isLoading = false;
      isJobRunning = true;

      onChanged();

      await _jobSub?.cancel();
      _jobSub = _repository.watchBulkImportJob(activeJobId).listen(
        (data) {
          if (data == null) return;

          jobStatus = (data['status'] ?? '').toString();
          totalStudents = (data['totalStudents'] ?? totalStudents) as int;
          totalChunks = (data['totalChunks'] ?? totalChunks) as int;
          processedChunks = (data['processedChunks'] ?? processedChunks) as int;
          successCount = (data['successCount'] ?? successCount) as int;
          failCount = (data['failCount'] ?? failCount) as int;

          isJobRunning = jobStatus == 'queued' || jobStatus == 'processing';

          onChanged();
        },
        onError: (Object error) {
          jobStatus = 'failed';
          isJobRunning = false;
          isLoading = false;
          selectedFileName = _cleanError(error);
          onChanged();
        },
      );

      return null;
    } catch (e) {
      isLoading = false;
      isJobRunning = false;
      onChanged();
      return _cleanError(e);
    }
  }

  void reset() {
    parsedStudents = [];
    selectedFileName = '';
    sourceFileName = '';
    activeJobId = '';
    jobStatus = '';
    totalStudents = 0;
    totalChunks = 0;
    processedChunks = 0;
    successCount = 0;
    failCount = 0;
    isJobRunning = false;
  }

  Future<void> dispose() async {
    await _jobSub?.cancel();
    reset();
  }
}
