<?php
/**
 * NDRL DEVELOPMENT Firebase queue, milestone 4I.5.
 * Manual only. Device 2, event 14, messages > 8. No historical replay.
 * Ambiguous in-flight delivery states are NOT automatically retried.
 */
declare(strict_types=1);

const PROJECT = 'ndrl-notifications-dev';
const DEVICE_ID = 2;
const EVENT_ID = 14;
const MIN_MESSAGE_ID = 8;
const OAUTH_URI = 'https://oauth2.googleapis.com/token';
const MAX_ATTEMPTS = 3;

function say(string $s): void { fwrite(STDOUT, $s . PHP_EOL); }
function fail(string $s): never { fwrite(STDERR, "ERROR: $s\n"); exit(1); }
function setting(string $k): string {
    $v = getenv($k);
    if (!is_string($v) || $v === '') throw new RuntimeException("Missing setting $k");
    return $v;
}
function b64(string $str): string { return rtrim(strtr(base64_encode($str), '+/', '-_'), '='); }
function postJson(string $uri, array $headers, string $body): array {
    $c = curl_init($uri);
    if ($c === false) throw new RuntimeException('Cannot start HTTPS');
    curl_setopt_array($c, [
        CURLOPT_POST => true, CURLOPT_POSTFIELDS => $body,
        CURLOPT_HTTPHEADER => $headers, CURLOPT_RETURNTRANSFER => true,
        CURLOPT_CONNECTTIMEOUT => 10, CURLOPT_TIMEOUT => 30,
        CURLOPT_SSL_VERIFYPEER => true, CURLOPT_SSL_VERIFYHOST => 2,
        CURLOPT_FOLLOWLOCATION => false,
    ]);
    $raw = curl_exec($c);
    $status = (int)curl_getinfo($c, CURLINFO_RESPONSE_CODE);
    curl_close($c);
    if (!is_string($raw)) throw new RuntimeException('HTTPS request failed');
    $data = json_decode($raw, true);
    if (!is_array($data)) throw new RuntimeException("Non-JSON HTTPS response ($status)");
    return [$status, $data];
}
function oauth(array $key): string {
    $now = time();
    $head = b64(json_encode(['alg' => 'RS256','typ' => 'JWT'], JSON_THROW_ON_ERROR));
    $claim = b64(json_encode([
        'iss' => $key['client_email'],
        'scope' => 'https://www.googleapis.com/auth/firebase.messaging',
        'aud' => OAUTH_URI, 'iat' => $now, 'exp' => $now + 1800,
    ], JSON_THROW_ON_ERROR));
    $unsigned = "$head.$claim";
    $sig = '';
    if (!openssl_sign($unsigned, $sig, $key['private_key'], OPENSSL_ALGO_SHA256)) {
        throw new RuntimeException('OAuth signing failed');
    }
    [$status, $response] = postJson(OAUTH_URI, ['Content-Type: application/x-www-form-urlencoded'],
        http_build_query([
            'grant_type' => 'urn:ietf:params:oauth:grant-type:jwt-bearer',
            'assertion' => "$unsigned." . b64($sig),
        ]));
    if ($status !== 200 || !is_string($response['access_token'] ?? null)) {
        throw new RuntimeException("Google OAuth rejected assertion ($status)");
    }
    return $response['access_token'];
}
function db(): PDO {
    $pdo = new PDO('mysql:host=' . setting('DB_HOST') . ';port=3306;dbname=' . setting('DB_NAME') . ';charset=utf8mb4',
        setting('DB_USER'), setting('DB_PASSWORD'), [
            PDO::ATTR_ERRMODE => PDO::ERRMODE_EXCEPTION,
            PDO::ATTR_DEFAULT_FETCH_MODE => PDO::FETCH_ASSOC,
            PDO::ATTR_EMULATE_PREPARES => false,
            PDO::ATTR_TIMEOUT => 10,
        ]);
    $pdo->exec("SET time_zone = '+00:00'");
    return $pdo;
}
/** Determine current eligibility (including mutes) without exposing the token. */
function eligible(PDO $db, array $msg): ?array {
    $type = (string)$msg['audience'];
    if (!in_array($type, ['class', 'event'], true) || (int)$msg['event_id'] !== EVENT_ID) {
        return null; // milestone 4I.5 intentionally excludes news and other events
    }
    $sql = <<<'SQL'
SELECT d.device_id, d.push_token
FROM notify_devices d
WHERE d.device_id = :device
  AND d.is_active = 1
  AND d.notifications_enabled = 1
  AND d.push_token IS NOT NULL AND d.push_token <> ''
  AND EXISTS (
    SELECT 1 FROM notify_subscriptions s
    WHERE s.device_id = d.device_id AND s.is_enabled = 1
      AND ((:audience1 = 'class' AND s.subscription_type = 'class' AND s.class_id = :class_id)
        OR (:audience2 = 'event' AND s.subscription_type = 'event_general'))
  )
  AND NOT EXISTS (
    SELECT 1 FROM notify_event_mutes m
    WHERE m.device_id = d.device_id AND m.event_id = :event_id
  )
LIMIT 1
SQL;
    $s = $db->prepare($sql);
    $s->execute([
        'device' => DEVICE_ID,
        'audience1' => $type,
        'audience2' => $type,
        'class_id' => $msg['class_id'] === null ? 0 : (int)$msg['class_id'],
        'event_id' => EVENT_ID,
    ]);
    $row = $s->fetch();
    return $row ?: null;
}
function prepareQueue(PDO $db): void {
    $s = $db->prepare("SELECT message_id FROM notify_messages WHERE message_id > :min AND event_id = :event AND status = 'published' AND published_at IS NOT NULL AND audience IN ('class','event') ORDER BY message_id ASC LIMIT 25");
    $s->execute(['min' => MIN_MESSAGE_ID, 'event' => EVENT_ID]);
    $ids = $s->fetchAll(PDO::FETCH_COLUMN);
    foreach ($ids as $id) {
        $db->beginTransaction();
        try {
            $lock = $db->prepare('SELECT message_id, event_id, class_id, audience, status FROM notify_messages WHERE message_id = ? FOR UPDATE');
            $lock->execute([(int)$id]);
            $msg = $lock->fetch();
            if (!$msg || $msg['status'] !== 'published') { $db->commit(); continue; }
            $device = eligible($db, $msg);
            if ($device !== null) {
                $ins = $db->prepare("INSERT IGNORE INTO notify_deliveries (message_id, device_id, status) VALUES (?, ?, 'pending')");
                $ins->execute([(int)$id, DEVICE_ID]);
                $up = $db->prepare("UPDATE notify_messages SET status='queued', queued_at=UTC_TIMESTAMP() WHERE message_id=? AND status='published'");
                $up->execute([(int)$id]);
                say("Message $id queued for device " . DEVICE_ID . '.');
            } else {
                // No recipients in this deliberately single-device development scope.
                $up = $db->prepare("UPDATE notify_messages SET status='sent', sent_at=UTC_TIMESTAMP() WHERE message_id=? AND status='published'");
                $up->execute([(int)$id]);
                say("Message $id completed with no eligible test recipient; no push sent.");
            }
            $db->commit();
        } catch (Throwable $e) { if ($db->inTransaction()) $db->rollBack(); throw $e; }
    }
}
function claim(PDO $db): ?array {
    $db->beginTransaction();
    try {
        $sql = <<<'SQL'
SELECT d.delivery_id, d.message_id, d.attempts,
       m.event_id, m.class_id, m.audience, m.title, m.body, m.message_type, m.round_label
FROM notify_deliveries d
JOIN notify_messages m ON m.message_id = d.message_id
WHERE d.device_id = :device
  AND m.message_id > :min
  AND m.event_id = :event
  AND m.audience IN ('class', 'event')
  AND m.status IN ('queued', 'processing')
  AND (d.status = 'pending' OR (d.status = 'retry' AND (d.next_attempt_at IS NULL OR d.next_attempt_at <= UTC_TIMESTAMP())))
ORDER BY d.delivery_id ASC
LIMIT 1 FOR UPDATE
SQL;
        $s = $db->prepare($sql);
        $s->execute(['device' => DEVICE_ID, 'min' => MIN_MESSAGE_ID, 'event' => EVENT_ID]);
        $delivery = $s->fetch();
        if (!$delivery) { $db->commit(); return null; }
        $update = $db->prepare("UPDATE notify_deliveries SET status='processing', attempts=attempts+1, last_attempt_at=UTC_TIMESTAMP(), next_attempt_at=NULL WHERE delivery_id=?");
        $update->execute([(int)$delivery['delivery_id']]);
        $updateMessage = $db->prepare("UPDATE notify_messages SET status='processing' WHERE message_id=? AND status='queued'");
        $updateMessage->execute([(int)$delivery['message_id']]);
        $db->commit();
        return $delivery;
    } catch (Throwable $e) { if ($db->inTransaction()) $db->rollBack(); throw $e; }
}
function finalizeMessage(PDO $db, int $id): void {
    $s = $db->prepare("SELECT COUNT(*) AS unfinished, COALESCE(SUM(status='failed'),0) AS failures FROM notify_deliveries WHERE message_id=? AND status IN ('pending','processing','retry','failed')");
    $s->execute([$id]);
    $r = $s->fetch();
    if ((int)$r['unfinished'] > (int)$r['failures']) return;
    $status = (int)$r['failures'] > 0 ? 'failed' : 'sent';
    $s = $db->prepare("UPDATE notify_messages SET status=?, sent_at=UTC_TIMESTAMP() WHERE message_id=? AND status IN ('queued','processing')");
    $s->execute([$status, $id]);
}
function complete(PDO $db, array $d, string $status, ?string $providerId, ?string $reason, ?int $wait): void {
    $s = $db->prepare('UPDATE notify_deliveries SET status=?, provider_message_id=?, last_error=?, next_attempt_at=IF(? IS NULL,NULL,DATE_ADD(UTC_TIMESTAMP(),INTERVAL ? SECOND)) WHERE delivery_id=? AND status=\'processing\'');
    $s->execute([$status, $providerId, $reason, $wait, $wait, (int)$d['delivery_id']]);
    finalizeMessage($db, (int)$d['message_id']);
}
function runQueue(PDO $db, array $key): void {
    prepareQueue($db);
    $d = claim($db);
    if ($d === null) { say('No eligible pending delivery. No Firebase call made.'); return; }
    $id = (int)$d['delivery_id'];
    say("Processing delivery $id for message " . $d['message_id'] . ' and device 2.');
    $device = eligible($db, $d);
    if (!$device) {
        complete($db, $d, 'skipped', null, 'Recipient no longer eligible', null);
        say("Delivery $id skipped: recipient disabled, unsubscribed, muted, or missing token.");
        return;
    }
    // If Google auth or network fails unexpectedly after claiming, delivery remains
    // processing and must be inspected manually: blindly retrying risks duplicates.
    $token = oauth($key);
    $payload = json_encode(['message' => [
        'token' => $device['push_token'],
        'notification' => ['title' => $d['title'], 'body' => $d['body']],
        'data' => [
            'kind' => 'race_control',
            'message_id' => (string)$d['message_id'],
            'event_id' => (string)$d['event_id'],
            'class_id' => $d['class_id'] === null ? '' : (string)$d['class_id'],
            'ndrl_message_type' => (string)$d['message_type'],
            'round_label' => (string)($d['round_label'] ?? ''),
        ],
        'android' => ['priority' => 'HIGH'],
    ]], JSON_THROW_ON_ERROR);
    [$http, $res] = postJson('https://fcm.googleapis.com/v1/projects/' . PROJECT . '/messages:send',
        ['Authorization: Bearer ' . $token, 'Content-Type: application/json; charset=UTF-8'], $payload);
    if ($http === 200 && is_string($res['name'] ?? null)) {
        complete($db, $d, 'accepted', $res['name'], null, null);
        say("FCM accepted delivery $id. Provider message ID recorded.");
        return;
    }
    $error = $res['error'] ?? [];
    $reason = is_array($error) ? (string)($error['status'] ?? 'UNKNOWN') : 'UNKNOWN';
    $reason = preg_replace('/[^A-Z0-9_]/', '', strtoupper($reason)) ?: 'UNKNOWN';
    $attempt = (int)$d['attempts'] + 1;
    $transient = in_array($http, [408, 429, 500, 502, 503, 504], true);
    if ($transient && $attempt < MAX_ATTEMPTS) {
        $seconds = min(3600, 60 * (2 ** ($attempt - 1)));
        complete($db, $d, 'retry', null, "FCM_HTTP_{$http}_{$reason}", $seconds);
        say("Delivery $id scheduled for retry after $seconds seconds (HTTP $http, $reason).");
    } else {
        complete($db, $d, 'failed', null, "FCM_HTTP_{$http}_{$reason}", null);
        say("Delivery $id failed (HTTP $http, $reason). No automatic replay.");
    }
}
try {
    $mode = $argv[1] ?? 'inspect';
    if (!in_array($mode, ['inspect','run-once'], true) || ($mode === 'run-once' && ($argc !== 3 || $argv[2] !== '--confirm'))) {
        fail('Usage: inspect OR run-once --confirm');
    }
    if (setting('FIREBASE_PROJECT_ID') !== PROJECT || setting('DB_HOST') !== 'db'
        || setting('DB_NAME') !== 'ndrl_fantasy' || setting('DB_USER') !== 'ndrl_fcm_queue_dev'
        || setting('ALLOWED_DEVICE_ID') !== (string)DEVICE_ID || setting('DEV_EVENT_ID') !== (string)EVENT_ID) {
        fail('Development-only safety settings mismatch');
    }
    $file = setting('FIREBASE_CREDENTIALS');
    if ($file !== '/run/secrets/firebase-service-account.json' || !is_readable($file)) fail('Credential mount not readable');
    $key = json_decode((string)file_get_contents($file), true, 512, JSON_THROW_ON_ERROR);
    if (!is_array($key) || ($key['type'] ?? '') !== 'service_account'
        || ($key['project_id'] ?? '') !== PROJECT || !is_string($key['client_email'] ?? null)
        || !is_string($key['private_key'] ?? null)) fail('Unexpected Firebase credentials');
    $db = db();
    say('Firebase DEV and database credentials verified; hard limits: device 2, event 14, message IDs > 8.');
    if ($mode === 'inspect') {
        $s = $db->query("SELECT message_id, audience, class_id, status FROM notify_messages WHERE message_id > 8 AND event_id = 14 ORDER BY message_id DESC LIMIT 10");
        foreach ($s as $row) {
            say('Message ' . $row['message_id'] . ': ' . $row['audience'] . ' / class ' . ($row['class_id'] ?? '-') . ' / ' . $row['status']);
        }
        say('INSPECT ONLY. No data changed. No notification sent.');
    } else {
        runQueue($db, $key);
    }
} catch (Throwable $e) {
    // Do not echo exception strings: they may contain tokens or connection credentials.
    fail('Queue operation stopped (' . get_class($e) . '). Check configuration and DB delivery state; do not blindly rerun processing items.');
}
