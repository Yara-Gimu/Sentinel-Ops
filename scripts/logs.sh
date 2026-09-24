#!/usr/bin/env bash
# Show recent logs for the Sentinel-Ops services.

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

service="${1:-all}"
lines="${2:-100}"

case "$service" in
  all)
    docker compose logs --no-color --tail="$lines" payment-gateway prometheus
    ;;
  payment-gateway|prometheus)
    docker compose logs --no-color --tail="$lines" "$service"
    ;;
  *)
    echo "Usage: $0 [all|payment-gateway|prometheus] [lines]"
    exit 2
    ;;
esac
