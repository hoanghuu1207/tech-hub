# Use official Playwright image for Python
FROM mcr.microsoft.com/playwright/python:v1.43.0-jammy

# Set working directory
WORKDIR /app

# Copy requirements file
COPY requirements.txt .

# Install dependencies
RUN pip install --no-cache-dir -r requirements.txt

# Install Playwright browser (Chromium only as requested)
RUN playwright install chromium
RUN playwright install-deps chromium

# Copy the rest of the application code
COPY . .

# Set environment variable (optional, helpful for some libraries)
ENV PYTHONUNBUFFERED=1

# Default command (adjust if main.py needs arguments)
CMD ["python", "main.py"]
