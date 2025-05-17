import requests
import random
from datetime import datetime, timedelta

# --- CONFIGURATION ---
PROJECT_ID = "family-health-tracker-b8c3b"
API_KEY = "AIzaSyCtfJ0Mgxyr1wnmkJSj4sU_qIS8J938zel"
BASE_URL = f"https://firestore.googleapis.com/v1/projects/{PROJECT_ID}/databases/(default)/documents"

# --- USER INPUT ---
user_id = input("Enter user ID (e.g., 1000): ").strip()
start_date = input("Enter start date (YYYY-MM-DD): ").strip()
end_date = input("Enter end date (YYYY-MM-DD): ").strip()

step_min, step_max = map(int, input("Enter step range (min max): ").split())
water_min, water_max = map(float, input("Enter water range (min max): ").split())
sleep_min, sleep_max = map(float, input("Enter sleep range (min max): ").split())
weight_min, weight_max = map(float, input("Enter weight range (min max): ").split())

# --- DATE RANGE GENERATOR ---
def daterange(start, end):
    for n in range(int((end - start).days) + 1):
        yield start + timedelta(n)

start_dt = datetime.strptime(start_date, "%Y-%m-%d")
end_dt = datetime.strptime(end_date, "%Y-%m-%d")

# --- UPLOAD FUNCTION ---
def upload_metric(metric, date_str, value, timestamp):
    # Proper Firestore path for nested subcollection
    url = f"{BASE_URL}/userData/{user_id}/{metric}/{date_str}?key={API_KEY}"
    payload = {
        "fields": {
            "value": {
                "doubleValue": float(value)
            },
            "timestamp": {
                "timestampValue": timestamp.strftime("%Y-%m-%dT%H:%M:%SZ")
            }
        }
    }

    headers = {
        "Content-Type": "application/json"
    }

    response = requests.put(url, headers=headers, json=payload)
    if response.status_code in [200, 201]:
        print(f"[✓] {metric.capitalize()} - {date_str}")
    else:
        print(f"[!] Failed to insert {metric} on {date_str}:\n{response.text}")

# --- LOOP THROUGH DATES AND INSERT DATA ---
for single_date in daterange(start_dt, end_dt):
    date_str = single_date.strftime("%Y-%m-%d")
    metrics = {
        "steps": random.randint(step_min, step_max),
        "water": round(random.uniform(water_min, water_max), 1),
        "sleep": round(random.uniform(sleep_min, sleep_max), 1),
        "weight": round(random.uniform(weight_min, weight_max), 1)
    }

    for metric, value in metrics.items():
        upload_metric(metric, date_str, value, single_date)

print("\n✅ Dummy data upload complete!")
