# main.py
import asyncio, json, os, glob, re
from config import CATEGORY_URLS, SCRAPER_CONFIG
from scrapers.brand_scraper   import get_brands, get_product_lines
from scrapers.list_scraper    import get_product_urls
from scrapers.detail_scraper  import scrape_product
from transformers.specs_normalizer import normalize_specs
# from exporters.postgres_exporter import save_to_postgres
# from exporters.qdrant_exporter   import index_to_qdrant


def load_scraped_urls(raw_dir: str) -> set[str]:
    """Đọc tất cả file JSON trong data/raw/, lấy trường 'url' để skip."""
    scraped = set()
    for filepath in glob.glob(os.path.join(raw_dir, "*.json")):
        try:
            with open(filepath, "r", encoding="utf-8") as f:
                data = json.load(f)
                url = data.get("url")
                if url:
                    scraped.add(url)
        except Exception:
            pass
    return scraped


def url_to_slug(url: str) -> str:
    """Chuyển URL thành slug để dùng làm tên file.
    Ví dụ: https://cellphones.com.vn/iphone-17-pro-max.html → iphone-17-pro-max
    """
    # Lấy phần path cuối, bỏ .html
    slug = url.rstrip("/").split("/")[-1]
    slug = re.sub(r"\.html$", "", slug)
    # Chỉ giữ ký tự an toàn
    slug = re.sub(r"[^\w\-]", "_", slug)
    return slug


async def run():
    all_products = []
    raw_dir = "data/raw"

    # Đảm bảo thư mục data/raw tồn tại
    os.makedirs(raw_dir, exist_ok=True)

    # ── Load danh sách URL đã cào trước đó ──────────────────────
    scraped_urls = load_scraped_urls(raw_dir)
    if scraped_urls:
        print(f"📂 Tìm thấy {len(scraped_urls)} sản phẩm đã cào trước đó, sẽ bỏ qua.")
    else:
        print("📂 Chưa có dữ liệu cũ, cào từ đầu.")

    skipped = 0
    new_count = 0

    for category, cfg in CATEGORY_URLS.items():
        print(f"\n{'='*60}")
        print(f"🔍 Đang cào category: {category}")
        print(f"{'='*60}")

        # 1. Lấy danh sách brand từ trang category
        brands = await get_brands(category, cfg["list_url"])
        if not brands:
            print(f"  ⚠️ Không tìm thấy brand nào cho {category}, bỏ qua.")
            continue

        # 2. Duyệt từng brand
        for brand in brands:
            brand_name = brand["name"]
            brand_url  = brand["url"]
            print(f"\n  🏷️  Brand: {brand_name}")
            print(f"     URL: {brand_url}")

            # 3. Lấy danh sách product line từ trang brand
            product_lines = await get_product_lines(brand_name, brand_url)

            # 4. Xây dựng mapping {product_url: product_line_name}
            #    bằng cách visit từng trang product line và lấy URLs
            pl_mapping = {}  # url → product_line_name
            for pl in product_lines:
                pl_name = pl["name"]
                pl_url  = pl["url"]
                print(f"\n    📦 Product Line: {pl_name}")

                pl_product_urls = await get_product_urls(
                    pl_url,
                    label=f"{category}/{brand_name}/{pl_name}"
                )
                for url in pl_product_urls:
                    pl_mapping[url] = pl_name

                # Delay lịch sự giữa các request
                await asyncio.sleep(SCRAPER_CONFIG["delay_between_requests"])

            print(f"\n    🗺️  Đã map {len(pl_mapping)} product URL → product line")

            # 5. Lấy TẤT CẢ product URLs từ trang brand (superset)
            #    Bao gồm cả product không thuộc product line nào
            print(f"\n    📥 Đang lấy tất cả sản phẩm từ brand {brand_name}...")
            all_brand_urls = await get_product_urls(
                brand_url,
                label=f"{category}/{brand_name}"
            )

            if not all_brand_urls:
                print(f"    ⚠️ Không tìm thấy sản phẩm nào cho {brand_name}")
                continue

            # 6. Cào từng sản phẩm
            for i, url in enumerate(all_brand_urls):
                # ── Skip nếu đã cào trước đó ────────────────────
                if url in scraped_urls:
                    skipped += 1
                    print(f"    [{i+1}/{len(all_brand_urls)}] ⏭️  Đã có, bỏ qua: {url}")
                    continue

                # Tra cứu product_line từ mapping (None nếu không thuộc PL nào)
                product_line = pl_mapping.get(url, None)
                pl_display = product_line or "N/A"

                print(f"    [{i+1}/{len(all_brand_urls)}] "
                      f"[PL: {pl_display}] {url}")

                raw = await scrape_product(url, category)
                if not raw:
                    continue

                # Gán brand + product_line
                raw["brand"] = brand_name
                raw["product_line"] = product_line

                # 7. Chuẩn hóa specs
                raw["specs"] = normalize_specs(
                    raw.get("specs", {}), category
                )

                all_products.append(raw)
                new_count += 1

                # Lưu raw JSON — filename dựa trên URL slug (deterministic)
                slug = url_to_slug(url)
                filepath = os.path.join(raw_dir, f"{category}_{slug}.json")
                with open(filepath, "w", encoding="utf-8") as f:
                    json.dump(raw, f, ensure_ascii=False, indent=2)

                # Thêm vào set để không cào trùng trong cùng run
                scraped_urls.add(url)

                # Delay lịch sự
                await asyncio.sleep(SCRAPER_CONFIG["delay_between_requests"])

    print(f"\n{'='*60}")
    print(f"✅ Tổng cào mới: {new_count} sản phẩm")
    print(f"⏭️  Đã bỏ qua: {skipped} sản phẩm (đã cào trước đó)")
    print(f"📊 Tổng tích lũy: {len(scraped_urls)} sản phẩm")
    print(f"{'='*60}")

    # # 4. Xuất vào PostgreSQL
    # print("\n💾 Đang lưu vào PostgreSQL...")
    # await save_to_postgres(all_products)

    # # 5. Xuất vào Qdrant
    # print("\n🔍 Đang index vào Qdrant...")
    # await index_to_qdrant(all_products)

    print("\n🎉 Hoàn thành!")

if __name__ == "__main__":
    asyncio.run(run())