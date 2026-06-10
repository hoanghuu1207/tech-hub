#!/bin/bash
# =============================================================
# Export Database từ Local Docker Container
# Chạy trên MÁY LOCAL (trong Git Bash / WSL / Linux terminal)
# =============================================================
set -e

CONTAINER_NAME="techshop_postgres"
DB_NAME="techshop"
DB_USER="postgres"
BACKUP_DIR="$(dirname "$0")/../database"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
BACKUP_FILE="$BACKUP_DIR/techshop_backup_${TIMESTAMP}.sql"

mkdir -p "$BACKUP_DIR"

echo "=========================================="
echo "📦 TechShop - Export Database"
echo "=========================================="
echo ""
echo "📋 Container: $CONTAINER_NAME"
echo "📋 Database:  $DB_NAME"
echo "📋 User:      $DB_USER"
echo ""

# Export full database (schema + data)
echo "⏳ Đang export database..."
docker exec -t "$CONTAINER_NAME" pg_dump \
  -U "$DB_USER" \
  -d "$DB_NAME" \
  --clean \
  --if-exists \
  --no-owner \
  --no-privileges \
  > "$BACKUP_FILE"

# Tạo bản nén
gzip -k "$BACKUP_FILE"

FILE_SIZE=$(du -h "$BACKUP_FILE" | cut -f1)
GZ_SIZE=$(du -h "${BACKUP_FILE}.gz" | cut -f1)

echo ""
echo "=========================================="
echo "✅ Export thành công!"
echo "=========================================="
echo "📁 File SQL:  $BACKUP_FILE ($FILE_SIZE)"
echo "📁 File GZ:   ${BACKUP_FILE}.gz ($GZ_SIZE)"
echo ""
echo "📌 Bước tiếp theo:"
echo "   1. Copy file lên VPS:"
echo "      scp ${BACKUP_FILE}.gz deploy@YOUR_VPS_IP:~/apps/backend/database/"
echo ""
echo "   2. Import trên VPS:"
echo "      cd ~/apps/backend && bash scripts/import_db.sh"
