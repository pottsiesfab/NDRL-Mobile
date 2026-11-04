<?php
/**
 * NDRL FCM DEVELOPMENT manual one-device tester.
 * Not an automated queue worker. No incoming HTTP server.
 * Explicitly limited to Firebase project ndrl-notifications-dev and device 2.
 */
declare(strict_types=1);

const TEST_PROJECT = 'ndrl-notifications-dev';
const TEST_DEVICE = 2;
const OAUTH_ENDPOINT = 'https://oauth2.googleapis.com/token';

function out(string $text): void { fwrite(STDOUT, $text . PHP_EOL); }
function abortRun(string $message): never {
    fwrite(STDERR, 'ERROR: ' . $message . PHP_EOL);
    exit(1);
}
function b64url(string $binary): string {
    return rtrim(strtr(base64_encode($binary), '+/', '-_'), '=');
}
function requireSetting(string $name): string {
    $value = getenv($name);
    if (!is_string($value) || $value === '') {
        abortRun("Missing configuration: $name");
    }
    return $value;
}
function request(string $url, array $headers, string $payload): array {
    $curl = curl_init($url);
    if ($curl === false) abortRun('Unable to initialize HTTPS client');
    curl_setopt_array($curl, [
        CURLOPT_POST => true,
        CURLOPT_POSTFIELDS => $payload,
        CURLOPT_HTTPHEADER => $headers,
        CURLOPT_RETURNTRANSFER => true,
        CURLOPT_CONNECTTIMEOUT => 10,
        CURLOPT_TIMEOUT => 25,
        CURLOPT_SSL_VERIFYPEER => true,
        CURLOPT_SSL_VERIFYHOST => 2,
        CURLOPT_FOLLOWLOCATION => false,
    ]);
    $body = curl_exec($curl);
    $status = (int)curl_getinfo($curl, CURLINFO_RESPONSE_CODE);
    $error = curl_error($curl);
    curl_close($curl);
    if ($body === false) abortRun('HTTPS connection failed: ' . $error);
    // Never echo raw HTTP responses; they may contain credentials or tokens.
    $parsed = json_decode($body, true);
    if (!is_array($parsed)) abortRun("Invalid remote JSON response (HTTP $status)");
    return [$status, $parsed];
}
function oauthToken(array $key): string {
    $now = time();
    $header = ['alg' => 'RS256', 'typ' => 'JWT'];
    $claims = [
        'iss' => $key['client_email'],
        'scope' => 'https://www.googleapis.com/auth/firebase.messaging',
        'aud' => OAUTH_ENDPOINT,
        'iat' => $now,
        'exp' => $now + 1800,
    ];
    $unsigned = b64url(json_encode($header, JSON_THROW_ON_ERROR)) . '.'
        . b64url(json_encode($claims, JSON_THROW_ON_ERROR));
    $signature = '';
    if (!openssl_sign($unsigned, $signature, $key['private_key'], OPENSSL_ALGO_SHA256)) {
        abortRun('Unable to sign Firebase OAuth assertion');
    }
    $assertion = $unsigned . '.' . b64url($signature);
    [$status, $response] = request(OAUTH_ENDPOINT,
        ['Content-Type: application/x-www-form-urlencoded'],
        http_build_query([
            'grant_type' => 'urn:ietf:params:oauth:grant-type:jwt-bearer',
            'assertion' => $assertion,
        ]));
    if ($status !== 200 || !isset($response['access_token'])) {
        $reason = (string)($response['error'] ?? 'unknown');
        abortRun("Google OAuth failed (HTTP $status; reason $reason)");
    }
    return (string)$response['access_token'];
}

