#!/bin/bash
set -e

echo "=========================================="
echo "🚀 TechShop Backend - Deploy Script"
echo "=========================================="

cd "$(dirname "$0")"

# Parse arguments
IMPORT_DB=false
for arg in "$@"; do
    case $arg in
        --import-db)
            IMPORT_DB=true
            ;;
    esac
done

echo ""
echo "🔄 [1/6] Pulling latest code..."
git pull origin web/admin

echo ""
echo "🏗️  [2/6] Building & restarting containers..."
docker compose -f docker-compose.prod.yml up -d --build

echo ""
echo "⏳ [3/6] Waiting for database to be ready..."
sleep 8

# Import database nếu có flag --import-db
if [ "$IMPORT_DB" = true ]; then
    echo ""
    echo "📥 [4/6] Importing database from backup..."
    
    # Tìm file backup mới nhất
    BACKUP_FILE=$(ls -t database/*.sql.gz 2>/dev/null | head -1)
    if [ -z "$BACKUP_FILE" ]; then
        BACKUP_FILE=$(ls -t database/*.sql 2>/dev/null | head -1)
    fi
    
    if [ -n "$BACKUP_FILE" ]; then
        source .env
        DB_USER="${POSTGRES_USER:-postgres}"
        DB_NAME="${POSTGRES_DB:-techshop}"
        
        echo "   📦 File: $BACKUP_FILE"
        echo "   📋 Database: $DB_NAME | User: $DB_USER"
        
        if [[ "$BACKUP_FILE" == *.gz ]]; then
            gunzip -c "$BACKUP_FILE" | docker compose -f docker-compose.prod.yml exec -T postgres psql -U "$DB_USER" -d "$DB_NAME"
        else
            docker compose -f docker-compose.prod.yml exec -T postgres psql -U "$DB_USER" -d "$DB_NAME" < "$BACKUP_FILE"
        fi
        echo "   ✅ Import database thành công!"
    else
        echo "   ⚠️  Không tìm thấy file backup trong database/. Bỏ qua import."
    fi
else
    echo ""
    echo "📦 [4/6] Running database migrations..."
    docker compose -f docker-compose.prod.yml exec -T backend alembic upgrade head
fi

echo ""
echo "🧹 [5/6] Cleaning up old Docker images..."
docker image prune -f

echo ""
echo "=========================================="
echo "✅ [6/6] Deploy complete!"
echo "=========================================="
echo ""
docker compose -f docker-compose.prod.yml ps
echo ""
echo "📋 View logs: docker compose -f docker-compose.prod.yml logs -f backend"
echo ""
echo "💡 Tip: Lần deploy đầu có data, dùng: ./deploy.sh --import-db"
echo "   Các lần sau chỉ cần:                 ./deploy.sh"
