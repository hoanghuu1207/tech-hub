"""
Chat Tools — Định nghĩa tất cả Function Calling tools cho TechBot.

Mỗi tool được Gemini gọi tự động dựa trên ngữ cảnh hội thoại.
Tool handlers nằm trong chat_tool_handlers.py.
"""

import google.generativeai as genai


# ── 1. search_products ──
search_products_func = genai.protos.FunctionDeclaration(
    name="search_products",
    description=(
        "Tìm kiếm sản phẩm trong kho hàng TechShop. "
        "BẮT BUỘC dùng khi người dùng muốn tìm, mua, xem, gợi ý sản phẩm. "
        "Ví dụ: 'cho tôi xem iPhone', 'laptop gaming dưới 20 triệu', 'điện thoại pin trâu'."
    ),
    parameters=genai.protos.Schema(
        type=genai.protos.Type.OBJECT,
        properties={
            "query": genai.protos.Schema(
                type=genai.protos.Type.STRING,
                description="Câu tìm kiếm sản phẩm bằng ngôn ngữ tự nhiên.",
            ),
            "limit": genai.protos.Schema(
                type=genai.protos.Type.INTEGER,
                description="Số lượng sản phẩm tối đa trả về (mặc định 10).",
            ),
        },
        required=["query"],
    ),
)

# ── 2. get_product_detail ──
get_product_detail_func = genai.protos.FunctionDeclaration(
    name="get_product_detail",
    description=(
        "Lấy thông tin chi tiết và thông số kỹ thuật của MỘT sản phẩm cụ thể. "
        "Dùng khi người dùng muốn xem chi tiết, specs, cấu hình của sản phẩm. "
        "Cần product_id hoặc product_slug (lấy từ kết quả search trước đó). "
        "Ví dụ: 'cho tôi xem chi tiết sản phẩm đầu tiên', 'thông số kỹ thuật iPhone 15'."
    ),
    parameters=genai.protos.Schema(
        type=genai.protos.Type.OBJECT,
        properties={
            "product_id": genai.protos.Schema(
                type=genai.protos.Type.STRING,
                description="UUID của sản phẩm (lấy từ kết quả search_products trước đó).",
            ),
            "product_slug": genai.protos.Schema(
                type=genai.protos.Type.STRING,
                description="Slug của sản phẩm (dùng khi không có product_id).",
            ),
        },
    ),
)

# ── 3. compare_products ──
compare_products_func = genai.protos.FunctionDeclaration(
    name="compare_products",
    description=(
        "So sánh hai hoặc nhiều sản phẩm theo thông số kỹ thuật. "
        "Cần danh sách product_ids (lấy từ kết quả search_products trước đó). "
        "Ví dụ: 'so sánh 2 sản phẩm đầu tiên', 'so sánh iPhone 15 và Samsung S24'."
    ),
    parameters=genai.protos.Schema(
        type=genai.protos.Type.OBJECT,
        properties={
            "product_ids": genai.protos.Schema(
                type=genai.protos.Type.ARRAY,
                items=genai.protos.Schema(type=genai.protos.Type.STRING),
                description="Danh sách UUID của các sản phẩm cần so sánh (tối thiểu 2).",
            ),
        },
        required=["product_ids"],
    ),
)

# ── 4. add_to_cart ──
add_to_cart_func = genai.protos.FunctionDeclaration(
    name="add_to_cart",
    description=(
        "CHỈ dùng khi người dùng MUỐN THÊM VÀO GIỎ HÀNG, KHÔNG phải khi muốn mua ngay. "
        "KHÔNG ĐƯỢC tự nói 'đã thêm' mà không gọi tool. "
        "Cần product_id (UUID lấy từ kết quả search_products hoặc get_product_detail trước đó). "
        "Khi người dùng nói 'thêm vào giỏ', 'cho vào giỏ', 'bỏ vào giỏ hàng', 'add to cart' → gọi add_to_cart. "
        "⚠️ KHÔNG gọi add_to_cart khi người dùng nói 'mua', 'tôi muốn mua', 'mua cái này', 'đặt mua' — những câu đó phải dùng buy_product. "
        "Nếu kết quả trả về yêu cầu chọn màu (action='select_variant'), hãy hỏi người dùng chọn màu rồi gọi lại với variant_id. "
        "Ví dụ: 'thêm sản phẩm đầu tiên vào giỏ', 'cho vào giỏ cái thứ 2', 'bỏ vào giỏ hàng'."
    ),
    parameters=genai.protos.Schema(
        type=genai.protos.Type.OBJECT,
        properties={
            "product_id": genai.protos.Schema(
                type=genai.protos.Type.STRING,
                description="UUID của sản phẩm cần thêm vào giỏ.",
            ),
            "variant_id": genai.protos.Schema(
                type=genai.protos.Type.STRING,
                description="UUID hoặc tên màu của variant đã chọn. Bắt buộc nếu sản phẩm có nhiều màu.",
            ),
            "quantity": genai.protos.Schema(
                type=genai.protos.Type.INTEGER,
                description="Số lượng (mặc định 1).",
            ),
        },
        required=["product_id"],
    ),
)

