#!/bin/bash
# =============================================================
# Import Database vào VPS Docker Container
# Chạy trên VPS sau khi containers đã khởi động
# =============================================================
set -e

BACKUP_DIR="$(dirname "$0")/../database"
COMPOSE_FILE="$(dirname "$0")/../docker-compose.prod.yml"

echo "=========================================="
echo "📥 TechShop - Import Database"
echo "=========================================="

# Tìm file backup mới nhất
echo ""
echo "📋 Các file backup có sẵn:"
ls -lh "$BACKUP_DIR"/*.sql.gz "$BACKUP_DIR"/*.sql 2>/dev/null || true

# Tự động chọn file .sql.gz mới nhất, hoặc .sql mới nhất
BACKUP_FILE=$(ls -t "$BACKUP_DIR"/*.sql.gz 2>/dev/null | head -1)
if [ -z "$BACKUP_FILE" ]; then
    BACKUP_FILE=$(ls -t "$BACKUP_DIR"/*.sql 2>/dev/null | head -1)
fi

if [ -z "$BACKUP_FILE" ]; then
    echo "❌ Không tìm thấy file backup trong thư mục: $BACKUP_DIR"
    echo "   Hãy copy file backup vào thư mục database/ trước."
    exit 1
fi

echo ""
echo "📦 Sử dụng file: $BACKUP_FILE"
echo ""

# Lấy thông tin DB từ .env
source "$(dirname "$0")/../.env"
DB_USER="${POSTGRES_USER:-postgres}"
DB_NAME="${POSTGRES_DB:-techshop}"

echo "📋 Database: $DB_NAME"
echo "📋 User:     $DB_USER"
echo ""

# Xác nhận
read -p "⚠️  Thao tác này sẽ GHI ĐÈ toàn bộ dữ liệu hiện tại. Tiếp tục? (y/N): " confirm
if [[ "$confirm" != "y" && "$confirm" != "Y" ]]; then
    echo "❌ Đã huỷ."
    exit 0
fi

echo ""
echo "⏳ Đang import database..."

# Import dựa trên đuôi file
if [[ "$BACKUP_FILE" == *.gz ]]; then
    gunzip -c "$BACKUP_FILE" | docker compose -f "$COMPOSE_FILE" exec -T postgres psql -U "$DB_USER" -d "$DB_NAME"
else
    docker compose -f "$COMPOSE_FILE" exec -T postgres psql -U "$DB_USER" -d "$DB_NAME" < "$BACKUP_FILE"
fi

echo ""
echo "=========================================="
echo "✅ Import database thành công!"
echo "=========================================="
echo ""
echo "📌 Kiểm tra dữ liệu:"
echo "   docker compose -f docker-compose.prod.yml exec postgres psql -U $DB_USER -d $DB_NAME -c '\\dt'"
