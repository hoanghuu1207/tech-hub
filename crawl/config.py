# config.py
CATEGORY_URLS = {
    "smartphone": {
        "list_url": "https://cellphones.com.vn/mobile.html",
    },
    "laptop": {
        "list_url": "https://cellphones.com.vn/laptop.html",
    },
    "tablet": {
        "list_url": "https://cellphones.com.vn/tablet.html",
    },
    "headphone": {
        "list_url": "https://cellphones.com.vn/thiet-bi-am-thanh/tai-nghe.html",
    },
    "smartwatch": {
        "list_url": "https://cellphones.com.vn/do-choi-cong-nghe.html",
    },
}

SCRAPER_CONFIG = {
    "delay_between_requests": 2.5,   # giây
    "delay_between_pages": 3.0,
    "headless": True,                 # False để debug xem browser
    "timeout": 30000,                 # ms
    "max_retries": 3,
}