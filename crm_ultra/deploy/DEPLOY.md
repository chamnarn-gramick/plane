# Deploy CRM Ultra (ERPNext)

ติดตั้ง ERPNext + แอป `crm_ultra` อัตโนมัติด้วยสคริปต์เดียว

## ตัวเลือก A — `install.sh` (native, แนะนำ)

ใช้ได้ทั้งบนเซิร์ฟเวอร์ปกติและคอนเทนเนอร์ที่ **ไม่มี systemd** หรือมี **proxy CA** เอง
(สคริปต์จัดการ workaround ให้หมด: ปิด PPA ที่บล็อก, ตั้ง utf8mb4, เริ่ม MariaDB ผ่าน
`mysqld_safe`, ตั้ง CA ให้ uv/node/requests, แก้ custom field ของ ERPNext, รัน setup wizard)

```bash
# รันด้วย root บน Ubuntu 22.04/24.04 (ต้องมี Node 18+ ติดตั้งไว้ก่อน)
sudo bash crm_ultra/deploy/install.sh

# พร้อมข้อมูลตัวอย่าง:
sudo SEED_DEMO=1 bash crm_ultra/deploy/install.sh
```

เริ่มเซิร์ฟเวอร์หลังติดตั้ง:
```bash
sudo bash crm_ultra/deploy/start.sh        # เริ่ม MariaDB + bench start
# เปิด http://localhost:8000  (login: Administrator / <ADMIN_PASSWORD>)
```

### ปรับแต่งผ่าน environment variables

| ตัวแปร | ค่าเริ่มต้น | ความหมาย |
|---|---|---|
| `SITE_NAME` | `crm.local` | ชื่อ site |
| `ADMIN_PASSWORD` | `admin` | รหัส Administrator |
| `DB_ROOT_PASSWORD` | `root` | รหัส root ของ MariaDB |
| `BENCH_USER` | `frappe` | ผู้ใช้ที่รัน bench |
| `BENCH_HOME` | `/opt/bench` | โฟลเดอร์ bench |
| `FRAPPE_BRANCH` | `version-15` | branch ของ frappe/erpnext |
| `SEED_DEMO` | `0` | `1` = ใส่ข้อมูลตัวอย่าง |
| `SKIP_BUILD` | `0` | `1` = ข้าม `bench build` |
| `APP_GIT_URL` | (ว่าง) | ถ้าตั้ง จะ clone crm_ultra จาก git แทนโฟลเดอร์ในรีโป |
| `COMPANY_NAME` / `COMPANY_ABBR` | `Demo Co` / `DEMO` | บริษัทเริ่มต้น |
| `COUNTRY` / `CURRENCY` / `TIMEZONE` | `Thailand` / `THB` / `Asia/Bangkok` | locale |

สคริปต์ **idempotent** — รันซ้ำได้ ข้ามขั้นตอนที่ทำไปแล้วโดยอัตโนมัติ

## ตัวเลือก A2 — `dev-mac.sh` (สำหรับ dev บน macOS)

รันบน **เครื่อง Mac ของคุณเอง** (Apple Silicon/Intel) ด้วย Homebrew — ไม่ต้อง sudo

```bash
# ต้องมี Homebrew ก่อน (https://brew.sh) แล้ว clone รีโปนี้ลงเครื่อง
cd <โฟลเดอร์รีโป plane>
bash crm_ultra/deploy/dev-mac.sh
# พร้อมข้อมูลตัวอย่าง:
SEED_DEMO=1 bash crm_ultra/deploy/dev-mac.sh

# เริ่ม dev server:
cd ~/frappe-bench && bench start
# เปิด http://crm.localhost:8000   (login: Administrator / admin)
```

สคริปต์จะ `brew install` python/node/redis/mariadb/wkhtmltopdf, ตั้ง utf8mb4,
เริ่มบริการผ่าน `brew services`, ติดตั้ง bench + erpnext + crm_ultra, สร้าง site,
รัน setup wizard และ build assets ให้อัตโนมัติ

> หมายเหตุ: `wkhtmltopdf` จาก Homebrew อาจไม่มี patched-Qt ทำให้ส่วนหัว/ท้ายกระดาษ
> ของ PDF เพี้ยนได้ — ตัวใบเสนอราคา/ใบกำกับภาษีของ crm_ultra ไม่ใช้ header/footer จึงใช้ได้ปกติ

## ตัวเลือก B — Docker

หากเซิร์ฟเวอร์ของคุณเข้าถึง Docker Hub ได้ (เครื่อง dev บางที่/คลาวด์บางที่บล็อก CDN ของ
registry) ให้ใช้ **official frappe_docker** ซึ่งดูแล stack เต็ม (db/redis/worker/scheduler):

```bash
git clone https://github.com/frappe/frappe_docker
cd frappe_docker
# ทำตาม docs/development.md เพื่อสร้าง bench แล้วทำขั้นตอนเดียวกับตัวเลือก A
# (get-app crm_ultra, install-app, migrate)
```

> เราเลือกไม่ shippping docker-compose เอง เพราะการประกอบ stack ERPNext ที่ถูกต้อง
> (configurator + create-site job) เปราะและเปลี่ยนตามเวอร์ชัน — ใช้ของ official ปลอดภัยกว่า

## ความต้องการขั้นต่ำ
- Ubuntu 22.04 / 24.04, สิทธิ์ root
- Node.js 18+ (ติดตั้งก่อนรันสคริปต์ เช่นผ่าน [nvm](https://github.com/nvm-sh/nvm))
- RAM ≥ 4 GB (แนะนำ 8 GB), ดิสก์ว่าง ≥ 10 GB

## ตรวจสอบหลังติดตั้ง
ดูเช็คลิสต์ทดสอบทุกฟีเจอร์ใน [`../TESTING.md`](../TESTING.md)
