"""
TechHub Benchmark Test Script
=============================
Đo thời gian phản hồi API thực tế và đánh giá chất lượng tìm kiếm ngữ nghĩa.
Chạy: python scripts/benchmark_test.py
"""

import requests
import time
import json
import sys

BASE_URL = "http://localhost:8000/api/v1"

# ─── Test account ───
TEST_EMAIL = "benchmark@test.com"
TEST_PASSWORD = "test123456"
TEST_NAME = "Benchmark User"
TEST_PHONE = "0900000099"

# ─── Colors for terminal output ───
GREEN = "\033[92m"
YELLOW = "\033[93m"
RED = "\033[91m"
CYAN = "\033[96m"
RESET = "\033[0m"
BOLD = "\033[1m"


def print_header(title):
    print(f"\n{BOLD}{CYAN}{'='*60}")
    print(f"  {title}")
    print(f"{'='*60}{RESET}\n")


def print_result(name, elapsed_ms, status_code, extra=""):
    color = GREEN if elapsed_ms < 500 else YELLOW if elapsed_ms < 3000 else RED
    print(f"  {color}[{elapsed_ms:>7.1f}ms]{RESET}  {status_code}  {name}  {extra}")


def measure_request(method, url, **kwargs):
    """Measure request time and return (response, elapsed_ms)."""
    start = time.perf_counter()
    try:
        resp = requests.request(method, url, timeout=30, **kwargs)
        elapsed = (time.perf_counter() - start) * 1000
        return resp, elapsed
    except Exception as e:
        elapsed = (time.perf_counter() - start) * 1000
        return None, elapsed


def get_auth_token():
    """Login or register test user, return JWT token."""
    # Try login first
    resp, _ = measure_request("POST", f"{BASE_URL}/auth/login", json={
        "email": TEST_EMAIL, "password": TEST_PASSWORD
    })
    if resp and resp.status_code == 200:
        data = resp.json()
        # StandardResponse format: {success, message, data: {access_token, ...}}
        token = (data.get("data") or {}).get("access_token") or data.get("access_token")
        if token:
            return token

    # Register if not exists
    resp, _ = measure_request("POST", f"{BASE_URL}/auth/register", json={
        "email": TEST_EMAIL, "password": TEST_PASSWORD,
        "full_name": TEST_NAME, "phone": TEST_PHONE
    })
    if resp and resp.status_code in (200, 201):
        data = resp.json()
        token = (data.get("data") or {}).get("access_token") or data.get("access_token")
        if token:
            return token
        # Try login again
        resp, _ = measure_request("POST", f"{BASE_URL}/auth/login", json={
            "email": TEST_EMAIL, "password": TEST_PASSWORD
        })
        if resp and resp.status_code == 200:
            data2 = resp.json()
            return (data2.get("data") or {}).get("access_token") or data2.get("access_token")
    return None


def test_api_performance(token):
    """Test 1: Đo thời gian phản hồi các API chính."""
    print_header("TEST 1: API PERFORMANCE (Thời gian phản hồi)")

    headers = {"Authorization": f"Bearer {token}"} if token else {}
    results = []

    # 1. Auth - Login
    resp, ms = measure_request("POST", f"{BASE_URL}/auth/login", json={
        "email": TEST_EMAIL, "password": TEST_PASSWORD
    })
    print_result("POST /auth/login", ms, resp.status_code if resp else "ERR")
    results.append(("Auth (đăng nhập)", ms))

    # 2. Catalog - Categories
    resp, ms = measure_request("GET", f"{BASE_URL}/catalog/categories")
    print_result("GET /catalog/categories", ms, resp.status_code if resp else "ERR")
    results.append(("Catalog (danh mục)", ms))

    # 3. Catalog - Products list
    resp, ms = measure_request("GET", f"{BASE_URL}/catalog/products?limit=20", headers=headers)
    products_data = resp.json() if resp and resp.status_code == 200 else {}
    # Could be {items: []} or {data: {items: []}} or direct list
    items_list = products_data.get("items") or (products_data.get("data") or {}).get("items") or []
    product_count = len(items_list)
    print_result("GET /catalog/products", ms, resp.status_code if resp else "ERR", f"({product_count} items)")
    results.append(("Catalog (danh sách SP)", ms))

    # 4. Catalog - Product detail (get first product)
    product_id = None
    if resp and resp.status_code == 200:
        items = items_list
        if items:
            product_id = items[0].get("id") or items[0].get("product_id")

    if product_id:
        resp2, ms2 = measure_request("GET", f"{BASE_URL}/catalog/products/{product_id}")
        print_result("GET /catalog/products/:id", ms2, resp2.status_code if resp2 else "ERR")
        results.append(("Product Detail", ms2))

    # 5. Cart - Get
    if token:
        resp, ms = measure_request("GET", f"{BASE_URL}/cart", headers=headers)
        print_result("GET /cart", ms, resp.status_code if resp else "ERR")
        results.append(("Cart (xem giỏ)", ms))

    # 6. Orders - Get
    if token:
        resp, ms = measure_request("GET", f"{BASE_URL}/orders", headers=headers)
        print_result("GET /orders", ms, resp.status_code if resp else "ERR")
        results.append(("Orders (danh sách)", ms))

    return results, product_id


