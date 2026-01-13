# Performance Testing with K6

## Overview

K6 is a modern load testing tool for testing the performance and reliability of your APIs. This guide shows how to setup and run performance tests for SmartRent API.

## Installation

### Windows (using Chocolatey)

Open PowerShell as Administrator and run:

```powershell
choco install k6 -y
```

### Windows (using winget)

```powershell
winget install k6 --source winget
```

### Manual Installation

1. Download from https://k6.io/docs/getting-started/installation/
2. Extract and add to PATH

### Verify Installation

```powershell
k6 version
```

## Basic K6 Test Script

Create a file `tests/performance/basic-load-test.js`:

```javascript
import http from 'k6/http';
import { check, sleep } from 'k6';

// Test configuration
export const options = {
  stages: [
    { duration: '30s', target: 10 },  // Ramp up to 10 users over 30s
    { duration: '1m', target: 10 },   // Stay at 10 users for 1 minute
    { duration: '30s', target: 0 },   // Ramp down to 0 users
  ],
  thresholds: {
    http_req_duration: ['p(95)<500'], // 95% of requests should be below 500ms
    http_req_failed: ['rate<0.01'],   // Error rate should be less than 1%
  },
};

const BASE_URL = 'https://dev.api.smartrent.io.vn';

export default function () {
  // Test health check endpoint
  const healthRes = http.get(`${BASE_URL}/actuator/health`);

  check(healthRes, {
    'health check status is 200': (r) => r.status === 200,
    'health check response time < 200ms': (r) => r.timings.duration < 200,
  });

  sleep(1);
}
```

## Running Tests

### Basic Load Test

```powershell
k6 run tests/performance/basic-load-test.js
```

### Run with Custom VUs (Virtual Users)

```powershell
# 10 VUs for 30 seconds
k6 run --vus 10 --duration 30s tests/performance/basic-load-test.js

# 100 VUs for 5 minutes
k6 run --vus 100 --duration 5m tests/performance/basic-load-test.js
```

### Smoke Test (minimal load)

```powershell
k6 run --vus 1 --duration 1m tests/performance/smoke-test.js
```

### Stress Test (high load)

```powershell
k6 run --vus 200 --duration 10m tests/performance/stress-test.js
```

## Advanced Test Scripts

### API Test with Authentication

Create `tests/performance/api-auth-test.js`:

```javascript
import http from 'k6/http';
import { check, sleep } from 'k6';

export const options = {
  stages: [
    { duration: '1m', target: 20 },
    { duration: '3m', target: 20 },
    { duration: '1m', target: 0 },
  ],
};

const BASE_URL = 'https://dev.api.smartrent.io.vn';

// Login and get token
function login() {
  const loginPayload = JSON.stringify({
    email: 'test@example.com',
    password: 'password123'
  });

  const params = {
    headers: {
      'Content-Type': 'application/json',
    },
  };

  const loginRes = http.post(`${BASE_URL}/v1/auth/login`, loginPayload, params);

  check(loginRes, {
    'login successful': (r) => r.status === 200,
  });

  return loginRes.json('access_token');
}

export default function () {
  const token = login();

  // Test protected endpoint
  const params = {
    headers: {
      'Authorization': `Bearer ${token}`,
      'Content-Type': 'application/json',
    },
  };

  const res = http.get(`${BASE_URL}/v1/users/me`, params);

  check(res, {
    'status is 200': (r) => r.status === 200,
    'response time < 500ms': (r) => r.timings.duration < 500,
  });

  sleep(1);
}
```

### Multiple Endpoints Test

Create `tests/performance/multiple-endpoints-test.js`:

```javascript
import http from 'k6/http';
import { check, group, sleep } from 'k6';

export const options = {
  stages: [
    { duration: '2m', target: 50 },
    { duration: '5m', target: 50 },
    { duration: '2m', target: 0 },
  ],
  thresholds: {
    'http_req_duration': ['p(95)<1000', 'p(99)<2000'],
    'http_req_failed': ['rate<0.05'],
    'group_duration{group:::API Health}': ['avg<200'],
    'group_duration{group:::Properties List}': ['avg<500'],
  },
};

const BASE_URL = 'https://dev.api.smartrent.io.vn';

export default function () {
  group('API Health', function () {
    const res = http.get(`${BASE_URL}/actuator/health`);
    check(res, {
      'health check OK': (r) => r.status === 200,
    });
  });

  group('Properties List', function () {
    const res = http.get(`${BASE_URL}/v1/properties`);
    check(res, {
      'properties list OK': (r) => r.status === 200 || r.status === 401,
    });
  });

  group('Contracts List', function () {
    const res = http.get(`${BASE_URL}/v1/contracts`);
    check(res, {
      'contracts list OK': (r) => r.status === 200 || r.status === 401,
    });
  });

  sleep(Math.random() * 3); // Random sleep between 0-3 seconds
}
```

