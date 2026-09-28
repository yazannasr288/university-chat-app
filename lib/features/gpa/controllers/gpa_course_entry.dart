import 'package:flutter/material.dart';

import '../../../data/models/gpa_models.dart';

class GpaCourseEntry {
  final TextEditingController nameController = TextEditingController();
  final TextEditingController creditsController = TextEditingController();
  GpaGradeOption grade;
  bool isRepeatedFailedCourse = false;

  GpaCourseEntry({required GpaGradeOption defaultGrade})
      : grade = defaultGrade;

  void attach(VoidCallback listener) {
    nameController.addListener(listener);
    creditsController.addListener(listener);
  }

  void clear({required GpaGradeOption defaultGrade}) {
    nameController.clear();
    creditsController.clear();
    grade = defaultGrade;
    isRepeatedFailedCourse = false;
  }

  void dispose(VoidCallback listener) {
    nameController
      ..removeListener(listener)
      ..dispose();
    creditsController
      ..removeListener(listener)
      ..dispose();
  }
}
