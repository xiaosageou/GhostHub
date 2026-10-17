# ==============================================================================
# Production Dockerfile for GhostHub Media Server
# ==============================================================================
FROM python:3.9-slim

ENV PYTHONUNBUFFERED=1 \
    PYTHONDONTWRITEBYTECODE=1 \
    PORT=5000 \
    FLASK_CONFIG=production \
    GHOSTHUB_DOCKER=true

WORKDIR /app

# 1. Install runtime and build dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
    ffmpeg \
    curl \
    gosu \
    libudev1 \
    build-essential \
    libudev-dev \
    && rm -rf /var/lib/apt/lists/*

# 2. Install Python dependencies directly into the system environment
COPY requirements.txt .
RUN pip install --no-cache-dir --upgrade pip setuptools wheel \
    && pip install --no-cache-dir -r requirements.txt packaging \
    && apt-get purge -y --auto-remove build-essential libudev-dev \
    && rm -rf /var/lib/apt/lists/* /root/.cache

# 3. Copy application source code
COPY . /app

# 4. Verify critical Gunicorn + GeventWebSocketWorker imports during build
RUN python -c "import packaging; import gunicorn.workers.ggevent; import geventwebsocket.gunicorn.workers; print('>>> Build verification PASSED: Gunicorn and GeventWebSocketWorker loaded successfully!')"

# 5. Ensure entrypoint is executable and default directories exist
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
