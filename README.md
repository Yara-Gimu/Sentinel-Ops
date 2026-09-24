# Sentinel-Ops 🛡️
**Internal Monitoring & Observability Platform**

## Overview
Sentinel-Ops is an enterprise-grade infrastructure monitoring and observability platform engineered to provide real-time visibility into system health. Designed for cloud-native environments, this project automates the provisioning of cloud infrastructure and orchestrates a robust telemetry pipeline, ensuring high availability, proactive alerting, and zero-blind-spot monitoring.

## Tech Stack
* **Cloud Environment:** Microsoft Azure (Virtual Machines, VNet, NSG)
* **Infrastructure as Code (IaC):** Terraform
* **Containerization:** Docker & Docker Compose
* **Metrics & Time-Series Data:** Prometheus
* **Data Visualization & Alerting:** Grafana
* **Automation:** Bash Scripting

## Architecture & Workflow
The platform is built with a secure, highly scalable architecture tailored for modern DevOps workflows:
1. **Automated Provisioning:** Terraform securely provisions the Azure network and compute resources from scratch, applying strict network security rules.
2. **Containerized Deployment:** Docker Compose orchestrates the Prometheus and Grafana instances, ensuring isolated and reproducible environments.
3. **Telemetry Collection:** Prometheus acts as the central metrics engine, scraping live infrastructure performance data and simulated stress-test metrics.
4. **Actionable Insights:** Grafana translates raw time-series data into dynamic, operational dashboards equipped with threshold-based alerts for rapid incident response.

## Quick Start (Local Integration Gate)
Run the complete monitoring stack locally before using Azure:

```powershell
docker compose up -d --build
docker compose ps
```

- Payment gateway: `http://localhost:5000/health`
- Prometheus targets: `http://localhost:9090/targets`

The target should be `payment-gateway:5000` and report `UP`.

## Azure Deployment
The active Azure subscription may reject VM SKUs with `NotAvailableForSubscription`.
Confirm an available VM size in the Azure Portal before applying.

```powershell
cd terraform
terraform init
terraform plan -var='admin_password=REPLACE_WITH_A_SECRET' -var='ssh_source_address_prefix=YOUR_PUBLIC_IP/32'
terraform apply -var='admin_password=REPLACE_WITH_A_SECRET' -var='ssh_source_address_prefix=YOUR_PUBLIC_IP/32'
```

Override `location`, `vm_size`, and `ssh_source_address_prefix` only with values confirmed for the subscription. Do not commit passwords or `terraform.tfvars`.

After connecting to Ubuntu:

```bash
sudo ./scripts/install.sh
docker compose up -d --build
./scripts/healthcheck.sh
```

## Infrastructure Provisioning (P1)

### Overview

Sentinel-Ops infrastructure is provisioned on Microsoft Azure with **Terraform**. The configuration includes a resource group, virtual network, subnet, network security group, public IP, network interface, and Linux virtual machine.

### Azure VM Configuration

The Azure for Students subscription reported capacity restrictions for several B-Series VM sizes. The tested configuration that passed SKU availability checks uses:

- **Location:** `centralus`
- **VM size:** `Standard_D2s_v7`
- **Image:** Canonical Ubuntu Server 22.04 Gen2
- **Image SKU:** `22_04-lts-gen2`

The Gen2 image is required because `Standard_D2s_v7` does not boot Gen1 images.

### Network Access

The NSG defines these inbound rules:

- `22` (SSH), restricted to `ssh_source_address_prefix`
- `5000` (Payment Gateway), available for the demonstration service
- `9090` (Prometheus), available for monitoring access

Confirm the public IP with `terraform output public_ip_address` after a successful apply. Do not commit passwords, `terraform.tfvars`, or public IP values as secrets.

### Apply the Infrastructure

```bash
cd terraform
terraform init
terraform apply \
	-var="admin_password=YOUR_SECURE_PASS" \
	-var="ssh_source_address_prefix=YOUR_IP/32"
```

After deployment, run `sudo ./scripts/install.sh` on the VM and start the Docker Compose stack from the project directory.
