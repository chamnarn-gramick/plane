"""สร้างข้อมูลตัวอย่าง (demo) ให้ Dashboard มีตัวเลขทันที

วิธีใช้:
    bench --site <site> execute crm_ultra.demo.make_demo_data
    bench --site <site> execute crm_ultra.demo.clear_demo_data   # ล้างข้อมูล demo

หมายเหตุ: ข้อมูลนี้เป็นตัวอย่างสำหรับทดสอบ Dashboard เท่านั้น
ใบแจ้งหนี้/ใบเสนอราคาถูกตั้งสถานะตรงๆ (ไม่ลงบัญชี GL จริง) จึง "ไม่ควรใช้บนระบบ production"
ทุกรายการมีคำนำหน้า [DEMO] เพื่อให้ลบออกได้ง่ายด้วย clear_demo_data
"""

import random

import frappe
from frappe.utils import add_days, add_months, get_first_day, nowdate

CHANNELS = ["Facebook", "LINE", "Instagram", "Website", "Phone", "Walk-in", "Referral"]
SEGMENTS = ["A - VIP", "B - ประจำ", "C - ทั่วไป", "D - ใหม่"]

COMPANY_NAMES = [
    "สยามเทคโนโลยี",
    "รุ่งเรืองพาณิชย์",
    "บ้านสวนคาเฟ่",
    "ไทยเจริญการช่าง",
    "ดิจิทัลพลัส",
    "กรีนฟาร์มออร์แกนิก",
    "เมืองทองอิเล็กทรอนิกส์",
    "ภูเก็ตทราเวล",
    "อีสานฟู้ดส์",
    "ล้านนาเฟอร์นิเจอร์",
]

PERSON_NAMES = [
    "สมชาย ใจดี",
    "สมหญิง รักเรียน",
    "วิชัย พัฒนา",
    "นภาพร สุขใจ",
    "ธนวัฒน์ มั่งมี",
    "ปิยะดา ทองคำ",
    "อนุชา ก้าวหน้า",
    "กมลวรรณ ศรีสุข",
    "ภาณุพงศ์ เรืองชัย",
    "ศิริพร แสงทอง",
    "ณัฐพล วงศ์ใหญ่",
    "พิมพ์ชนก ดีงาม",
]


def make_demo_data():
    """สร้างข้อมูลตัวอย่างทั้งชุด"""
    company = _get_company()
    currency = frappe.get_cached_value("Company", company, "default_currency") or "THB"
    item = _ensure_item()
    stages = frappe.get_all("Sales Stage", pluck="name") or ["Prospecting"]
    today = nowdate()

    summary = {
        "customers": 0,
        "leads": 0,
        "opportunities": 0,
        "quotations": 0,
        "quotations_pending": 0,
        "quotations_expiring": 0,
        "sales_invoices": 0,
        "errors": 0,
    }

    # 1) ลูกค้า
    customers = []
    for i, name in enumerate(COMPANY_NAMES):
        try:
            customers.append(_make_customer(name, i))
            summary["customers"] += 1
        except Exception:
            summary["errors"] += 1
            frappe.log_error(frappe.get_traceback(), "CRM Ultra demo: customer")

    # 2) Lead (สร้างเดือนนี้ -> โชว์ใน 'Lead ใหม่เดือนนี้')
    for i, person in enumerate(PERSON_NAMES):
        try:
            _make_lead(person, i)
            summary["leads"] += 1
        except Exception:
            summary["errors"] += 1
            frappe.log_error(frappe.get_traceback(), "CRM Ultra demo: lead")

    # 3) Opportunity (Open, กระจายตามขั้นตอน -> โชว์ Pipeline + 'ดีลที่เปิดอยู่')
    for i in range(10):
        try:
            _make_opportunity(random.choice(customers), random.choice(stages))
            summary["opportunities"] += 1
        except Exception:
            summary["errors"] += 1
            frappe.log_error(frappe.get_traceback(), "CRM Ultra demo: opportunity")

    # 4) Quotation ปกติ (submit แล้ว) เดือนนี้
    for _ in range(6):
        try:
            _make_quotation(
                random.choice(customers), item, company, currency,
                txn_date=today, rate=random.randint(5000, 80000),
                qty=random.randint(1, 10), valid_days=20, mode="approved",
            )
            summary["quotations"] += 1
        except Exception:
            summary["errors"] += 1
            frappe.log_error(frappe.get_traceback(), "CRM Ultra demo: quotation")

    # 5) Quotation รออนุมัติ (ส่วนลด > 10% -> โชว์ 'ใบเสนอราคารออนุมัติ')
    try:
        _make_quotation(
            random.choice(customers), item, company, currency,
            txn_date=today, rate=60000, qty=5, valid_days=20, mode="pending",
        )
        summary["quotations_pending"] += 1
    except Exception:
        summary["errors"] += 1
        frappe.log_error(frappe.get_traceback(), "CRM Ultra demo: quotation pending")

    # 6) Quotation ใกล้หมดอายุ (valid_till +2 วัน -> ทดสอบงานแจ้งเตือน)
    for _ in range(2):
        try:
            _make_quotation(
                random.choice(customers), item, company, currency,
                txn_date=today, rate=random.randint(10000, 50000),
                qty=random.randint(1, 5), valid_days=2, mode="approved",
            )
            summary["quotations_expiring"] += 1
        except Exception:
            summary["errors"] += 1
            frappe.log_error(frappe.get_traceback(), "CRM Ultra demo: quotation expiring")

    # 7) Sales Invoice ย้อนหลัง 3 เดือน (-> กราฟยอดขายรายเดือน + 'ยอดขายเดือนนี้')
    for month_offset in range(3):
        pdate = get_first_day(add_months(today, -month_offset))
        pdate = add_days(pdate, random.randint(0, 20))
        for _ in range(3):
            try:
                _make_sales_invoice(
                    random.choice(customers), item, company, currency,
                    posting_date=pdate, rate=random.randint(8000, 120000),
                    qty=random.randint(1, 8),
                )
                summary["sales_invoices"] += 1
            except Exception:
                summary["errors"] += 1
                frappe.log_error(frappe.get_traceback(), "CRM Ultra demo: sales invoice")

    frappe.db.commit()
    _print_summary(summary)
    return summary