# ── 5. get_cart ──
get_cart_func = genai.protos.FunctionDeclaration(
    name="get_cart",
    description=(
        "Lấy thông tin giỏ hàng hiện tại của người dùng. YÊU CẦU ĐĂNG NHẬP. "
        "Dùng khi người dùng hỏi về giỏ hàng, xem giỏ, kiểm tra giỏ. "
        "Ví dụ: 'giỏ hàng của tôi có gì', 'xem giỏ hàng'."
    ),
    parameters=genai.protos.Schema(
        type=genai.protos.Type.OBJECT,
        properties={},
    ),
)

# ── 6. proceed_to_checkout ──
proceed_to_checkout_func = genai.protos.FunctionDeclaration(
    name="proceed_to_checkout",
    description=(
        "Khởi tạo luồng thanh toán, chuyển người dùng sang màn hình checkout. YÊU CẦU ĐĂNG NHẬP. "
        "Dùng khi người dùng muốn thanh toán, đặt hàng, mua ngay. "
        "Ví dụ: 'tôi muốn thanh toán', 'đặt hàng luôn', 'checkout'."
    ),
    parameters=genai.protos.Schema(
        type=genai.protos.Type.OBJECT,
        properties={},
    ),
)

# ── 7. get_order_status ──
get_order_status_func = genai.protos.FunctionDeclaration(
    name="get_order_status",
    description=(
        "Tra cứu trạng thái đơn hàng của người dùng. YÊU CẦU ĐĂNG NHẬP. "
        "Dùng khi người dùng hỏi về đơn hàng, tình trạng giao hàng. "
        "Ví dụ: 'đơn hàng của tôi đến đâu rồi', 'kiểm tra đơn hàng'."
    ),
    parameters=genai.protos.Schema(
        type=genai.protos.Type.OBJECT,
        properties={
            "order_id": genai.protos.Schema(
                type=genai.protos.Type.STRING,
                description="UUID của đơn hàng cụ thể (nếu có). Để trống để lấy đơn gần nhất.",
            ),
        },
    ),
)

# ── 8. get_promotions ──
get_promotions_func = genai.protos.FunctionDeclaration(
    name="get_promotions",
    description=(
        "Lấy danh sách sản phẩm đang giảm giá, khuyến mãi hot. "
        "Dùng khi người dùng hỏi về khuyến mãi, giảm giá, deal hot. "
        "Ví dụ: 'có sản phẩm nào đang giảm giá không', 'deal hot hôm nay'."
    ),
    parameters=genai.protos.Schema(
        type=genai.protos.Type.OBJECT,
        properties={
            "category": genai.protos.Schema(
                type=genai.protos.Type.STRING,
                description="Danh mục sản phẩm muốn xem khuyến mãi (để trống = tất cả).",
            ),
            "limit": genai.protos.Schema(
                type=genai.protos.Type.INTEGER,
                description="Số lượng sản phẩm tối đa (mặc định 10).",
            ),
        },
    ),
)

# ── 9. buy_product ──
buy_product_func = genai.protos.FunctionDeclaration(
    name="buy_product",
    description=(
        "Mua ngay sản phẩm KHÔNG qua giỏ hàng — tạo đơn hàng trực tiếp + thanh toán PayOS. YÊU CẦU ĐĂNG NHẬP. "
        "Cần product_id (UUID lấy từ kết quả search_products hoặc get_product_detail trước đó). "
        "BẮT BUỘC gọi tool này khi người dùng muốn MUA sản phẩm. "
        "Khi người dùng nói 'mua', 'tôi muốn mua', 'mua cái này', 'mua ngay', 'đặt mua', 'đặt hàng', 'mua luôn', 'mua cho tôi', 'order' → PHẢI gọi buy_product. "
        "Nếu kết quả trả về yêu cầu chọn màu (action='select_variant'), hãy hỏi người dùng chọn màu rồi gọi lại với variant_id. "
        "Ví dụ: 'tôi muốn mua cái này', 'mua ngay sản phẩm đầu tiên', 'đặt mua 2 cái iPhone', 'mua cho tôi cái thứ 3'."
    ),
    parameters=genai.protos.Schema(
        type=genai.protos.Type.OBJECT,
        properties={
            "product_id": genai.protos.Schema(
                type=genai.protos.Type.STRING,
                description="UUID của sản phẩm cần mua (lấy từ kết quả search hoặc detail trước đó).",
            ),
            "variant_id": genai.protos.Schema(
                type=genai.protos.Type.STRING,
                description="UUID hoặc tên màu của variant đã chọn. Bắt buộc nếu sản phẩm có nhiều màu.",
            ),
            "quantity": genai.protos.Schema(
                type=genai.protos.Type.INTEGER,
                description="Số lượng muốn mua (mặc định 1).",
            ),
        },
        required=["product_id"],
    ),
)


# ── Tổng hợp tất cả tools ──
ALL_TOOLS = genai.protos.Tool(
    function_declarations=[
        search_products_func,
        get_product_detail_func,
        compare_products_func,
        add_to_cart_func,
        get_cart_func,
        proceed_to_checkout_func,
        get_order_status_func,
        get_promotions_func,
        buy_product_func,
    ]
)

# Danh sách tool yêu cầu đăng nhập
AUTH_REQUIRED_TOOLS = {"add_to_cart", "get_cart", "proceed_to_checkout", "get_order_status", "buy_product"}
