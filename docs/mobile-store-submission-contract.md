# Mobile store submission contract

> **This document is tied to NO build in particular.** It used to be titled
> "— build 49" and named build 49 throughout, long after builds 50 and 52 had
> shipped: an operator opening it read the identity of an artifact that no
> longer existed. The build number is therefore gone from here — it lives in
> `docs/release-ledger.md`, which is its source, and a document that copies it
> ends up contradicting it.

This file is the release operator's compact source of truth for the **artifact
that is actually uploaded**. Marketing copy remains in `store-listing-copy.md`;
the detailed data inventory remains in `data-inventory.md` and
`STORE_READINESS.md`.

An unchecked item is a launch blocker. Repository checks cannot substitute for
Apple/Google console state, a signed artifact, or a physical-device result.

## 1. Immutable artifact identity

| Field | Required value | Verified by repository |
|---|---|---|
| Public name | KPB Education | Source metadata tests |
| Marketing version | `2.3.1` | `pubspec.yaml` + les deux préflights, verrouillés par `artifact_signing_contract_test.dart`. Passée de 2.3.0 à 2.3.1 pour la build 57 (décision du propriétaire du 16/10/2026, posée le 18/10/2026) : la 2.3.0 est en vente depuis le 07/10/2026 (App Store) et ITMS-90062 refuse une version marketing non supérieure. Passée de 2.2.0 à 2.3.0 pour la build 54, jamais envoyée aux boutiques (constat du 03/10/2026) ; la build 55 la remplace et garde ce nom (la 2.2.0 est en vente depuis le 13/09/2026 et ITMS-90062 refuse une version marketing non supérieure). Passée de 2.1.0 à 2.2.0 le 03/09/2026 : `isVersionBelow` ignore le numéro de build, donc sans changement de version marketing la porte de mise à jour ne peut distinguer aucune build. |
| Build/version code | le **Courant** de `docs/release-ledger.md` | Registre + les deux préflights, appariés par `build_number_test.dart` |
| Android application ID | `com.karatou.android` | Gradle + AAB manifest preflight |
| iOS bundle ID | `Karatou.karatou` | Xcode + signed-app preflight |
| iOS Apple team | `DNPB788LKX` | Signed-app/profile preflight |
| iOS push entitlement | `aps-environment=production` | Signed-app/profile preflight |
| Interface language | French (`fr`) | iOS manifest test; store English copy must say the UI is French |

Run the artifact checks without copying private keys into the repository:

```bash
# Android: the expected SHA-256 is the PUBLIC upload-certificate fingerprint
# from Play Console → App integrity.
scripts/preflight-android-aab.sh \
  --aab build/app/outputs/bundle/release/app-release.aab \
  --expected-cert-sha256 '<PLAY_UPLOAD_CERT_SHA256>'

# iOS: run against the .app inside the Xcode Organizer archive.
scripts/preflight-ios-archive.sh \
  --xcconfig ios/Flutter/Generated.xcconfig \
  --archive-plist '<Runner.xcarchive>/Products/Applications/Runner.app/Info.plist'
```

The Android check rejects an unsigned/corrupt bundle, the debug certificate, a
certificate that differs from Play's upload certificate, wrong identifiers or
versions, `AD_ID`, `QUERY_ALL_PACKAGES`, and enabled-at-start native analytics.
The iOS check rejects unsigned, ad-hoc, Apple Development, development-APNs,
debuggable, Ad Hoc, Enterprise, expired, wrong-team, wrong-bundle, or wrong-build
artifacts. It also requires the app privacy manifest inside the signed bundle.

## 2. Publisher, language, and legal URLs

Use the same seller/service identity in both consoles and in review notes:

```text
KPB Global L.L.C-FZ
Meydan Grandstand, 6th floor, Meydan Road, Nad Al Sheba,
Dubai, United Arab Emirates — licence 2537631.01
KPB Education is a service of KPB Global L.L.C-FZ.
```

| Console field | Submission value |
|---|---|
| Privacy policy | `https://kpbeducation.cloud/confidentialite.html` |
| Terms | `https://kpbeducation.cloud/conditions.html` |
| Account deletion | `https://kpbeducation.cloud/suppression-compte.html` |
| Support | `contact@kpbeducation.com` |
| Privacy contact | `privacy@kpbeducation.com` |

Before submission, open all three HTTPS pages from a network outside the KPB
host. A URL present in source but unreachable in production does not satisfy a
store requirement.

The binary UI is French. French is the primary listing. An English storefront
may be provided only with the explicit sentence **“The app interface is in
French in this version.”** Do not declare English as an app localization.

## 3. Privacy answers for the exact release

Both stores: **the app collects data: Yes**. **Advertising/cross-app tracking:
No**. There is no advertising SDK; the Android merged manifest must not contain
`com.google.android.gms.permission.AD_ID`; the Apple app manifest declares
`NSPrivacyTracking=false`.

### Apple App Privacy

Declare the categories below. “Linked” means linked to the account or profile,
not sold or used for advertising.