# ---------- helpers ----------

def _get_company():
    company = frappe.defaults.get_global_default("company") or frappe.db.get_value(
        "Company", {}, "name"
    )
    if not company:
        frappe.throw(
            "ไม่พบ Company — กรุณาทำ Setup Wizard ของ ERPNext ให้เสร็จก่อนรัน seed"
        )
    return company


def _leaf(doctype):
    """คืนค่าโหนดที่ไม่ใช่ group (เช่น Customer Group/Territory/Item Group)"""
    return frappe.db.get_value(doctype, {"is_group": 0}, "name")


def _ensure_item():
    code = "CRM-DEMO-ITEM"
    if frappe.db.exists("Item", code):
        return code
    frappe.get_doc(
        {
            "doctype": "Item",
            "item_code": code,
            "item_name": "[DEMO] แพ็กเกจบริการตัวอย่าง",
            "item_group": _leaf("Item Group") or "All Item Groups",
            "stock_uom": "Nos",
            "is_stock_item": 0,
            "is_sales_item": 1,
        }
    ).insert(ignore_permissions=True)
    return code


def _make_customer(name_th, idx):
    cname = f"[DEMO] {name_th}"
    if frappe.db.exists("Customer", cname):
        return cname
    frappe.get_doc(
        {
            "doctype": "Customer",
            "customer_name": cname,
            "customer_type": "Company",
            "customer_group": _leaf("Customer Group"),
            "territory": _leaf("Territory"),
            "crm_segment": random.choice(SEGMENTS),
            "crm_line_id": f"Udemo{idx:04d}",
        }
    ).insert(ignore_permissions=True)
    return cname


def _make_lead(person, idx):
    lname = f"[DEMO] {person}"
    if frappe.db.exists("Lead", {"lead_name": lname}):
        return
    lead = frappe.get_doc(
        {
            "doctype": "Lead",
            "lead_name": lname,
            "company_name": "[DEMO] บริษัทตัวอย่าง",
            "crm_channel": random.choice(CHANNELS),
            "crm_line_id": f"Ulead{idx:04d}",
            "crm_segment": random.choice(SEGMENTS),
        }
    )
    lead.flags.ignore_mandatory = True
    lead.insert(ignore_permissions=True)


def _make_opportunity(customer, stage):
    opp = frappe.get_doc(
        {
            "doctype": "Opportunity",
            "opportunity_from": "Customer",
            "party_name": customer,
            "status": "Open",
            "sales_stage": stage,
            "crm_channel": random.choice(CHANNELS),
            "opportunity_amount": random.randint(20000, 500000),
        }
    )
    opp.flags.ignore_mandatory = True
    opp.insert(ignore_permissions=True)


