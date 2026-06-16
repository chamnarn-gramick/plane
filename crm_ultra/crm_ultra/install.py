import frappe


def after_install():
    """ทำงานหลังติดตั้งแอป crm_ultra เสร็จ"""
    _ensure_sales_roles()
    _set_thai_defaults()
    frappe.db.commit()
    print(
        "\n[CRM Ultra] ติดตั้งเสร็จเรียบร้อย\n"
        "  - ตั้งค่าระบบเป็นแบบไทย (ภาษา/โซนเวลา/รูปแบบวันที่)\n"
        "  - Custom Fields (ช่องทาง/segment/LINE ID) ถูกเพิ่มแล้ว\n"
        "  - Workflow 'CRM Ultra Quotation Approval' (Approve Center) พร้อมใช้\n"
        "  - Print Format ไทย (ใบเสนอราคา/ใบกำกับภาษี) พร้อมใช้\n"
        "  - Workspace 'CRM Ultra' + Dashboard ยอดขาย พร้อมใช้\n"
        "  - เลขเอกสารใบเสนอราคาแบบไทย (QU-YY-MM-#####) พร้อมใช้\n"
        "  - งานแจ้งเตือนใบเสนอราคาหมดอายุจะรันทุกวันอัตโนมัติ\n"
    )


def _set_thai_defaults():
    """ตั้งค่าระบบให้เหมาะกับผู้ใช้ไทย (UX/UI)

    ตั้งภาษาไทย, โซนเวลากรุงเทพฯ, รูปแบบวันที่ และรูปแบบตัวเลข
    """
    ss = frappe.get_single("System Settings")
    defaults = {
        "language": "th",
        "time_zone": "Asia/Bangkok",
        "date_format": "dd/mm/yyyy",
        "time_format": "HH:mm:ss",
        "number_format": "#,###.##",
        "first_day_of_the_week": "Monday",
    }
    for field, value in defaults.items():
        if hasattr(ss, field):
            ss.set(field, value)

    if not ss.get("country"):
        ss.set("country", "Thailand")

    ss.flags.ignore_mandatory = True
    ss.save(ignore_permissions=True)


def _ensure_sales_roles():
    """ตรวจสอบว่ามี Role ที่ workflow ใช้ (มากับ ERPNext อยู่แล้ว แต่กันพลาด)"""
    for role in ("Sales User", "Sales Manager"):
        if not frappe.db.exists("Role", role):
            frappe.get_doc({"doctype": "Role", "role_name": role}).insert(
                ignore_permissions=True
            )
