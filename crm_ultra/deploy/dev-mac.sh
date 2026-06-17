#!/usr/bin/env bash
#
# dev-mac.sh — ติดตั้ง ERPNext + แอป crm_ultra สำหรับ "dev" บน macOS (Homebrew)
#
# รันบนเครื่อง Mac ของคุณ (Apple Silicon หรือ Intel) — ไม่ต้องใช้ sudo/root
# (รันในฐานะผู้ใช้ปกติของคุณ)
#
# วิธีใช้:
#   cd <โฟลเดอร์รีโป plane>
#   bash crm_ultra/deploy/dev-mac.sh
#   # พร้อมข้อมูลตัวอย่าง:  SEED_DEMO=1 bash crm_ultra/deploy/dev-mac.sh
#
set -euo pipefail

# ---------- ค่าปรับแต่งได้ ----------
BENCH_DIR="${BENCH_DIR:-$HOME/frappe-bench}"
SITE_NAME="${SITE_NAME:-crm.localhost}"     # *.localhost ชี้ 127.0.0.1 บน Mac อยู่แล้ว
ADMIN_PASSWORD="${ADMIN_PASSWORD:-admin}"
DB_ROOT_PASSWORD="${DB_ROOT_PASSWORD:-root}"
FRAPPE_BRANCH="${FRAPPE_BRANCH:-version-15}"
PY_VER="${PY_VER:-3.11}"
NODE_VER="${NODE_VER:-20}"
SEED_DEMO="${SEED_DEMO:-0}"
SKIP_BUILD="${SKIP_BUILD:-0}"

COMPANY_NAME="${COMPANY_NAME:-Demo Co}"
COMPANY_ABBR="${COMPANY_ABBR:-DEMO}"
COUNTRY="${COUNTRY:-Thailand}"
CURRENCY="${CURRENCY:-THB}"
TIMEZONE="${TIMEZONE:-Asia/Bangkok}"
FY_START="${FY_START:-$(date +%Y)-01-01}"
FY_END="${FY_END:-$(date +%Y)-12-31}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
APP_DIR="${APP_DIR:-$(cd "$SCRIPT_DIR/.." && pwd)}"   # = โฟลเดอร์ crm_ultra

log()  { printf '\n\033[1;36m[dev-mac]\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33m[warn]\033[0m %s\n' "$*"; }
die()  { printf '\033[1;31m[error]\033[0m %s\n' "$*" >&2; exit 1; }
trap 'die "ล้มเหลวที่บรรทัด $LINENO"' ERR

[ "$(uname)" = "Darwin" ] || die "สคริปต์นี้สำหรับ macOS เท่านั้น (ใช้ install.sh สำหรับ Linux)"
[ "$(id -u)" != "0" ]     || die "อย่ารันด้วย sudo — รันในฐานะผู้ใช้ปกติของคุณ"
command -v brew >/dev/null 2>&1 || die "ไม่พบ Homebrew — ติดตั้งก่อนที่ https://brew.sh"

BREW_PREFIX="$(brew --prefix)"

# ============================================================
log "1/10 ติดตั้ง dependencies ผ่าน Homebrew"
brew install "python@${PY_VER}" "node@${NODE_VER}" yarn git redis mariadb
# ใส่ node@xx ใน PATH ของ shell นี้ (เป็น keg-only)
export PATH="$BREW_PREFIX/opt/node@${NODE_VER}/bin:$BREW_PREFIX/opt/python@${PY_VER}/bin:$PATH"
command -v yarn >/dev/null 2>&1 || npm install -g yarn
# wkhtmltopdf ถูกถอดออกจาก Homebrew core แล้ว -> ติดตั้งแยก (ไม่บังคับ; ใช้พิมพ์ PDF เท่านั้น)
if ! command -v wkhtmltopdf >/dev/null 2>&1; then
  warn "ไม่พบ wkhtmltopdf (Homebrew ถอดออกแล้ว) — ข้ามได้ ระบบ dev ใช้งานได้ปกติ ยกเว้นการพิมพ์ PDF"
  warn "ต้องการ PDF ภายหลัง? โหลด .pkg จาก https://wkhtmltopdf.org/downloads.html มาติดตั้ง"
