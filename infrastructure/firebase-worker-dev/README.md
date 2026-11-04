# NDRL DEV FCM queue - milestone 4I.5 (guarded manual prototype)

* Does **not** replace the known-good `worker.php` and `compose.yaml`.
* No service or cron. Single explicit invocation processes **up to one delivery**.
* Hardcoded Firebase project: `ndrl-notifications-dev`.
* Hardcoded device: `2`; event: `14`; historic messages `<=8` excluded.
* Class and event audiences only. News and other events intentionally deferred.
* Subscriptions and event mutes checked at enqueue and **again before send**.
* A `processing` delivery is deliberately not auto-replayed; a crash after Firebase acceptance creates ambiguous delivery outcome. Review such rows manually.
* Retriable explicit HTTP errors: 408/429/5xx, up to three attempts with backoff; unknown transport errors leave delivery in processing for manual review.
* FCM 200 signifies **acceptance**, not guaranteed display.

## Installation

Copy these five files into `/srv/ndrl/firebase-worker-dev` (without deleting old files).
Run `sudo bash setup-queue-db-user.sh` once, then `sudo docker compose -f compose.queue.yaml build queue`.

## Subscription

Run on DEV only:

```bash
docker exec -i dev-db-1 sh -c 'mariadb -u root -p"$MYSQL_ROOT_PASSWORD" ndrl_fantasy' <<'SQL'
INSERT INTO notify_subscriptions (device_id, subscription_type, class_id, is_enabled)
VALUES (2, 'class', 1, 1)
ON DUPLICATE KEY UPDATE is_enabled=1;
SELECT device_id, subscription_type, class_id, is_enabled
FROM notify_subscriptions WHERE device_id=2;
SQL
```

## Verify

```bash
cd /srv/ndrl/firebase-worker-dev
sudo docker compose -f compose.queue.yaml run --rm queue inspect
```

Then create and **publish a new** message for DEV event 14 and Pro 7.0 (class ID 1) through the DEV Race Control UI. Only IDs > 8 qualify. From the VPS:

```bash
sudo docker compose -f compose.queue.yaml run --rm queue run-once --confirm
```

One delivery is processed per invocation. Nothing is scheduled. A new message published while device 2 is unsubscribed will be completed with no recipients (by design for this test scope).

## Inspect results

```bash
docker exec dev-db-1 sh -c 'mariadb -u root -p"$MYSQL_ROOT_PASSWORD" ndrl_fantasy -e "SELECT message_id, status, queued_at, sent_at FROM notify_messages WHERE message_id > 8 ORDER BY message_id DESC LIMIT 10; SELECT delivery_id, message_id, device_id, status, attempts, provider_message_id, last_error FROM notify_deliveries WHERE device_id = 2 ORDER BY delivery_id DESC LIMIT 10;"'
```

**Important:** This is a guarded development prototype, *not* the final multi-device production queue. In production we will replace the hardcoded recipient, use robust worker leasing/recovery and true queue orchestration, and define policy for ambiguous delivery outcomes.
