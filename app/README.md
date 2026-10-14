# Sentinel-Ops – Mock Payment Gateway (P3)

Part of the [Sentinel-Ops](../README.md) observability platform. This service is the
showcase application used by the platform: Prometheus scrapes its metrics, Grafana
visualizes them, and the load simulator stresses it to trigger Alertmanager rules.

## Quick Start
From the repository root:
```bash
docker compose up -d --build
docker compose ps
```
The compose file starts five services on the `sentinel-net` network:

| Service | Port |
|---|---|
| `payment-gateway` (this app) | 5000 |
| `prometheus` | 9090 |
| `grafana` | 3000 |
| `alertmanager` | 9093 |
| `node-exporter` | 9100 |

## Endpoints

| Endpoint   | Method | Description                                  |
|------------|--------|-----------------------------------------------|
| `/health`  | GET    | Liveness check — confirms the service is up   |
| `/api/pay` | POST   | Simulates a payment (random success/failure)  |
| `/metrics` | GET    | Prometheus metrics                            |

### Test example
```bash
curl http://localhost:5000/health

curl -X POST http://localhost:5000/api/pay \
  -H "Content-Type: application/json" \
  -d '{"amount": 120.50, "currency": "USD"}'

curl http://localhost:5000/metrics
```

## Metrics (Prometheus scrape target: `payment-gateway:5000`)
- `payment_requests_total{status="success|failed"}`
- `payment_request_duration_seconds` (histogram)
- `orders_successful_total`
- `transaction_failures_total{reason=...}`

## Configuration
Set in `docker-compose.yml` under the `payment-gateway` service:

| Variable | Default | Description |
|---|---|---|
| `FAILURE_RATE` | `0.1` | Fraction of simulated payments that fail |
| `MIN_LATENCY_MS` | `50` | Minimum simulated processing time |
| `MAX_LATENCY_MS` | `400` | Maximum simulated processing time |

## Verification
```bash
bash scripts/verify-deployment.sh
```
Checks that `/health` responds, `/metrics` exposes `payment_requests_total`, and sends one
sample transaction. Port `5000` is not exposed publicly on the Azure VM, so run it from
inside the VM (`SERVICE_URL` defaults to `http://localhost:5000`).

## Load Simulation

| Script | Language | Description |
|---|---|---|
| `scripts/load_simulator.py` | Python | Concurrent workers, live stats, latency tracking |
| `scripts/load_simulator.sh` | Bash | Lightweight sequential alternative |

```bash
python -m pip install -r scripts/requirements-loadtest.txt
python scripts/load_simulator.py --url http://localhost:5000 --rate 50 --duration 300 --workers 50
```

| Option | Description |
|---|---|
| `--url` | Base URL of the payment gateway |
| `--rate` | Target combined requests per second |
| `--duration` | Run time in seconds |
| `--workers` | Number of concurrent worker threads |

The simulator prints live counters and a final summary (total, successful, failed,
connection errors, average and maximum latency, actual rate).

### Result: 5-minute run
| Metric | Value |
|---|---|
| Total requests | 15,049 |
| Successful / failed | 13,518 / 1,531 (about 10.2% failed) |
| Connection errors | 0 |
| Average / max latency | 235.4 ms / 443.8 ms |
| Actual rate | 49.95 req/s |

## Monitoring

### Prometheus targets
| Target | Endpoint |
|---|---|
| `payment-gateway` | `http://payment-gateway:5000/metrics` |
| `node-exporter` | `http://node-exporter:9100/metrics` |

### Grafana dashboard
`grafana/sentinel-ops-dashboard.json` defines the **Sentinel Ops Monitoring** dashboard:
successful orders, failed transactions, payment gateway latency, payment gateway CPU and
memory, host CPU, host memory, host disk usage and host network throughput.

### Alert rules (`/etc/prometheus/alert_rules.yml`)

| Alert | Expression | Severity |
|---|---|---|
| `HighTransactionFailures` | `sum(increase(transaction_failures_total[5m])) >= 1` | warning |
| `HighCPUUsage` | `100 - (avg by (instance) (rate(node_cpu_seconds_total{job="node-exporter",mode="idle"}[5m])) * 100) > 80` for 2m | critical |

Both alerts were triggered and delivered to Alertmanager:
- `HighTransactionFailures` fired during the load simulation (272 failures in 5 minutes).
- `HighCPUUsage` moved from Pending to Firing under a CPU stress test (99.9% CPU):
  ```bash
  docker run -d --rm --name cpu-stress alpine sh -c 'for i in $(seq 1 $(nproc)); do (while :; do :; done) & done; sleep 600'
  ```

## Checklist
- [x] Mock payment gateway API with Prometheus metrics
- [x] Dockerfile and Docker Compose setup
- [x] Post-deployment verification script
- [x] Python and Bash load simulators
- [x] Prometheus scraping the gateway and node-exporter
- [x] Grafana dashboard displaying application and infrastructure metrics
- [x] Alertmanager receiving `HighTransactionFailures` and `HighCPUUsage`
