# CRM Ultra (Frappe App)

Frappe/ERPNext custom app ที่แพ็กการปรับแต่งให้ ERPNext ทำงานแบบ
[CRM Ultra (crmultra.com)](https://www.crmultra.com/) — ระบบบริหารงานขายออนไลน์

ติดตั้งทับ ERPNext แล้วได้ฟีเจอร์เหล่านี้ทันที (ไม่ต้องเขียนโค้ดเพิ่ม):

| ฟีเจอร์ | สิ่งที่ได้ |
|---|---|
| **Customer / Lead fields** | ช่องทางที่มา (Facebook/LINE/IG/Website/Phone/Walk-in/Exhibition/Referral), LINE ID, กลุ่มลูกค้า (Segment A–D) บน Lead, Opportunity, Customer |
| **Approve Center** | Workflow `CRM Ultra Quotation Approval` — ใบเสนอราคาที่ส่วนลด > 10% ต้องผ่านการอนุมัติจาก Sales Manager ก่อน submit |
| **เลขเอกสารไทย** | ใบเสนอราคารันเลข `QU-YY-MM-#####` |
| **Print Format ไทย** | `CRM Ultra Quotation TH` — ใบเสนอราคาภาษาไทยพร้อมพิมพ์/ส่ง PDF |
| **แจ้งเตือนหมดอายุ** | งานรันทุกวัน ส่งอีเมล + สร้าง ToDo ติดตามใบเสนอราคาที่ใกล้หมดอายุภายใน 3 วัน |
| **ใบกำกับภาษีไทย** | `CRM Ultra Tax Invoice TH` — ใบกำกับภาษี/ใบเสร็จรับเงินภาษาไทย (มีเลขผู้เสียภาษีบริษัท/ลูกค้า) |
| **Dashboard ยอดขาย** | Dashboard `CRM Ultra Sales`: ยอดขายเดือนนี้, ดีลที่เปิดอยู่, Lead ใหม่, ใบเสนอราคารออนุมัติ + กราฟยอดขายรายเดือน + Pipeline ตามขั้นตอน |
| **LINE Webhook** | สร้าง Lead อัตโนมัติเมื่อมีคนทักผ่าน LINE (ตรวจลายเซ็น, กันซ้ำ, เก็บข้อความเป็น comment) |
| **UX/UI ไทย** | ฟอนต์ Sarabun ทั้งระบบ, คำแปลภาษาไทย, Workspace `CRM Ultra` รวมเมนู/ปุ่มลัด/KPI, ตั้งค่าเริ่มต้นแบบไทย (ภาษา/โซนเวลา Asia/Bangkok/วันที่ dd/mm/yyyy) |

> ฟีเจอร์ส่วนที่เหลือของ CRM Ultra (Activity, Pipeline, Marketing, Service/Helpdesk,
> Reports & Dashboards, Mobile) มากับ ERPNext + Frappe CRM + Frappe Helpdesk อยู่แล้ว
> ดูแผนเต็มที่ [`../docs/crm/erpnext-crm-ultra-plan.md`](../docs/crm/erpnext-crm-ultra-plan.md)

---

## วิธีติดตั้ง

ต้องมี [Frappe Bench](https://github.com/frappe/bench) + ERPNext (version-15) ติดตั้งไว้แล้ว

```bash
# 1) ดึงแอปเข้า bench (จาก git remote ของคุณ)
bench get-app crm_ultra <git-url-ของ-repo-นี้/crm_ultra>
#   หรือถ้า clone มาแล้ว: bench get-app /path/to/crm_ultra

# 2) ติดตั้งลง site
bench --site <ชื่อ-site> install-app crm_ultra

# 3) โหลด fixtures (custom fields, workflow, print format ฯลฯ)
bench --site <ชื่อ-site> migrate

# 4) เปิด scheduler เพื่อให้แจ้งเตือนหมดอายุทำงาน
bench --site <ชื่อ-site> enable-scheduler
```

## ทดสอบหลังติดตั้ง
1. ไปที่ **Quotation ใหม่** → จะเห็นเลขเอกสารขึ้นต้น `QU-`
2. ใส่ส่วนลด (Additional Discount) > 10% → ปุ่ม **Submit for Approval** จะปรากฏ → สถานะเป็น *Pending Approval* รอ Sales Manager กด **Approve**
3. กด **Print → CRM Ultra Quotation TH** เพื่อดูใบเสนอราคาภาษาไทย
4. Lead/Customer จะมีฟิลด์ **ช่องทางที่มา / LINE ID / กลุ่มลูกค้า**

## ตั้งค่า LINE (ออปชัน)
1. ใส่ค่าใน `site_config.json`:
   ```json
   "line_channel_secret": "<channel secret จาก LINE Developers>"
   ```
2. ตั้ง Webhook URL ใน LINE Developers Console เป็น:
   `https://<your-domain>/api/method/crm_ultra.api.line.webhook`
3. ทักแชทเข้า LINE OA → ระบบจะสร้าง **Lead** ช่องทาง LINE ให้อัตโนมัติ

## ดู Dashboard
ไปที่เมนู **Dashboard → CRM Ultra Sales** จะเห็น KPI card + กราฟยอดขาย/Pipeline
หรือเปิด Workspace **CRM Ultra** จากแถบซ้าย จะเห็นทุกอย่างรวมกันเป็นภาษาไทย

## UX/UI ไทย
- **ฟอนต์ Sarabun**: โหลดอัตโนมัติผ่าน `app_include_css` (เห็นผลหลัง `bench build`)
- **คำแปลไทย**: อยู่ใน `crm_ultra/translations/th.csv` (มีผลเมื่อภาษา = ไทย)
- **ตั้งค่าระบบ**: `install.py` ตั้งภาษาไทย/โซนเวลา Asia/Bangkok/วันที่ dd/mm/yyyy ให้อัตโนมัติตอนติดตั้ง
  (ปรับภายหลังได้ที่ **System Settings**)
- **ฟอนต์ใน PDF**: ติดตั้งฟอนต์ Sarabun บนเซิร์ฟเวอร์เพื่อให้ wkhtmltopdf เรนเดอร์ภาษาไทยสวย
  เช่น `sudo apt install fonts-thai-tlwg`

## ปรับแต่งต่อ
- เกณฑ์อนุมัติ (ตอนนี้ = ส่วนลด > 10%): แก้ที่ **Workflow → CRM Ultra Quotation Approval → Transitions → condition**
- รูปแบบใบเสนอราคา: แก้ที่ **Print Format → CRM Ultra Quotation TH**
- เลขเอกสาร: แก้ที่ **Customize Form → Quotation → naming_series**

## โครงสร้างไฟล์
```
crm_ultra/
├── pyproject.toml              # metadata + dependency (frappe, erpnext)
├── README.md
└── crm_ultra/
    ├── hooks.py                # ลงทะเบียน fixtures + scheduler
    ├── install.py              # after_install
    ├── tasks.py                # งานแจ้งเตือนใบเสนอราคาหมดอายุ
    ├── modules.txt             # โมดูล "CRM Ultra"
    └── fixtures/
        ├── custom_field.json           # ฟิลด์ลูกค้า/ช่องทาง/segment
        ├── property_setter.json        # เลขเอกสารไทย
        ├── workflow.json               # Approve Center
        ├── workflow_state.json
        ├── workflow_action_master.json
        └── print_format.json           # ใบเสนอราคาภาษาไทย
```
