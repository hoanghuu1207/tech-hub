"""
Qdrant Cloud Collection Setup
Khởi tạo collection 'products' trên Qdrant Cloud với vector config
và payload indexes để hỗ trợ filter hiệu quả.
"""

from qdrant_client.models import (
    VectorParams, Distance, PayloadSchemaType
)

# Import qdrant_client đã cấu hình sẵn từ app
from app.db.qdrant import qdrant_client


def setup_products_collection():
    """
    Tạo collection 'products' trên Qdrant Cloud.
    - Vector size: 1536 (tương thích text-embedding-3-small của OpenAI)
    - Distance: COSINE (chuẩn cho semantic search)
    """
    collection_name = "products"

    # Kiểm tra nếu collection đã tồn tại
    existing = [c.name for c in qdrant_client.get_collections().collections]
    if collection_name in existing:
        print(f"[INFO] Collection '{collection_name}' already exists. Skipping creation.")
    else:
        qdrant_client.create_collection(
            collection_name=collection_name,
            vectors_config=VectorParams(
                size=1536,                # text-embedding-3-small
                distance=Distance.COSINE
            )
        )
        print(f"[OK] Created collection '{collection_name}'.")

    # ────────────────────────────────────────────────────────────
    # Payload Indexes — tăng tốc filter mà không cần full scan
    # ────────────────────────────────────────────────────────────
    payload_indexes = [
        ("category_slug", PayloadSchemaType.KEYWORD),
        ("brand_slug",    PayloadSchemaType.KEYWORD),
        ("line_slug",     PayloadSchemaType.KEYWORD),
        ("status",        PayloadSchemaType.KEYWORD),
        ("base_price",    PayloadSchemaType.FLOAT),
        ("sale_price",    PayloadSchemaType.FLOAT),
        ("rating_avg",    PayloadSchemaType.FLOAT),
        ("sold_count",    PayloadSchemaType.INTEGER),
        ("is_active",     PayloadSchemaType.BOOL),
        ("ram_gb",        PayloadSchemaType.INTEGER),
        ("storage_gb",    PayloadSchemaType.INTEGER),
        ("screen_size",   PayloadSchemaType.FLOAT),
    ]

    for field_name, schema_type in payload_indexes:
        try:
            qdrant_client.create_payload_index(
                collection_name=collection_name,
                field_name=field_name,
                field_schema=schema_type,
            )
            print(f"  [OK] Index created: {field_name} ({schema_type})")
        except Exception as e:
            # Qdrant trả lỗi nếu index đã tồn tại — bỏ qua
            if "already exists" in str(e).lower():
                print(f"  [SKIP] Index already exists: {field_name}")
            else:
                print(f"  [ERROR] Failed to create index {field_name}: {e}")

    print("\n[DONE] Qdrant setup complete.")


if __name__ == "__main__":
    setup_products_collection()
