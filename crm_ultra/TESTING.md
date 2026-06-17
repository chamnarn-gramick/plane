# วิธีทดสอบ CRM Ultra App

แอปนี้รันบน **Frappe/ERPNext** (คนละ stack กับ Plane) จึงต้องทดสอบบน Frappe Bench จริง
เอกสารนี้ให้ทางที่เร็วที่สุด 2 แบบ + เช็คลิสต์ทดสอบทุกฟีเจอร์

---

## ทางเลือก A — ติดตั้งด้วย Bench (ตรงไปตรงมาที่สุด)

ใช้ Ubuntu 22.04 (หรือ WSL2 บน Windows / Multipass บน Mac)

### 1) ติดตั้ง dependency
```bash
sudo apt update
sudo apt install -y python3-dev python3.11-venv python3-pip redis-server \
  mariadb-server libmysqlclient-dev wkhtmltopdf fonts-thai-tlwg git curl
# ติดตั้ง Node 18 + yarn
curl -fsSL https://deb.nodesource.com/setup_18.x | sudo -E bash -
sudo apt install -y nodejs && sudo npm install -g yarn
pip install frappe-bench
```

ตั้งค่า MariaDB ให้รองรับ utf8mb4 (ใส่ใน `/etc/mysql/my.cnf` แล้ว `sudo service mysql restart`):
```ini
[mysqld]
character-set-client-handshake = FALSE
character-set-server = utf8mb4
collation-server = utf8mb4_unicode_ci
[mysql]
default-character-set = utf8mb4
```

### 2) สร้าง bench + ติดตั้ง ERPNext
```bash
bench init --frappe-branch version-15 frappe-bench
cd frappe-bench
bench get-app --branch version-15 erpnext
bench new-site crm.local --admin-password admin --mariadb-root-password <รหัส-mariadb>
bench --site crm.local install-app erpnext
```

### 3) ติดตั้งแอป crm_ultra
```bash
# ดึงจาก git (branch ของเรา) — เอาเฉพาะโฟลเดอร์ crm_ultra
bench get-app https://github.com/chamnarn-gramick/plane \
  --branch claude/crm-system-requirements-xfhkxp
#   ↑ ถ้า get-app ไม่เจอ app ใน subfolder ให้ clone แล้วชี้ path:
#   git clone -b claude/crm-system-requirements-xfhkxp https://github.com/chamnarn-gramick/plane /tmp/plane
#   bench get-app /tmp/plane/crm_ultra

bench --site crm.local install-app crm_ultra
bench --site crm.local migrate          # โหลด fixtures ทั้งหมด
bench build                              # รวมไฟล์ CSS (ฟอนต์ไทย)
bench --site crm.local enable-scheduler  # เปิดงานแจ้งเตือนอัตโนมัติ
bench start
```

เปิดเบราว์เซอร์ → `http://crm.local:8000` (login: Administrator / admin)
> ถ้า DNS ไม่รู้จัก `crm.local` ให้เพิ่มใน `/etc/hosts`: `127.0.0.1 crm.local`

---

## ทางเลือก B — Docker (ไม่อยากลงเอง)

```bash
git clone https://github.com/frappe/frappe_docker
cd frappe_docker
# ใช้ devcontainer ตาม docs: https://github.com/frappe/frappe_docker/blob/main/docs/development.md
# จากใน container ทำขั้นตอนเดียวกับทางเลือก A ตั้งแต่ข้อ 2
```

---

## เช็คลิสต์ทดสอบทีละฟีเจอร์

### ✅ 1. Custom Fields (ฟิลด์ลูกค้าไทย)
- เปิด **Lead ใหม่** → ต้องเห็นฟิลด์ **ช่องทางที่มา (Channel)**, **LINE ID**, **กลุ่มลูกค้า (Segment)**
- เปิด **Customer / Opportunity** → เห็นฟิลด์ที่เกี่ยวข้องเช่นกัน

### ✅ 2. เลขเอกสารไทย
- เปิด **Quotation ใหม่** → ช่อง Series ต้องมีตัวเลือก `QU-.YY.-.MM.-.#####`
- บันทึก → เลขที่ควรเป็นรูปแบบ `QU-26-06-00001`

### ✅ 3. Approve Center (workflow อนุมัติ)
1. สร้าง Quotation ใส่ลูกค้า + สินค้า
2. ใส่ **Additional Discount Percentage = 15** (เกิน 10%)
3. บันทึก → ปุ่ม **Submit for Approval** ต้องโผล่ → สถานะเป็น *Pending Approval*
4. Login เป็น user ที่มี role **Sales Manager** → กด **Approve** → เอกสาร submit (docstatus=1)
5. ลองอีกใบ ใส่ส่วนลด 5% → ควรกด **Approve** ผ่านได้เลย (ไม่ต้องรออนุมัติ)

> สร้าง user ทดสอบ 2 คน: คนหนึ่ง role *Sales User*, อีกคน *Sales Manager*

### ✅ 4. Print Format ไทย
- เปิด Quotation → **Print** → เลือก **CRM Ultra Quotation TH** → ดูใบเสนอราคาภาษาไทย
- เปิด Sales Invoice → **Print** → **CRM Ultra Tax Invoice TH** → ดูใบกำกับภาษี
- กด **PDF** เพื่อเช็คว่าฟอนต์ไทยไม่กลายเป็นกล่อง (ต้องลง `fonts-thai-tlwg` แล้ว)

