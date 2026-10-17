#!/bin/sh
set -e

# Ensure required persistent and temporary directories exist
mkdir -p /app/instance
mkdir -p /tmp/ghosthub_sqlite
mkdir -p /media

# If custom PUID/PGID are supplied, adjust permissions if running as root
if [ "$(id -u)" = "0" ] && [ -n "$PUID" ] && [ -n "$PGID" ]; then
    groupadd -g "$PGID" ghosthub 2>/dev/null || true
    useradd -u "$PUID" -g "$PGID" -M -s /bin/sh ghosthub 2>/dev/null || true
    chown -R "$PUID:$PGID" /app/instance /tmp/ghosthub_sqlite 2>/dev/null || true
    exec gosu "$PUID:$PGID" "$@"
fi

exec "$@"
