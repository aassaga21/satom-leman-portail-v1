// Test de charge nominal (k6) : k6 run -e BASE_URL=https://dxxxx.cloudfront.net tests/load-test.js
// Critere TP : 0 erreur 5xx en charge nominale. Rester SOUS la limite WAF (500 req / 5 min / IP)
// => 1 requete/s par VU, 1 VU = 300 requetes / 5 min. Pour plus de charge, utiliser plusieurs IP
//    ou relever temporairement RateLimitPer5Min.
import http from 'k6/http';
import { check, sleep } from 'k6';

export const options = {
  scenarios: {
    nominal: { executor: 'constant-arrival-rate', rate: 1, timeUnit: '1s', duration: '4m', preAllocatedVUs: 5 },
  },
  thresholds: {
    'checks{type:no5xx}': ['rate==1.0'],
    http_req_duration: ['p(95)<500'],
  },
};

const BASE = __ENV.BASE_URL;
const PATHS = ['/', '/api/portefeuilles', '/static/style.css', '/api/health'];

export default function () {
  const res = http.get(`${BASE}${PATHS[Math.floor(Math.random() * PATHS.length)]}`);
  check(res, { 'pas de 5xx': (r) => r.status < 500 }, { type: 'no5xx' });
  sleep(0.1);
}
