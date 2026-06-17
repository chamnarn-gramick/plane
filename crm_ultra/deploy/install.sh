#!/usr/bin/env bash
#
# install.sh — ติดตั้ง ERPNext + แอป crm_ultra แบบอัตโนมัติ (native, ไม่ใช้ Docker)
#
# รองรับสภาพแวดล้อมที่ไม่มี systemd และมี proxy ที่ใช้ CA ของตัวเอง
# (เช่น คอนเทนเนอร์ cloud) ออกแบบให้รันซ้ำได้ (idempotent)
#
# วิธีใช้ (รันด้วย root หรือผู้ใช้ที่ sudo ได้):
#   sudo bash install.sh
#
# ปรับแต่งผ่าน environment variables (มีค่าเริ่มต้นให้):
#   SITE_NAME=crm.local ADMIN_PASSWORD=admin DB_ROOT_PASSWORD=root \
#   SEED_DEMO=1 bash install.sh
#
set -euo pipefail

# ---------- ค่าปรับแต่งได้ ----------
BENCH_USER="${BENCH_USER:-frappe}"
BENCH_HOME="${BENCH_HOME:-/opt/bench}"
BENCH_NAME="${BENCH_NAME:-frappe-bench}"
SITE_NAME="${SITE_NAME:-crm.local}"
ADMIN_PASSWORD="${ADMIN_PASSWORD:-admin}"
DB_ROOT_PASSWORD="${DB_ROOT_PASSWORD:-root}"
FRAPPE_BRANCH="${FRAPPE_BRANCH:-version-15}"
SEED_DEMO="${SEED_DEMO:-0}"
SKIP_BUILD="${SKIP_BUILD:-0}"

# ข้อมูลบริษัทสำหรับ setup wizard
COMPANY_NAME="${COMPANY_NAME:-Demo Co}"
COMPANY_ABBR="${COMPANY_ABBR:-DEMO}"
COUNTRY="${COUNTRY:-Thailand}"
CURRENCY="${CURRENCY:-THB}"
TIMEZONE="${TIMEZONE:-Asia/Bangkok}"
FY_START="${FY_START:-$(date +%Y)-01-01}"
FY_END="${FY_END:-$(date +%Y)-12-31}"

# ที่มาของแอป crm_ultra: ถ้าตั้ง APP_GIT_URL จะ clone จาก git; ไม่งั้นใช้โฟลเดอร์ในรีโปนี้
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
APP_DIR="${APP_DIR:-$(cd "$SCRIPT_DIR/.." && pwd)}"   # = โฟลเดอร์ crm_ultra
APP_GIT_URL="${APP_GIT_URL:-}"
APP_GIT_BRANCH="${APP_GIT_BRANCH:-}"

CA_BUNDLE="/etc/ssl/certs/ca-certificates.crt"
BENCH_PATH="$BENCH_HOME/$BENCH_NAME"

log()  { printf '\n\033[1;36m[install]\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33m[warn]\033[0m %s\n' "$*"; }
die()  { printf '\033[1;31m[error]\033[0m %s\n' "$*" >&2; exit 1; }
trap 'die "ล้มเหลวที่บรรทัด $LINENO"' ERR

[ "$(id -u)" = "0" ] || die "กรุณารันด้วย root (sudo bash install.sh)"

# env สำหรับให้ uv / node / requests / git เชื่อ CA ของระบบ (รวม proxy CA)
BENCH_ENV="export UV_SYSTEM_CERTS=1 NODE_EXTRA_CA_CERTS=$CA_BUNDLE REQUESTS_CA_BUNDLE=$CA_BUNDLE SSL_CERT_FILE=$CA_BUNDLE GIT_SSL_CAINFO=$CA_BUNDLE;"

# รันคำสั่งในฐานะ BENCH_USER พร้อม env ที่ถูกต้อง
run_bench() { sudo -u "$BENCH_USER" bash -lc "$BENCH_ENV cd $BENCH_PATH && $*"; }
run_user()  { sudo -u "$BENCH_USER" bash -lc "$BENCH_ENV $*"; }

