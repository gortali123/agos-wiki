"""
Fetches dbt dependencies from manifest.json and writes to CSV.
"""
import json
import sys
import csv
from datetime import datetime, timezone
from pathlib import Path

def fetch_dependencies(manifest_path="target/manifest.json"):
    if not Path(manifest_path).exists():
        sys.exit(f"[ERROR] Manifest non trovato: {manifest_path}")

    with open(manifest_path, encoding="utf-8") as f:
        manifest = json.load(f)

    dbt_version = manifest.get("metadata", {}).get("dbt_version", "n/a")
    print(f"[INFO] dbt version: {dbt_version}")

    loaded_at = datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")
    rows = []
    node_collections = ["nodes", "sources", "exposures", "metrics", "semantic_models"]

    for collection in node_collections:
        for unique_id, node in manifest.get(collection, {}).items():
            depends_on_nodes = node.get("depends_on", {}).get("nodes", [])
            resource_type = node.get("resource_type", "") or unique_id.split(".", maxsplit=2)[0]
            node_name = node.get("name", "") or unique_id.split(".", maxsplit=2)[2]
            schema = node.get("schema", "")

            if not depends_on_nodes:
                row = {
                    "node_resource_type": resource_type.upper() if resource_type else "",
                    "node_schema": schema.upper() if schema else "",
                    "node_name": node_name.upper() if node_name else "",
                    "depends_on_type": "",
                    "depends_on_name": "",
                    "dependency_order": "",
                    "loaded_at": loaded_at
                }
                rows.append(row)
            else:
                for idx, dep_uid in enumerate(depends_on_nodes, start=1):
                    dep_parts = dep_uid.split(".", maxsplit=2)
                    dep_type = dep_parts[0] if dep_parts else "unknown"
                    dep_name = dep_parts[2] if len(dep_parts) > 2 else dep_uid

                    row = {
                        "node_resource_type": resource_type.upper() if resource_type else "",
                        "node_schema": schema.upper() if schema else "",
                        "node_name": node_name.upper() if node_name else "",
                        "depends_on_type": dep_type.upper() if dep_type else "",
                        "depends_on_name": dep_name.upper() if dep_name else "",
                        "dependency_order": idx,
                        "loaded_at": loaded_at
                    }
                    rows.append(row)

    return rows

def write_csv(rows):
    """Scrive le dipendenze in CSV."""
    if not rows:
        print("[WARN] Nessuna dipendenza da scrivere")
        return

    fieldnames = ["node_resource_type", "node_schema", "node_name", "depends_on_type", "depends_on_name", "dependency_order", "loaded_at"]

    with open("dbt_dependencies.csv", "w", newline="", encoding="utf-8") as f:
        writer = csv.DictWriter(f, fieldnames=fieldnames)
        writer.writeheader()
        writer.writerows(rows)

    print(f"✓ {len(rows)} dipendenze scritte in dbt_dependencies.csv")

if __name__ == "__main__":
    manifest_path = "target/manifest.json"
    if len(sys.argv) > 1:
        manifest_path = sys.argv[1]

    print(f"[INFO] Lettura manifest: {manifest_path}")
    rows = fetch_dependencies(manifest_path)
    print(f"[INFO] {len(rows)} righe estratte")
    write_csv(rows)