fi

PYBIN="$BREW_PREFIX/opt/python@${PY_VER}/bin/python${PY_VER}"
[ -x "$PYBIN" ] || PYBIN="$(command -v python3)"

# ============================================================
log "2/10 ตั้งค่า MariaDB (utf8mb4) + เริ่มบริการ"
MYCNF="$BREW_PREFIX/etc/my.cnf"
if ! grep -q "character-set-server = utf8mb4" "$MYCNF" 2>/dev/null; then
  cat >> "$MYCNF" <<'EOF'

# ---- added by crm_ultra dev-mac.sh ----
[mysqld]
character-set-client-handshake = FALSE
character-set-server = utf8mb4
collation-server = utf8mb4_unicode_ci

[mysql]
default-character-set = utf8mb4
EOF
fi
brew services start mariadb
brew services start redis
# รอ MariaDB พร้อม
for i in $(seq 1 30); do "$BREW_PREFIX/bin/mysqladmin" ping >/dev/null 2>&1 && break; sleep 1; done

log "3/10 ตั้งรหัสผ่าน root ของ MariaDB"
if mysql -u root -p"$DB_ROOT_PASSWORD" -e "SELECT 1" >/dev/null 2>&1; then
  log "root password ถูกตั้งไว้แล้ว — ข้าม"
else
  mysql -u root <<SQL || warn "ตั้งรหัส root ไม่สำเร็จ (อาจตั้งไว้แล้ว)"
ALTER USER 'root'@'localhost' IDENTIFIED BY '$DB_ROOT_PASSWORD';
FLUSH PRIVILEGES;
SQL
fi

# ============================================================
log "4/10 ติดตั้ง frappe-bench"
command -v bench >/dev/null 2>&1 || "$PYBIN" -m pip install --user frappe-bench
export PATH="$HOME/Library/Python/${PY_VER}/bin:$HOME/.local/bin:$PATH"
command -v bench >/dev/null 2>&1 || die "ติดตั้ง bench แล้วแต่ไม่อยู่ใน PATH — เพิ่ม ~/Library/Python/${PY_VER}/bin ใน PATH"

# ============================================================
log "5/10 bench init (frappe $FRAPPE_BRANCH)"
if [ -d "$BENCH_DIR/apps/frappe" ]; then
  log "พบ bench อยู่แล้ว — ข้าม init"
else
  bench init --frappe-branch "$FRAPPE_BRANCH" --python "$PYBIN" "$BENCH_DIR"
fi
cd "$BENCH_DIR"

# เริ่ม redis ของ bench (cache/queue) ที่จำเป็นตอน migrate
redis-server config/redis_cache.conf --daemonize yes 2>/dev/null || true
redis-server config/redis_queue.conf --daemonize yes 2>/dev/null || true
sleep 2

# ============================================================
log "6/10 ดึงแอป erpnext + เชื่อมแอป crm_ultra (โหมด dev = symlink)"
[ -d "$BENCH_DIR/apps/erpnext" ] || bench get-app --branch "$FRAPPE_BRANCH" erpnext
if [ ! -e "$BENCH_DIR/apps/crm_ultra" ]; then
  # โหมด dev: symlink โฟลเดอร์แอปจากรีโปที่คุณ clone เข้ามาใน bench
  # → แก้โค้ดในรีโป (เช่น ~/Desktop/webjs/crm-saas/crm_ultra) แล้วมีผลทันที + push กลับได้
  log "เชื่อม (symlink) $APP_DIR -> $BENCH_DIR/apps/crm_ultra"
  ln -s "$APP_DIR" "$BENCH_DIR/apps/crm_ultra"
  "$BENCH_DIR/env/bin/python" -m pip install -q -e "$BENCH_DIR/apps/crm_ultra"
  grep -qxF crm_ultra "$BENCH_DIR/sites/apps.txt" 2>/dev/null || echo "crm_ultra" >> "$BENCH_DIR/sites/apps.txt"
