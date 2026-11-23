import 'app_snapshot.dart';

abstract class AppRepository {
  Future<AppSnapshot> loadSnapshot();
  Future<void> saveSnapshot(AppSnapshot snapshot);

  /// Erase all locally-persisted state (used by account deletion and logout).
  /// Distinct from [saveSnapshot] with empty data: removes the stored snapshot
  /// entirely, with any copy of it kept aside (corrupt snapshot).
  Future<void> clear();
}
