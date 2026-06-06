"""
Firebase Cloud Messaging Service — Push notifications qua FCM.

Khởi tạo Firebase Admin SDK từ base64-encoded service account key,
cung cấp hàm gửi push notification tới device.
"""

import base64
import json
import logging

import firebase_admin
from firebase_admin import credentials, messaging

from app.core.config import settings

logger = logging.getLogger("fcm")

_firebase_app = None


def _init_firebase():
    """Khởi tạo Firebase Admin SDK (chỉ gọi 1 lần)."""
    global _firebase_app

    if _firebase_app is not None:
        return True

    b64 = settings.FIREBASE_SERVICE_ACCOUNT_BASE64
    if not b64:
        logger.warning("⚠️ FIREBASE_SERVICE_ACCOUNT_BASE64 not set — FCM disabled")
        return False

    try:
        decoded = base64.b64decode(b64)
        service_account = json.loads(decoded)
        cred = credentials.Certificate(service_account)
        _firebase_app = firebase_admin.initialize_app(cred)
        logger.info("🔥 Firebase Admin SDK initialized successfully")
        return True
    except Exception as e:
        logger.error(f"❌ Firebase init error: {e}")
        return False


async def send_push_notification(
    fcm_token: str,
    title: str,
    body: str,
    data: dict | None = None,
):
    """Gửi push notification tới 1 device qua FCM token.

    Returns True nếu gửi thành công, False nếu lỗi.
    """
    if not _init_firebase():
        return False

    try:
        message = messaging.Message(
            notification=messaging.Notification(
                title=title,
                body=body,
            ),
            data={k: str(v) for k, v in (data or {}).items()},
            token=fcm_token,
            android=messaging.AndroidConfig(
                priority="high",
                notification=messaging.AndroidNotification(
                    channel_id="techhub_oos",
                    sound="default",
                ),
            ),
        )
        response = messaging.send(message)
        logger.info(f"🔥 [FCM] Sent to token {fcm_token[:20]}...: {response}")
        return True
    except messaging.UnregisteredError:
        logger.warning(f"🔥 [FCM] Token expired/unregistered: {fcm_token[:20]}...")
        return False
    except Exception as e:
        logger.error(f"🔥 [FCM] Send error: {e}")
        return False


async def send_push_to_multiple(
    fcm_tokens: list[str],
    title: str,
    body: str,
    data: dict | None = None,
):
    """Gửi push notification tới nhiều devices."""
    if not _init_firebase() or not fcm_tokens:
        return

    try:
        message = messaging.MulticastMessage(
            notification=messaging.Notification(
                title=title,
                body=body,
            ),
            data={k: str(v) for k, v in (data or {}).items()},
            tokens=fcm_tokens,
            android=messaging.AndroidConfig(
                priority="high",
                notification=messaging.AndroidNotification(
                    channel_id="techhub_oos",
                    sound="default",
                ),
            ),
        )
        response = messaging.send_each_for_multicast(message)
        logger.info(
            f"🔥 [FCM] Multicast: {response.success_count} success, "
            f"{response.failure_count} failed"
        )
    except Exception as e:
        logger.error(f"🔥 [FCM] Multicast error: {e}")
