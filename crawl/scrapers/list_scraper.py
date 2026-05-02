# scrapers/list_scraper.py
import asyncio
from playwright.async_api import async_playwright
from config import SCRAPER_CONFIG


async def get_product_urls(page_url: str, label: str = "") -> list[str]:
    """
    Cào danh sách URL sản phẩm từ một trang listing (brand hoặc product line).
    Bấm nút "Xem thêm" nhiều lần cho đến khi hết.

    Hỗ trợ 3 layout HTML:
      Layout A (smartphone, laptop, tablet):
        - Product: .product-info-container a.product__link
        - Xem thêm: a.btn-show-more
      Layout B (headphone):
        - Product: .product-info a[href]
        - Xem thêm: a/button chứa "Xem thêm"
      Layout C (smartwatch):
        - Product: div.product-item > a[href]
        - Xem thêm: span[data-slot="button"] chứa "Xem thêm"
    """
    urls = []

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
            await page.goto(page_url, timeout=SCRAPER_CONFIG["timeout"])
            await asyncio.sleep(2)

            # Chờ sản phẩm load — thử nhiều layout
            product_loaded = False
            for selector in [
                ".product-info-container",         # Layout A
                "div.product-item",                 # Layout C (smartwatch)
                ".product-info",                    # Layout B
            ]:
                try:
                    await page.wait_for_selector(selector, timeout=5000)
                    product_loaded = True
                    break
                except Exception:
                    continue

            if not product_loaded:
                print(f"      [{label}] Không tìm thấy sản phẩm")
                await browser.close()
                return urls

            # Bấm "Xem thêm" cho đến khi hết
            click_count = 0
            while True:
                # Scroll xuống để nút "Xem thêm" hiện ra
                await page.evaluate(
                    "window.scrollTo(0, document.body.scrollHeight)"
                )
                await asyncio.sleep(1)

                # Tìm nút "Xem thêm" — thử nhiều selector cho các layout khác nhau
                show_more = None
                for btn_selector in [
                    "a.btn-show-more",                               # Layout A
                    "button.btn-show-more",                          # Layout A variant
                    'span[data-slot="button"]:has-text("Xem thêm")', # Layout C (smartwatch)
                    "a:has-text('Xem thêm')",                        # Generic
                    "button:has-text('Xem thêm')",                   # Generic
                ]:
                    try:
                        show_more = await page.query_selector(btn_selector)
                        if show_more:
                            break
                    except Exception:
                        continue

                if not show_more:
                    break

                # Kiểm tra nút còn hiển thị không
                try:
                    is_visible = await show_more.is_visible()
                    if not is_visible:
                        break
                except Exception:
                    break

                try:
                    await show_more.click()
                    click_count += 1
                    print(f"      [{label}] Đã bấm 'Xem thêm' lần {click_count}")
                    await asyncio.sleep(SCRAPER_CONFIG["delay_between_pages"])
                except Exception:
                    break

            # Scroll lần cuối để load hết
            await page.evaluate(
                "window.scrollTo(0, document.body.scrollHeight)"
            )
            await asyncio.sleep(1)

            # Lấy tất cả link sản phẩm — hỗ trợ cả 3 layout
            urls = await page.evaluate("""
                () => {
                    const seen = new Set();
                    const results = [];

                    // Layout A: .product-info-container a.product__link
                    let links = document.querySelectorAll(
                        '.product-info-container a.product__link'
                    );

                    // Layout C: div.product-item > a[href] (smartwatch)
                    if (links.length === 0) {
                        links = document.querySelectorAll(
                            'div.product-item > a[href]'
                        );
                    }

                    // Layout B: .product-info a[href]
                    if (links.length === 0) {
                        links = document.querySelectorAll(
                            '.product-info a[href]'
                        );
                    }

                    for (const a of links) {
                        const h = a.href;
                        if (h && h.includes('cellphones.com.vn')
                              && h.endsWith('.html')
                              && !h.includes('/mobile.')
                              && !h.includes('/laptop.')
                              && !h.includes('/tablet.')
                              && !h.includes('/tai-nghe.')
                              && !h.includes('/dong-ho-thong-minh.')
                              && !h.includes('/do-choi-cong-nghe.')
                              && !h.includes('/thiet-bi-am-thanh.')
                              && !seen.has(h)) {
                            seen.add(h);
                            results.push(h);
                        }
                    }
                    return results;
                }
            """)

        except Exception as e:
            print(f"      [{label}] ❌ Lỗi: {e}")
        finally:
            await browser.close()

    # Deduplicate (đề phòng)
    urls = list(dict.fromkeys(urls))
    print(f"      [{label}] ✅ Tổng {len(urls)} URL sản phẩm")
    return urls