#!/usr/bin/env bash
# Run via sudo bash setup-db-user.sh on ndrlsite.
set -euo pipefail
if [[ "$(id -u)" != 0 ]]; then echo 'Run as root using sudo.' >&2; exit 1; fi
if ! docker inspect dev-db-1 --format '{{.State.Running}}' | grep -qx true; then
  echo 'Development database container is not running' >&2; exit 1
fi
root=/srv/ndrl-data/private/firebase/dev
key="$root/service-account.json"
if [[ ! -f "$key" ]]; then echo 'Firebase service key missing' >&2; exit 1; fi
if ! getent group 20070 >/dev/null; then groupadd --gid 20070 ndrl_fcm_dev; fi
# Parent directories remain root-only. A single-file Docker bind mount
# gives the worker access without granting host directory traversal.
setfacl -b "$key"
chown root:20070 "$key"
chmod 0640 "$key"
secret="$(openssl rand -hex 32)"
# Root-owned environment file, read by sudo docker compose on the host.
umask 077
printf 'DB_HOST=db\nDB_NAME=ndrl_fantasy\nDB_USER=ndrl_fcm_dev\nDB_PASSWORD=%s\n' "$secret" > "$root/worker.env"
chown root:root "$root/worker.env"
chmod 0600 "$root/worker.env"
# MYSQL_ROOT_PASSWORD is expanded only inside the DB container.
# The generated password uses hex characters only, avoiding SQL quoting issues.
docker exec -i dev-db-1 sh -c 'mariadb -u root -p"$MYSQL_ROOT_PASSWORD"' <<SQL
CREATE USER IF NOT EXISTS 'ndrl_fcm_dev'@'%' IDENTIFIED BY '$secret';
ALTER USER 'ndrl_fcm_dev'@'%' IDENTIFIED BY '$secret';
GRANT SELECT (device_id, push_token, is_active, notifications_enabled)
  ON ndrl_fantasy.notify_devices TO 'ndrl_fcm_dev'@'%';
SQL
unset secret
printf 'DB user created/updated with column-limited SELECT; env stored root-only.\n'
stat -c '%a %U:%G %n' "$key" "$root/worker.env"