try {
    $mode = $argv[1] ?? 'check';
    if (!in_array($mode, ['check', 'send-test'], true)) {
        abortRun('Usage: check OR send-test 2 --confirm');
    }
    if (requireSetting('FIREBASE_PROJECT_ID') !== TEST_PROJECT
        || requireSetting('ALLOWED_DEVICE_ID') !== (string)TEST_DEVICE
        || requireSetting('DB_NAME') !== 'ndrl_fantasy'
        || requireSetting('DB_HOST') !== 'db'
        || requireSetting('DB_USER') !== 'ndrl_fcm_dev') {
        abortRun('Worker safety settings mismatch');
    }
    if ($mode === 'send-test'
        && ($argc !== 4 || $argv[2] !== (string)TEST_DEVICE || $argv[3] !== '--confirm')) {
        abortRun('Sending requires: send-test 2 --confirm');
    }
    $path = requireSetting('FIREBASE_CREDENTIALS');
    if ($path !== '/run/secrets/firebase-service-account.json' || !is_readable($path)) {
        abortRun('Firebase key is not readable by dedicated worker user');
    }
    $key = json_decode((string)file_get_contents($path), true, 512, JSON_THROW_ON_ERROR);
    if (!is_array($key) || ($key['type'] ?? '') !== 'service_account'
        || ($key['project_id'] ?? '') !== TEST_PROJECT
        || empty($key['client_email']) || empty($key['private_key'])) {
        abortRun('Invalid or incorrect Firebase service account');
    }
    out('Firebase key: validated (' . TEST_PROJECT . ')');
    $db = new PDO(
        'mysql:host=' . requireSetting('DB_HOST') . ';port=3306;dbname=' . requireSetting('DB_NAME') . ';charset=utf8mb4',
        requireSetting('DB_USER'), requireSetting('DB_PASSWORD'),
        [PDO::ATTR_ERRMODE => PDO::ERRMODE_EXCEPTION,
         PDO::ATTR_DEFAULT_FETCH_MODE => PDO::FETCH_ASSOC,
         PDO::ATTR_TIMEOUT => 10,
         PDO::ATTR_EMULATE_PREPARES => false]
    );
    $stmt = $db->prepare('SELECT device_id, push_token, is_active, notifications_enabled FROM notify_devices WHERE device_id = ? LIMIT 1');
    $stmt->execute([TEST_DEVICE]);
    $device = $stmt->fetch();
    if (!$device || (int)$device['is_active'] !== 1
        || (int)$device['notifications_enabled'] !== 1
        || !is_string($device['push_token']) || $device['push_token'] === '') {
        abortRun('Test device 2 is missing, disabled, or lacks an FCM token');
    }
    out('Development DB: connected; device 2 active; token present (not displayed)');
    if ($mode === 'check') {
        out('CHECK PASSED. No OAuth token requested. No message sent.');
        exit(0);
    }
    $accessToken = oauthToken($key);
    out('Google OAuth: access token acquired (not displayed)');
    $payload = json_encode([
        'message' => [
            'token' => $device['push_token'],
            'notification' => [
                'title' => 'NDRL DEVELOPMENT TEST',
                'body' => 'This is a controlled Firebase test sent to emulator device 2 only.',
            ],
            'data' => ['kind' => 'development_test', 'device_id' => '2'],
            'android' => ['priority' => 'HIGH'],
        ],
    ], JSON_THROW_ON_ERROR);
    [$status, $response] = request(
        'https://fcm.googleapis.com/v1/projects/' . TEST_PROJECT . '/messages:send',
        ['Authorization: Bearer ' . $accessToken,
         'Content-Type: application/json; charset=UTF-8'],
        $payload
    );
    if ($status !== 200 || !isset($response['name'])) {
        $error = $response['error'] ?? [];
        $reason = is_array($error) ? ($error['status'] ?? 'unknown') : 'unknown';
        $code = is_array($error) ? ($error['code'] ?? $status) : $status;
        abortRun("FCM rejected test message (HTTP $status, code $code, status $reason)");
    }
    out('FCM accepted the test message. Message ID: ' . $response['name']);
    out('Acceptance does not by itself prove device display or delivery.');
} catch (Throwable $e) {
    // Do not print exception text that might include secrets or credentials.
    abortRun('Worker operation failed (' . get_class($e) . '). Check local configuration.');
}
