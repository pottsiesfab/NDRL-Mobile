# COPY THIS INTO A NEW CHAT — NDRL Firebase DEV → PRODUCTION Migration

You are assisting with promotion of the **Nostalgia Drag Racing League (NDRL)** Flutter/FCM mobile notification system to production. I need a **start-to-finish, gated migration** from an existing proven DEV setup to a separate secure production setup. First audit the live code, databases, and configuration; do not guess missing facts. Give exact copy-paste commands and complete file replacements when needed. Perform actions in small verified stages; require an explicit approval before anything that touches PROD or sends to real members. My preferred Linux editor is `vim`.

## Proven development baseline (November 4, 2026)

- DEV Firebase project `ndrl-notifications-dev`, number `1045907764607`; DEV Android application ID currently **`com.nostalgiadragleague.ndrl`** (NOT suffixed `.dev`); app ID `1:1045907764607:android:b56cd2aaddab31dede164a`.
- Working Flutter app `C:\Projects\NDRL-Mobile`; private Git repo intended `pottsiesfab/NDRL-Mobile`. Repo includes Android application + version-controlled worker source, but never credentials.
- Existing NDRL website repo `pottsiesfab/ndrl-site`, branch `main`; website code on VPS `/srv/ndrl/dev` and `/srv/ndrl/prod`. **Do not assume both environments share configs, users, or schema state**; verify.
- VPS `ndrlsite`, Docker dev containers `dev-web-1`, `dev-db-1`; dev Docker network `dev_ndrl_net`; dev MariaDB hostname `db`, schema `ndrl_fantasy` for notifications, and `ndrl_portal` for member/role/event data.
- DEV Firebase service-account key at `/srv/ndrl-data/private/firebase/dev/service-account.json` (protected root-only parent directories; key restricted `root:20070`, `0640` for worker bind mount). DEV database credentials live in `/srv/ndrl-data/private/firebase/dev/worker.env` (root-only). Never copy these to production.
- DEV manual worker deployed `/srv/ndrl/firebase-worker-dev`; Docker Compose `ndrl-fcm-test`, PHP 8.3 CLI image; service only device 2, no ports, manual invocation, non-root UID 20070, DEV DB read-only access. `sudo docker compose run --rm worker check` succeeded and `... send-test 2 --confirm` was accepted by FCM; **Android notification was visibly received** Nov. 4, 2026.
- Worker includes `Dockerfile`, `compose.yaml`, `worker.php`, `setup-db-user.sh`, `README.md`; its current behavior is *only a one-device test*, **NOT a production delivery queue**. Never remove the device-2 guard and point it at production as a shortcut.
- NDRL DEV APIs/pages: `api/notify_device_api.php` (register/`me`/DEV `token.set`), `portal/notify/race_control.php`, `event_announcements.php`, `permissions.php`, and `portal/api/notify_control_api.php`, `notify_control_send_api.php`, `notify_control_publish_api.php`, `notify_event_announcement_api.php`, `notify_permissions_api.php`.
- DB notification tables: `notify_devices`, `notify_subscriptions`, `notify_event_mutes`, `notify_messages`, `notify_deliveries`, `notify_staging_status`, `notify_audit_log`. Review current DDL/migrations, grants, unique keys, statuses, scopes, and role rules. Relevant classes include Pro 7.0, Pro 7.5, Pro Comp, Pro Gas, Modified Production, Nostalgia Super Stock, Nostalgia Gasser.
- DEV test event **ID 14** was used for development. Do NOT assume that event exists in PROD, or copy DEV announcement/delivery rows into PROD.
- Production notification switches were disabled during DEV work; no production pushes have been configured. Recheck this before any rollout.

## Production target — design before action

