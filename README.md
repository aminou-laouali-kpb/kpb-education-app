# KPB Education Relaunch

KPB Education is being rebuilt as an Africa-first orientation, study-abroad, scholarship, and counseling platform for students, parents, and future partners.

This repository now contains three aligned workspaces:

- `lib/`: the relaunched Flutter mobile experience
- `backend/`: a NestJS API scaffold around the unified `Case` domain
- `admin/`: a Next.js admin web scaffold for counselors and admins

## Mobile relaunch foundation

The Flutter app now exposes the new product backbone:

- bilingual onboarding for `student`, `parent`, and `partner`
- localized app shell around `Home`, `Orientation`, `Explore`, `Scholarships`, `My Cases`, `Saved`, `Profile`, and `Community`
- structured orientation engine with field recommendations
- unified `My Cases` experience replacing fragmented request history
- service messaging and case timeline in case detail
- save flow for fields, countries, programs, and scholarships
- KPB service offers, support destinations, articles, and forum taxonomy modeled in the relaunch layer
- local persistence for onboarding, profile, saved items, cases, and orientation history
- a dedicated API client boundary for the relaunch backend

The mobile layer still uses mock catalog content for the current demo experience, but it no longer behaves as a throwaway in-memory prototype. The app state now persists locally and is shaped around the future API contracts.

## Backend scaffold

The backend workspace is designed for:

- authentication and profiles
- catalog delivery
- orientation sessions/results
- case creation, listing, updates, and messaging
- admin case assignment, tasking, notes, and timeline events
- content operations for service offers, support destinations, and articles
- community operations for forum categories, tags, and moderation
- notification templates, campaigns, and delivery logs
- admin users and reporting
- appointments, saved items, and partner leads
- future counselor/admin operations

The Prisma schema introduces the first version of:

- `UserProfile`
- `Case`
- `CaseMessage`
- `CaseTimelineEvent`
- `CaseTask`
- `CaseDocument`
- `CaseInternalNote`
- `ServiceOffer`
- `SupportDestination`
- `Article`
- `ForumCategory`
- `ForumTopicTag`
- `NotificationTemplate`
- `NotificationCampaign`
- `NotificationDelivery`

## Admin scaffold

The admin workspace now provides an authenticated operations workspace for:

- overview metrics
- case operations
- content management
- community and moderation
- notification campaigns
- user and role management
- reporting

## Important note

This implementation now has:

- Flutter analysis and widget tests
- Nest backend build passing
- Next admin build passing
- local admin auth and RBAC validated against protected routes
- Prisma migration applied on a local PostgreSQL database
- Prisma seed validated against the local database
- API write/read validation confirmed against Postgres for dashboard-managed content

Local dashboard login currently uses seeded internal emails from the backend mock data:

- `fatou@kpb.education`
- `amina@kpb.education`
- `moussa@kpb.education`

Useful local commands:

- create local DB once: `createdb kpb_education`
- generate Prisma client: `cd backend && npm run prisma:generate`
- apply migrations: `cd backend && npx prisma migrate dev`
- seed local DB: `cd backend && npm run prisma:seed`
- backend on default port: `cd backend && node dist/main.js`
- backend on a custom port: `cd backend && PORT=4100 node dist/main.js`
- admin: `cd admin && NEXT_PUBLIC_KPB_API_BASE_URL=http://127.0.0.1:4000/api npm run dev`
- mobile with live sync: `flutter run --dart-define=KPB_ENABLE_REMOTE_SYNC=true --dart-define=KPB_API_BASE_URL=http://127.0.0.1:4000/api`

Quality gates (recommended before each PR):

- mobile: `dart format --set-exit-if-changed . && flutter analyze && flutter test`
- backend: `cd backend && npm ci && npm run lint && npm run build`
- admin: `cd admin && npm ci && npm run lint && npm run build`

Local backend environment expects a PostgreSQL socket URL by default:

- `DATABASE_URL="postgresql://aminou@localhost/kpb_education?host=/tmp&schema=public"`

## Current state of persistence

Cases, appointments, saved items, coach conversations and AI quotas are stored
in PostgreSQL through Prisma. Without `DATABASE_URL`, these routes answer 503
(`assertDb`) — the remaining in-memory arrays only back the non-production
degraded mode of the content module, plus per-process caches (Kayak, YouTube).
