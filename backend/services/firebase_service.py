from __future__ import annotations

import asyncio

import firebase_admin
from firebase_admin import credentials, messaging

from config import settings
from logger import logger

_log = logger.bind(module="firebase_service")

# Initialise once at import time
_cred = credentials.Certificate(settings.firebase_credentials_path)
_app  = firebase_admin.initialize_app(_cred)


async def send_push(
    fcm_token: str,
    title: str,
    body: str,
    data: dict | None = None,
) -> dict:
    """Send a push notification to a single device. Returns a result dict."""

    def _send() -> dict:
        message = messaging.Message(
            notification=messaging.Notification(title=title, body=body),
            data={k: str(v) for k, v in (data or {}).items()},
            token=fcm_token,
            android=messaging.AndroidConfig(
                priority="high",
                notification=messaging.AndroidNotification(
                    channel_id="daily_outfit",
                    icon="ic_launcher",
                    color="#1A1A1A",
                ),
            ),
            apns=messaging.APNSConfig(
                payload=messaging.APNSPayload(
                    aps=messaging.Aps(badge=1, sound="default"),
                ),
            ),
        )
        try:
            response = messaging.send(message)
            _log.info("push_sent", message_id=response)
            return {"success": True, "message_id": response}
        except messaging.UnregisteredError:
            _log.warning("push_token_unregistered", token_prefix=fcm_token[:20])
            return {"success": False, "reason": "unregistered", "should_delete_token": True}
        except messaging.SenderIdMismatchError:
            _log.warning("push_sender_mismatch")
            return {"success": False, "reason": "sender_mismatch"}
        except Exception as exc:
            _log.error("push_failed", error=str(exc))
            return {"success": False, "reason": str(exc)}

    return await asyncio.to_thread(_send)


async def send_push_multicast(
    fcm_tokens: list[str],
    title: str,
    body: str,
    data: dict | None = None,
) -> dict:
    """Send the same notification to multiple devices at once (max 500)."""

    def _send() -> dict:
        message = messaging.MulticastMessage(
            notification=messaging.Notification(title=title, body=body),
            data={k: str(v) for k, v in (data or {}).items()},
            tokens=fcm_tokens[:500],
            android=messaging.AndroidConfig(
                priority="high",
                notification=messaging.AndroidNotification(
                    channel_id="daily_outfit",
                    icon="ic_launcher",
                    color="#1A1A1A",
                ),
            ),
            apns=messaging.APNSConfig(
                payload=messaging.APNSPayload(
                    aps=messaging.Aps(badge=1, sound="default"),
                ),
            ),
        )
        response = messaging.send_each_for_multicast(message)
        invalid_tokens = [
            fcm_tokens[i]
            for i, r in enumerate(response.responses)
            if not r.success and isinstance(r.exception, messaging.UnregisteredError)
        ]
        _log.info("push_multicast_sent",
                  success_count=response.success_count,
                  failure_count=response.failure_count)
        return {
            "success_count": response.success_count,
            "failure_count": response.failure_count,
            "invalid_tokens": invalid_tokens,
        }

    return await asyncio.to_thread(_send)
