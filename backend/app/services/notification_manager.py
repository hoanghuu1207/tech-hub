"""
WebSocket Notification Manager — Quản lý kết nối WebSocket cho real-time notifications.

Cho phép backend push notification tới mobile client khi có sự kiện mới.
"""

import json
import logging
from typing import Dict, List
from uuid import UUID
from fastapi import WebSocket

logger = logging.getLogger("notification_ws")


class NotificationManager:
    """Singleton manager giữ các WebSocket connections theo user_id."""

    _instance = None

    def __new__(cls):
        if cls._instance is None:
            cls._instance = super().__new__(cls)
            cls._instance._connections: Dict[str, List[WebSocket]] = {}
        return cls._instance

    async def connect(self, user_id: str, websocket: WebSocket):
        """Accept và lưu WebSocket connection cho user."""
        await websocket.accept()
        if user_id not in self._connections:
            self._connections[user_id] = []
        self._connections[user_id].append(websocket)
        logger.info(f"🔔 [WS] User {user_id} connected (total: {len(self._connections[user_id])})")

    def disconnect(self, user_id: str, websocket: WebSocket):
        """Xóa WebSocket connection khi user ngắt kết nối."""
        if user_id in self._connections:
            self._connections[user_id] = [
                ws for ws in self._connections[user_id] if ws != websocket
            ]
            if not self._connections[user_id]:
                del self._connections[user_id]
        logger.info(f"🔔 [WS] User {user_id} disconnected")

    async def send_to_user(self, user_id, data: dict):
        """Gửi data JSON tới tất cả connections của một user."""
        uid = str(user_id)
        if uid not in self._connections:
            return

        dead = []
        for ws in self._connections[uid]:
            try:
                await ws.send_json(data)
            except Exception:
                dead.append(ws)

        # Cleanup dead connections
        for ws in dead:
            self._connections[uid] = [
                w for w in self._connections.get(uid, []) if w != ws
            ]


# Global singleton
notification_manager = NotificationManager()
