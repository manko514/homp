/**
 * k6 load test: 1 000 concurrent QR code scans (guest self-service check-in)
 *
 * Usage:
 *   k6 run --env BASE_URL=http://localhost:3001 \
 *          --env QR_TOKENS=token1,token2,token3 \
 *          k6/qr-scan.js
 *
 * The QR-scan endpoint is unauthenticated (guests scan without logging in).
 * QR_TOKENS should be pre-generated reservation QR payloads (base64 or UUID).
 *
 * Thresholds (fail the test if these are breached):
 *   - 95th percentile response time < 500 ms (QR scan must feel instant)
 *   - error rate < 0.5%
 */

import http from 'k6/http';
import { check, sleep } from 'k6';
import { Trend, Rate, Counter } from 'k6/metrics';

// ─── Custom metrics ───────────────────────────────────────────────────────────
const qrScanDuration = new Trend('qr_scan_duration', true);
const qrScanErrors = new Rate('qr_scan_errors');
const qrScansTotal = new Counter('qr_scans_total');

// ─── Options ──────────────────────────────────────────────────────────────────
export const options = {
  scenarios: {
    qr_burst: {
      executor: 'ramping-vus',
      startVUs: 0,
      stages: [
        { duration: '20s', target: 250 },   // quick ramp — simulate a tour group arriving
        { duration: '60s', target: 1000 },  // ramp to 1 000 VUs
        { duration: '120s', target: 1000 }, // hold
        { duration: '20s', target: 0 },     // cool down
      ],
    },
  },
  thresholds: {
    http_req_duration: ['p(95)<500'],       // 95th pct under 500 ms
    qr_scan_errors: ['rate<0.005'],         // fewer than 0.5% errors
    http_req_failed: ['rate<0.005'],
  },
};

// ─── Setup ────────────────────────────────────────────────────────────────────
const BASE_URL = __ENV.BASE_URL || 'http://localhost:3001';

// QR tokens (reservation identifiers embedded in guest QR codes)
let qrTokens = [];
if (__ENV.QR_TOKENS) {
  qrTokens = __ENV.QR_TOKENS.split(',').map((s) => s.trim()).filter(Boolean);
} else {
  // Fallback placeholder tokens — replace with real tokens from your seed data
  qrTokens = ['placeholder-qr-token-1', 'placeholder-qr-token-2', 'placeholder-qr-token-3'];
}

// ─── Virtual-user script ──────────────────────────────────────────────────────
export default function () {
  const token = qrTokens[Math.floor(Math.random() * qrTokens.length)];

  // Endpoint: GET /hotel/qr-checkin/:token  (public, no auth needed)
  const url = `${BASE_URL}/hotel/qr-checkin/${encodeURIComponent(token)}`;
  const params = {
    headers: { 'Accept': 'application/json' },
    timeout: '5s',
  };

  const res = http.get(url, params);

  const ok = check(res, {
    'status is 200': (r) => r.status === 200,
    'status is not 5xx': (r) => r.status < 500,
    'has reservation data': (r) => {
      try { return !!JSON.parse(r.body); } catch { return false; }
    },
    'response time < 1s': (r) => r.timings.duration < 1000,
  });

  qrScanDuration.add(res.timings.duration);
  qrScanErrors.add(!ok);
  qrScansTotal.add(1);

  // Guests scan and wait briefly before the next action
  sleep(Math.random() * 0.3 + 0.05); // 50–350 ms
}

// ─── Teardown summary ─────────────────────────────────────────────────────────
export function handleSummary(data) {
  const p95 = data.metrics.http_req_duration?.values?.['p(95)'] ?? 0;
  const p99 = data.metrics.http_req_duration?.values?.['p(99)'] ?? 0;
  const errRate = (data.metrics.qr_scan_errors?.values?.rate ?? 0) * 100;
  const total = data.metrics.qr_scans_total?.values?.count ?? 0;

  console.log(`\nQR-scan load test complete`);
  console.log(`  Total scans : ${total}`);
  console.log(`  p95 latency : ${p95.toFixed(0)} ms`);
  console.log(`  p99 latency : ${p99.toFixed(0)} ms`);
  console.log(`  Error rate  : ${errRate.toFixed(2)}%`);

  return {
    'stdout': JSON.stringify(data, null, 2),
  };
}
