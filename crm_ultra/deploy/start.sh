#!/usr/bin/env bash
#
# start.sh — เริ่ม MariaDB + Redis + เซิร์ฟเวอร์ Frappe/ERPNext
# สำหรับสภาพแวดล้อมที่ไม่มี systemd (เช่นคอนเทนเนอร์)
#
set -euo pipefail

BENCH_USER="${BENCH_USER:-frappe}"
BENCH_HOME="${BENCH_HOME:-/opt/bench}"
BENCH_NAME="${BENCH_NAME:-frappe-bench}"
BENCH_PATH="$BENCH_HOME/$BENCH_NAME"
CA_BUNDLE="/etc/ssl/certs/ca-certificates.crt"
BENCH_ENV="export UV_SYSTEM_CERTS=1 NODE_EXTRA_CA_CERTS=$CA_BUNDLE REQUESTS_CA_BUNDLE=$CA_BUNDLE SSL_CERT_FILE=$CA_BUNDLE;"

[ "$(id -u)" = "0" ] || { echo "กรุณารันด้วย root"; exit 1; }

# MariaDB
mkdir -p /var/run/mysqld && chown mysql:mysql /var/run/mysqld
if ! mysqladmin ping >/dev/null 2>&1; then
  echo "เริ่ม MariaDB..."
  ( mysqld_safe --user=mysql >/tmp/mariadb.log 2>&1 & )
  for i in $(seq 1 30); do mysqladmin ping >/dev/null 2>&1 && break; sleep 1; done
fi
echo "MariaDB: $(mysqladmin ping 2>&1 | head -1)"

# เริ่มทั้ง stack ด้วย bench start (จัดการ web/socketio/redis/worker/scheduler เอง)
echo "เริ่ม bench start ที่ $BENCH_PATH ..."
exec sudo -u "$BENCH_USER" bash -lc "$BENCH_ENV cd $BENCH_PATH && bench start"
