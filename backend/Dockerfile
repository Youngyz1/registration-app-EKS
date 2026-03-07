# ---------- Build Stage ----------
FROM python:3.9-alpine AS build
WORKDIR /app

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY . .

# ---------- Production Stage ----------
FROM python:3.9-alpine
WORKDIR /app

RUN apk add --no-cache curl

# Copy Python packages from build stage
COPY --from=build /usr/local/lib/python3.9/site-packages /usr/local/lib/python3.9/site-packages
COPY --from=build /usr/local/bin /usr/local/bin

# Copy application code
COPY . .

EXPOSE 8000

# Database tables will be initialized automatically on app startup
# via init_db() call in main.py
CMD ["python", "main.py"]