### Spike Test (sudden traffic spike)

Create `tests/performance/spike-test.js`:

```javascript
import http from 'k6/http';
import { check, sleep } from 'k6';

export const options = {
  stages: [
    { duration: '10s', target: 10 },    // Normal load
    { duration: '30s', target: 200 },   // Sudden spike!
    { duration: '1m', target: 200 },    // Sustain spike
    { duration: '10s', target: 10 },    // Recovery
    { duration: '1m', target: 10 },     // Normal load
    { duration: '10s', target: 0 },     // Ramp down
  ],
};

const BASE_URL = 'https://dev.api.smartrent.io.vn';

export default function () {
  const res = http.get(`${BASE_URL}/actuator/health`);

  check(res, {
    'status is 200': (r) => r.status === 200,
  });

  sleep(1);
}
```

## Test Types

### 1. Smoke Test
**Purpose**: Verify system works with minimal load

```javascript
export const options = {
  vus: 1,
  duration: '1m',
};
```

### 2. Load Test
**Purpose**: Test system under expected normal load

```javascript
export const options = {
  stages: [
    { duration: '5m', target: 50 },   // Ramp up
    { duration: '10m', target: 50 },  // Stay at load
    { duration: '5m', target: 0 },    // Ramp down
  ],
};
```

### 3. Stress Test
**Purpose**: Find system breaking point

```javascript
export const options = {
  stages: [
    { duration: '2m', target: 100 },
    { duration: '5m', target: 100 },
    { duration: '2m', target: 200 },
    { duration: '5m', target: 200 },
    { duration: '2m', target: 300 },
    { duration: '5m', target: 300 },
    { duration: '10m', target: 0 },
  ],
};
```

### 4. Spike Test
**Purpose**: Test sudden traffic increase

```javascript
export const options = {
  stages: [
    { duration: '10s', target: 10 },
    { duration: '1m', target: 200 },   // Sudden spike
    { duration: '10s', target: 10 },
  ],
};
```

### 5. Soak Test (Endurance)
**Purpose**: Test system stability over extended period

```javascript
export const options = {
  stages: [
    { duration: '5m', target: 50 },
    { duration: '8h', target: 50 },    // Long duration
    { duration: '5m', target: 0 },
  ],
};
```

## Understanding K6 Metrics

### HTTP Metrics

- **http_req_duration**: Total request time
- **http_req_waiting**: Time waiting for response (TTFB)
- **http_req_connecting**: Time establishing TCP connection
- **http_req_tls_handshaking**: Time for TLS handshake
- **http_req_sending**: Time sending data
- **http_req_receiving**: Time receiving response
- **http_req_blocked**: Time blocked before initiating request
- **http_req_failed**: Rate of failed requests

### Example Output

```
     ✓ status is 200
     ✓ response time < 500ms

     checks.........................: 100.00% ✓ 1000      ✗ 0
     data_received..................: 2.5 MB  42 kB/s
     data_sent......................: 200 kB  3.3 kB/s
     http_req_blocked...............: avg=1.2ms    min=0s     med=0s      max=150ms   p(90)=0s      p(95)=0s
     http_req_connecting............: avg=650µs    min=0s     med=0s      max=80ms    p(90)=0s      p(95)=0s
     http_req_duration..............: avg=250ms    min=100ms  med=200ms   max=800ms   p(90)=400ms   p(95)=500ms
     http_req_failed................: 0.00%   ✓ 0         ✗ 1000
     http_req_receiving.............: avg=1.5ms    min=100µs  med=500µs   max=50ms    p(90)=3ms     p(95)=5ms
     http_req_sending...............: avg=500µs    min=50µs   med=200µs   max=10ms    p(90)=1ms     p(95)=2ms
     http_req_tls_handshaking.......: avg=500µs    min=0s     med=0s      max=70ms    p(90)=0s      p(95)=0s
     http_req_waiting...............: avg=248ms    min=98ms   med=198ms   max=795ms   p(90)=398ms   p(95)=498ms
     http_reqs......................: 1000    16.666667/s
     iteration_duration.............: avg=1.25s    min=1.1s   med=1.2s    max=1.8s    p(90)=1.4s    p(95)=1.5s
     iterations.....................: 1000    16.666667/s
     vus............................: 10      min=10      max=10
     vus_max........................: 10      min=10      max=10
```

