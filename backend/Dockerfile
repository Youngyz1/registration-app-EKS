# ---------- Build Stage ----------
FROM python:3.9-alpine AS build
WORKDIR /app
RUN apk update && apk upgrade --no-cache
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt
COPY main.py .
COPY database.py .
COPY models.py .
COPY init_db.py .

# ---------- Production Stage ----------
FROM python:3.9-alpine
WORKDIR /app
RUN apk update && apk upgrade --no-cache && apk add --no-cache curl
RUN addgroup -S appgroup && adduser -S appuser -G appgroup
COPY --from=build /usr/local/lib/python3.9/site-packages /usr/local/lib/python3.9/site-packages
COPY --from=build /usr/local/bin /usr/local/bin
COPY --from=build /app/main.py .
COPY --from=build /app/database.py .
COPY --from=build /app/models.py .
COPY --from=build /app/init_db.py .
RUN chown -R appuser:appgroup /app
USER appuser
EXPOSE 8000
CMD ["python", "main.py"]
