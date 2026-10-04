# Sentinel-Ops: Infrastructure Runbook & Troubleshooting Guide

## 1. Environment Teardown & Rebuild (Integration Gate #2)
This procedure completely destroys and rebuilds the Azure infrastructure from scratch.

### 🔴 Automated Teardown (Destruction)
Execute this when a fresh state is required or to stop billing charges:
```bash
cd terraform
terraform destroy -var="admin_password=YOUR_SECURE_PASS" -var="ssh_source_address_prefix=YOUR_IP/32" -auto-approve
```

*Note: This will delete the VM, NSG, VNet, and all associated resources permanently.*

### 🟢 Automated Rebuild (Provisioning)
Execute this to bring the environment back online:

Bash

```
cd terraform
terraform init
terraform apply -var="admin_password=YOUR_SECURE_PASS" -var="ssh_source_address_prefix=YOUR_IP/32" -auto-approve
```

## 2. Infrastructure Health Checks
If the monitoring stack fails to respond or the dashboard goes down, run these checks sequentially on the Azure VM.

### Check 1: System Resources (Memory & CPU)
Verify if the VM is experiencing a resource bottleneck.

Bash

```
# Check memory availability
free -m

# Check disk space (Ensure /dev/sda1 is not 100% full)
df -h

# Monitor CPU usage
top -bn1 | grep "Cpu(s)"
```

**Action:** If memory is depleted or disk is full, you may need to resize the Azure VM (`Standard_D2s_v7`) via Terraform or clear Docker logs.

### Check 2: Docker Stack Status
Ensure all containers are running and healthy.

Bash

```
# List container states
docker compose ps

# Restart the entire stack if containers are stuck or exited
docker compose restart
```

### Check 3: Network & Port Connectivity
Verify internal service connectivity.

Bash

```
# Test internal connection to Payment Gateway
curl -I http://localhost:5000/health

# Test internal connection to Prometheus
curl -I http://localhost:9090/-/healthy
```

**Action:** If connections fail, inspect the Docker logs (`docker compose logs payment-gateway`).

## 3. Security Lockdown Procedures (Production Ready)
Before final sign-off, ensure the following security measures are enforced via Terraform.

1. **SSH Access Validation:** Ensure the `ssh_source_address_prefix` in `terraform.tfvars` is explicitly set to the Administrator's IP address (e.g., `64.137.196.213/32`) and never `*`.
2. **Internal App Isolation:** Ensure no NSG rules expose Port 5000 to the internet. The Payment Gateway must only be accessible locally by Prometheus.
3. **Grafana Exposure:** Expose Port 3000 in the NSG only to trusted administrative IPs for dashboard viewing.
