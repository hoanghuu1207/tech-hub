# scrapers/detail_scraper.py
import asyncio, json, re
from playwright.async_api import async_playwright, Page
from config import SCRAPER_CONFIG

async def scrape_product(url: str, category: str) -> dict | None:
    """Cào toàn bộ thông tin 1 trang sản phẩm."""

    async with async_playwright() as p:
        browser = await p.chromium.launch(
            headless=SCRAPER_CONFIG["headless"]
        )
        page = await browser.new_page()
        await page.set_extra_http_headers({
            "User-Agent": "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) "
                          "AppleWebKit/537.36 Chrome/120.0.0.0 Safari/537.36",
            "Accept-Language": "vi-VN,vi;q=0.9",
        })

        try:
            # domcontentloaded + chờ element cụ thể
            # (networkidle bị timeout vì CellphoneS liên tục gọi analytics)
            await page.goto(url, timeout=SCRAPER_CONFIG["timeout"],
                            wait_until="domcontentloaded")

            # Đợi Vue render xong nội dung sản phẩm
            try:
                await page.wait_for_selector("h1", timeout=10000)
            except Exception:
                pass

            # Đợi phần specs section xuất hiện
            try:
                await page.wait_for_selector(
                    ".box-specifi, .product-technical, .box-product-specification",
                    timeout=10000
                )
            except Exception:
                pass

            await asyncio.sleep(2)

            # ── Mở modal thông số kỹ thuật ─────────────────────────────
            modal_opened = False
            try:
                btn = await page.wait_for_selector(
                    '.box-specifi button, '
                    '.product-technical button, '
                    'button:has-text("Xem tất cả"), '
                    'button:has-text("Xem thêm cấu hình")',
                    timeout=8000
                )
                if btn:
                    await btn.click()
                    await asyncio.sleep(1)
                    # Chờ đúng selector mà ta sẽ extract
                    try:
                        await page.wait_for_selector(
                            '.teleport-modal_main .teleport-modal_content table',
                            timeout=8000
                        )
                        modal_opened = True
                    except Exception:
                        pass
            except Exception:
                pass

            data = await page.evaluate("""
                (args) => {
                    const [url, modalOpened] = args;

                    const getText = (sel) => {
                        const el = document.querySelector(sel);
                        return el ? el.innerText.trim() : null;
                    };
                    
                    const name = getText('h1.product-title, h1.product-name, h1');
                    
                    // Price logic
                    const priceEl = document.querySelector('.box-product-price .sale-price');
                    const price = priceEl 
                        ? parseInt(priceEl.innerText.match(/\\d[\\d\\.]*/)?.[0].replace(/\\./g, '')) 
                        : null;
                    
                    const salePriceEl = document.querySelector('.box-product-price .base-price');
                    const sale_price = salePriceEl 
                        ? parseInt(salePriceEl.innerText.match(/\\d[\\d\\.]*/)?.[0].replace(/\\./g, '')) 
                        : null;

                    // Options/Colors
                    const colors = [...document.querySelectorAll('.storage-item, .color-item, [class*="product-option"] span, .box-product-variants .box-content .list-variants .item-variant .item-variant-name')]
                        .map(e => e.innerText.trim())
                        .filter(c => c && c.length < 50);

                    // Images - uu tiên lấy từ thẻ a.spotlight (chứa link gốc chất lượng cao, không bị ảnh hưởng bởi lazy-load)
                    const imgLinks = [
                        ...[...document.querySelectorAll('.box-gallery .gallery-slide a.spotlight')].map(a => a.href),
                        ...[...document.querySelectorAll('.box-gallery img')].map(i => i.src || i.dataset?.src)
                    ];
                    
                    const images = [...new Set(
                        imgLinks.filter(s => s && s.includes('cdn2') && !s.includes('placehoder.png') && !s.includes('placeholder'))
                    )].slice(0, 10);

                    // ── Technical specs ────────────────────────────────
                    const specs = {};
                    
                    // 1) Ưu tiên: lấy từ modal (đầy đủ nhất)
                    let specRows = document.querySelectorAll(
                        '.teleport-modal_main .teleport-modal_content table tr'
                    );
                    
                    // 2) Fallback: lấy từ bảng rút gọn trên trang
                    if (specRows.length === 0) {
                        specRows = document.querySelectorAll(
                            '.box-specifi table tr, ' +
                            '.product-technical table tr, ' +
                            '.specifications table tr, ' +
                            '.box-product-specification table tr'
                        );
                    }
                    
                    specRows.forEach(row => {
                        const cells = row.querySelectorAll('td, th, p');
                        if (cells.length >= 2) {
                            const key = cells[0].innerText.trim();
                            // Lấy ô cuối cùng (chứa giá trị), do đôi khi CellphoneS render cấu trúc HTML lồng nhau
                            const val = cells[cells.length - 1].innerText.trim();
                            if (key && val && key !== val) {
                                specs[key] = val;
                            }
                        }
                    });

                    const features = [...document.querySelectorAll('.ksp-item, .highlight-item, .product-usps li')]
                        .map(e => e.innerText.trim());

                    const description = getText('.product-description, .description');
                    const ratingEl = document.querySelector('.rating-result span, .stars-value');
                    const ratingCountEl = document.querySelector('.rating-count, .review-count');

                    return {
                        name,
                        price,
                        sale_price,
                        colors,
                        images,
                        specs,
                        spec_count: Object.keys(specs).length,
                        features,
                        description,
                        rating: ratingEl ? parseFloat(ratingEl.innerText) : null,
                        rating_count: ratingCountEl ? parseInt(ratingCountEl.innerText.replace(/[^0-9]/g, '')) : 0,
                        url
                    };
                }
            """, [url, modal_opened])

            # ── Retry: nếu specs trống và chưa mở được modal, thử lại 1 lần ──
            if data.get("spec_count", 0) == 0 and not modal_opened:
                print(f"      ⚠️ Specs trống, thử lại...")
                await asyncio.sleep(2)

                # Thử click lại nút mở modal
                try:
                    btn = await page.query_selector(
                        '.box-specifi button, '
                        '.product-technical button, '
                        'button:has-text("Xem tất cả")'
                    )
                    if btn and await btn.is_visible():
                        await btn.click()
                        await asyncio.sleep(1.5)
                        await page.wait_for_selector(
                            '.teleport-modal_main .teleport-modal_content table',
                            timeout=8000
                        )
                        await asyncio.sleep(1)

                        # Extract lại specs
                        retry_specs = await page.evaluate("""
                            () => {
                                const specs = {};
                                let specRows = document.querySelectorAll(
                                    '.teleport-modal_main .teleport-modal_content table tr'
                                );
                                if (specRows.length === 0) {
                                    specRows = document.querySelectorAll(
                                        '.box-specifi table tr, ' +
                                        '.product-technical table tr, ' +
                                        '.specifications table tr, ' +
                                        '.box-product-specification table tr'
                                    );
                                }
                                specRows.forEach(row => {
                                    const cells = row.querySelectorAll('td, th, p');
                                    if (cells.length >= 2) {
                                        const key = cells[0].innerText.trim();
                                        const val = cells[cells.length - 1].innerText.trim();
                                        if (key && val && key !== val) {
                                            specs[key] = val;
                                        }
                                    }
                                });
                                return specs;
                            }
                        """)
                        if retry_specs and len(retry_specs) > 0:
                            data["specs"] = retry_specs
                            data["spec_count"] = len(retry_specs)
                            print(f"      ✅ Retry thành công: {len(retry_specs)} specs")
                except Exception:
                    pass

            # Xóa trường tạm spec_count
            data.pop("spec_count", None)

            data["category"] = category
            data["status"] = "new"
            return data

        except Exception as e:
            print(f"  ❌ Lỗi cào {url}: {e}")
            return None
        finally:
            await browser.close()