def _make_quotation(customer, item, company, currency, txn_date, rate, qty, valid_days, mode):
    q = frappe.get_doc(
        {
            "doctype": "Quotation",
            "quotation_to": "Customer",
            "party_name": customer,
            "transaction_date": txn_date,
            "valid_till": add_days(txn_date, valid_days),
            "company": company,
            "currency": currency,
            "items": [{"item_code": item, "qty": qty, "rate": rate}],
        }
    )
    if mode == "pending":
        q.additional_discount_percentage = 15
    q.flags.ignore_mandatory = True
    q.insert(ignore_permissions=True)

    if mode == "pending":
        # ค้างรออนุมัติ (docstatus ยังเป็น 0)
        frappe.db.set_value(
            "Quotation", q.name, "workflow_state", "Pending Approval",
            update_modified=False,
        )
    else:
        # ตั้งเป็น submit แล้ว เพื่อให้นับใน dashboard (demo: ไม่ลง GL)
        frappe.db.set_value(
            "Quotation", q.name,
            {"docstatus": 1, "status": "Open", "workflow_state": "Approved"},
            update_modified=False,
        )
    return q.name


def _make_sales_invoice(customer, item, company, currency, posting_date, rate, qty):
    si = frappe.get_doc(
        {
            "doctype": "Sales Invoice",
            "customer": customer,
            "posting_date": posting_date,
            "set_posting_time": 1,
            "due_date": add_days(posting_date, 30),
            "company": company,
            "currency": currency,
            "update_stock": 0,
            "items": [{"item_code": item, "qty": qty, "rate": rate}],
        }
    )
    si.flags.ignore_mandatory = True
    si.insert(ignore_permissions=True)
    grand = si.grand_total
    # ตั้งเป็น submit เพื่อให้นับใน dashboard (demo: ไม่ลง GL)
    frappe.db.set_value(
        "Sales Invoice", si.name,
        {"docstatus": 1, "status": "Unpaid", "outstanding_amount": grand},
        update_modified=False,
    )
    return si.name


def _print_summary(summary):
    print("\n=== CRM Ultra: สร้างข้อมูลตัวอย่างเสร็จ ===")
    print(f"  ลูกค้า (Customer)            : {summary['customers']}")
    print(f"  Lead ใหม่                    : {summary['leads']}")
    print(f"  โอกาสการขาย (Opportunity)   : {summary['opportunities']}")
    print(f"  ใบเสนอราคา (Quotation)       : {summary['quotations']}")
    print(f"  ใบเสนอราคารออนุมัติ          : {summary['quotations_pending']}")
    print(f"  ใบเสนอราคาใกล้หมดอายุ        : {summary['quotations_expiring']}")
    print(f"  ใบแจ้งหนี้ (Sales Invoice)   : {summary['sales_invoices']}")
    if summary["errors"]:
        print(f"  ** ข้อผิดพลาด {summary['errors']} รายการ (ดู Error Log) **")
    print("เปิด Workspace 'CRM Ultra' หรือ Dashboard 'CRM Ultra Sales' เพื่อดูผล\n")


def clear_demo_data():
    """ลบข้อมูลตัวอย่างทั้งหมด (รายการที่ขึ้นต้นด้วย [DEMO])"""
    demo_customers = frappe.get_all(
        "Customer", filters={"name": ["like", "[DEMO]%"]}, pluck="name"
    )

    for dt, field in [
        ("Sales Invoice", "customer"),
        ("Quotation", "party_name"),
        ("Opportunity", "party_name"),
    ]:
        if not demo_customers:
            break
        for name in frappe.get_all(dt, filters={field: ["in", demo_customers]}, pluck="name"):
            frappe.delete_doc(dt, name, force=True, ignore_permissions=True, delete_permanently=True)

    for name in frappe.get_all("Lead", filters={"lead_name": ["like", "[DEMO]%"]}, pluck="name"):
        frappe.delete_doc("Lead", name, force=True, ignore_permissions=True, delete_permanently=True)

    for name in demo_customers:
        frappe.delete_doc("Customer", name, force=True, ignore_permissions=True, delete_permanently=True)

    if frappe.db.exists("Item", "CRM-DEMO-ITEM"):
        frappe.delete_doc("Item", "CRM-DEMO-ITEM", force=True, ignore_permissions=True)

    frappe.db.commit()
    print("=== CRM Ultra: ลบข้อมูลตัวอย่างเรียบร้อย ===")
