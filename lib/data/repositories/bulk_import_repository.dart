import 'dart:convert';
import 'dart:io';
import '../../core/permissions/app_roles.dart';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:excel/excel.dart';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';

class BulkImportRepository {
  static const List<String> _allowedExtensions = ['json', 'xlsx'];
  static const int _maxStudentsPerImport = 1500;
  static const int _maxImportFileBytes = 8 * 1024 * 1024;

  static const List<String> _requiredHeaders = [
    'fullName',
    'userId',
    'phone',
    'department',
    'password',
    'accountType',
  ];

  final FirebaseFunctions _functions;
  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  String lastPickedFileName = '';

  BulkImportRepository({
    FirebaseFunctions? functions,
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
  })  : _functions =
      functions ?? FirebaseFunctions.instanceFor(region: 'us-central1'),
        _firestore = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance;

  Future<List<Map<String, dynamic>>> pickAndParseFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: _allowedExtensions,
      withData: false,
    );

    if (result == null || result.files.isEmpty) {
      throw Exception(tr('auth.bulk_import.no_file_was_selected'));
    }

    final file = result.files.first;
    lastPickedFileName = file.name.trim();

    final extension = file.extension?.toLowerCase().trim();

    if (extension == 'json') {
      return _parseJsonFile(file);
    }

    if (extension == 'xlsx') {
      return _parseExcelFile(file);
    }

    throw Exception(tr('chat.unsupported_file_type'));
  }

  Future<List<int>> _readBytes(PlatformFile file) async {
    final path = file.path;

    if (path != null && path.trim().isNotEmpty) {
      final diskBytes = await File(path).readAsBytes();

      if (diskBytes.length > _maxImportFileBytes) {
        throw Exception('حجم ملف الاستيراد كبير جدًا. الحد الأقصى 8MB');
      }

      if (diskBytes.isNotEmpty) {
        return diskBytes;
      }
    }

    final memoryBytes = file.bytes;

    if (memoryBytes != null && memoryBytes.isNotEmpty) {
      if (memoryBytes.length > _maxImportFileBytes) {
        throw Exception('حجم ملف الاستيراد كبير جدًا. الحد الأقصى 8MB');
      }

      return memoryBytes;
    }

    throw Exception('تعذر قراءة الملف المختار');
  }

  Map<String, dynamic> _normalizeStudent(Map<String, dynamic> item) {
    final accountType = (item['accountType'] ?? AppRoles.user).toString().trim();

    return {
      'fullName': (item['fullName'] ?? '').toString().trim(),
      'userId': (item['userId'] ?? '').toString().trim(),
      'phone': (item['phone'] ?? '').toString().trim(),
      'department': (item['department'] ?? '').toString().trim(),
      'password': (item['password'] ?? '').toString().trim(),
      'accountType': accountType.isEmpty ? AppRoles.user : accountType,
    };
  }

  void _validateParsedStudents(List<Map<String, dynamic>> students) {
    if (students.isEmpty) {
      throw Exception('الملف لا يحتوي على طلاب');
    }

    if (students.length > _maxStudentsPerImport) {
      throw Exception('عدد الطلاب في الملف يتجاوز الحد الأقصى $_maxStudentsPerImport طالب');
    }

    final seenUserIds = <String, int>{};
    final seenPhones = <String, int>{};

    for (var i = 0; i < students.length; i++) {
      final rowNumber = i + 2;
      final student = students[i];

      final fullName = student['fullName']?.toString().trim() ?? '';
      final userId = student['userId']?.toString().trim() ?? '';
      final phone = student['phone']?.toString().trim() ?? '';
      final department = student['department']?.toString().trim() ?? '';
      final password = student['password']?.toString().trim() ?? '';
      final accountType = student['accountType']?.toString().trim() ?? '';

      if (fullName.isEmpty) {
        throw Exception('الاسم مفقود في السطر $rowNumber');
      }

      if (userId.isEmpty) {
        throw Exception('الرقم الجامعي مفقود في السطر $rowNumber');
      }

      if (phone.isEmpty) {
        throw Exception('رقم الهاتف مفقود في السطر $rowNumber');
      }

      if (department.isEmpty) {
        throw Exception('القسم مفقود في السطر $rowNumber');
      }

      if (password.isEmpty) {
        throw Exception('كلمة المرور مفقودة في السطر $rowNumber');
      }

      if (accountType.isEmpty) {
        throw Exception('نوع الحساب مفقود في السطر $rowNumber');
      }

      if (fullName.length > 80) {
        throw Exception('الاسم طويل جدًا في السطر $rowNumber');
      }

      if (userId.length > 40) {
        throw Exception('الرقم الجامعي طويل جدًا في السطر $rowNumber');
      }

      if (phone.length > 25) {
        throw Exception('رقم الهاتف طويل جدًا في السطر $rowNumber');
      }

      if (password.length > 128) {
        throw Exception('كلمة المرور طويلة جدًا في السطر $rowNumber');
      }

      final normalizedUserId = userId.toLowerCase();
      final normalizedPhone = phone.replaceAll(RegExp(r'\s+'), '');

      if (seenUserIds.containsKey(normalizedUserId)) {
        throw Exception('الرقم الجامعي $userId مكرر في السطرين ${seenUserIds[normalizedUserId]} و $rowNumber');
      }

      if (seenPhones.containsKey(normalizedPhone)) {
        throw Exception('رقم الهاتف $phone مكرر في السطرين ${seenPhones[normalizedPhone]} و $rowNumber');
      }

      seenUserIds[normalizedUserId] = rowNumber;
      seenPhones[normalizedPhone] = rowNumber;
    }
  }

  Future<List<Map<String, dynamic>>> _parseJsonFile(PlatformFile file) async {
    final bytes = await _readBytes(file);

    late final dynamic decoded;

    try {
      final text = utf8.decode(bytes);
      decoded = jsonDecode(text);
    } catch (_) {
      throw Exception('ملف JSON غير قابل للقراءة أو يحتوي على تنسيق غير صحيح');
    }

    final List<dynamic> rows;

    if (decoded is List) {
      rows = decoded;
    } else if (decoded is Map && decoded['students'] is List) {
      rows = decoded['students'] as List;
    } else {
      throw Exception(tr('auth.bulk_import.json_file_must_list'));
    }

    final students = rows.map<Map<String, dynamic>>((item) {
      if (item is! Map) {
        throw Exception('كل عنصر داخل ملف JSON يجب أن يكون Object');
      }

      return _normalizeStudent(Map<String, dynamic>.from(item));
    }).toList();

    _validateParsedStudents(students);
    return students;
  }

  String _cellToString(dynamic cellValue) {
    if (cellValue == null) return '';

    if (cellValue is TextCellValue) {
      return cellValue.toString().trim();
    }

    if (cellValue is IntCellValue) {
      return cellValue.value.toString().trim();
    }

    if (cellValue is DoubleCellValue) {
      final value = cellValue.value;

      if (value == value.roundToDouble()) {
        return value.toInt().toString();
      }

      return value.toString().trim();
    }

    if (cellValue is BoolCellValue) {
      return cellValue.value.toString().trim();
    }

    if (cellValue is FormulaCellValue) {
      throw Exception('لا يمكن استخدام صيغ Excel داخل ملف الاستيراد. انسخ القيم النهائية بدل الصيغ ثم أعد المحاولة.');
    }

    if (cellValue is DateCellValue) {
      return cellValue.asDateTimeLocal().toIso8601String();
    }

    if (cellValue is DateTimeCellValue) {
      return cellValue.asDateTimeLocal().toIso8601String();
    }

    if (cellValue is TimeCellValue) {
      return cellValue.asDuration().toString().trim();
    }

    return cellValue.toString().trim();
  }

  Future<List<Map<String, dynamic>>> _parseExcelFile(PlatformFile file) async {
    final bytes = await _readBytes(file);

    if (bytes.length < 4 || bytes[0] != 0x50 || bytes[1] != 0x4B) {
      throw Exception(
        'الملف المختار ليس ملف Excel بصيغة .xlsx. افتحه في Excel أو Google Sheets ثم احفظه كـ .xlsx من جديد.',
      );
    }

    late final Excel excel;

    try {
      excel = Excel.decodeBytes(bytes);
    } catch (_) {
      throw Exception(
        'ملف Excel غير قابل للقراءة. تأكد أنه .xlsx حقيقي وليس .xls تم تغيير اسمه فقط.',
      );
    }

    if (excel.tables.isEmpty) {
      throw Exception(tr('auth.bulk_import.excel_file_empty'));
    }

    Sheet? sheet;

    for (final item in excel.tables.values) {
      if (item.rows.isNotEmpty) {
        sheet = item;
        break;
      }
    }

    if (sheet == null || sheet.rows.isEmpty) {
      throw Exception(tr('auth.bulk_import.excel_file_contains_no_data'));
    }

    final rows = sheet.rows;

    final headers = rows.first.map((cell) {
      return _cellToString(cell?.value).replaceAll('\uFEFF', '').trim();
    }).toList();

    for (final header in _requiredHeaders) {
      if (!headers.contains(header)) {
        throw Exception(tr('auth.bulk_import.column_value_missing_excel_file', args: [header]));
      }
    }

    final data = <Map<String, dynamic>>[];

    for (int i = 1; i < rows.length; i++) {
      final row = rows[i];

      if (row.every((cell) => _cellToString(cell?.value).isEmpty)) {
        continue;
      }

      String valueOf(String key) {
        final index = headers.indexOf(key);
        if (index == -1 || index >= row.length) return '';
        return _cellToString(row[index]?.value);
      }

      final accountType = valueOf('accountType');

      data.add({
        'fullName': valueOf('fullName'),
        'userId': valueOf('userId'),
        'phone': valueOf('phone'),
        'department': valueOf('department'),
        'password': valueOf('password'),
        'accountType': accountType.isEmpty ? AppRoles.user : accountType,
      });
    }

    _validateParsedStudents(data);
    return data;
  }

  Future<Map<String, dynamic>> startBulkImport(
      List<Map<String, dynamic>> students, {
        String sourceFileName = '',
      }) async {
    final user = _auth.currentUser;

    if (user == null) {
      throw Exception('يجب تسجيل الدخول بحساب مسؤول قبل رفع الطلاب');
    }

    _validateParsedStudents(students);

    await user.getIdToken(true);

    final cleanSourceFileName = sourceFileName.trim().isNotEmpty
        ? sourceFileName.trim()
        : lastPickedFileName;

    try {
      final callable = _functions.httpsCallable('startBulkRegisterStudents');

      final response = await callable.call({
        'students': students,
        'sourceFileName': cleanSourceFileName,
      });

      return Map<String, dynamic>.from(response.data as Map);
    } on FirebaseFunctionsException catch (e) {
      throw Exception(e.message ?? 'فشل رفع الطلاب: ${e.code}');
    }
  }

  Stream<Map<String, dynamic>?> watchBulkImportJob(String jobId) {
    final cleanJobId = jobId.trim();

    if (cleanJobId.isEmpty) {
      return const Stream<Map<String, dynamic>?>.empty();
    }

    return _firestore
        .collection('bulkImports')
        .doc(cleanJobId)
        .snapshots()
        .map((doc) {
      final data = doc.data();

      if (data == null) {
        return null;
      }

      return Map<String, dynamic>.from(data);
    });
  }
}
