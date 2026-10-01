#!/usr/bin/env bash
# verify-deployment.sh - P3 (Week 2): Post-deployment verification for payment-gateway
# Run this on the Azure VM after `docker compose up -d --build`
# Confirms the service is healthy and ready for Prometheus scraping + live Grafana
# connection, and is safe to use as part of Integration Gate #2 (Rebuild from Scratch).
#
# Usage: ./scripts/verify-deployment.sh
# Optional: SERVICE_URL=http://<vm-ip>:5000 ./scripts/verify-deployment.sh

set -euo pipefail

SERVICE_URL="${SERVICE_URL:-http://localhost:5000}"
MAX_RETRIES=10
RETRY_DELAY=3

log() { echo "[$(date '+%F %T')] $*"; }

log "Verifying payment-gateway deployment at ${SERVICE_URL}"

# 1) Wait for the health endpoint to respond (container may still be starting)
for i in $(seq 1 "$MAX_RETRIES"); do
  if curl -fsS "${SERVICE_URL}/health" >/dev/null 2>&1; then
    log "Health check passed"
    break
  fi
  if [[ "$i" -eq "$MAX_RETRIES" ]]; then
    log "ERROR: Health check failed after ${MAX_RETRIES} attempts"
    exit 1
  fi
  log "Waiting for service... (attempt $i/$MAX_RETRIES)"
  sleep "$RETRY_DELAY"
done

# 2) Confirm /metrics is exposing Prometheus-formatted data
if curl -fsS "${SERVICE_URL}/metrics" | grep -q "payment_requests_total"; then
  log "Metrics endpoint verified (payment_requests_total found)"
else
  log "ERROR: /metrics endpoint missing expected metric names"
  exit 1
fi

# 3) Fire one sample transaction so there is immediate data for
#    Prometheus/Grafana to display during the integration test
curl -fsS -X POST "${SERVICE_URL}/api/pay" \
  -H "Content-Type: application/json" \
  -d '{"amount": 42.00, "currency": "USD"}' >/dev/null

log "Sample transaction sent successfully"
log "payment-gateway is ready: Prometheus can scrape it and Grafana can connect."