1. **Separate Firebase production project**, e.g. `ndrl-notifications-prod` (confirm chosen name is available), with FCM HTTP v1 API enabled, appropriate access/quotas, dedicated service accounts and least-privilege roles. Existing DEV service-account keys must remain DEV only. Prefer Workload Identity Federation/keyless auth if operationally feasible; if a production service-account key is approved, securely store it in a distinct protected production directory, mount read-only, and apply key rotation/revocation procedures. Google Cloud organization policies may block key creation; never weaken an organization-wide security policy casually.
2. **Android package/build flavors decision BEFORE Firebase configuration.** Current DEV uses `com.nostalgiadragleague.ndrl`, which would be the natural PROD package ID; design Android `dev`/`prod` flavors so DEV eventually becomes something like `com.nostalgiadragleague.ndrl.dev`, with PROD retaining `com.nostalgiadragleague.ndrl`. Changing DEV package requires a separate Firebase Android app registration, its own config and fresh emulator registrations. Establish Android/Gradle/flavor-specific Firebase configuration and Dart `--dart-define`/configuration, including DEV vs PROD API base URLs and on-screen environment indicator. Use separate signing/release strategy. Never ship a binary that uses PROD API with DEV Firebase credentials or vice versa.
3. **DEV/PROD server isolation**. Production API under existing `/srv/ndrl/prod` site; production notifications schema in correct PROD MariaDB. New production worker and secrets separate from `/srv/ndrl/firebase-worker-dev` and `/srv/ndrl-data/private/firebase/dev`. DB user should have only necessary table/column permissions for recipients, queue claims, and audited delivery status updates. Confirm Docker network and routing; do not attach PROD worker to `dev_ndrl_net`.
4. **Complete queue implementation before rollout**: select published approved messages, validate event/class/member permissions, expand recipient subscriptions, apply event mutes, exclude inactive/disabled devices, upsert unique `notify_deliveries` rows (message/device), transactional claims and concurrency safety, retry with bounded exponential backoff, appropriate `Retry-After`/429 handling, and classify permanent versus transient FCM errors. Treat invalid/unregistered tokens as disabled or cleared without logging token content. Enforce size/rate quotas, TTL/collapse behavior where appropriate, idempotency, metrics, audit trails, and protected operational logs. Staging announcements must not trigger repeat sends during state transitions. A Firebase 200 response means **accepted**, not necessarily displayed.
5. **No device-token migration** from DEV to PROD. Firebase registration tokens belong to the project/app installation; PROD builds must obtain fresh PROD tokens and register with PROD APIs. DEV installation IDs/secrets are likewise not assumed portable. Use separate installation registration and subscriptions.
6. **Mobile app release**: notification channels (especially Android 8+), permission flow Android 13+, foreground handlers and local UI, background/terminated behavior, notification click/deep link navigation, subscription preferences, token rotation via `onTokenRefresh`, logout/account association, removal/unregister, API error handling, class/event/news preferences, and validation on actual Android device(s). Verify iOS separately if ever planned; this is currently Android-only.
7. **Admin/operations**: protect Race Control endpoints with role checks and CSRF/authorization as appropriate, ensure publishing and queueing have explicit authority, restrict emergency/event-wide messages, maintain per-event mute enforcement, observe delivery dashboards, add kill-switch, cap per-run sends, prevent stale/accidental replay, design monitoring and safe rollback. Avoid logging account secrets/FCM tokens.

## Gated runbook you must carry out with me

**Phase A — Inventory only (safe):** Inspect `git status`, HEAD commit, DEV/PROD Docker manifests and network names, auth/notification source, DB DDL/indexes/grants (no passwords), secrets path metadata (no contents), Firebase IAM and package/build configurations, and current published PROD notification flags. Produce gap/risk checklist. Confirm backups before any migration.

**Phase B — Design/repo prep (DEV only):** Design environment-specific flavors, config, worker architecture, DB migrations with reversible scripts, smoke tests and rollout checklist. Commit in a separate reviewed change set. Never change PROD at this phase.

**Phase C — Separate Firebase PROD setup:** Create PROD project; enable required APIs; configure Android app ID, proper auth roles and dedicated credential; restrict secrets. Verify PROD credential resolves to PROD project, not DEV, using metadata-only output.

**Phase D — Database/server staging:** Create required PROD schema/migrations only after approval, take DB backup, use separate DB user and production-only network/secret volume, deploy production worker disabled (`restart: no` or gated scheduler), run safe `check` without sends, verify PROD toggles remain off.

**Phase E — Controlled pilot:** Build signed test/release candidate with PROD Firebase and PROD API, register only consenting admin/test devices, confirm isolated PROD device rows and opt-in subscriptions, send approved one-device PROD pilot message, verify receipt, receipts/audits, retries and no duplicates. Never assume device ID 2 applies to PROD.

**Phase F — Rollout:** Enable a limited set of events/classes/members with explicit authorization, monitor failures and rates, incrementally increase scope, document rollback. Keep DEV functioning independently.

**Phase G — Finalize:** Release/signing/Play Console strategy as appropriate, disaster recovery, secret rotation, rollback docs, deployment instructions, source-controlled configuration templates (never keys/passwords), and final audited PROD/DEV separation verification.

## Mandatory safety rules

- **Never** run `docker compose up`/restart worker against PROD, enable publishing, trigger a broadcast, or modify PROD DB without explicit approval after previewing precise commands and scope.
- Never paste/service-account JSON, full private key, `worker.env`, database passwords, Android keystores, installation secrets, or full FCM tokens into chat or version control.
- Review and validate that key creation restrictions, IAM permissions, GitHub credentials, VPN access, and production package IDs are correct. Make no unverified assumptions about production schema or path.
- Use dev only until test results are complete and approved.
- Begin by asking for **read-only inventory outputs**, not by creating a production Firebase project or sender.

References: https://firebase.google.com/docs/projects/multiprojects ; https://firebase.google.com/docs/flutter/setup ; https://firebase.google.com/docs/cloud-messaging/migrate-v1
