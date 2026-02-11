# Stage 1: Build Flutter Web
FROM ghcr.io/cirruslabs/flutter:3.27.3 AS flutter-build

WORKDIR /app/frontend

# Copy pubspec first for caching
COPY frontend/pubspec.yaml frontend/pubspec.lock* ./
RUN flutter pub get 2>/dev/null || true

# Copy source and build
COPY frontend/ ./
RUN flutter pub get && flutter build web --release --web-renderer html

# Stage 2: Python Runtime
FROM python:3.12-slim

WORKDIR /app

# Install system deps
RUN apt-get update && apt-get install -y --no-install-recommends \
    curl \
    && rm -rf /var/lib/apt/lists/*

# Install Python dependencies
COPY backend/requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Copy backend source
COPY backend/app/ /app/backend/app/

# Copy Flutter web build
COPY --from=flutter-build /app/frontend/build/web /app/frontend/build/web

# Create data directory with correct permissions
RUN mkdir -p /app/backend/app/data && \
    chown -R 1000:1000 /app/backend/app/data

# Copy harmonic data
COPY backend/app/data/harmonics.json /app/backend/app/data/harmonics.json

ENV PYTHONPATH=/app
ENV TZ=Europe/London

EXPOSE 8080

HEALTHCHECK --interval=30s --timeout=5s --start-period=120s --retries=3 \
    CMD curl -f http://localhost:8080/api/health || exit 1

CMD ["uvicorn", "backend.app.main:app", "--host", "0.0.0.0", "--port", "8080"]
