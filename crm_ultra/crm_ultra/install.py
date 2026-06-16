import frappe


def after_install():
    """ทำงานหลังติดตั้งแอป crm_ultra เสร็จ"""
    _ensure_sales_roles()
    frappe.db.commit()
    print(
        "\n[CRM Ultra] ติดตั้งเสร็จเรียบร้อย\n"
        "  - Custom Fields (ช่องทาง/segment/LINE ID) ถูกเพิ่มแล้ว\n"
        "  - Workflow 'CRM Ultra Quotation Approval' (Approve Center) พร้อมใช้\n"
        "  - Print Format 'CRM Ultra Quotation TH' พร้อมใช้\n"
        "  - เลขเอกสารใบเสนอราคาแบบไทย (QU-YY-MM-#####) พร้อมใช้\n"
        "  - งานแจ้งเตือนใบเสนอราคาหมดอายุจะรันทุกวันอัตโนมัติ\n"
    )


def _ensure_sales_roles():
    """ตรวจสอบว่ามี Role ที่ workflow ใช้ (มากับ ERPNext อยู่แล้ว แต่กันพลาด)"""
    for role in ("Sales User", "Sales Manager"):
        if not frappe.db.exists("Role", role):
            frappe.get_doc({"doctype": "Role", "role_name": role}).insert(
                ignore_permissions=True
            )
