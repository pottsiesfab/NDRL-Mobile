# NDRL Firebase Manual Test Worker (development only)

No general queue processing. No ports exposed. Only `device_id=2` and project `ndrl-notifications-dev` are accepted by the code.

## Install and configure on ndrlsite

Unzip folder into `/srv/ndrl/firebase-worker-dev` (outside `/srv/ndrl/dev` and `/srv/ndrl/prod`).

1. Verify Firebase key exists at `/srv/ndrl-data/private/firebase/dev/service-account.json`, with expected project. Parent directories stay root-only.
2. `cd /srv/ndrl/firebase-worker-dev`
3. `sudo bash setup-db-user.sh` (creates a restricted MariaDB user, root-readable worker.env, and group-readable key for UID/GID 20070).
4. `sudo docker compose build worker`
5. `sudo docker compose run --rm worker check` — safe preflight only.
6. **Only after verifying** the key, device, and project: `sudo docker compose run --rm worker send-test 2 --confirm`.

Note: On Docker Compose, `run` overrides the image CMD but preserves ENTRYPOINT, allowing the two supported commands.

The returned FCM `name` means Google accepted the request, not necessarily that Android displayed it. To see a system notification, background the app on the emulator first (Home button). Foreground messages may be delivered only to the app's onMessage handler.

## Security

- Existing parent `/srv/ndrl-data/private` ACLs are not changed.
- Firebase service-account key is bind-mounted **read-only** into only the worker, not Apache.
- Host file is root:20070 0640; directories remain root-only (2700/0700). UID 20070 runs the container.
- Worker env is root:root 0600; use `sudo docker compose` to read it.
- The Docker group is root-equivalent; only trusted VPS admins should have Docker access.
- Worker DB account is SELECT-limited to four columns of `ndrl_fantasy.notify_devices`.
- No delivery records, subscriptions, or staging records are modified.
- No automated scheduler or restart policy; each send must be manually invoked.
- The test device token is a sensitive identifier; don't paste it into logs/chats.

For production, plan a proper database-backed queue worker, rate limiting, idempotency, token revocation handling, and more robust FCM error classification.
