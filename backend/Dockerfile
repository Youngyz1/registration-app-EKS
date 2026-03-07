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

# Copy from build stage
COPY --from=build /app /app

# Run migrations/initialization before starting app
RUN python -c "from init_db import init_db; init_db()"

EXPOSE 8000

CMD ["python", "main.py"]
