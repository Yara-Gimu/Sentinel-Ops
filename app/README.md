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

The service will run at: `http://localhost:5000`

## Endpoints

| Endpoint      | Method | Description                                  |
|---------------|--------|-----------------------------------------------|
| `/health`     | GET    | Liveness check — confirms the service is up   |
| `/api/pay`    | POST   | Simulates a payment (random success/failure)  |
| `/metrics`    | GET    | Prometheus metrics (used by P4)               |

### Test example
```bash
curl http://localhost:5000/health

curl -X POST http://localhost:5000/api/pay \
  -H "Content-Type: application/json" \
  -d '{"amount": 120.50, "currency": "USD"}'

curl http://localhost:5000/metrics
```

## Metrics available for P4 (Prometheus scrape target: `payment-gateway:5000`)
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
- **NSG / firewall rules:** confirmed with `terraform/main.tf` and the team's decision
  — port `5000` stays **internal-only**. It is reachable only by Prometheus on the
  same VM/Docker network; it is intentionally **not** exposed externally, so no NSG
  rule is needed. ✅ Resolved.

## Next Step (coordination with P4)
Ask P4 to add the Prometheus service to this same `docker-compose.yml`, pointing the
scrape target at `payment-gateway:5000/metrics`. Then run the full stack together and
confirm Prometheus is actively scraping — this is exactly what **Integration Gate #1
(Sept 25)** requires.

## Checklist – Week 1 (P3)
- [x] Build the mock payment API
- [x] Set up Dockerfile + docker-compose for the application
- [x] Align compose command and network naming with the team's root README
- [x] Test the endpoints locally (`curl` or Postman)
- [x] Coordinate with P4 to merge Prometheus into the same compose stack
- [x] Confirm `/metrics` is reachable before Sept 25 (Integration Gate #1)

---

## Week 2 – Cloud Integration (Sept 27 – Oct 3)

Per the plan, P3 is grouped with P4 under **Observability Team** for this week, with
the stated task: *"Connect live Grafana to the hosted Prometheus data source
endpoint."* That specific wiring is P4's work. P3's concrete contribution is making
sure the payment-gateway container is **cloud-ready** before that connection happens,
and that it survives **Integration Gate #2 (Oct 2 – "Rebuild from Scratch" Test)**.

### P3 tasks this week
1. Confirm the `payment-gateway` service comes up cleanly on the Azure VM (not just
   locally) once P1 has provisioned infrastructure and P2 has migrated the Docker
   setup — no hardcoded `localhost`-only assumptions in the app.
2. Confirm `/metrics` is reachable from Prometheus running on the same VM/network, so
   P4 can point Grafana at it.
3. Make sure `docker compose up -d --build` can be re-run automatically after a full
   `terraform destroy` + `terraform apply` cycle with **zero manual steps** — this is
   exactly what Integration Gate #2 tests.

### Post-deployment verification
The service is **internal-only** (port `5000` is not exposed to the public internet
by design — only Prometheus on the same VM reaches it). Run the check **from inside
the Azure VM itself** (SSH in first), using `localhost`:
```bash
ssh <user>@<vm-ip>
cd Sentinel-Ops
./scripts/verify-deployment.sh
```
This checks that `/health` responds, `/metrics` exposes the expected Prometheus
metric names, and sends one sample transaction so Prometheus/Grafana have live data
to show immediately during the integration test. `SERVICE_URL` defaults to
`http://localhost:5000`, which is correct here — do **not** point it at the VM's
public IP, since the port is intentionally not reachable from outside.

### Checklist – Week 2 (P3)
- [ ] Re-run `docker compose up -d --build` on the Azure VM once P1/P2 finish provisioning
- [ ] SSH into the VM and run `scripts/verify-deployment.sh` against `localhost`
- [ ] Confirm with P4 that Prometheus (on the VM) can scrape `payment-gateway:5000/metrics`
- [ ] Participate in Integration Gate #2 (Oct 2): verify the service comes back up
      automatically after `terraform destroy` + `terraform apply`
- [x] Port 5000 confirmed internal-only — no NSG rule needed

---

## Week 3 – Load Simulation & Final Demo (Oct 4 – Oct 10)

P3's role this week: **Testing Lead**. Task per the plan:

> *"Develop the Live Load Simulation script (Python/Bash) to flood the showcase
> payment gateway with mock transaction traffic."*

This load feeds P4's Grafana dashboards (Infrastructure Vitals + Application/Business
Metrics) and triggers P4's Alertmanager thresholds, so it directly powers
**Integration Gate #3 (Oct 8 – Final Demo Rehearsal)**.

### Scripts provided
| Script | Language | When to use |
|---|---|---|
| `scripts/load_simulator.py` | Python | Primary — concurrent workers, live stats, latency tracking |
| `scripts/load_simulator.sh` | Bash | Fallback if Python/requests isn't available on the VM |

Both send repeated mock transactions to `/api/pay`, so both success and failure paths
fire (the app has a built-in ~10% simulated failure rate), which is what makes the
"Transaction Failure Rates" panel and Alertmanager thresholds meaningful.

### Running it (on the Azure VM, since the API is internal-only)
```bash
ssh <user>@<vm-ip>
cd Sentinel-Ops

# Python version (install requests once):
pip install -r scripts/requirements-loadtest.txt --break-system-packages
python3 scripts/load_simulator.py --url http://localhost:5000 --rate 10 --duration 120 --workers 20

# Or the Bash fallback:
chmod +x scripts/load_simulator.sh
./scripts/load_simulator.sh http://localhost:5000 120 10
```
- `--rate` / 3rd bash arg: target requests per second (raise this for a more dramatic
  demo spike).
- `--duration` / 2nd bash arg: how long to run, in seconds.
- Both print live stats every couple seconds and a final summary (total, success,
  failed, latency).

### Checklist – Week 3 (P3)
- [x] Build the load simulation script (Python primary, Bash fallback)
- [ ] Run it on the VM and confirm Grafana panels move in real time (coordinate with P4)
- [ ] Confirm Alertmanager fires when thresholds are crossed (raise `--rate` if needed
      to push CPU or failure-rate metrics past P4's configured limits)
- [ ] Rehearse the exact command + parameters to use live during Integration Gate #3
      (Oct 8) so the demo runs smoothly