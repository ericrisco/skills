// Example k6 load test shipped with the scaling skill.
// Used as the checkable artifact for verify.sh and as a copy-paste starting point.
// Run against a PROD-LIKE target, never localhost: TARGET_URL=https://staging.example.com k6 run example.load.js
import http from 'k6/http';
import { check, sleep } from 'k6';

export const options = {
  stages: [
    { duration: '1m', target: 50 }, // ramp up to 50 virtual users
    { duration: '3m', target: 50 }, // hold steady (this is the load test)
    { duration: '1m', target: 0 },  // ramp down
  ],
  thresholds: {
    http_req_duration: ['p(95)<500'], // SLO: 95% of requests under 500 ms
    http_req_failed: ['rate<0.01'],   // SLO: under 1% errors
  },
};

export default function () {
  const target = __ENV.TARGET_URL || 'https://staging.example.com';
  const res = http.get(`${target}/api/health`);
  check(res, { 'status is 200': (r) => r.status === 200 });
  sleep(1);
}
