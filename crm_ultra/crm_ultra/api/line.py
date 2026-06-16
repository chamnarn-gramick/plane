"""LINE Messaging API webhook → สร้าง Lead อัตโนมัติ

ตั้งค่าใน site_config.json:
    "line_channel_secret": "xxxx"   # ใช้ตรวจลายเซ็น (แนะนำให้ตั้ง)

แล้วชี้ Webhook URL ใน LINE Developers Console มาที่:
    https://<your-domain>/api/method/crm_ultra.api.line.webhook
"""

import base64
import hashlib
import hmac
import json

import frappe
from frappe import _


@frappe.whitelist(allow_guest=True)
def webhook():
    """รับ event จาก LINE แล้วสร้าง Lead ให้ทีมขายติดตาม"""
    body = frappe.request.get_data() or b""
    signature = frappe.get_request_header("X-Line-Signature") or ""
    secret = frappe.conf.get("line_channel_secret")

    # ตรวจลายเซ็น ถ้ามีการตั้งค่า secret ไว้
    if secret and not _verify_signature(body, signature, secret):
        frappe.throw(_("Invalid LINE signature"), frappe.AuthenticationError)

    try:
        payload = json.loads(body or b"{}")
    except json.JSONDecodeError:
        payload = {}

    created = 0
    for event in payload.get("events", []):
        if _handle_event(event):
            created += 1

    return {"status": "ok", "leads_created": created}


def _verify_signature(body: bytes, signature: str, secret: str) -> bool:
    digest = hmac.new(secret.encode("utf-8"), body, hashlib.sha256).digest()
    expected = base64.b64encode(digest).decode("utf-8")
    return hmac.compare_digest(expected, signature)


def _handle_event(event: dict) -> bool:
    """สร้าง Lead จาก LINE userId (กันซ้ำด้วย crm_line_id)"""
    user_id = (event.get("source") or {}).get("userId")
    if not user_id:
        return False

    if frappe.db.exists("Lead", {"crm_line_id": user_id}):
        # มี Lead จาก LINE คนนี้แล้ว — แนบข้อความเป็น comment เพิ่ม
        _append_message(user_id, event)
        return False

    lead = frappe.get_doc(
        {
            "doctype": "Lead",
            "lead_name": f"LINE User {user_id[:8]}",
            "crm_channel": "LINE",
            "crm_line_id": user_id,
        }
    )
    lead.flags.ignore_mandatory = True
    lead.insert(ignore_permissions=True)

    text = _extract_text(event)
    if text:
        lead.add_comment("Comment", text=text)

    frappe.db.commit()
    return True


def _append_message(user_id: str, event: dict):
    text = _extract_text(event)
    if not text:
        return
    name = frappe.db.get_value("Lead", {"crm_line_id": user_id}, "name")
    if name:
        frappe.get_doc("Lead", name).add_comment("Comment", text=text)
        frappe.db.commit()


def _extract_text(event: dict) -> str:
    message = event.get("message") or {}
    if event.get("type") == "message" and message.get("type") == "text":
        return message.get("text", "")
    return ""
