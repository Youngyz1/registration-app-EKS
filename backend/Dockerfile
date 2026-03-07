# ---------- Build Stage ----------
FROM python:3.9-alpine AS build
WORKDIR /app

# Update Alpine packages to fix CVE-2025-15467
RUN apk update && apk upgrade

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY . .

# ---------- Production Stage ----------
FROM python:3.9-alpine
WORKDIR /app

# Update Alpine packages to fix OpenSSL CVE-2025-15467
RUN apk update && apk upgrade && apk add --no-cache curl

# Copy Python packages from build stage
COPY --from=build /usr/local/lib/python3.9/site-packages /usr/local/lib/python3.9/site-packages
COPY --from=build /usr/local/bin /usr/local/bin

# Copy application code
COPY . .

EXPOSE 8000

# Database tables will be initialized automatically on app startup
# via init_db() call in main.py
CMD ["python", "main.py"]