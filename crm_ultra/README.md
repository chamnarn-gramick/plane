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
