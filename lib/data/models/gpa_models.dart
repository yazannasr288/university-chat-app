class GpaGradeOption {
  final String label;
  final double points;

  const GpaGradeOption({
    required this.label,
    required this.points,
  });
}

class GpaSummary {
  final double? semesterGpa;
  final double? cumulativeGpa;
  final double currentCredits;
  final double currentPoints;
  final double previousCredits;
  final double adjustedPreviousCredits;
  final double repeatedFailedCredits;
  final double previousPoints;
  final double totalCredits;
  final int validCourses;
  final bool hasInvalidPreviousGpa;

  const GpaSummary({
    required this.semesterGpa,
    required this.cumulativeGpa,
    required this.currentCredits,
    required this.currentPoints,
    required this.previousCredits,
    required this.adjustedPreviousCredits,
    required this.repeatedFailedCredits,
    required this.previousPoints,
    required this.totalCredits,
    required this.validCourses,
    required this.hasInvalidPreviousGpa,
  });
}
