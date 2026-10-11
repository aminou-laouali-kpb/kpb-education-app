// KPB Education catalog facade.
// Static seed content lives in mock_catalog/*.dart, split per domain.
// ignore_for_file: lines_longer_than_80_chars
import '../models/app_models.dart';

import 'mock_catalog/orientation_data.dart';
import 'mock_catalog/fields_data.dart';
import 'mock_catalog/countries_data.dart';
import 'mock_catalog/institutions_data.dart';
import 'mock_catalog/programs_data.dart';
import 'mock_catalog/services_data.dart';
import 'mock_catalog/community_data.dart';
import 'mock_catalog/academy_data.dart';

class MockCatalog {
  static const orientationQuestions = kOrientationQuestions;
  static const fields = kFields;
  static const countries = kCountries;
  static const institutions = kInstitutions;
  static const programs = kPrograms;
  static const scholarships = <ScholarshipModel>[];
  static const serviceOffers = kServiceOffers;
  static const supportDestinations = kSupportDestinations;
  static final articles = kArticles;
  static const forumCategories = kForumCategories;
  static const forumTopicTags = kForumTopicTags;
  static const academyCourses = kAcademyCourses;
  static const academyLessons = kAcademyLessons;
}