| Apple category | Collected | Linked | Tracking | Purpose |
|---|---:|---:|---:|---|
| Contact Info — name, email, phone | Yes | Yes | No | App Functionality |
| Identifiers — user ID, device ID/push token | Yes | Yes | No | App Functionality, Analytics |
| User Content — avatar, customer-support/case messages, coach/orientation content | Yes | Yes | No | App Functionality |
| Usage Data — product interaction, search history | Yes | Yes | No | Analytics, App Functionality |
| Diagnostics — crash, performance, other diagnostics | Yes | No | No | App Functionality |
| Other Data — birth date, guardian/academic profile | Yes | Yes | No | App Functionality |
| Precise/coarse location | No | — | — | — |
| Contacts/address book, health, payment-card/account data | No | — | — | — |

PostHog interaction/session-replay declarations apply only when the uploaded
binary has a non-empty `POSTHOG_API_KEY`. Replay is declared as Product
Interaction; text and images remain masked. The preflight makes the key choice
explicit without printing it.

Push goes through Firebase Cloud Messaging directly: Google receives the device
push token only; the token-to-account link lives in the KPB backend
(`DeviceToken`). The app no longer embeds the OneSignal SDK; the backend keeps a
OneSignal fallback for earlier builds only (see `docs/CONSOLE_ANSWERS.md`
§0sexies). `NSLocationWhenInUseUsageDescription` was declared for OneSignal's
location module and is kept as a precaution until the archive proves no library
references CoreLocation; the app requests no location permission.
Do not claim location collection. Review the Xcode-generated privacy report for
the final archive because third-party manifests are aggregated separately.

### Google Play Data Safety

- Data collected: **Yes**.
- Data shared for advertising/tracking: **No**. Processor transfers still need
  to be described in the privacy policy and answered according to the current
  Play form wording and the executed processor contracts.
- Encrypted in transit: **Yes**; verify the production endpoints before upload.
- Deletion request: **Yes**, in-app and through the public deletion URL.
- Advertising ID: **No**, only after the final AAB preflight proves `AD_ID` is
  absent.
- Data types: personal information; messages; optional avatar; app activity and
  search; crash/diagnostics; device or other IDs. Files/documents are **No** in
  the submitted build while document upload remains disabled, unless the production
  Success Lab feature is opened and accepts a file—confirm the production flag
  before answering.
- Analytics, replay, and diagnostics are user-controllable. They must start
  disabled natively until the persisted choice is applied.

## 4. Age/content questionnaire facts

Do not hard-code “Apple 12+” or “Google Teen” in release documentation. The
consoles calculate the displayed rating from their current questionnaires.
Answer these facts and retain screenshots/PDFs of the submitted answers:

- contractual/onboarding minimum age: **16**; guardian consent below 18;
- generative AI/free-text assistant: **Yes**;
- staff-facing user content (case and coach messages): **Yes**;
- public user-to-user community in the submitted build: **No** (`KPB_MVP_ONLY=true`);
- objectionable generative-AI output can be reported **in app** from both the
  coach reply and orientation explanation. A report is persisted as an
  authenticated Trust & Safety case and is visible to authorised KPB staff;
  another-user blocking is not applicable while the community is disabled;
- unrestricted web browsing: **No**; external links open outside the app;
- advertising, gambling, sexual/violent editorial content, in-app purchases:
  **No**, subject to a final editorial catalog review;
- outbound links include official scholarship/institution sites and WhatsApp.

The final rating displayed by each console is an external result. Record it in
the release evidence; do not infer it from the contractual 16-year floor.

## 5. Required manual evidence

- [ ] Clean immutable release SHA, synced to the intended `origin/main` commit.
- [ ] The submitted build's signed AAB passes `preflight-android-aab.sh` and matches Play's
      public upload-certificate SHA-256.
- [ ] The submitted build's Apple Distribution archive passes
      `preflight-ios-archive.sh`; Xcode privacy report reviewed.
- [ ] Play Internal Testing install and TestFlight install are both the submitted build.
- [ ] Submit one AI-output report from the coach and one from orientation on
      those internal-track builds; retain both case references and evidence
      that authorised staff received them in the back-office case queue.
- [ ] Physical Android and iOS smoke: first run, guest browse, account creation,
      OAuth/OTP, notifications, case messaging/dictation, export, deletion,
      analytics refusal, offline/reconnect, external links.
- [ ] Screenshots and Play feature graphic captured from the submitted build; no masked or
      server-disabled feature shown.
- [ ] Reference-device AAB delivered size, five-run cold-start average, memory,
      and representative-session network bytes recorded in `STORE_READINESS.md`.
- [ ] Privacy/Data Safety and age questionnaires updated in both consoles;
      submitted-answer evidence retained.
- [ ] Seller identity, French/English storefront language, review account/notes,
      support/privacy/deletion URLs verified in the consoles.

Until every item above is checked, the repository is more defensible but the
mobile/store gate remains **not ready for public rollout**.