## Thresholds

Thresholds define pass/fail criteria:

```javascript
export const options = {
  thresholds: {
    // 95% of requests should be below 500ms
    'http_req_duration': ['p(95)<500'],

    // 99% of requests should be below 1000ms
    'http_req_duration': ['p(99)<1000'],

    // Average response time should be below 300ms
    'http_req_duration': ['avg<300'],

    // Error rate should be less than 1%
    'http_req_failed': ['rate<0.01'],

    // 95% of checks should pass
    'checks': ['rate>0.95'],
  },
};
```

## Output Formats

### JSON Output

```powershell
k6 run --out json=results.json tests/performance/load-test.js
```

### CSV Output

```powershell
k6 run --out csv=results.csv tests/performance/load-test.js
```

### InfluxDB + Grafana (Advanced)

```powershell
k6 run --out influxdb=http://localhost:8086/k6 tests/performance/load-test.js
```

## Running K6 in Kubernetes

For distributed testing, you can run K6 in Kubernetes:

### Create K6 Job

Create `tests/performance/k6-job.yaml`:

```yaml
apiVersion: batch/v1
kind: Job
metadata:
  name: k6-load-test
  namespace: dev
spec:
  template:
    spec:
      containers:
      - name: k6
        image: grafana/k6:latest
        args:
        - run
        - --vus=50
        - --duration=5m
        - /scripts/load-test.js
        volumeMounts:
        - name: k6-scripts
          mountPath: /scripts
      volumes:
      - name: k6-scripts
        configMap:
          name: k6-scripts
      restartPolicy: Never
  backoffLimit: 1
```

### Create ConfigMap with test script

```powershell
kubectl create configmap k6-scripts -n dev --from-file=tests/performance/load-test.js
```

### Run the job

```powershell
kubectl apply -f tests/performance/k6-job.yaml
```

### View logs

```powershell
kubectl logs -n dev job/k6-load-test -f
```

## Best Practices

1. **Start Small**: Begin with smoke tests before running large load tests

2. **Ramp Up Gradually**: Don't jump straight to max load
   ```javascript
   stages: [
     { duration: '2m', target: 50 },   // Gradual ramp up
     { duration: '5m', target: 100 },
     { duration: '2m', target: 0 },
   ]
   ```

3. **Use Realistic Data**: Use production-like test data

4. **Think Delays**: Add sleep between requests to simulate real users
   ```javascript
   sleep(Math.random() * 5); // Random 0-5 seconds
   ```

5. **Monitor Backend**: Watch logs in Grafana while running tests

6. **Set Thresholds**: Define acceptable performance metrics

7. **Test Different Scenarios**: Mix read/write operations

8. **Run in CI/CD**: Automate performance tests in your pipeline

## Common Issues

### SSL/TLS Errors

Add to script:
```javascript
export const options = {
  insecureSkipTLSVerify: true, // Only for testing!
};
```

### Rate Limiting

If you hit rate limits, adjust:
```javascript
export const options = {
  rps: 100, // Limit to 100 requests per second
};
```

### Timeout Errors

Increase timeout:
```javascript
export const options = {
  httpDebug: 'full',
  timeout: '60s',
};
```

## Monitoring Performance Tests

While running K6 tests, monitor in Grafana:

1. Go to Grafana dashboard
2. Look at "Log Rate" - should see spike during test
3. Look at "Error Logs" - watch for errors
4. Check backend pod CPU/Memory usage

## Example Test Plan

### Day 1: Smoke Tests
- 1 VU for 1 minute
- Verify all endpoints work

### Day 2: Light Load
- 10 VUs for 5 minutes
- Establish baseline metrics

### Day 3: Normal Load
- 50 VUs for 10 minutes
- Test expected production load

### Day 4: Heavy Load
- 100 VUs for 10 minutes
- Test peak traffic

### Day 5: Stress Test
- Ramp up to 200+ VUs
- Find breaking point

### Week 2: Soak Test
- 50 VUs for 8 hours
- Test for memory leaks and stability

## Resources

- [K6 Documentation](https://k6.io/docs/)
- [K6 Examples](https://k6.io/docs/examples/)
- [K6 Cloud](https://k6.io/cloud/) - Managed K6 service
- [Awesome K6](https://github.com/grafana/awesome-k6) - Curated resources
