# แผน Setup ERPNext + ปรับแต่งให้เหมือน CRM Ultra

เอกสารนี้เป็นแผนสร้างระบบ CRM แบบ [CRM Ultra (crmultra.com)](https://www.crmultra.com/) โดยใช้
**ERPNext / Frappe Framework** เป็นฐาน (open-source, GPL, ฟรีทั้งหมด ไม่มีฟีเจอร์ล็อกหลังกำแพงเงิน)

> หมายเหตุ: เอกสารนี้เป็น "แผน/ข้อกำหนด" ระบบ ERPNext เป็นคนละ stack กับ Plane ในรีโปนี้
> (Plane = Django/Next.js project management) เก็บไว้เป็น reference ก่อนลงมือติดตั้งจริงบนเซิร์ฟเวอร์แยก

---

## 1. ทำไมเลือก ERPNext

CRM Ultra มี 8 โมดูล — ERPNext + Frappe CRM/Helpdesk รองรับครบเกือบทั้งหมด **out-of-the-box**
จุดที่ชนะตัวอื่นคือมี **Workflow engine ในตัว** (= Approve Center) และ **Report/Dashboard builder** แบบ low-code
ปรับแต่งผ่าน DocType ได้โดยไม่ต้องแก้ core

| โมดูล CRM Ultra | ตัวรองรับใน ERPNext | ต้องปรับแต่งเพิ่ม |
|---|---|---|
| Customer Management | Customer, Contact, Address, Lead, Customer Group | แท็ก/แหล่งที่มา, custom fields |
| Activity Management | ToDo, Event, CRM Note, Calendar | Activity type เฉพาะ (โทร/เข้าพบ) |
| Sales Force Automation | Lead → Opportunity → Quotation → Sales Order → Sales Invoice, Item, Price List | เลขเอกสารไทย, แจ้งเตือนหมดอายุ, sales target |
| Marketing Management | Email Campaign, Newsletter, Email Group, Lead Source | segment + tracking |
| Service Management | Issue (Helpdesk), Service Level Agreement, Knowledge Base | SLA ภาษาไทย |
| Approve Center | **Workflow (core Frappe)** + Workflow Action | กำหนดวงเงิน/ผู้อนุมัติ |
| Reports & Dashboards | Query/Script Report, Dashboard, Number Card, Dashboard Chart | กราฟยอดขาย/KPI |
| CRM Ultra Mobile | Frappe Mobile App / PWA | - |

---

## 2. สถาปัตยกรรม & Hosting

```
┌──────────────────────────────────────────────┐
│  Server (Ubuntu 22.04, 4 vCPU / 8GB RAM ขึ้นไป) │
│                                                │
│  Frappe Bench                                  │
│   ├── frappe (framework)                       │
│   ├── erpnext (CRM + Sales + Accounts)         │
│   ├── crm (Frappe CRM - UI ขายสมัยใหม่)        │
│   ├── helpdesk (Frappe Helpdesk - Service)     │
│   └── erpnext_thailand (ภาษีไทย/WHT) *ชุมชน    │
│                                                │
│  MariaDB 10.6+  │  Redis  │  Nginx  │  Supervisor│
└──────────────────────────────────────────────┘
```

**ตัวเลือกติดตั้ง:** แนะนำ **Docker (frappe_docker)** สำหรับ production จะคุม version ง่ายกว่า
หรือ **bench (manual)** สำหรับ dev/ลองเล่น

---

## 3. ขั้นตอนติดตั้ง (dev ด้วย bench)

```bash
# 1) ติดตั้ง dependency: python3.11, node 18, mariadb, redis, wkhtmltopdf (สำหรับ PDF)
# 2) ติดตั้ง bench
pip install frappe-bench
bench init --frappe-branch version-15 frappe-bench
cd frappe-bench

# 3) ดึง apps
bench get-app --branch version-15 erpnext
bench get-app crm          # Frappe CRM
bench get-app helpdesk     # Frappe Helpdesk

# 4) สร้าง site + ติดตั้ง apps
bench new-site crm.local
bench --site crm.local install-app erpnext
bench --site crm.local install-app crm
bench --site crm.local install-app helpdesk

# 5) รัน
bench start
```

Production: ใช้ `frappe_docker` + `docker compose` แล้วตั้ง domain + SSL (Let's Encrypt)

---

## 4. ปรับแต่งรายโมดูลให้เหมือน CRM Ultra

### 4.1 Customer Management
- เปิดใช้ DocType: **Lead, Customer, Contact, Address**
- Custom Fields ที่ควรเพิ่ม (ผ่าน Customize Form):
  - `lead_source` (แหล่งที่มา): Facebook / LINE / เว็บไซต์ / โทรเข้า / งานแสดงสินค้า
  - `customer_segment`, `tags`
- ตั้ง **Customer Group / Territory** สำหรับแบ่งกลุ่มลูกค้า
- ประวัติ 360°: ใช้ Linked Documents + Activity timeline ที่มีอยู่แล้ว
- นำเข้า: Data Import Tool (Excel/CSV) + ตั้ง Naming เพื่อกันซ้ำ

### 4.2 Activity Management
- DocType: **Event, ToDo, CRM Note**
- เพิ่ม Activity Type custom: โทร / นัดพบ / ส่งอีเมล / ส่งใบเสนอราคา
- ปฏิทินทีม + reminder (Notification + Email Alert)
- ผูกกิจกรรมกับ Lead/Opportunity/Customer ผ่าน Dynamic Link

### 4.3 Sales Force Automation (หัวใจ)
- Pipeline: **Opportunity** + กำหนด `sales_stage` (Prospecting → Qualification → Quotation → Negotiation → Won/Lost) → ดูเป็น Kanban
- เอกสารขาย flow: **Quotation → Sales Order → Sales Invoice**
- **Item** + **Price List** (หลายราคา/ลูกค้า), หน่วยนับ, ภาษี (Tax Template 7%)
- ปรับแต่ง:
  - Naming Series เลขเอกสารไทย เช่น `QU-{YY}{MM}-#####`
  - Print Format ใบเสนอราคา/ใบกำกับภาษีภาษาไทย (Jinja/HTML)
  - Auto-email เมื่อ submit Quotation (Notification + attach PDF)
  - แจ้งเตือนใบเสนอราคา**ใกล้หมดอายุ** (Scheduled Job เช็ค `valid_till`)
  - **Sales Target**: Sales Person + Target Detail → เทียบกับ Sales Order/Invoice จริง

### 4.4 Marketing Management
- **Email Campaign** + **Campaign** + **Email Group** + **Newsletter**
- Lead Source tracking → วัด conversion ต่อแคมเปญ
- Segment: ใช้ filter บน Lead/Customer สร้าง Email Group อัตโนมัติ
- (ออปชัน) เชื่อม LINE/Facebook ผ่าน Webhook + custom app ภายหลัง

### 4.5 Service Management
- ใช้ **Frappe Helpdesk** หรือ DocType **Issue**
- **Service Level Agreement (SLA)**: ตั้งเวลาตอบ/แก้ตามระดับความสำคัญ + แจ้งเตือนเกินเวลา
- **Knowledge Base / FAQ**
- ผูก Issue กับ Customer + ประวัติ

### 4.6 Approve Center ⭐ (จุดเด่นของ ERPNext)
- ใช้ **Workflow** (core) สร้างขั้นอนุมัติ เช่น Quotation ที่ส่วนลด > 10%:
  - States: Draft → Pending Approval → Approved / Rejected
  - Transitions: ผูกกับ Role (เช่น Sales Manager) + เงื่อนไข `discount_amount > X`
- **Workflow Action** + Email: ผู้อนุมัติกดอนุมัติจากอีเมล/หน้าจอได้
- หลายระดับ: ตั้งหลาย state ตามวงเงิน (พนักงาน → หัวหน้า → ผู้จัดการ)
- ศูนย์รวมงานรออนุมัติ: List View filter `workflow_state = Pending Approval` + Dashboard

### 4.7 Reports & Dashboards
- **Dashboard** + **Number Card** (ยอดขายเดือนนี้, ดีลที่ปิดได้, Lead ใหม่)
- **Dashboard Chart** (กราฟยอดขายรายเดือน, funnel pipeline)
- **Query Report / Script Report** สำหรับรายงานเฉพาะ (KPI เซลล์, เป้าเทียบผล)
- Filter หลายเงื่อนไข + Export Excel/PDF (มีในตัว)

### 4.8 CRM Ultra Mobile
- **Frappe Mobile App** (มี iOS/Android) ใช้ login เข้า site ได้เลย
- หรือทำ **PWA**: Frappe CRM UI เป็น responsive อยู่แล้ว
- ฟังก์ชันเซลล์นอกสถานที่: ดูลูกค้า, สร้าง Quotation, บันทึก Activity, รับ Notification

---

## 5. Localization ไทย
- ติดตั้ง **erpnext_thailand** (community) → ภาษีหัก ณ ที่จ่าย (WHT), หนังสือรับรองหัก ณ ที่จ่าย, ใบกำกับภาษีไทย
- ตั้งภาษา = ไทย, สกุลเงิน = THB, รอบบัญชี, เลขผู้เสียภาษี
- Print Format ภาษาไทย: ใบเสนอราคา / ใบแจ้งหนี้ / ใบเสร็จ / ใบกำกับภาษี

---

## 6. Roadmap แนะนำ (เป็นเฟส)

| เฟส | ขอบเขต | ผลลัพธ์ |
|---|---|---|
| 0 | ติดตั้ง bench + erpnext + crm + helpdesk + ภาษาไทย | ระบบรันได้ |
| 1 | Customer + Activity + Pipeline (Opportunity) | เซลล์เริ่มใช้จัดการลูกค้า/ดีล |
| 2 | เอกสารขาย: Item/Price + Quotation→SO→Invoice + Print Format ไทย + auto email | ออกใบเสนอราคา/ใบกำกับได้ |
| 3 | Approve Center (Workflow อนุมัติ) + Sales Target | ควบคุมการอนุมัติ + วัดเป้า |
| 4 | Reports & Dashboards (Number Card + Chart + KPI) | ผู้บริหารดูภาพรวม |
| 5 | Service (Helpdesk + SLA) + Marketing (Email Campaign) | บริการหลังขาย + การตลาด |
| 6 | Mobile + (ออปชัน) Omnichannel LINE/FB/IG | ครบเหมือน CRM Ultra |

---

## 7. สิ่งที่ต้องเตรียม
- เซิร์ฟเวอร์ (VPS/Cloud) Ubuntu ≥ 4 vCPU / 8GB RAM / SSD
- Domain + SSL
- SMTP / SendGrid สำหรับส่งอีเมล (ใบเสนอราคา/แคมเปญ)
- (ออปชัน) LINE Messaging API, Meta (FB/IG) API ถ้าต้องการ Omnichannel
- ผู้ดูแลที่เข้าใจ DocType/Workflow ของ Frappe (low-code) — ปรับแต่งได้โดยไม่ต้องเขียน Python มาก

---

## อ้างอิง
- ERPNext: https://erpnext.com / https://github.com/frappe/erpnext
- Frappe CRM: https://github.com/frappe/crm
- Frappe Helpdesk: https://github.com/frappe/helpdesk
- CRM Ultra (ต้นแบบฟีเจอร์): https://www.crmultra.com/
