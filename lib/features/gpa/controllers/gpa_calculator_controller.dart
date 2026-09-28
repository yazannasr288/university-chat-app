import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'gpa_course_entry.dart';
import '../../../data/models/gpa_models.dart';

class GpaCalculatorController {
  static const int maxCourses = 18;

  bool get canAddCourse => courses.length < maxCourses;
  final TextEditingController previousGpaController = TextEditingController();
  final TextEditingController previousCreditsController =
      TextEditingController();
  final List<GpaCourseEntry> courses = [];

  static const List<GpaGradeOption> gradeOptions = [
    GpaGradeOption(label: '< 50', points: 0.00),
    GpaGradeOption(label: '50 - 54', points: 1.50),
    GpaGradeOption(label: '55 - 59', points: 1.75),
    GpaGradeOption(label: '60 - 64', points: 2.00),
    GpaGradeOption(label: '65 - 69', points: 2.25),
    GpaGradeOption(label: '70 - 74', points: 2.50),
    GpaGradeOption(label: '75 - 79', points: 2.75),
    GpaGradeOption(label: '80 - 84', points: 3.00),
    GpaGradeOption(label: '85 - 89', points: 3.25),
    GpaGradeOption(label: '90 - 94', points: 3.50),
    GpaGradeOption(label: '95 - 99', points: 3.75),
    GpaGradeOption(label: '100', points: 4.00),
  ];

  static GpaGradeOption get defaultGrade => gradeOptions.last;

  static final List<TextInputFormatter> numberInputFormatters = [
    FilteringTextInputFormatter.allow(RegExp(r'[0-9\.,]')),
  ];

  void init(VoidCallback listener) {
    previousGpaController.addListener(listener);
    previousCreditsController.addListener(listener);

    if (courses.isEmpty) {
      for (var i = 0; i < 4; i++) {
        addCourse(listener, notify: false);
      }
    }
  }

  bool addCourse(VoidCallback listener, {bool notify = true}) {
    if (!canAddCourse) return false;

    final course = GpaCourseEntry(defaultGrade: defaultGrade)..attach(listener);
    courses.add(course);

    if (notify) listener();

    return true;
  }
  void removeCourse(GpaCourseEntry course, VoidCallback listener) {

    if (courses.length == 1) {
      course.clear(defaultGrade: defaultGrade);
      listener();
      return;
    }

    courses.remove(course);
    course.dispose(listener);
    listener();
  }

  void updateCourseGrade({
    required GpaCourseEntry course,
    required GpaGradeOption grade,
    required VoidCallback listener,
  }) {
    course.grade = grade;
    listener();
  }

  void updateCourseRepeatedFailedStatus({
    required GpaCourseEntry course,
    required bool value,
    required VoidCallback listener,
  }) {
    course.isRepeatedFailedCourse = value;
    listener();
  }

  void reset(VoidCallback listener) {
    previousGpaController.clear();
    previousCreditsController.clear();

    for (final course in courses) {
      course.dispose(listener);
    }

    courses
      ..clear()
      ..addAll(
        List.generate(4, (_) {
          final course = GpaCourseEntry(defaultGrade: defaultGrade)
            ..attach(listener);
          return course;
        }),
      );

    listener();
  }

  double? parseNumber(String value) {
    final normalized = value.trim().replaceAll(',', '.');
    if (normalized.isEmpty) return null;
    return double.tryParse(normalized);
  }

  double? courseWeightedPoints(GpaCourseEntry course) {
    final credits = parseNumber(course.creditsController.text);
    if (credits == null || credits <= 0) return null;
    return credits * course.grade.points;
  }

  GpaSummary get summary {
    var currentCredits = 0.0;
    var currentPoints = 0.0;
    var repeatedFailedCreditsInput = 0.0;
    var validCourses = 0;

    for (final course in courses) {
      final credits = parseNumber(course.creditsController.text);
      if (credits == null || credits <= 0) continue;
      currentCredits += credits;
      currentPoints += credits * course.grade.points;
      if (course.isRepeatedFailedCourse) {
        repeatedFailedCreditsInput += credits;
      }
      validCourses++;
    }

    final semesterGpa =
        currentCredits > 0 ? currentPoints / currentCredits : null;
    final previousGpa = parseNumber(previousGpaController.text);
    final previousCreditsInput = parseNumber(previousCreditsController.text);
    final hasValidPrevious = previousGpa != null &&
        previousGpa >= 0 &&
        previousGpa <= 4 &&
        previousCreditsInput != null &&
        previousCreditsInput > 0;

    final previousCredits = hasValidPrevious ? previousCreditsInput : 0.0;
    final repeatedFailedCredits = hasValidPrevious
        ? repeatedFailedCreditsInput > previousCredits
            ? previousCredits
            : repeatedFailedCreditsInput
        : 0.0;
    final adjustedPreviousCredits = previousCredits - repeatedFailedCredits;
    final previousPoints =
        hasValidPrevious ? previousGpa * previousCredits : 0.0;
    final totalCredits = currentCredits + adjustedPreviousCredits;
    final cumulativeGpa = totalCredits > 0
        ? (previousPoints + currentPoints) / totalCredits
        : null;

    return GpaSummary(
      semesterGpa: semesterGpa,
      cumulativeGpa: cumulativeGpa,
      currentCredits: currentCredits,
      currentPoints: currentPoints,
      previousCredits: previousCredits,
      adjustedPreviousCredits: adjustedPreviousCredits,
      repeatedFailedCredits: repeatedFailedCredits,
      previousPoints: previousPoints,
      totalCredits: totalCredits,
      validCourses: validCourses,
      hasInvalidPreviousGpa:
          previousGpa != null && (previousGpa < 0 || previousGpa > 4),
    );
  }

  String formatNumber(double? value) {
    if (value == null || value.isNaN || value.isInfinite) return '--';
    return value.toStringAsFixed(2);
  }

  String standingKey(double? gpa) {
    if (gpa == null) return 'gpa.standing.empty';
    if (gpa >= 3.7) return 'gpa.standing.excellent';
    if (gpa >= 3.0) return 'gpa.standing.very_good';
    if (gpa >= 2.0) return 'gpa.standing.good';
    if (gpa >= 1.0) return 'gpa.standing.warning';
    return 'gpa.standing.critical';
  }

  void dispose(VoidCallback listener) {
    previousGpaController
      ..removeListener(listener)
      ..dispose();
    previousCreditsController
      ..removeListener(listener)
      ..dispose();

    for (final course in courses) {
      course.dispose(listener);
    }
    courses.clear();
  }
}
