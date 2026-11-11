import os
import threading
import time

from flask import Flask, Response, g, jsonify, request
from prometheus_client import (
    CONTENT_TYPE_LATEST,
    Counter,
    Gauge,
    Histogram,
    generate_latest,
)

MAX_NOTES = 100
MAX_TEXT = 200

REQUESTS = Counter(
    "http_requests_total", "Requests handled", ["method", "route", "status"]
)
LATENCY = Histogram("http_request_duration_seconds", "Request duration", ["route"])
STORED = Gauge("notes_stored", "Notes currently held in memory")


def create_app():
    app = Flask(__name__)
    version = os.environ.get("APP_VERSION", "dev")
    env_name = os.environ.get("APP_ENV", "local")

    notes = []
    lock = threading.Lock()

    @app.before_request
    def start_timer():
        g.started = time.perf_counter()

    @app.after_request
    def record_metrics(resp):
        # the route rule, not the raw path, so random 404 urls do not add series
        route = request.url_rule.rule if request.url_rule else "unmatched"
        REQUESTS.labels(request.method, route, resp.status_code).inc()
        LATENCY.labels(route).observe(time.perf_counter() - g.started)
        return resp

    @app.get("/")
    def index():
        return jsonify(service="notes", version=version, environment=env_name)

    @app.get("/health")
    def health():
        return jsonify(status="ok")

    @app.get("/metrics")
    def metrics():
        return Response(generate_latest(), mimetype=CONTENT_TYPE_LATEST)

    @app.get("/notes")
    def list_notes():
        with lock:
            return jsonify(notes=list(notes))

    @app.post("/notes")
    def add_note():
        body = request.get_json(silent=True) or {}
        text = body.get("text")
        if not isinstance(text, str) or not text.strip():
            return jsonify(error="text is required"), 400
        if len(text) > MAX_TEXT:
            return jsonify(error=f"text is longer than {MAX_TEXT} characters"), 400
        with lock:
            if len(notes) >= MAX_NOTES:
                return jsonify(error="note limit reached"), 409
            note = {"id": len(notes) + 1, "text": text.strip()}
            notes.append(note)
            STORED.set(len(notes))
        return jsonify(note), 201

    @app.get("/notes/<int:note_id>")
    def get_note(note_id):
        with lock:
            for note in notes:
                if note["id"] == note_id:
                    return jsonify(note)
        return jsonify(error="not found"), 404

    return app
