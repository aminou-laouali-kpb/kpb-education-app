part of '../app_controller.dart';

mixin _RoadmapMixin on _AppControllerBase {
  bool isStepCompleted(String scholarshipId, RoadmapStepType type) {
    return _completedRoadmapSteps[scholarshipId]?.contains(type.name) ?? false;
  }

  void toggleRoadmapStep(String scholarshipId, RoadmapStepType type) {
    KpbHaptics.selection();
    final steps = _completedRoadmapSteps[scholarshipId] ?? [];
    if (steps.contains(type.name)) {
      steps.remove(type.name);
    } else {
      steps.add(type.name);
    }
    _completedRoadmapSteps[scholarshipId] = steps;
    _persist();
    update();
  }

  Map<String, dynamic>? getNextUrgentMilestone() {
    // ... logic is fine ...
    return _findNextStep(
        scholarships.where((s) => isSaved(SavedItemType.scholarship, s.id)));
  }

  double getChildOverallProgressPercentage() {
    final saved =
        scholarships.where((s) => isSaved(SavedItemType.scholarship, s.id));
    if (saved.isEmpty) return 0.0;

    int totalSteps = saved.length * RoadmapEngine.getSteps().length;
    int completedCount = 0;

    for (final s in saved) {
      completedCount += (_completedRoadmapSteps[s.id]?.length ?? 0);
    }

    return completedCount / totalSteps;
  }

  Map<String, dynamic> getEstimatedFinancialSummary() {
    // Mock financial data based on profile
    final p = profile;
    double tuition = 12000; // Mock average
    double lifestyle = 8000;

    if (p != null) {
      if (p.targetCountryIds.contains('canada')) {
        tuition = 15000;
        lifestyle = 10000;
      } else if (p.targetCountryIds.contains('france')) {
        tuition = 5000;
        lifestyle = 8000;
      }
    }

    final savedScholarships =
        scholarships.where((s) => isSaved(SavedItemType.scholarship, s.id));
    double totalSavings =
        savedScholarships.length * 5000.0; // Mock scholarship value

    return {
      'totalCost': (tuition + lifestyle),
      'potentialSavings': totalSavings,
      'gap': (tuition + lifestyle) - totalSavings,
    };
  }

  Map<String, dynamic>? _findNextStep(
      Iterable<ScholarshipModel> savedScholarships) {
    final now = DateTime.now();
    Map<String, dynamic>? closest;
    DateTime? closestDate;

    for (final s in savedScholarships) {
      final deadline =
          RoadmapEngine.calculateDate(now.add(const Duration(days: 90)), 0);
      final steps = RoadmapEngine.getSteps();

      for (final step in steps) {
        if (!isStepCompleted(s.id, step.type)) {
          final stepDate =
              RoadmapEngine.calculateDate(deadline, step.daysBeforeDeadline);
          if (stepDate.isAfter(now)) {
            if (closestDate == null || stepDate.isBefore(closestDate)) {
              closestDate = stepDate;
              closest = {'scholarship': s, 'step': step, 'date': stepDate};
            }
          }
        }
      }
    }
    return closest;
  }
}