def test_semantic_search(token):
    """Test 2: Đánh giá tìm kiếm ngữ nghĩa AI."""
    print_header("TEST 2: SEMANTIC SEARCH (Tìm kiếm ngữ nghĩa AI)")

    headers = {"Authorization": f"Bearer {token}"} if token else {}

    test_queries = [
        {
            "query": "laptop gaming dưới 20 triệu",
            "expected_category": "laptop",
            "expected_keywords": ["gaming", "laptop"],
            "description": "Truy vấn NLP cơ bản"
        },
        {
            "query": "điện thoại chụp ảnh đẹp pin trâu",
            "expected_category": "smartphone",
            "expected_keywords": ["điện thoại", "phone"],
            "description": "Truy vấn NLP mô tả tính năng"
        },
        {
            "query": "tai nghe chống ồn",
            "expected_category": "headphone",
            "expected_keywords": ["tai nghe", "headphone", "noise"],
            "description": "Truy vấn NLP ngắn"
        },
        {
            "query": "ip 15 pro max",
            "expected_category": "smartphone",
            "expected_keywords": ["iphone", "15", "pro"],
            "description": "Tiếng lóng / viết tắt"
        },
        {
            "query": "máy tính bảng cho trẻ em",
            "expected_category": "tablet",
            "expected_keywords": ["tablet", "máy tính bảng", "ipad"],
            "description": "Truy vấn NLP ngữ cảnh"
        },
        {
            "query": "đồng hồ thông minh theo dõi sức khỏe",
            "expected_category": "smartwatch",
            "expected_keywords": ["watch", "đồng hồ", "smartwatch"],
            "description": "Truy vấn NLP dài"
        },
        {
            "query": "laptop mỏng nhẹ cho sinh viên",
            "expected_category": "laptop",
            "expected_keywords": ["laptop"],
            "description": "Truy vấn theo nhu cầu"
        },
        {
            "query": "samsung galaxy s24",
            "expected_category": "smartphone",
            "expected_keywords": ["samsung", "galaxy", "s24"],
            "description": "Truy vấn tên sản phẩm"
        },
        {
            "query": "airpods",
            "expected_category": "headphone",
            "expected_keywords": ["airpods", "apple"],
            "description": "Truy vấn tên sản phẩm ngắn"
        },
        {
            "query": "điện thoại giá 3 triệu",
            "expected_category": "smartphone",
            "expected_keywords": ["điện thoại", "phone"],
            "description": "Truy vấn kèm giá"
        },
    ]

    results = []
    total_correct = 0

    for i, test in enumerate(test_queries, 1):
        resp, ms = measure_request("POST", f"{BASE_URL}/ai/search",
                                   json={"query": test["query"], "limit": 5},
                                   headers=headers)

        if resp and resp.status_code == 200:
            data = resp.json()
            # AISearchResponse: {success, data: {products: [...], total, query, search_time_ms}}
            inner = data.get("data") or data
            products = inner.get("products") or inner.get("items") or inner.get("results") or []

            # Check if results contain expected keywords
            correct = False
            if products and len(products) > 0:
                # Check first result
                first = products[0]
                name = (first.get("name", "") or "").lower()
                cat = (first.get("category_name", "") or first.get("category", {}).get("name", "") or "").lower()
                brand = (first.get("brand_name", "") or first.get("brand", {}).get("name", "") or "").lower()
                combined = f"{name} {cat} {brand}"

                for kw in test["expected_keywords"]:
                    if kw.lower() in combined:
                        correct = True
                        break

            status = f"{GREEN}✓{RESET}" if correct else f"{RED}✗{RESET}"
            total_correct += 1 if correct else 0
            first_name = products[0].get("name", "?")[:45] if products else "NO RESULTS"
            print(f"  {status} [{ms:>7.1f}ms] Q{i}: \"{test['query']}\"")
            print(f"              → Top-1: {first_name} ({len(products)} kết quả)")
            results.append({
                "query": test["query"],
                "description": test["description"],
                "time_ms": round(ms, 1),
                "num_results": len(products) if products else 0,
                "top1": first_name if products else "N/A",
                "correct": correct
            })
        else:
            status_code = resp.status_code if resp else "TIMEOUT"
            print(f"  {RED}✗ [{ms:>7.1f}ms] Q{i}: \"{test['query']}\" → ERROR {status_code}{RESET}")
            results.append({
                "query": test["query"],
                "description": test["description"],
                "time_ms": round(ms, 1),
                "num_results": 0,
                "top1": f"ERROR {status_code}",
                "correct": False
            })

    accuracy = (total_correct / len(test_queries)) * 100
    avg_time = sum(r["time_ms"] for r in results) / len(results)
    print(f"\n  {BOLD}Tổng kết: {total_correct}/{len(test_queries)} chính xác ({accuracy:.0f}%) | Avg: {avg_time:.0f}ms{RESET}")

    return results, accuracy, avg_time


