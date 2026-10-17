# ==============================================================================
# Multi-stage Dockerfile for GhostHub Media Server
# ==============================================================================

# ---- Stage 1: Build Dependencies ----
FROM python:3.9-slim-bullseye AS builder

WORKDIR /build

# Install build dependencies for C-extensions (gevent, psutil, pyudev, etc.)
RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential \
    gcc \
    g++ \
    make \
    python3-dev \
    libudev-dev \
    libjpeg-dev \
    zlib1g-dev \
    libfreetype6-dev \
    && rm -rf /var/lib/apt/lists/*

COPY requirements.txt .

# Install dependencies into /install prefix
RUN pip install --no-cache-dir --upgrade pip setuptools wheel \
    && pip install --no-cache-dir --prefix=/install -r requirements.txt

# ---- Stage 2: Final Production Runtime ----
FROM python:3.9-slim-bullseye AS runner

ENV PYTHONUNBUFFERED=1 \
    PYTHONDONTWRITEBYTECODE=1 \
    PORT=5000 \
    FLASK_CONFIG=production \
    GHOSTHUB_DOCKER=true

WORKDIR /app

# Install runtime dependencies (ffmpeg for media extraction/conversion, curl for health checks, gosu)
RUN apt-get update && apt-get install -y --no-install-recommends \
    ffmpeg \
    curl \
    gosu \
    libudev1 \
    libjpeg62-turbo \
    zlib1g \
    libfreetype6 \
    liblcms2-2 \
    libopenjp2-7 \
    libtiff5 \
    libwebp6 \
    && rm -rf /var/lib/apt/lists/*

# Copy installed Python packages from builder
COPY --from=builder /install /usr/local

# Copy application source code
COPY . /app

# Ensure entrypoint is executable and default directories exist
RUN chmod +x /app/docker-entrypoint.sh \
    && mkdir -p /app/instance /media /tmp/ghosthub_sqlite

EXPOSE 5000

# Mount points for persistent data and media libraries
VOLUME ["/app/instance", "/media"]

# Healthcheck to verify the web server is responding
HEALTHCHECK --interval=30s --timeout=10s --start-period=20s --retries=3 \
    CMD curl -f http://localhost:${PORT:-5000}/ || exit 1

ENTRYPOINT ["/app/docker-entrypoint.sh"]
CMD ["python", "-m", "gunicorn", "-c", "gunicorn_config.py", "wsgi:app"]
