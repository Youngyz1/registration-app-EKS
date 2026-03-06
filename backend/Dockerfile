FROM python:3.9-alpine3.21

WORKDIR /app

# Install curl for healthcheck
RUN apk add --no-cache curl

COPY requirements.txt .
RUN pip install --upgrade pip && pip install --no-cache-dir -r requirements.txt

COPY . .

EXPOSE 8000

CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "8000"]
