# Sentinel-Ops – Mock Payment Gateway (P3, Week 1)

Part of the [Sentinel-Ops](../README.md) observability platform. This service is the
**showcase/load-testing application** referenced in the main project README — it is not
production infrastructure, only a lightweight target for Prometheus to scrape and for the
Week 3 load simulator to stress-test.

## Task Scope
- Build a lightweight mock payment gateway API
- Set up the local application container (Docker Compose)

## Quick Start
```bash
cd sentinel-ops-p3
docker compose up -d --build
```
> Confirmed against `scripts/install.sh`: the team's servers only install the
> `docker-compose-plugin` (Compose V2), so `docker compose` (no hyphen) is the
> correct and only supported syntax — matches the root project README's convention.

Service is running: `http://localhost:5000`

## Endpoints 

| Endpoint      | Method | Description                                      |
|---------------|--------|---------------------------------------------|
| `/health`     | GET    | Health chech                       |
| `/api/pay`    | POST   | Simulating a payment transaction(random success/failure)          |
| `/metrics`    | GET    | For Prometheus scraping (P4)             |

### Example test
```bash
curl http://localhost:5000/health

curl -X POST http://localhost:5000/api/pay \
  -H "Content-Type: application/json" \
  -d '{"amount": 120.50, "currency": "USD"}'

curl http://localhost:5000/metrics
```

## Available metrics P4 (Prometheus scrape target: `payment-gateway:5000`)
- `payment_requests_total{status="success|failed"}`
- `payment_request_duration_seconds` (histogram)
- `orders_successful_total`
- `transaction_failures_total{reason=...}`

## Integration Notes (alignment with team repo)
- **Compose command:** standardized on `docker compose up -d --build` to match the root
  project README's `docker-compose up -d` convention.
- **Network:** service joins a named bridge network `sentinel-net` — P4 should attach
  their Prometheus/Grafana services to the **same network name** so containers can
  resolve each other by service name (`payment-gateway:5000`).
- **Folder placement:** this service lives under `app/` at the repo root, alongside
  the existing `scripts/` and `terraform/` folders — confirm with the team this naming
  doesn't conflict with anything already planned.
- **Docker/Compose version:** verified against `scripts/install.sh` — Compose V2
  plugin only, `docker compose` syntax confirmed correct. ✅
- **NSG / firewall rules:** confirmed with `terraform/main.tf` — no NSG resource
  exists yet (only Resource Group, VNet, Subnet). Port `5000` is neither blocked nor
  explicitly allowed. **Action needed:** decide with the team whether the API should
  stay internal-only (reachable just by Prometheus on the same Docker network — no NSG
  change needed) or be exposed externally (e.g. for a load simulator running off-VM),
  in which case P1 needs to add an NSG rule for port `5000` in Week 2.

## Next Step (coordination with P4)
Ask P4 to add the Prometheus service to this same `docker-compose.yml`, pointing the
scrape target at `payment-gateway:5000/metrics`. Then run the full stack together and
confirm Prometheus is actively scraping — this is exactly what **Integration Gate #1
(Sept 25)** requires.

## Checklist – Week 1 (P3)
- [x] Build the mock payment API
- [x] Set up Dockerfile + docker-compose for the application
- [x] Align compose command and network naming with the team's root README
- [ ] Test the endpoints locally (`curl` or Postman)
- [ ] Coordinate with P4 to merge Prometheus into the same compose stack
- [ ] Confirm `/metrics` is reachable before Sept 25 (Integration Gate #1)