def test_chat_function_calling(token):
    """Test 3: Đánh giá chatbot Function Calling."""
    print_header("TEST 3: CHATBOT FUNCTION CALLING")

    if not token:
        print(f"  {RED}SKIP: Cần đăng nhập{RESET}")
        return []

    headers = {"Authorization": f"Bearer {token}"}

    test_messages = [
        {"msg": "Tìm cho tôi iPhone", "expected_tool": "search_products"},
        {"msg": "Xem chi tiết sản phẩm đầu tiên", "expected_tool": "get_product_detail"},
        {"msg": "Đang có khuyến mãi gì không?", "expected_tool": "get_promotions"},
        {"msg": "Xem giỏ hàng", "expected_tool": "get_cart"},
        {"msg": "Cho tôi xem đơn hàng", "expected_tool": "get_order_status"},
    ]

    results = []
    # No need to create conversation separately - it auto-creates
    conv_id = None

    for i, test in enumerate(test_messages, 1):
        payload = {"message": test["msg"]}
        if conv_id:
            payload["conversation_id"] = str(conv_id)

        resp, ms = measure_request("POST", f"{BASE_URL}/chat",
                                   json=payload, headers=headers)

        if resp and resp.status_code == 200:
            data = resp.json()
            inner = data.get("data") or data
            intent = inner.get("intent_type", "unknown")
            reply = (inner.get("message") or inner.get("content") or "")[:60]
            # Save conversation_id for follow-up messages
            if not conv_id:
                conv_id = inner.get("session_id") or inner.get("conversation_id")

            print(f"  [{ms:>7.1f}ms] \"{test['msg']}\"")
            print(f"              → intent: {intent} | reply: {reply}...")
            results.append({
                "message": test["msg"],
                "time_ms": round(ms, 1),
                "intent": intent,
                "expected_tool": test["expected_tool"],
            })
        else:
            status_code = resp.status_code if resp else "TIMEOUT"
            print(f"  {RED}[{ms:>7.1f}ms] \"{test['msg']}\" → ERROR {status_code}{RESET}")
            if resp:
                try:
                    print(f"              → {resp.text[:200]}")
                except:
                    pass
            results.append({
                "message": test["msg"],
                "time_ms": round(ms, 1),
                "intent": "error",
                "expected_tool": test["expected_tool"],
            })

    if results:
        avg_time = sum(r["time_ms"] for r in results) / len(results)
        print(f"\n  {BOLD}Avg chat response: {avg_time:.0f}ms{RESET}")

    return results


