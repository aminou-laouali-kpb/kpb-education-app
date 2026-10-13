# Security & compliance (engineering)

Companion to **Phase 4** in `[production-readiness-plan.md](production-readiness-plan.md)`. This document is for builders and reviewers; end-user wording lives in the app (**Politique de confidentialité**) and on `web/public/confidentialite.html`.

The **code-derived** list of processors, data types and permissions is
`[data-inventory.md](data-inventory.md)`. Re-read the code, not this file, when
a flow changes.

## Credential storage


| Data                                 | Where                                                                                                  | Notes                                                                                                                                     |
| ------------------------------------ | ------------------------------------------------------------------------------------------------------ | ----------------------------------------------------------------------------------------------------------------------------------------- |
| Access token, refresh token, user id | `FlutterSecureStorage` via `[kpbFlutterSecureStorage](../lib/app/core/config/kpb_secure_storage.dart)` | Android: Keystore + AES-GCM (package defaults). iOS: Keychain, `first_unlock_this_device`, not iCloud-synced.                             |
| REST calls                           | `AppApiClient` + `_AuthInterceptor`                                                                    | Same storage instance as `[AuthService](../lib/app/core/services/auth_service.dart)` — identical options so reads/writes stay consistent. |


Passwords are never stored locally beyond OS-level secure credential flows during login.

## Local snapshot (`SharedPreferences`)

`[LocalAppRepository](../lib/app/core/repositories/local_app_repository.dart)` persists a JSON snapshot (preferences, catalog mirrors, cases metadata, etc.). **Email, phone, and WhatsApp are not written** to disk (loaded from API on sync). Tokens are **not** in this blob.

## Hive boxes

Catalog cache and message outbox hold non-auth payloads (cached JSON, queued actions). Treat devices as trusted-enough for UX caching; rely on HTTPS and auth headers for origin data.

## App lock (`SecurityService`)

Biometric / device PIN unlock after resume — see class doc on `[SecurityService](../lib/app/core/services/security_service.dart)`. Not a banking-grade isolation layer.

## Platform permissions

### Android (`android/app/src/main/AndroidManifest.xml`)


| Permission             | Purpose                                                                                         |
| ---------------------- | ----------------------------------------------------------------------------------------------- |
| `INTERNET`             | API, Firebase (incl. Cloud Messaging), PostHog, Supabase                                        |
| `ACCESS_NETWORK_STATE` | Connectivity checks                                                                             |
| `POST_NOTIFICATIONS`   | FCM push (Android 13+); requested at runtime                                                    |
| `USE_BIOMETRIC`        | Local auth for app lock                                                                         |
| `RECORD_AUDIO`         | Voice dictation on a support / case request                                                     |


### iOS (`Info.plist`)

Usage descriptions currently declared (do **not** claim they were removed):

| Key | Actual use |
|---|---|
| `NSCameraUsageDescription` | Dossier attachment **and** profile photo |
| `NSPhotoLibraryUsageDescription` | Same |
| `NSMicrophoneUsageDescription` | Voice dictation |
| `NSSpeechRecognitionUsageDescription` | Speech-to-text for the same message |
| `NSFaceIDUsageDescription` | App lock |
| `NSLocationWhenInUseUsageDescription` | Originally declared for the OneSignal SDK (now removed); kept as a precaution until an archive proves no library references CoreLocation. **Never requested, never used.** |

## Privacy disclosure alignment

In-app policy screens (`[legal_pages.dart](../lib/app/features/legal/legal_pages.dart)`) and `web/public/confidentialite.html` must name every processor that the code talks to: Groq, Firebase (incl. Cloud Messaging), OneSignal (legacy app versions, server-side fallback), PostHog, Supabase, Resend, Mautic, the KPB backend, plus PayDunya / CinetPay. A static guard (`test/core/privacy_disclosure_parity_test.dart`) derives hosts and permissions from the git-tracked tree and fails if a disclosure is missing.

## Controller identity

Resolved on 16/08/2026. The controller is **KPB Global L.L.C-FZ**, a free-zone LLC registered with the Meydan Free Zone (Meydan City Corporation, Emirate of Dubai) under licence no. 2537631.01, registered office Meydan Grandstand, 6th floor, Meydan Road, Nad Al Sheba, Dubai, United Arab Emirates. **KPB Education is a service of that company, not a separate legal person** — the policies must say so, otherwise the user consents to an entity they cannot name.

Governing regime: UAE Federal Decree-Law no. 45 of 2021 on the Protection of Personal Data; supervisory authority: the UAE Data Office. Terms are governed by UAE law with venue in Dubai, without prejudice to mandatory consumer protections in the user's country of residence.

A static guard (`test/core/legal_identity_test.dart`) fails if any of the four published surfaces — the FR and EN translation blocks, `web/public/confidentialite.html`, `web/public/conditions.html` — stops naming the entity, or if the pre-16/08/2026 placeholder wording comes back. (The guard scans for that wording, so this document deliberately does not quote it.)

The Meydan licence expires **21/09/2027**; the identity block must be re-checked at renewal.

## Periodic review

Re-run `[data-inventory.md](data-inventory.md)` after adding sensors, a new third-party host, or a new persisted field. The parity test is the executable half of that review.
