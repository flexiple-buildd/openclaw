#!/bin/bash
set -e

# Recreate Claude Max proxy symlinks from persistent storage on every boot
if [ -d /home/node/.openclaw/claude-max-api-proxy ]; then
mkdir -p /home/node/.local/lib/node_modules /home/node/.local/bin /home/node/.openclaw/logs

ln -sfn /home/node/.openclaw/claude-max-api-proxy \
/home/node/.local/lib/node_modules/claude-max-api-proxy

ln -sfn /home/node/.local/lib/node_modules/claude-max-api-proxy/dist/server/standalone.js \
/home/node/.local/bin/claude-max-api

chmod +x /home/node/.local/bin/claude-max-api

/home/node/.local/bin/claude-max-api \
> /home/node/.openclaw/logs/claude-max-api.log 2>&1 &

sleep 2
fi

# Hand off to the normal OpenClaw entrypoint
exec /home/node/entrypoint.sh "$@"