# ============================================================
log "1/11 ติดตั้ง system dependencies (apt)"
# ปิด PPA ที่อาจถูกบล็อก เพื่อให้ apt update ผ่าน
for f in $(grep -rlE "launchpadcontent|deadsnakes|ondrej" /etc/apt/sources.list.d/ 2>/dev/null || true); do
  warn "ปิด PPA ที่อาจบล็อก: $f"; mv "$f" "$f.disabled" 2>/dev/null || true
done
export DEBIAN_FRONTEND=noninteractive
apt-get update -y
apt-get install -y --no-install-recommends \
  mariadb-server mariadb-client libmariadb-dev pkg-config build-essential \
  redis-server cron git curl ca-certificates \
  wkhtmltopdf xfonts-75dpi xfonts-base fonts-thai-tlwg \
  python3 python3-dev python3-venv python3-pip

# Node (ต้องการ >=18) — แจ้งเตือนถ้าเวอร์ชันต่ำไป
if command -v node >/dev/null 2>&1; then
  NODE_MAJOR="$(node -p 'process.versions.node.split(".")[0]')"
  [ "$NODE_MAJOR" -ge 18 ] || warn "Node เวอร์ชัน $NODE_MAJOR ต่ำกว่า 18 อาจ build assets ไม่ผ่าน"
else
  die "ไม่พบ Node.js — กรุณาติดตั้ง Node 18+ (เช่นผ่าน nvm) ก่อน"
fi
command -v yarn >/dev/null 2>&1 || npm install -g yarn

# ============================================================
log "2/11 ตั้งค่า MariaDB (utf8mb4) + เริ่มบริการ"
cat > /etc/mysql/mariadb.conf.d/99-frappe.cnf <<'EOF'
[mysqld]
character-set-client-handshake = FALSE
character-set-server = utf8mb4
collation-server = utf8mb4_unicode_ci

[mysql]
default-character-set = utf8mb4
EOF

mkdir -p /var/run/mysqld && chown mysql:mysql /var/run/mysqld
if ! mysqladmin ping >/dev/null 2>&1; then
  log "เริ่ม MariaDB ผ่าน mysqld_safe (สภาพแวดล้อมไม่มี systemd)"
  ( mysqld_safe --user=mysql >/tmp/mariadb.log 2>&1 & )
  for i in $(seq 1 30); do mysqladmin ping >/dev/null 2>&1 && break; sleep 1; done
  mysqladmin ping >/dev/null 2>&1 || die "เริ่ม MariaDB ไม่สำเร็จ (ดู /tmp/mariadb.log)"
fi

log "3/11 ตั้งรหัสผ่าน root ของ MariaDB"
if mysql -u root -p"$DB_ROOT_PASSWORD" -e "SELECT 1" >/dev/null 2>&1; then
  log "root password ถูกตั้งไว้แล้ว — ข้าม"
else
  mysql -u root <<SQL
ALTER USER 'root'@'localhost' IDENTIFIED BY '$DB_ROOT_PASSWORD';
CREATE USER IF NOT EXISTS 'root'@'127.0.0.1' IDENTIFIED BY '$DB_ROOT_PASSWORD';
GRANT ALL PRIVILEGES ON *.* TO 'root'@'127.0.0.1' WITH GRANT OPTION;
FLUSH PRIVILEGES;
SQL
fi

# ============================================================
log "4/11 เตรียมผู้ใช้ $BENCH_USER และ frappe-bench"
id "$BENCH_USER" >/dev/null 2>&1 || useradd -m -s /bin/bash "$BENCH_USER"
mkdir -p "$BENCH_HOME" && chown -R "$BENCH_USER:$BENCH_USER" "$BENCH_HOME"

