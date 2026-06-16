import frappe
from frappe.utils import add_days, nowdate


def notify_expiring_quotations():
    """แจ้งเตือนใบเสนอราคาที่ใกล้หมดอายุภายใน 3 วัน

    - ส่งอีเมลถึงเจ้าของใบเสนอราคา
    - สร้าง ToDo ติดตามให้เซลล์ปิดการขาย

    ฟังก์ชันนี้ถูกเรียกโดย scheduler ทุกวัน (ดู hooks.py)
    """
    threshold = add_days(nowdate(), 3)

    quotations = frappe.get_all(
        "Quotation",
        filters={
            "docstatus": 1,
            "status": ["not in", ["Expired", "Lost", "Ordered", "Cancelled"]],
            "valid_till": ["between", [nowdate(), threshold]],
        },
        fields=["name", "owner", "customer_name", "valid_till", "grand_total"],
    )

    for q in quotations:
        recipient = q.get("owner")
        if not recipient:
            continue

        grand_total = q.get("grand_total") or 0

        frappe.sendmail(
            recipients=[recipient],
            subject=f"⏰ ใบเสนอราคา {q.name} ใกล้หมดอายุ ({q.valid_till})",
            message=(
                "เรียนเจ้าของงานขาย,<br><br>"
                f"ใบเสนอราคา <b>{q.name}</b> ของลูกค้า "
                f"<b>{q.get('customer_name') or '-'}</b> "
                f"มูลค่า {grand_total:,.2f} บาท "
                f"จะหมดอายุในวันที่ <b>{q.valid_till}</b><br><br>"
                "กรุณาติดตามลูกค้าเพื่อปิดการขายก่อนใบเสนอราคาหมดอายุ"
            ),
            reference_doctype="Quotation",
            reference_name=q.name,
        )

        # สร้างงานติดตาม (ToDo) ถ้ายังไม่มี
        existing = frappe.db.exists(
            "ToDo",
            {
                "reference_type": "Quotation",
                "reference_name": q.name,
                "status": "Open",
            },
        )
        if not existing:
            frappe.get_doc(
                {
                    "doctype": "ToDo",
                    "allocated_to": recipient,
                    "reference_type": "Quotation",
                    "reference_name": q.name,
                    "date": q.valid_till,
                    "priority": "High",
                    "description": f"ติดตามใบเสนอราคา {q.name} ก่อนหมดอายุ",
                }
            ).insert(ignore_permissions=True)

    frappe.db.commit()
