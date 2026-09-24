#!/usr/bin/env bash
# Check the local or VM Sentinel-Ops stack.

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

failures=0

check_url() {
  local name="$1"
  local url="$2"

  if curl -fsS --max-time 5 "$url" >/dev/null; then
    printf 'OK   %-20s %s\n' "$name" "$url"
  else
    printf 'FAIL %-20s %s\n' "$name" "$url"
    failures=$((failures + 1))
  fi
}

if ! command -v docker >/dev/null 2>&1; then
  echo "FAIL Docker is not installed"
  exit 1
fi

if ! docker compose ps >/dev/null 2>&1; then
  echo "FAIL Docker Compose is unavailable or the stack is not initialized"
  exit 1
fi

check_url "payment health" "http://localhost:5000/health"
check_url "payment metrics" "http://localhost:5000/metrics"
check_url "prometheus ready" "http://localhost:9090/-/ready"

running_services="$(docker compose ps --services --filter status=running)"
if grep -qx 'payment-gateway' <<<"$running_services" && grep -qx 'prometheus' <<<"$running_services"; then
  echo "OK   containers            required services are running"
else
  echo "FAIL containers            payment-gateway and prometheus must be running"
  failures=$((failures + 1))
fi

if [[ "$failures" -gt 0 ]]; then
  echo "Health check failed: $failures check(s) failed."
  exit 1
fi

echo "Health check passed."