def generate_report(api_results, search_results, search_accuracy, search_avg_time, chat_results):
    """Generate markdown report with real data."""
    print_header("GENERATING REPORT")

    report = []
    report.append("# KẾT QUẢ BENCHMARK THỰC TẾ - TechHub")
    report.append(f"**Thời gian chạy:** {time.strftime('%Y-%m-%d %H:%M:%S')}\n")

    # API Performance table
    report.append("## 1. Hiệu năng API (Thời gian phản hồi thực tế)\n")
    report.append("| API | Thời gian phản hồi | Ghi chú |")
    report.append("|-----|-------------------|---------|")
    for name, ms in api_results:
        level = "✅ Nhanh" if ms < 300 else "⚡ Trung bình" if ms < 1000 else "⏳ Chậm (AI)"
        report.append(f"| {name} | {ms:.0f}ms | {level} |")

    # Semantic Search table
    report.append(f"\n## 2. Đánh giá tìm kiếm ngữ nghĩa AI\n")
    report.append(f"**Tổng độ chính xác: {search_accuracy:.0f}% ({sum(1 for r in search_results if r['correct'])}/{len(search_results)})**")
    report.append(f"**Thời gian phản hồi trung bình: {search_avg_time:.0f}ms**\n")
    report.append("| # | Truy vấn | Loại | Kết quả Top-1 | Thời gian | Đúng? |")
    report.append("|---|---------|------|---------------|-----------|-------|")
    for i, r in enumerate(search_results, 1):
        check = "✅" if r["correct"] else "❌"
        top1 = r["top1"][:35] + "..." if len(r["top1"]) > 35 else r["top1"]
        report.append(f"| {i} | {r['query']} | {r['description']} | {top1} | {r['time_ms']:.0f}ms | {check} |")

    # Chat results
    if chat_results:
        report.append(f"\n## 3. Đánh giá Chatbot Function Calling\n")
        avg_chat = sum(r["time_ms"] for r in chat_results) / len(chat_results)
        report.append(f"**Thời gian phản hồi trung bình: {avg_chat:.0f}ms**\n")
        report.append("| # | Tin nhắn | Intent trả về | Thời gian |")
        report.append("|---|---------|--------------|-----------|")
        for i, r in enumerate(chat_results, 1):
            report.append(f"| {i} | {r['message']} | {r['intent']} | {r['time_ms']:.0f}ms |")

    report_text = "\n".join(report)

    # Save to file
    report_path = "scripts/benchmark_results.md"
    with open(report_path, "w", encoding="utf-8") as f:
        f.write(report_text)
    print(f"  {GREEN}Report saved to: {report_path}{RESET}")

    return report_text


def main():
    print(f"\n{BOLD}{CYAN}╔══════════════════════════════════════════════╗")
    print(f"║     TechHub Benchmark Test Suite v1.0       ║")
    print(f"╚══════════════════════════════════════════════╝{RESET}")

    # Check server
    try:
        resp = requests.get(f"{BASE_URL.replace('/api/v1', '')}/docs", timeout=3)
        print(f"\n  {GREEN}✓ Server đang chạy tại {BASE_URL}{RESET}")
    except:
        print(f"\n  {RED}✗ Server không phản hồi! Hãy chạy: docker compose up{RESET}")
        sys.exit(1)

    # Auth
    print(f"\n  Đang đăng nhập test user...")
    token = get_auth_token()
    if token:
        print(f"  {GREEN}✓ Đã đăng nhập thành công{RESET}")
    else:
        print(f"  {YELLOW}⚠ Không thể đăng nhập, một số test sẽ bị bỏ qua{RESET}")

    # Run tests
    api_results, product_id = test_api_performance(token)
    search_results, accuracy, avg_time = test_semantic_search(token)
    chat_results = test_chat_function_calling(token)

    # Generate report
    report = generate_report(api_results, search_results, accuracy, avg_time, chat_results)

    print(f"\n{BOLD}{GREEN}═══ BENCHMARK HOÀN TẤT ═══{RESET}\n")


if __name__ == "__main__":
    main()
