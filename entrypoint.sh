#!/bin/bash
npx playwright install chromium 2>/dev/null
exec "$@"
