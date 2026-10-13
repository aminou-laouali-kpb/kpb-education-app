import 'package:firebase_crashlytics/firebase_crashlytics.dart';

import '../observability/crashlytics_observability.dart';
import '../utils/app_logger.dart';
import 'analytics_service.dart';
import 'transient_retry.dart';

/// Structured sync observability: debug logs, Analytics events, and Crashlytics custom keys.
abstract final class SyncTelemetry {
  static const _tag = 'sync';

  static void fullSyncStarted() {
    AppLogger.info('full_sync_started', tag: _tag);
    _safeSetKeys(<String, Object>{
      CrashlyticsObsKey.domain: CrashlyticsObsDomain.sync,
      'sync_full_last_started_ms': DateTime.now().millisecondsSinceEpoch,
    });
  }

  static void fullSyncFinished({
    required bool success,
    required Duration elapsed,
    int catalogHiveFallbackCount = 0,
    String? failureStage,
    SyncErrorKind? errorKind,
  }) {
    AppLogger.info(
      'full_sync_finished success=$success elapsedMs=${elapsed.inMilliseconds} '
      'hiveFallbacks=$catalogHiveFallbackCount stage=$failureStage '
      'error=${errorKind?.wireValue}',
      tag: _tag,
    );
    _safeSetKeys(<String, Object>{
      CrashlyticsObsKey.domain: CrashlyticsObsDomain.sync,
      'sync_full_last_finished_ms': DateTime.now().millisecondsSinceEpoch,
      'sync_full_last_success': success,
      'sync_full_last_elapsed_ms': elapsed.inMilliseconds,
      'sync_catalog_hive_fallback_last': catalogHiveFallbackCount,
    });
    AnalyticsService.instance.logFullSyncResult(
      success: success,
      elapsedMs: elapsed.inMilliseconds,
      catalogHiveFallbackCount: catalogHiveFallbackCount,
      failureStage: success ? null : failureStage,
      errorKind: success ? null : errorKind?.wireValue,
    );
  }

  static void profileSkippedRemotePull({required String reason}) {
    AppLogger.warning('profile_skipped_remote_pull reason=$reason', tag: _tag);
    AnalyticsService.instance.logSyncConflict(
      domain: 'profile',
      resolution: reason,
    );
  }

  static void casesMerged({
    required int remoteCount,
    required int localWinCount,
    required int keptLocalOnlyCount,
  }) {
    if (localWinCount == 0 && keptLocalOnlyCount == 0) return;
    AppLogger.info(
      'cases_merge remote=$remoteCount localWins=$localWinCount '
      'localOnly=$keptLocalOnlyCount',
      tag: _tag,
    );
    AnalyticsService.instance.logSyncConflict(
      domain: 'cases',
      resolution: 'merge:LWW=$localWinCount'
          '_pending=$keptLocalOnlyCount:remote=$remoteCount',
    );
  }

  static void savedItemsMerged({required int unionExtraLocals}) {
    if (unionExtraLocals == 0) return;
    AppLogger.info('saved_items_merge union_extra_locals=$unionExtraLocals',
        tag: _tag);
    AnalyticsService.instance.logSyncConflict(
      domain: 'saved_items',
      resolution: 'union_extra_local=$unionExtraLocals',
    );
  }

  static void catalogHiveFallback({
    required String resource,
    required int attempts,
  }) {
    AppLogger.warning(
      'catalog_hive_fallback resource=$resource attempts=$attempts',
      tag: _tag,
    );
    AnalyticsService.instance.logCatalogSyncFallback(
      resource: resource,
      attempts: attempts,
    );
  }

  static void _safeSetKeys(Map<String, Object> keys) {
    for (final e in keys.entries) {
      try {
        FirebaseCrashlytics.instance.setCustomKey(e.key, e.value);
      } catch (_) {}
    }
  }
}
