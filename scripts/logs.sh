#!/usr/bin/env bash
# Show recent logs for the Sentinel-Ops services.
# Usage: ./scripts/logs.sh [all|payment-gateway|prometheus|grafana] [lines] [--errors] [--follow]

set -uo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR" || { echo "FAIL cannot cd to $ROOT_DIR"; exit 1; }

ALL_SERVICES=(payment-gateway prometheus grafana)

service="all"
lines="100"
errors_only=false
follow=""

for arg in "$@"; do
  case "$arg" in
    --errors)
      errors_only=true
      ;;
    --follow|-f)
      follow="--follow"
      ;;
    all|payment-gateway|prometheus|grafana)
      service="$arg"
      ;;
    *[!0-9]*|'')
      echo "Usage: $0 [all|payment-gateway|prometheus|grafana] [lines] [--errors] [--follow]"
      exit 2
      ;;
    *)
      lines="$arg"
      ;;
  esac
done

if [[ "$service" == "all" ]]; then
  targets=("${ALL_SERVICES[@]}")
else
  targets=("$service")
fi

if $errors_only; then
  echo "=== Errors and warnings (last $lines lines per service) ==="
  found=false
  for svc in "${targets[@]}"; do
    output="$(docker compose logs --no-color --tail="$lines" "$svc" 2>/dev/null \
              | grep -E 'level=(error|warn)|\[(ERROR|WARNING|CRITICAL)\]|(ERROR|CRITICAL|Traceback|panic|fatal)[: ]|error="[^"]|" (4[0-9]{2}|5[0-9]{2}) ')"
    if [[ -n "$output" ]]; then
      found=true
      echo ""
      echo "--- $svc ---"
      echo "$output"
    fi
  done
  $found || echo "No errors or warnings found."
else
  docker compose logs --no-color $follow --tail="$lines" "${targets[@]}"
fi
