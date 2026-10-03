# Sentinel-Ops 🛡️
**Internal Monitoring & Observability Platform**

## Overview
Sentinel-Ops is an enterprise-grade infrastructure monitoring and observability platform engineered to provide real-time visibility into system health. Designed for cloud-native environments, this project automates the provisioning of cloud infrastructure and orchestrates a robust telemetry pipeline, ensuring high availability, proactive alerting, and zero-blind-spot monitoring. 

The E-Commerce/payment environment within this project is utilized strictly as a demonstration showcase and load-testing use case.

## Tech Stack
* **Cloud Environment:** Microsoft Azure (Virtual Machines, VNet, NSG)
* **Infrastructure as Code (IaC):** Terraform
* **Containerization:** Docker & Docker Compose V2
* **Metrics & Time-Series Data:** Prometheus
* **Data Visualization & Alerting:** Grafana
* **Automation & Scripting:** Bash

## Team Roles & Workflow
The platform is built with a secure, highly scalable architecture tailored for modern DevOps workflows, divided into distinct team responsibilities:
1. **Infrastructure (P1):** Terraform securely provisions the Azure network and compute resources from scratch, applying strict network security rules.
2. **Automation (P2):** Bash scripts automate OS-level configuration, security hardening, and Docker installations.
3. **App & Testing (P3):** A containerized mock payment gateway acts as the showcase target for load-testing and Prometheus scraping.
4. **Observability (P4):** Prometheus and Grafana translate raw time-series data into dynamic dashboards with threshold-based alerts.

---

## Quick Start (Local Integration Gate)
Run the complete monitoring stack locally before deploying to Azure:

```bash
docker compose up -d --build
docker compose ps
```

**Local Endpoints:**
- Payment gateway health: `http://localhost:5000/health`
- Prometheus targets: `http://localhost:9090/targets` *(Target should be `payment-gateway:5000` and report `UP`)*
- Grafana Dashboard: `http://localhost:3000`

---

## Module 1: Infrastructure Provisioning (P1)
Sentinel-Ops infrastructure is provisioned on Microsoft Azure with **Terraform**. The configuration includes a resource group, VNet, subnet, NSG, public IP, network interface, and a Linux VM.

### Azure VM Configuration
* **Location:** `centralus`
* **VM size:** `Standard_D2s_v7` (Selected to bypass capacity restrictions)
* **Image:** Canonical Ubuntu Server 22.04 Gen2 (`22_04-lts-gen2`)

### Network Access (NSG Rules)
* `Port 22` (SSH): Restricted to `ssh_source_address_prefix`
* `Port 5000` (Payment Gateway): Internal only (no public exposure by design)
* `Port 9090` (Prometheus): Available for monitoring access

### Deployment Execution
```bash
cd terraform
terraform init
terraform apply \
  -var="admin_password=YOUR_SECURE_PASS" \
  -var="ssh_source_address_prefix=YOUR_PUBLIC_IP/32"
```
*Note: Confirm the public IP with `terraform output public_ip_address`. Do not commit passwords or `terraform.tfvars`.*

---

## Module 2: Automation & Configuration (P2)
This module automates the configuration and hardening of the underlying operating system, ensuring the Azure VM is ready to host containerized applications immediately after Terraform provisioning.

### OS-Level Scripts
* **`scripts/install.sh`**: Automates the installation of Docker, Docker Compose V2, and essential system dependencies.
* **`scripts/healthcheck.sh`**: Diagnostic script to verify the live states of critical services (Docker daemon, memory, network).
* **`scripts/verify-deployment.sh`**: Tests core application functionality post-deployment.

### Execution
Scripts must be executed with elevated privileges directly on the Azure VM post-deployment:
```bash
chmod +x scripts/*.sh
sudo ./scripts/install.sh
```

---

## Module 3: Mock Payment Gateway (P3)
This service is the showcase/load-testing application. It is a lightweight target for Prometheus to scrape and for the load simulator to stress-test.

### API Endpoints
| Endpoint | Method | Description |
|---|---|---|
| `/health` | GET | Check that the service is running |
| `/api/pay` | POST | Simulate a payment transaction (random success/failure) |
| `/metrics` | GET | Prometheus metrics endpoint for scraping |

### Test Examples (Localhost only)
```bash
# Check Health
curl http://localhost:5000/health

# Simulate Payment
curl -X POST http://localhost:5000/api/pay \
  -H "Content-Type: application/json" \
  -d '{"amount": 120.50, "currency": "USD"}'
```

### Post-Deployment Verification
Port 5000 is intentionally internal. Run the deployment check from inside the Azure VM itself:
```bash
ssh <user>@<vm-ip>
cd Sentinel-Ops
./scripts/verify-deployment.sh
```

---

## Module 4: Observability & Visualization (P4)
This module acts as the core monitoring engine, leveraging Prometheus for metric collection and Grafana for interactive data visualization.

### Telemetry Pipeline
* **Prometheus (`prometheus.yml`)**: Configured to scrape the `payment-gateway:5000/metrics` target alongside infrastructure node exporters.
* **Grafana Dashboards**: 
  * *Infrastructure Vitals*: Monitors CPU utilization, memory consumption, disk I/O, and network throughput.
  * *Application Metrics*: Visualizes successful orders, transaction failure rates, and mock API latency.
* **Alerting**: Alertmanager triggers notifications upon detecting CPU bottlenecks or spikes in simulated transaction failures.
