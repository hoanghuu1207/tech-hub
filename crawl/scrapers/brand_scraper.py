# scrapers/brand_scraper.py
import asyncio
from playwright.async_api import async_playwright
from config import SCRAPER_CONFIG


async def get_brands(category: str, list_url: str) -> list[dict]:
    """
    Cào danh sách brand từ trang category.
    Mỗi brand gồm: name, url.

    Hỗ trợ 2 layout HTML khác nhau:
      Layout A (smartphone, laptop, tablet):
        - Container: .block-filter-brands > .brands__content .list-brand a.list-brand__item
        - Name: img[alt]
      Layout B (headphone, smartwatch):
        - Container: .grid a[href] có chứa img[alt]
        - Name: img[alt]
    """
    brands = []

    async with async_playwright() as p:
        browser = await p.chromium.launch(
            headless=SCRAPER_CONFIG["headless"]
        )
        page = await browser.new_page()

        await page.set_extra_http_headers({
            "User-Agent": "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) "
                          "AppleWebKit/537.36 (KHTML, like Gecko) "
                          "Chrome/120.0.0.0 Safari/537.36",
            "Accept-Language": "vi-VN,vi;q=0.9",
        })

        try:
            await page.goto(list_url, timeout=SCRAPER_CONFIG["timeout"])
            await asyncio.sleep(2)

            # Thử cả 2 layout, ưu tiên Layout A trước
            brands = await page.evaluate("""
                () => {
                    const seen = new Set();
                    const results = [];

                    // ── Layout A: smartphone, laptop, tablet ──
                    // .block-filter-brands > .brands__content .list-brand a
                    let items = document.querySelectorAll(
                        '.block-filter-brands > .brands__content .list-brand a.list-brand__item'
                    );

                    // ── Layout B: headphone, smartwatch ──
                    // Grid layout với Tailwind: .grid a chứa img
                    if (items.length === 0) {
                        items = document.querySelectorAll(
                            '.grid.grid-cols-3 > a[href]'
                        );
                    }

                    for (const a of items) {
                        const img = a.querySelector('img');
                        const name = img ? img.alt.trim() : '';
                        const url = a.href;
                        if (name && url && !seen.has(url)) {
                            seen.add(url);
                            results.push({ name, url });
                        }
                    }
                    return results;
                }
            """)

            print(f"  📋 Tìm thấy {len(brands)} brand cho [{category}]:")
            for b in brands:
                print(f"     - {b['name']}: {b['url']}")

        except Exception as e:
            print(f"  ❌ Lỗi khi cào brand cho {category}: {e}")
        finally:
            await browser.close()

    return brands


async def get_product_lines(brand_name: str, brand_url: str) -> list[dict]:
    """
    Cào danh sách product line từ trang brand.
    Mỗi product line gồm: name, url.

    Hỗ trợ 2 layout HTML:
      Layout A: .block-filter-brands > .brands__content .list-brand a
        - Name: span innerText
      Layout B: .grid a[href] có chứa img[alt]
        - Name: img[alt]
    """
    product_lines = []

    async with async_playwright() as p:
        browser = await p.chromium.launch(
            headless=SCRAPER_CONFIG["headless"]
        )
        page = await browser.new_page()

        await page.set_extra_http_headers({
            "User-Agent": "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) "
                          "AppleWebKit/537.36 (KHTML, like Gecko) "
                          "Chrome/120.0.0.0 Safari/537.36",
            "Accept-Language": "vi-VN,vi;q=0.9",
        })

        try:
            await page.goto(brand_url, timeout=SCRAPER_CONFIG["timeout"])
            await asyncio.sleep(2)

            product_lines = await page.evaluate("""
                () => {
                    const seen = new Set();
                    const results = [];

                    // ── Layout A: smartphone, laptop, tablet ──
                    let items = document.querySelectorAll(
                        '.block-filter-brands > .brands__content .list-brand a.list-brand__item'
                    );

                    if (items.length > 0) {
                        // Layout A: product line name ở <span>
                        for (const a of items) {
                            const span = a.querySelector('span');
                            const name = span ? span.innerText.trim() : '';
                            const url = a.href;
                            if (name && url && !seen.has(url)) {
                                seen.add(url);
                                results.push({ name, url });
                            }
                        }
                    } else {
                        // ── Layout B: headphone, smartwatch ──
                        items = document.querySelectorAll(
                            '.grid.grid-cols-3 > a[href]'
                        );
                        for (const a of items) {
                            const img = a.querySelector('img');
                            const name = img ? img.alt.trim() : '';
                            const url = a.href;
                            if (name && url && !seen.has(url)) {
                                seen.add(url);
                                results.push({ name, url });
                            }
                        }
                    }

                    return results;
                }
            """)

            if product_lines:
                print(f"    📋 Tìm thấy {len(product_lines)} product line cho [{brand_name}]:")
                for pl in product_lines:
                    print(f"       - {pl['name']}: {pl['url']}")
            else:
                print(f"    ℹ️  Không có product line cho {brand_name}")

        except Exception as e:
            print(f"    ❌ Lỗi khi cào product line cho {brand_name}: {e}")
        finally:
            await browser.close()

    return product_lines
