FROM python:3.11-slim

# Ngăn Python tạo pyc file và không lưu buffer (tránh bị kẹt log docker)
ENV PYTHONDONTWRITEBYTECODE=1
ENV PYTHONUNBUFFERED=1

WORKDIR /app

# Cài đặt các thư viện hệ thống cần thiết (đặc biệt cho asyncpg nếu cần build)
RUN apt-get update && \
    apt-get install -y --no-install-recommends gcc libpq-dev && \
    rm -rf /var/lib/apt/lists/*

COPY requirements.txt .

# Nâng cấp pip và cài đặt thư viện
RUN pip install --upgrade pip && \
    pip install --no-cache-dir -r requirements.txt

# Copy project files (do mount ở dev mode nên thực tế ít dùng lệnh này cho local, nhưng vẫn cần cho production)
COPY . .

CMD ["uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8000"]
