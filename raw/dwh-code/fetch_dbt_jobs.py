"""
Fetches dbt jobs from API and writes to CSV.
"""
import os
import json
import sys
import csv
import urllib.request
import ssl

FIELDS = ["id", "name", "account_id", "project_id", "environment_id",
          "created_at", "updated_at", "layer", "source", "modulo", "subject_area", "model",
          "execute_steps", "settings"]

def fetch_jobs():
    token = os.environ.get("DBT_API_KEY")
    account_id = os.environ.get("DBT_ACCOUNT_ID")
    project_id = os.environ.get("DBT_PROJECT_ID")
    base_url = os.environ.get("DBT_BASE_URL")

    if not all([token, account_id, project_id, base_url]):
        sys.exit("[ERROR] Variabili d'ambiente DBT mancanti")

    jobs = []
    offset = 0
    page_size = 100

    ctx = ssl.create_default_context()
    ctx.check_hostname = False
    ctx.verify_mode = ssl.CERT_NONE

    while True:
        params = f"project_id={project_id}&limit={page_size}&offset={offset}"
        url = f"{base_url}/api/v2/accounts/{account_id}/jobs/?{params}"

        req = urllib.request.Request(url)
        req.add_header("Authorization", f"Token {token}")
        req.add_header("Content-Type", "application/json")

        try:
            response = urllib.request.urlopen(req, context=ctx)
            payload = json.load(response)
            batch = payload.get("data", [])
            jobs.extend(batch)

            total = payload.get("extra", {}).get("pagination", {}).get("total_count", len(jobs))
            offset += page_size

            if offset >= total or not batch:
                break
        except Exception as e:
            sys.exit(f"[ERROR] Errore nella richiesta API: {e}")

    return jobs

def write_csv(jobs):
    """Scrive i job in CSV."""
    if not jobs:
        print("[WARN] Nessun job da scrivere")
        return

    with open("dbt_jobs.csv", "w", newline="", encoding="utf-8") as f:
        writer = csv.DictWriter(f, fieldnames=FIELDS)
        writer.writeheader()

        for job in jobs:
            metadata = {}
            if job.get("description"):
                try:
                    metadata = json.loads(job.get("description", "{}"))
                except (json.JSONDecodeError, TypeError):
                    pass

            row = {}
            for field in FIELDS:
                if field in ["layer", "source", "modulo", "subject_area", "model"]:
                    row[field] = metadata.get(field, "")
                else:
                    value = job.get(field)
                    if isinstance(value, (dict, list)):
                        row[field] = json.dumps(value)
                    else:
                        row[field] = value if value is not None else ""
            writer.writerow(row)

    print(f"✓ {len(jobs)} jobs scritti in dbt_jobs.csv")

if __name__ == "__main__":
    jobs = fetch_jobs()
    print(f"[INFO] {len(jobs)} jobs recuperati dall'API")
    write_csv(jobs)
