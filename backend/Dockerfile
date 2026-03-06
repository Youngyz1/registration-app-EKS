FROM python:3.9-alpine3.21

# Fix CVE-2025-15467: upgrade OpenSSL libcrypto3/libssl3 to 3.3.6-r0
RUN apk update && apk upgrade --no-cache

WORKDIR /app

# Install curl for healthcheck
RUN apk add --no-cache curl

COPY requirements.txt .
RUN pip install --upgrade pip && pip install --no-cache-dir -r requirements.txt

COPY . .

EXPOSE 8000

CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "8000"]