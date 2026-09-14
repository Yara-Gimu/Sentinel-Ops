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

## Quick Start
To deploy the Sentinel-Ops stack in your Azure environment:

1. Clone the repository to your local machine.
2. Navigate to the `terraform/` directory and execute `terraform init` followed by `terraform apply` to provision the Azure infrastructure.
3. SSH into the deployed Virtual Machine.
4. Execute the automated bash setup scripts to configure the environment and install dependencies.
5. Launch the observability stack using `docker-compose up -d`.
6. Access the Grafana dashboard via the provided public IP and verify the live metrics stream.