# persist env ของ proxy CA ให้ผู้ใช้ bench (เผื่อใช้ bench ภายหลัง)
PROFILE="/home/$BENCH_USER/.profile"
grep -q UV_SYSTEM_CERTS "$PROFILE" 2>/dev/null || cat >> "$PROFILE" <<EOF
export UV_SYSTEM_CERTS=1
export NODE_EXTRA_CA_CERTS=$CA_BUNDLE
export REQUESTS_CA_BUNDLE=$CA_BUNDLE
export SSL_CERT_FILE=$CA_BUNDLE
export GIT_SSL_CAINFO=$CA_BUNDLE
EOF
chown "$BENCH_USER:$BENCH_USER" "$PROFILE"

# bench CLI + deps ที่ bench ต้องใช้ (jinja2/requests ต้องอยู่ใน global site)
command -v bench >/dev/null 2>&1 || pip install --break-system-packages frappe-bench
PIP_USER=0 pip install --break-system-packages jinja2 requests >/dev/null 2>&1 || true

# ============================================================
log "5/11 bench init (frappe $FRAPPE_BRANCH)"
if [ -d "$BENCH_PATH/apps/frappe" ]; then
  log "พบ frappe-bench อยู่แล้ว — ข้าม bench init"
else
  run_user "cd $BENCH_HOME && bench init --frappe-branch $FRAPPE_BRANCH --skip-assets --python python3 $BENCH_NAME"
fi

# เริ่ม redis ของ bench (cache 11000 / queue 13000) ที่จำเป็นตอน migrate
run_bench "redis-server config/redis_cache.conf --daemonize yes" || true
run_bench "redis-server config/redis_queue.conf --daemonize yes" || true
sleep 2

# ============================================================
log "6/11 ติดตั้งแอป erpnext และ crm_ultra เข้า bench"
if [ ! -d "$BENCH_PATH/apps/erpnext" ]; then
  run_bench "bench get-app --branch $FRAPPE_BRANCH --skip-assets erpnext"
else
  log "พบ erpnext อยู่แล้ว — ข้าม"
fi

if [ ! -d "$BENCH_PATH/apps/crm_ultra" ]; then
  # เตรียม source ของ crm_ultra ให้ bench get-app
  CRM_SRC="$BENCH_HOME/crm_ultra_src"
  rm -rf "$CRM_SRC"
  if [ -n "$APP_GIT_URL" ]; then
    run_user "git clone ${APP_GIT_BRANCH:+--branch $APP_GIT_BRANCH} $APP_GIT_URL $CRM_SRC.git && cp -r $CRM_SRC.git/crm_ultra $CRM_SRC 2>/dev/null || cp -r $CRM_SRC.git $CRM_SRC"
  else
    cp -r "$APP_DIR" "$CRM_SRC"
  fi
  chown -R "$BENCH_USER:$BENCH_USER" "$CRM_SRC"
  # bench get-app ต้องการ git repo
  run_user "cd $CRM_SRC && (git rev-parse --git-dir >/dev/null 2>&1 || (git init -q && git add -A && git -c commit.gpgsign=false -c user.email=deploy@local -c user.name=deploy commit -qm 'crm_ultra'))"
  run_bench "bench get-app --skip-assets $CRM_SRC"
else
  log "พบ crm_ultra อยู่แล้ว — ข้าม"
fi

# ============================================================
log "7/11 สร้าง site $SITE_NAME"
if [ -d "$BENCH_PATH/sites/$SITE_NAME" ]; then
  log "พบ site $SITE_NAME อยู่แล้ว — ข้าม new-site"
else
  run_bench "bench new-site $SITE_NAME --mariadb-root-password $DB_ROOT_PASSWORD --admin-password $ADMIN_PASSWORD --mariadb-user-host-login-scope='%'"
fi

log "8/11 ติดตั้ง erpnext + crm_ultra ลง site แล้ว migrate"
run_bench "bench --site $SITE_NAME install-app erpnext" || true
run_bench "bench --site $SITE_NAME install-app crm_ultra" || true
run_bench "bench --site $SITE_NAME migrate"

