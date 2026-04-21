import os
import time
from functools import wraps

from flask import Flask, Response, jsonify, request
from prometheus_client import CONTENT_TYPE_LATEST, Counter, Gauge, Histogram, generate_latest


app = Flask(__name__)
SERVICE_NAME = os.getenv("SERVICE_NAME", "app")

REQUEST_COUNT = Counter(
    "http_requests_total",
    "Total HTTP requests processed.",
    ["method", "path", "status", "service"],
)
REQUEST_LATENCY = Histogram(
    "http_request_duration_seconds",
    "HTTP request latency in seconds.",
    ["method", "path", "service"],
    buckets=(0.05, 0.1, 0.25, 0.5, 1.0, 2.0, 5.0, 10.0),
)
IN_FLIGHT = Gauge(
    "http_requests_in_flight",
    "HTTP requests currently in flight.",
    ["service"],
)


def instrument(path_template):
    def decorator(fn):
        @wraps(fn)
        def wrapped(*args, **kwargs):
            start = time.perf_counter()
            IN_FLIGHT.labels(service=SERVICE_NAME).inc()
            status_code = 500

            try:
                response = fn(*args, **kwargs)
                if isinstance(response, tuple):
                    status_code = response[1]
                elif hasattr(response, "status_code"):
                    status_code = response.status_code
                return response
            finally:
                elapsed = time.perf_counter() - start
                REQUEST_LATENCY.labels(
                    method=request.method,
                    path=path_template,
                    service=SERVICE_NAME,
                ).observe(elapsed)
                REQUEST_COUNT.labels(
                    method=request.method,
                    path=path_template,
                    status=str(status_code),
                    service=SERVICE_NAME,
                ).inc()
                IN_FLIGHT.labels(service=SERVICE_NAME).dec()

        return wrapped

    return decorator


@app.get("/")
@instrument("/")
def index():
    return jsonify({"service": SERVICE_NAME, "status": "ok"})


@app.get("/health")
@instrument("/health")
def health():
    return jsonify({"status": "healthy"})


@app.get("/status/<int:status_code>")
@instrument("/status/<status_code>")
def custom_status(status_code):
    body = {"status": status_code}
    return jsonify(body), status_code


@app.get("/delay/<float:seconds>")
@app.get("/delay/<int:seconds>")
@instrument("/delay/<seconds>")
def delay(seconds):
    time.sleep(float(seconds))
    return jsonify({"delayed_seconds": float(seconds)})


@app.get("/metrics")
def metrics():
    return Response(generate_latest(), mimetype=CONTENT_TYPE_LATEST)


if __name__ == "__main__":
    app.run(host="0.0.0.0", port=8080, threaded=True)
