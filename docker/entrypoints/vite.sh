#!/bin/sh
set -x

rm -rf /app/tmp/pids/server.pid
rm -rf /app/tmp/cache/*

pnpm install

echo "Ready to run Vite development server."

exec "$@"
