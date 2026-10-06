#!/usr/bin/env bash
# load_simulator.sh - P3 (Week 3): Simple Bash/curl load simulator
# Lightweight fallback if Python/requests isn't available on the VM.
#
# Usage: ./scripts/load_simulator.sh [URL] [DURATION_SECONDS] [REQUESTS_PER_SECOND]
# Example: ./scripts/load_simulator.sh http://localhost:5000 120 5

set -euo pipefail

URL="${1:-http://localhost:5000}"
DURATION="${2:-60}"
RATE="${3:-5}"

SLEEP_INTERVAL=$(awk "BEGIN {print 1/$RATE}")
END=$((SECONDS + DURATION))

total=0
success=0
failed=0

echo "[+] Starting bash load simulation: $URL  duration=${DURATION}s  rate=${RATE} req/s"
echo "[+] Press Ctrl+C to stop early."
echo ""

while [ $SECONDS -lt $END ]; do
  amount=$(awk 'BEGIN{srand(); printf "%.2f", rand()*495+5}')
  status=$(curl -s -o /dev/null -w "%{http_code}" -X POST "$URL/api/pay" \
    -H "Content-Type: application/json" \
    -d "{\"amount\": $amount, \"currency\": \"USD\"}" || echo "000")

  total=$((total + 1))
  if [ "$status" = "200" ]; then
    success=$((success + 1))
  else
    failed=$((failed + 1))
  fi

  if (( total % 20 == 0 )); then
    echo "    total=$total  success=$success  failed=$failed"
  fi

  sleep "$SLEEP_INTERVAL"
done

echo ""
echo "=================================================="
echo "LOAD SIMULATION SUMMARY (bash)"
echo "=================================================="
echo "Total requests: $total"
echo "Successful:     $success"
echo "Failed:         $failed"
echo "=================================================="
