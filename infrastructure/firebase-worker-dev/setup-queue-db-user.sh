#!/usr/bin/env bash
set -euo pipefail

PRIVATE=/srv/ndrl-data/private/firebase/dev
ENVFILE="$PRIVATE/worker-queue.env"
DB_CONTAINER=dev-db-1
DB_USER=ndrl_fcm_queue_dev

if [[ $EUID -ne 0 ]]; then echo 'Run with sudo.' >&2; exit 1; fi
if [[ -e "$ENVFILE" ]]; then
  echo "Refusing to overwrite existing $ENVFILE" >&2
  exit 1
fi
if ! docker inspect "$DB_CONTAINER" >/dev/null 2>&1; then
  echo 'Missing development DB container.' >&2; exit 1
fi
if [[ ! -f "$PRIVATE/service-account.json" ]]; then echo 'Firebase credential missing.' >&2; exit 1; fi
PASSWORD="$(openssl rand -hex 32)"
# Hex-only password is safe within the quoted SQL literal.
docker exec -i "$DB_CONTAINER" sh -c 'exec mariadb -u root -p"$MYSQL_ROOT_PASSWORD"' <<SQL
CREATE USER IF NOT EXISTS '${DB_USER}'@'%' IDENTIFIED BY '${PASSWORD}';
ALTER USER '${DB_USER}'@'%' IDENTIFIED BY '${PASSWORD}';
GRANT SELECT (device_id, push_token, is_active, notifications_enabled)
  ON ndrl_fantasy.notify_devices TO '${DB_USER}'@'%';
GRANT SELECT ON ndrl_fantasy.notify_subscriptions TO '${DB_USER}'@'%';
GRANT SELECT ON ndrl_fantasy.notify_event_mutes TO '${DB_USER}'@'%';
GRANT SELECT, UPDATE ON ndrl_fantasy.notify_messages TO '${DB_USER}'@'%';
GRANT SELECT, INSERT, UPDATE ON ndrl_fantasy.notify_deliveries TO '${DB_USER}'@'%';
SQL
umask 077
printf 'DB_HOST=db\nDB_NAME=ndrl_fantasy\nDB_USER=%s\nDB_PASSWORD=%s\n' "$DB_USER" "$PASSWORD" > "$ENVFILE"
chown root:root "$ENVFILE"
chmod 0600 "$ENVFILE"
# Docker mounts ONLY the individual credential file; no directory permissions change.
stat -c '%a %U:%G %n' "$ENVFILE" "$PRIVATE/service-account.json"
echo 'Restricted queue database user and root-only env file created. No secrets printed.'