fi

# ============================================================
log "7/10 สร้าง site $SITE_NAME + ติดตั้งแอป"
if [ ! -d "$BENCH_DIR/sites/$SITE_NAME" ]; then
  bench new-site "$SITE_NAME" --mariadb-root-password "$DB_ROOT_PASSWORD" \
    --admin-password "$ADMIN_PASSWORD" --mariadb-user-host-login-scope='%'
fi
bench --site "$SITE_NAME" install-app erpnext || true
bench --site "$SITE_NAME" install-app crm_ultra || true
bench --site "$SITE_NAME" migrate

# ============================================================
log "8/10 ตั้งค่าเริ่มต้น (Company / Setup Wizard)"
SETUP_PY="$BENCH_DIR/_setup.py"
cat > "$SETUP_PY" <<PY
import frappe, traceback
frappe.flags.in_setup_wizard = True
try:
    from erpnext.setup.install import create_address_and_contact_custom_fields as _f
    _f(); frappe.db.commit()
except Exception:
    pass
if not frappe.db.get_value("Company", {}, "name"):
    from frappe.desk.page.setup_wizard.setup_wizard import setup_complete
    args = {"language":"English","country":"$COUNTRY","currency":"$CURRENCY",
            "timezone":"$TIMEZONE","company_name":"$COMPANY_NAME","company_abbr":"$COMPANY_ABBR",
            "chart_of_accounts":"Standard","fy_start_date":"$FY_START","fy_end_date":"$FY_END",
            "full_name":"Admin User","email":"admin@example.com"}
    try:
        setup_complete(args); frappe.db.commit(); print("SETUP_OK")
    except Exception:
        print("SETUP_ERR"); traceback.print_exc()
else:
    print("SETUP_SKIP")
PY
echo "exec(open('$SETUP_PY').read())" | bench --site "$SITE_NAME" console 2>&1 \
  | tr '\r' '\n' | grep -aE "SETUP_OK|SETUP_ERR|SETUP_SKIP" || true

# ============================================================
if [ "$SKIP_BUILD" = "1" ]; then
  log "9/10 ข้าม bench build"
else
  log "9/10 build assets"
  bench build
fi

log "10/10 ตั้งค่าเพิ่มเติม"
bench --site "$SITE_NAME" set-config line_channel_secret change_me_line_secret >/dev/null 2>&1 || true
bench --site "$SITE_NAME" enable-scheduler >/dev/null 2>&1 || true
# ให้ bench รู้จัก site นี้เป็นค่าเริ่มต้น
bench use "$SITE_NAME" >/dev/null 2>&1 || true

if [ "$SEED_DEMO" = "1" ]; then
  log "ใส่ข้อมูลตัวอย่าง (demo)"
  echo "import crm_ultra.demo as d; d.make_demo_data()" | bench --site "$SITE_NAME" console 2>&1 \
    | tr '\r' '\n' | grep -aE "ลูกค้า|Lead|ใบแจ้งหนี้" || true
fi

cat <<DONE

============================================================
 ✅ ติดตั้งเสร็จเรียบร้อย (macOS dev)
============================================================
 Bench : $BENCH_DIR
 Site  : $SITE_NAME
 Login : Administrator / $ADMIN_PASSWORD

 เริ่ม dev server:
   cd $BENCH_DIR && bench start

 เปิดเบราว์เซอร์:  http://$SITE_NAME:8000

 --- dev loop (แก้โค้ดในรีโปของคุณ) ---
 แอปถูก symlink ไว้:  $BENCH_DIR/apps/crm_ultra  ->  $APP_DIR
   • แก้ไฟล์ Python      -> bench restart (หรือ dev server รีโหลดให้เอง)
   • แก้ fixtures/*.json -> bench --site $SITE_NAME migrate
   • แก้ JS/CSS          -> bench build
   • commit/push         -> ทำในโฟลเดอร์รีโป (เช่น ~/Desktop/webjs/crm-saas)
============================================================
DONE