### ✅ 5. Dashboard + Workspace
- แถบซ้าย → เปิด Workspace **CRM Ultra** → เห็นปุ่มลัด + การ์ด KPI + กราฟ + เมนูจัดกลุ่ม (ภาษาไทย)
- เมนู **Dashboard → CRM Ultra Sales** → การ์ดยอดขาย/ดีล/Lead และกราฟแสดงผล
  (ต้องมีข้อมูลตัวอย่างก่อน ตัวเลขถึงจะขึ้น — ดูข้อ "ใส่ข้อมูลตัวอย่าง" ด้านล่าง)

> **ใส่ข้อมูลตัวอย่างให้ Dashboard มีตัวเลขทันที**
> ```bash
> bench --site crm.local execute crm_ultra.demo.make_demo_data
> ```
> สร้างลูกค้า/Lead/ดีล/ใบเสนอราคา/ใบแจ้งหนี้ตัวอย่าง (ทุกชื่อขึ้นต้น `[DEMO]`)
> รวมถึงใบเสนอราคารออนุมัติ 1 ใบ และใบใกล้หมดอายุ 2 ใบ
> ล้างทิ้งภายหลัง: `bench --site crm.local execute crm_ultra.demo.clear_demo_data`

### ✅ 6. แจ้งเตือนใบเสนอราคาหมดอายุ (scheduler)
ไม่ต้องรอครบวัน — สั่งรันฟังก์ชันตรงๆ:
```bash
# สร้าง Quotation ที่ submit แล้ว ตั้ง Valid Till = ภายใน 3 วันข้างหน้า ก่อน
bench --site crm.local execute crm_ultra.tasks.notify_expiring_quotations
```
ตรวจผล: เจ้าของเอกสารควรได้ **อีเมล** + มี **ToDo** งานติดตามถูกสร้าง
> ตั้งค่า SMTP ก่อน (Email Account / Settings) อีเมลถึงจะส่งจริง

### ✅ 7. LINE Webhook (สร้าง Lead อัตโนมัติ)
ใส่ secret ใน `sites/crm.local/site_config.json`:
```json
"line_channel_secret": "test_secret_123"
```
รัน `bench --site crm.local clear-cache` แล้วยิงคำขอจำลอง LINE:
```bash
SECRET="test_secret_123"
BODY='{"events":[{"type":"message","source":{"userId":"Utest00001"},"message":{"type":"text","text":"สนใจสินค้าครับ"}}]}'
SIG=$(printf '%s' "$BODY" | openssl dgst -sha256 -hmac "$SECRET" -binary | base64)

curl -X POST http://crm.local:8000/api/method/crm_ultra.api.line.webhook \
  -H "Content-Type: application/json" \
  -H "X-Line-Signature: $SIG" \
  -d "$BODY"
```
ผลที่คาด: ตอบ `{"message": {"status": "ok", "leads_created": 1}}`
→ ไปดูที่ **Lead list** จะมี Lead ใหม่ ช่องทาง = LINE, LINE ID = Utest00001, มี comment "สนใจสินค้าครับ"
- ยิงซ้ำด้วย userId เดิม → ต้อง **ไม่สร้างซ้ำ** (`leads_created: 0`)
- ยิงด้วย signature ผิด → ต้องถูกปฏิเสธ (error)

### ✅ 8. ตั้งค่าไทย + ฟอนต์
- เมนู **System Settings** → ภาษา = ไทย, Time Zone = Asia/Bangkok, Date Format = dd/mm/yyyy
- ทั้ง UI ควรขึ้นฟอนต์ Sarabun (หลัง `bench build` + refresh แบบ hard reload)

---

## ทดสอบเร็วผ่าน console (ไม่ต้องคลิก)
```bash
bench --site crm.local console
```
```python
import frappe
# fixtures โหลดครบไหม
frappe.db.exists("Custom Field", "Lead-crm_channel")        # -> 'Lead-crm_channel'
frappe.db.exists("Workflow", "CRM Ultra Quotation Approval") # -> ชื่อ workflow
frappe.db.exists("Print Format", "CRM Ultra Quotation TH")
frappe.db.exists("Workspace", "CRM Ultra")
frappe.db.exists("Dashboard", "CRM Ultra Sales")
frappe.db.get_single_value("System Settings", "time_zone")   # -> 'Asia/Bangkok'
```

---

## แก้ปัญหาที่พบบ่อย
| อาการ | วิธีแก้ |
|---|---|
| ฟิลด์/workflow ไม่ขึ้น | รัน `bench --site crm.local migrate` ซ้ำ + `clear-cache` |
| ฟอนต์ไม่เปลี่ยน | `bench build` แล้ว hard reload (Ctrl+Shift+R) |
| PDF ไทยเป็นกล่อง | `sudo apt install fonts-thai-tlwg` แล้วรีสตาร์ท |
| อีเมลไม่ส่ง | ตั้ง Email Account (SMTP) ใน ERPNext |
| Workspace ว่าง | เช็คว่า number cards/charts ถูก import (migrate) แล้ว |
