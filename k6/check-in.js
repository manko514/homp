/**
 * k6 load test: 500 concurrent hotel check-ins
 *
 * Usage:
 *   k6 run --env BASE_URL=http://localhost:3001 \
 *          --env TENANT_TOKEN=<jwt> \
 *          --env RESERVATION_IDS_FILE=./reservation_ids.txt \
 *          k6/check-in.js
 *
 * Or with inline data (set RESERVATION_IDS as comma-separated list):
 *   k6 run --env BASE_URL=http://localhost:3001 \
 *          --env TENANT_TOKEN=<jwt> \
 *          --env RESERVATION_IDS=id1,id2,id3 \
 *          k6/check-in.js
 *
 * Thresholds (fail the test if these are breached):
 *   - 95th percentile response time < 1 000 ms
 *   - error rate < 1%
 */

import http from 'k6/http';
import { check, sleep } from 'k6';
import { Trend, Rate } from 'k6/metrics';

// ─── Custom metrics ───────────────────────────────────────────────────────────
const checkInDuration = new Trend('check_in_duration', true);
const checkInErrors = new Rate('check_in_errors');

// ─── Options ──────────────────────────────────────────────────────────────────
export const options = {
  scenarios: {
    peak_check_in: {
      executor: 'ramping-vus',
      startVUs: 0,
      stages: [
        { duration: '30s', target: 100 },   // ramp up to 100 VUs
        { duration: '60s', target: 500 },   // ramp up to 500 VUs
        { duration: '120s', target: 500 },  // hold at 500
        { duration: '30s', target: 0 },     // ramp down
      ],
    },
  },
  thresholds: {
    http_req_duration: ['p(95)<1000'],      // 95th pct under 1 s
    check_in_errors: ['rate<0.01'],         // fewer than 1% errors
    http_req_failed: ['rate<0.01'],
  },
};

// ─── Setup ────────────────────────────────────────────────────────────────────
const BASE_URL = __ENV.BASE_URL || 'http://localhost:3001';
const TOKEN = __ENV.TENANT_TOKEN || '';

// Reservation IDs — either inline CSV or a newline-separated text file
let reservationIds = [];
if (__ENV.RESERVATION_IDS) {
  reservationIds = __ENV.RESERVATION_IDS.split(',').map((s) => s.trim()).filter(Boolean);
} else {
  // Fallback: test IDs (replace with real UUIDs in your environment)
  reservationIds = ['placeholder-reservation-id-1', 'placeholder-reservation-id-2'];
}

// ─── Virtual-user script ──────────────────────────────────────────────────────
export default function () {
  const reservationId = reservationIds[Math.floor(Math.random() * reservationIds.length)];

  const url = `${BASE_URL}/hotel/reservations/${reservationId}/check-in`;
  const params = {
    headers: {
      'Content-Type': 'application/json',
      Authorization: `Bearer ${TOKEN}`,
    },
    timeout: '10s',
  };

  const res = http.patch(url, null, params);

  const ok = check(res, {
    'status is 200 or 204': (r) => r.status === 200 || r.status === 204,
    'status is not 5xx': (r) => r.status < 500,
    'response time < 2s': (r) => r.timings.duration < 2000,
  });

  checkInDuration.add(res.timings.duration);
  checkInErrors.add(!ok);

  // Brief think-time between requests (simulate realistic spacing)
  sleep(Math.random() * 0.5 + 0.1); // 100–600 ms
}

// ─── Teardown (optional summary) ─────────────────────────────────────────────
export function handleSummary(data) {
  const p95 = data.metrics.http_req_duration?.values?.['p(95)'] ?? 0;
  const errRate = (data.metrics.check_in_errors?.values?.rate ?? 0) * 100;
  console.log(`\nCheck-in load test complete`);
  console.log(`  p95 latency : ${p95.toFixed(0)} ms`);
  console.log(`  Error rate  : ${errRate.toFixed(2)}%`);
  return {
    'stdout': JSON.stringify(data, null, 2),
  };
}
