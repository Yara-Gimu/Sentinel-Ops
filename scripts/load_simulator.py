#!/usr/bin/env python3
"""
load_simulator.py - P3 (Week 3): Live Load Simulation Script

Floods the mock payment gateway with concurrent mock transactions to generate
observable load for Grafana dashboards and trigger Alertmanager thresholds
(Integration Gate #3 - Final Demo Rehearsal).

Usage:
    python3 load_simulator.py --url http://localhost:5000 --rate 10 --duration 120 --workers 20

Options:
    --url        Base URL of the payment gateway (default: http://localhost:5000)
    --rate       Target combined requests per second across all workers (default: 5)
    --duration   How long to run, in seconds (default: 60)
    --workers    Number of concurrent worker threads (default: 10)
"""
import argparse
import random
import threading
import time
from dataclasses import dataclass, field

try:
    import requests
except ImportError:
    raise SystemExit(
        "Missing dependency 'requests'. Install with:\n"
        "  pip install requests --break-system-packages"
    )


@dataclass
class Stats:
    lock: threading.Lock = field(default_factory=threading.Lock)
    total: int = 0
    success: int = 0
    failed: int = 0
    errors: int = 0
    latencies: list = field(default_factory=list)

    def record(self, success: bool, latency: float, error: bool = False):
        with self.lock:
            self.total += 1
            if error:
                self.errors += 1
            elif success:
                self.success += 1
            else:
                self.failed += 1
            self.latencies.append(latency)


def run(url: str, rate: float, duration: int, workers_count: int):
    stats = Stats()
    stop_event = threading.Event()

    # Each worker self-throttles so the combined rate across all workers
    # approximates the requested target rate.
    per_worker_delay = workers_count / max(rate, 0.1)

    def throttled_worker():
        session = requests.Session()
        while not stop_event.is_set():
            amount = round(random.uniform(5, 500), 2)
            start = time.time()
            try:
                resp = session.post(
                    f"{url}/api/pay",
                    json={"amount": amount, "currency": "USD"},
                    timeout=5,
                )
                latency = time.time() - start
                stats.record(success=(resp.status_code == 200), latency=latency)
            except requests.RequestException:
                latency = time.time() - start
                stats.record(success=False, latency=latency, error=True)
            time.sleep(max(per_worker_delay - latency, 0))

    threads = [threading.Thread(target=throttled_worker, daemon=True) for _ in range(workers_count)]

    print(f"[+] Starting load simulation: {url}  rate~{rate} req/s  "
          f"workers={workers_count}  duration={duration}s")
    print("[+] Press Ctrl+C to stop early.\n")

    start_time = time.time()
    for t in threads:
        t.start()

    try:
        while time.time() - start_time < duration:
            time.sleep(2)
            elapsed = time.time() - start_time
            print(f"    t+{elapsed:5.1f}s  total={stats.total:5d}  "
                  f"success={stats.success:5d}  failed={stats.failed:5d}  "
                  f"errors={stats.errors:5d}")
    except KeyboardInterrupt:
        print("\n[!] Interrupted by user, stopping...")

    stop_event.set()
    for t in threads:
        t.join(timeout=2)

    print_summary(stats, time.time() - start_time)


def print_summary(stats: Stats, elapsed: float):
    print("\n" + "=" * 50)
    print("LOAD SIMULATION SUMMARY")
    print("=" * 50)
    print(f"Duration:        {elapsed:.1f}s")
    print(f"Total requests:  {stats.total}")
    print(f"Successful:      {stats.success}")
    print(f"Failed (4xx):    {stats.failed}")
    print(f"Connection errs: {stats.errors}")
    if stats.latencies:
        avg = sum(stats.latencies) / len(stats.latencies)
        print(f"Avg latency:     {avg * 1000:.1f} ms")
        print(f"Max latency:     {max(stats.latencies) * 1000:.1f} ms")
    if elapsed > 0 and stats.total:
        print(f"Actual rate:     {stats.total / elapsed:.2f} req/s")
    print("=" * 50)


def main():
    parser = argparse.ArgumentParser(description="Sentinel Ops - Payment Gateway Load Simulator")
    parser.add_argument("--url", default="http://localhost:5000", help="Base URL of the payment gateway")
    parser.add_argument("--rate", type=float, default=5, help="Target requests per second (combined)")
    parser.add_argument("--duration", type=int, default=60, help="Duration in seconds")
    parser.add_argument("--workers", type=int, default=10, help="Number of concurrent worker threads")
    args = parser.parse_args()

    run(args.url, args.rate, args.duration, args.workers)


if __name__ == "__main__":
    main()
