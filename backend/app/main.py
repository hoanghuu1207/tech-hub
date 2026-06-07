import time
import logging
from fastapi import FastAPI, Request, WebSocket, WebSocketDisconnect
from fastapi.responses import JSONResponse, HTMLResponse
from fastapi.middleware.cors import CORSMiddleware
from fastapi.exceptions import RequestValidationError
from starlette.exceptions import HTTPException as StarletteHTTPException
from slowapi.errors import RateLimitExceeded
from app.db.qdrant import check_qdrant_connection, qdrant_client

from app.api.v1.router import api_router
from app.core.config import settings
from app.core.rate_limit import limiter
from app.services.notification_manager import notification_manager

# --- Logging setup ---
logger = logging.getLogger("api_logger")
logger.setLevel(logging.INFO)
ch = logging.StreamHandler()
formatter = logging.Formatter('%(asctime)s - %(name)s - %(levelname)s - %(message)s')
ch.setFormatter(formatter)
logger.addHandler(ch)

app = FastAPI(
    title=settings.APP_NAME,
    debug=settings.DEBUG
)

check_qdrant_connection()
logger.info(f"Qdrant URL: {settings.QDRANT_CLUSTER_ENDPOINT}")


# --- 1. Rate Limiting Setup ---
app.state.limiter = limiter

# --- 2. CORS Middleware ---
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"], # Phát triển cho phép tất cả các nguồn gọi API
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# --- 3. Request Logging Middleware ---
@app.middleware("http")
async def log_requests_and_duration(request: Request, call_next):
    start_time = time.time()
    response = await call_next(request)
    process_time = (time.time() - start_time) * 1000
    
    logger.info(
        f"METHOD: {request.method} | "
        f"PATH: {request.url.path} | "
        f"STATUS: {response.status_code} | "
        f"DURATION: {process_time:.2f}ms"
    )
    return response

# --- 4. Global Exception Handlers (Quy chuẩn JSON) ---
def error_response(message: str, status_code: int = 400):
    return JSONResponse(
        status_code=status_code,
        content={
            "success": False, 
            "message": message, 
            "data": None, 
            "error": message
        }
    )

@app.exception_handler(StarletteHTTPException)
async def http_exception_handler(request: Request, exc: StarletteHTTPException):
    return error_response(message=exc.detail, status_code=exc.status_code)

@app.exception_handler(RequestValidationError)
async def validation_exception_handler(request: Request, exc: RequestValidationError):
    # Lỗi do input schema JSON sai rules
    logger.error(f"❌ Validation Error on {request.method} {request.url.path}: {exc.errors()}")
    return error_response(message="Invalid input data base on definitions", status_code=422)

@app.exception_handler(RateLimitExceeded)
async def rate_limit_handler(request: Request, exc: RateLimitExceeded):
    # Tuỳ biến chuẩn hoá lỗi spam block
    return error_response(message="Too many login attempts. Please try again later.", status_code=429)

@app.exception_handler(Exception)
async def generic_exception_handler(request: Request, exc: Exception):
    logger.error(f"Internal Server Error: {str(exc)}")
    return error_response(message="Internal server error", status_code=500)

# --- 5b. Share Deep Link Redirect ---
@app.get("/share/product/{product_id}", response_class=HTMLResponse)
async def share_product_redirect(product_id: str, request: Request):
    """
    Trang redirect cho share link.
    Mở trong trình duyệt → tự động redirect sang app TechHub.
    Nếu app chưa cài → hiển thị trang landing fallback.
    """
    deep_link = f"techhub://product/{product_id}"

    html = f"""<!DOCTYPE html>
<html lang="vi">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>TechHub - Xem sản phẩm</title>
    <style>
        * {{ margin: 0; padding: 0; box-sizing: border-box; }}
        body {{
            font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
            background: linear-gradient(135deg, #0F172A 0%, #1E293B 100%);
            color: #fff;
            min-height: 100vh;
            display: flex;
            align-items: center;
            justify-content: center;
        }}
        .container {{
            text-align: center;
            padding: 40px 24px;
            max-width: 400px;
        }}
        .logo {{
            font-size: 48px;
            margin-bottom: 16px;
        }}
        .title {{
            font-size: 24px;
            font-weight: 700;
            margin-bottom: 8px;
        }}
        .subtitle {{
            color: #94A3B8;
            font-size: 14px;
            margin-bottom: 32px;
            line-height: 1.5;
        }}
        .spinner {{
            width: 40px; height: 40px;
            border: 3px solid #334155;
            border-top-color: #6366F1;
            border-radius: 50%;
            animation: spin 0.8s linear infinite;
            margin: 0 auto 24px;
        }}
        @keyframes spin {{ to {{ transform: rotate(360deg); }} }}
        .btn {{
            display: inline-block;
            background: #6366F1;
            color: #fff;
            padding: 14px 32px;
            border-radius: 12px;
            text-decoration: none;
            font-weight: 600;
            font-size: 16px;
            transition: background 0.2s;
        }}
        .btn:hover {{ background: #4F46E5; }}
        .fallback {{
            display: none;
            margin-top: 24px;
            color: #64748B;
            font-size: 13px;
        }}
    </style>
</head>
<body>
    <div class="container">
        <div class="logo">🛍️</div>
        <h1 class="title">TechHub</h1>
        <p class="subtitle">Đang mở ứng dụng TechHub...</p>
        <div class="spinner" id="spinner"></div>
        <a href="{deep_link}" class="btn" id="openBtn" style="display:none;">
            Mở trong TechHub
        </a>
        <p class="fallback" id="fallback">
            Nếu ứng dụng không tự mở, hãy ấn nút ở trên.<br>
            Bạn cần cài đặt ứng dụng TechHub trước.
        </p>
    </div>
    <script>
        // Thử redirect sang app
        window.location.href = "{deep_link}";

        // Sau 2s nếu vẫn ở trang này → app chưa cài, hiện nút fallback
        setTimeout(function() {{
            document.getElementById('spinner').style.display = 'none';
            document.getElementById('openBtn').style.display = 'inline-block';
            document.getElementById('fallback').style.display = 'block';
        }}, 2000);
    </script>
</body>
</html>"""

    return HTMLResponse(content=html)


# --- 6. Mount API Router ---
app.include_router(api_router, prefix="/api/v1")

# --- 6. WebSocket Notification Endpoint ---
@app.websocket("/ws/notifications/{user_id}")
async def notification_websocket(websocket: WebSocket, user_id: str):
    """WebSocket endpoint cho real-time notifications."""
    await notification_manager.connect(user_id, websocket)
    try:
        while True:
            # Keep alive — chờ tin nhắn từ client (ping/pong)
            await websocket.receive_text()
    except WebSocketDisconnect:
        notification_manager.disconnect(user_id, websocket)
    except Exception:
        notification_manager.disconnect(user_id, websocket)

