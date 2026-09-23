import os
import random
import time
import uuid
from flask import Flask, request, jsonify
from prometheus_client import Counter, Histogram, generate_latest, CONTENT_TYPE_LATEST

app = Flask(__name__)

# --- Prometheus Metrics (P4 will scrape these via /metrics) ---
PAYMENT_REQUESTS_TOTAL = Counter(
    "payment_requests_total", "Total number of payment requests", ["status"]
)
PAYMENT_LATENCY = Histogram(
    "payment_request_duration_seconds", "Payment request latency in seconds"
)
ORDERS_SUCCESSFUL_TOTAL = Counter(
    "orders_successful_total", "Total number of successful orders"
)
TRANSACTION_FAILURES_TOTAL = Counter(
    "transaction_failures_total", "Total number of failed transactions", ["reason"]
)

# Simulated failure rate (~10%) and latency to mimic a real payment gateway
FAILURE_RATE = float(os.getenv("FAILURE_RATE", "0.1"))
MIN_LATENCY_MS = int(os.getenv("MIN_LATENCY_MS", "50"))
MAX_LATENCY_MS = int(os.getenv("MAX_LATENCY_MS", "400"))

FAILURE_REASONS = ["insufficient_funds", "card_declined", "timeout", "fraud_check_failed"]


@app.route("/health", methods=["GET"])
def health():
    """Simple liveness check used by Docker/health checks."""
    return jsonify({"status": "ok"}), 200


@app.route("/api/pay", methods=["POST"])
def pay():
    """Mock payment endpoint. Accepts optional JSON body: {amount, currency}."""
    start = time.time()
    payload = request.get_json(silent=True) or {}
    amount = payload.get("amount", round(random.uniform(5, 500), 2))
    currency = payload.get("currency", "USD")

    # Simulate realistic processing latency
    latency_s = random.uniform(MIN_LATENCY_MS, MAX_LATENCY_MS) / 1000
    time.sleep(latency_s)

    transaction_id = str(uuid.uuid4())
    success = random.random() > FAILURE_RATE
    duration = time.time() - start
    PAYMENT_LATENCY.observe(duration)

    if success:
        PAYMENT_REQUESTS_TOTAL.labels(status="success").inc()
        ORDERS_SUCCESSFUL_TOTAL.inc()
        return jsonify({
            "transaction_id": transaction_id,
            "status": "success",
            "amount": amount,
            "currency": currency,
            "processed_in_ms": round(duration * 1000, 2),
        }), 200

    reason = random.choice(FAILURE_REASONS)
    PAYMENT_REQUESTS_TOTAL.labels(status="failed").inc()
    TRANSACTION_FAILURES_TOTAL.labels(reason=reason).inc()
    return jsonify({
        "transaction_id": transaction_id,
        "status": "failed",
        "reason": reason,
        "amount": amount,
        "currency": currency,
        "processed_in_ms": round(duration * 1000, 2),
    }), 402


@app.route("/metrics", methods=["GET"])
def metrics():
    """Prometheus scrape endpoint."""
    return generate_latest(), 200, {"Content-Type": CONTENT_TYPE_LATEST}


if __name__ == "__main__":
    app.run(host="0.0.0.0", port=5000)
