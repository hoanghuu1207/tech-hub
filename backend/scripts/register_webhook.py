import sys
import os

# d:\DATN\backend > docker exec -t techshop_backend python scripts/register_webhook.py https://fe67-2001-ee0-4b46-9560-413b-75b4-1565-dc4b.ngrok-free.app/api/v1/webhook/payos

# Make sure app path is in python path
sys.path.append(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

import requests
from app.core.config import settings
from payos import PayOS

def register():
    # Initialize PayOS
    payos = PayOS(
        client_id=settings.PAYOS_CLIENT_ID,
        api_key=settings.PAYOS_API_KEY,
        checksum_key=settings.PAYOS_CHECKSUM_KEY,
    )

    # 1. Try to get public URL automatically from local ngrok API
    ngrok_url = None
    try:
        res = requests.get("http://localhost:4040/api/tunnels", timeout=2)
        if res.status_code == 200:
            tunnels = res.json().get("tunnels", [])
            for t in tunnels:
                if t.get("proto") == "https":
                    ngrok_url = t.get("public_url")
                    break
    except Exception:
        pass

    if ngrok_url:
        webhook_url = f"{ngrok_url}/api/v1/webhook/payos"
        print(f"Detected running ngrok tunnel: {ngrok_url}")
    else:
        # Prompt or fallback to manual input if arguments are provided
        if len(sys.argv) > 1:
            webhook_url = sys.argv[1]
        else:
            print("Could not auto-detect running ngrok tunnel.")
            print("Usage: python scripts/register_webhook.py <your_webhook_url>")
            sys.exit(1)

    print(f"Registering webhook URL: {webhook_url}")
    try:
        # Using newer SDK confirm method
        result = payos.webhooks.confirm(webhook_url)
        print("✅ Webhook registered successfully!")
        print(f"Result URL: {result}")
    except Exception as e:
        print(f"❌ Failed to register webhook: {e}")

if __name__ == "__main__":
    register()
