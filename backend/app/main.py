import time
import logging
from fastapi import FastAPI, Request
from fastapi.responses import JSONResponse
from fastapi.middleware.cors import CORSMiddleware
from fastapi.exceptions import RequestValidationError
from starlette.exceptions import HTTPException as StarletteHTTPException
from slowapi.errors import RateLimitExceeded
from app.db.qdrant import check_qdrant_connection, qdrant_client

from app.api.v1.router import api_router
from app.core.config import settings
from app.core.rate_limit import limiter

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
logger.info(f"Qdrant API Key: {settings.QDRANT_API_KEY}")
qdrant_client.search(collection_name="products", query_vector=[0.1, 0.2, 0.3, 0.4, 0.5, 0.6, 0.7, 0.8, 0.9, 1.0], limit=5)

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
    return error_response(message="Invalid input data base on definitions", status_code=422)

@app.exception_handler(RateLimitExceeded)
async def rate_limit_handler(request: Request, exc: RateLimitExceeded):
    # Tuỳ biến chuẩn hoá lỗi spam block
    return error_response(message="Too many login attempts. Please try again later.", status_code=429)

@app.exception_handler(Exception)
async def generic_exception_handler(request: Request, exc: Exception):
    logger.error(f"Internal Server Error: {str(exc)}")
    return error_response(message="Internal server error", status_code=500)

# --- 5. Mount API Router ---
app.include_router(api_router, prefix="/api/v1")
