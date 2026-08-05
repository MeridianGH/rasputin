import os
import json
import csv

# Paths
config_path = "/app/data/wg0.json"
csv_path = "/app/csv/clients.csv"

# Ensure output directory exists
os.makedirs(os.path.dirname(csv_path), exist_ok=True)

# Load JSON
with open(config_path, "r") as file:
    data = json.load(file)

# Write CSV
with open(csv_path, "w", newline="") as csvfile:
    writer = csv.writer(csvfile)
    writer.writerow(["ip", "name"])

    clients = data.get("clients", {})
    for client_id, client_info in clients.items():
        ip = client_info.get("address")
        name = client_info.get("name")
        if ip and name:
            writer.writerow([ip, name])

print("Wrote JSON config data to CSV.")
