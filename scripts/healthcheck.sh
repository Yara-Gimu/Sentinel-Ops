#!/usr/bin/env bash
# Check the local or VM Sentinel-Ops stack.

set -uo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR" || { echo "FAIL cannot cd to $ROOT_DIR"; exit 1; }

failures=0

check_url() {
  local name="$1"
  local url="$2"

  if curl -fsS --max-time 5 "$url" >/dev/null 2>&1; then
    printf 'OK   %-20s %s\n' "$name" "$url"
  else
    printf 'FAIL %-20s %s\n' "$name" "$url"
    failures=$((failures + 1))
  fi
}

check_url_contains() {
  local name="$1"
  local url="$2"
  local expected="$3"
  local body

  body="$(curl -fsS --max-time 5 "$url" 2>/dev/null)"
  if [[ -z "$body" ]]; then
    printf 'FAIL %-20s %s (no response)\n' "$name" "$url"
    failures=$((failures + 1))
  elif grep -q "$expected" <<<"$body"; then
    printf 'OK   %-20s %s\n' "$name" "$url"
  else
    printf 'FAIL %-20s %s (unexpected body: %s)\n' "$name" "$url" "${body:0:60}"
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

check_url_contains "payment health" "http://localhost:5000/health" '"ok"'
check_url "payment metrics" "http://localhost:5000/metrics"
check_url "prometheus ready" "http://localhost:9090/-/ready"
check_url "grafana health"    "http://localhost:3000/api/health"

running_services="$(docker compose ps --services --filter status=running)"
for svc in payment-gateway prometheus grafana; do
  if grep -qx "$svc" <<<"$running_services"; then
    printf 'OK   %-20s container is running\n' "$svc"
  else
    printf 'FAIL %-20s container is NOT running\n' "$svc"
    failures=$((failures + 1))
  fi
done

targets_json="$(curl -fsS --max-time 5 http://localhost:9090/api/v1/targets 2>/dev/null)"
if [[ -z "$targets_json" ]]; then
  printf 'FAIL %-20s could not read scrape targets\n' "prometheus targets"
  failures=$((failures + 1))
elif ! command -v jq >/dev/null 2>&1; then
  printf 'SKIP %-20s jq not installed\n' "prometheus targets"
else
  total="$(jq '.data.activeTargets | length' <<<"$targets_json")"
  up="$(jq '[.data.activeTargets[] | select(.health=="up")] | length' <<<"$targets_json")"
  if [[ "$total" -eq 0 ]]; then
    printf 'FAIL %-20s no scrape targets configured\n' "prometheus targets"
    failures=$((failures + 1))
  elif [[ "$up" -eq "$total" ]]; then
    printf 'OK   %-20s %s/%s targets up\n' "prometheus targets" "$up" "$total"
  else
    printf 'FAIL %-20s only %s/%s targets up\n' "prometheus targets" "$up" "$total"
    jq -r '.data.activeTargets[] | select(.health!="up") | "       - \(.labels.job) (\(.scrapeUrl))"' <<<"$targets_json"
    failures=$((failures + 1))
  fi
fi

if [[ "$failures" -gt 0 ]]; then
  echo "Health check failed: $failures check(s) failed."
  exit 1
fi

echo "Health check passed."
