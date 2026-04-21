import os
from datetime import datetime, timezone

import requests
from flask import Flask, jsonify, request


app = Flask(__name__)
SLACK_WEBHOOK_URL = os.getenv("SLACK_WEBHOOK_URL", "").strip()
DISCORD_WEBHOOK_URL = os.getenv("DISCORD_WEBHOOK_URL", "").strip()
TIMEOUT_SECONDS = 10


def configured(url):
    return bool(url) and "YOUR/WEBHOOK/URL" not in url and "PLACEHOLDER" not in url


def format_text(payload):
    lines = []
    status = payload.get("status", "unknown").upper()
    alerts = payload.get("alerts", [])

    lines.append(f"[{status}] {len(alerts)} alerta(s)")

    for alert in alerts:
        labels = alert.get("labels", {})
        annotations = alert.get("annotations", {})
        starts_at = alert.get("startsAt", "")
        alertname = labels.get("alertname", "UnknownAlert")
        severity = labels.get("severity", "unknown").upper()
        instance = labels.get("instance", "-")
        summary = annotations.get("summary", "")
        description = annotations.get("description", "")
        dashboard = annotations.get("dashboard_url", "")
        runbook = annotations.get("runbook_url", "")

        lines.append("")
        lines.append(f"{severity} {alertname}")
        lines.append(f"Instancia: {instance}")
        if summary:
            lines.append(f"Resumo: {summary}")
        if description:
            lines.append(f"Descricao: {description}")
        if starts_at:
            lines.append(f"Inicio: {starts_at}")
        if dashboard:
            lines.append(f"Dashboard: {dashboard}")
        if runbook:
            lines.append(f"Runbook: {runbook}")

    lines.append("")
    lines.append(f"Emitido em: {datetime.now(timezone.utc).isoformat()}")
    return "\n".join(lines)


def post_slack(text):
    if not configured(SLACK_WEBHOOK_URL):
        return "slack_skipped"

    response = requests.post(
        SLACK_WEBHOOK_URL,
        json={"text": text},
        timeout=TIMEOUT_SECONDS,
    )
    response.raise_for_status()
    return "slack_sent"


def post_discord(text):
    if not configured(DISCORD_WEBHOOK_URL):
        return "discord_skipped"

    response = requests.post(
        DISCORD_WEBHOOK_URL,
        json={"content": text[:1900]},
        timeout=TIMEOUT_SECONDS,
    )
    response.raise_for_status()
    return "discord_sent"


@app.get("/health")
def health():
    return jsonify({"status": "ok"})


@app.post("/alert")
def alert():
    payload = request.get_json(force=True, silent=False)
    text = format_text(payload)

    results = []
    errors = []

    for sender in (post_slack, post_discord):
        try:
            results.append(sender(text))
        except requests.RequestException as exc:
            errors.append(str(exc))

    status_code = 200 if not errors else 502
    return jsonify({"results": results, "errors": errors}), status_code


if __name__ == "__main__":
    port = int(os.getenv("NOTIFIER_PORT", "5001"))
    app.run(host="0.0.0.0", port=port)
