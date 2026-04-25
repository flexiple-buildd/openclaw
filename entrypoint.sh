#!/bin/bash
export PATH="/home/node/.local/bin:$PATH"
npx playwright install chromium 2>/dev/null
exec "$@"