# ============================================================
log "9/11 ตั้งค่าเริ่มต้น (Company / Setup Wizard)"
SETUP_PY="$BENCH_HOME/_setup.py"
cat > "$SETUP_PY" <<PY
import frappe, traceback
frappe.flags.in_setup_wizard = True
# กันกรณี custom field ของ ERPNext ไม่ครบ (เช่นติดตั้งสะดุด)
try:
    from erpnext.setup.install import create_address_and_contact_custom_fields as _f
    _f(); frappe.db.commit()
except Exception:
    pass
if not frappe.db.get_value("Company", {}, "name"):
    from frappe.desk.page.setup_wizard.setup_wizard import setup_complete
    args = {
        "language": "English", "country": "$COUNTRY", "currency": "$CURRENCY",
        "timezone": "$TIMEZONE", "company_name": "$COMPANY_NAME",
        "company_abbr": "$COMPANY_ABBR", "chart_of_accounts": "Standard",
        "fy_start_date": "$FY_START", "fy_end_date": "$FY_END",
        "full_name": "Admin User", "email": "admin@example.com",
    }
    try:
        setup_complete(args); frappe.db.commit()
        print("SETUP_OK", frappe.db.get_value("Company", {}, "name"))
    except Exception:
        print("SETUP_ERR"); traceback.print_exc()
else:
    print("SETUP_SKIP")
PY
chown "$BENCH_USER:$BENCH_USER" "$SETUP_PY"
run_bench "echo \"exec(open('$SETUP_PY').read())\" | bench --site $SITE_NAME console" 2>&1 | tr '\r' '\n' | grep -aE "SETUP_OK|SETUP_ERR|SETUP_SKIP" || true

# ============================================================
if [ "$SKIP_BUILD" = "1" ]; then
  log "10/11 ข้าม bench build (SKIP_BUILD=1)"
else
  log "10/11 build assets (ใช้เวลาสักครู่)"
  run_bench "bench build"
fi

# ============================================================
log "11/11 ตั้งค่าเพิ่มเติม"
# ตั้งค่า LINE secret ตัวอย่าง (เปลี่ยนภายหลังได้)
run_bench "bench --site $SITE_NAME set-config line_channel_secret change_me_line_secret" >/dev/null 2>&1 || true
run_bench "bench --site $SITE_NAME enable-scheduler" >/dev/null 2>&1 || true

if [ "$SEED_DEMO" = "1" ]; then
  log "ใส่ข้อมูลตัวอย่าง (demo)"
  SEED_PY="$BENCH_HOME/_seed.py"
  echo "import crm_ultra.demo as d; d.make_demo_data()" > "$SEED_PY"
  chown "$BENCH_USER:$BENCH_USER" "$SEED_PY"
  run_bench "echo \"exec(open('$SEED_PY').read())\" | bench --site $SITE_NAME console" 2>&1 | tr '\r' '\n' | grep -aE "ลูกค้า|Lead|ใบแจ้งหนี้|error" || true
fi

cat <<DONE

============================================================
 ✅ ติดตั้งเสร็จเรียบร้อย
============================================================
 Bench : $BENCH_PATH
 Site  : $SITE_NAME
 Login : Administrator / $ADMIN_PASSWORD

 เริ่มเซิร์ฟเวอร์:
   sudo bash $SCRIPT_DIR/start.sh
   # หรือ:  sudo -u $BENCH_USER bash -lc 'cd $BENCH_PATH && bench start'

 เปิด: http://$SITE_NAME:8000  (เพิ่มใน /etc/hosts: 127.0.0.1 $SITE_NAME)
       หรือ http://localhost:8000

 ใส่ข้อมูลตัวอย่าง:
   sudo -u $BENCH_USER bash -lc 'cd $BENCH_PATH && echo "import crm_ultra.demo as d; d.make_demo_data()" | bench --site $SITE_NAME console'
============================================================
DONE
