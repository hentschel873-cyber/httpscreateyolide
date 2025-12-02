#!/usr/bin/env bash
# Simple curl-based Bitly shorten helper
# Usage:
#   export BITLY_TOKEN="..."
#   ./bitly_shorten.sh "https://example.com/very/long/url"

set -euo pipefail
if [ "$#" -lt 1 ]; then
  echo "Usage: $0 <long-url> [domain]"
  exit 1
fi
LONGURL=$1
DOMAIN=${2:-}
if [ -z "${BITLY_TOKEN:-}" ]; then
  echo "Please set BITLY_TOKEN environment variable"
  exit 2
fi

# Build JSON body safely (assumes URL doesn't contain literal '"')
if [ -n "$DOMAIN" ]; then
  BODY=$(printf '{"long_url":"%s","domain":"%s"}' "$LONGURL" "$DOMAIN")
else
  BODY=$(printf '{"long_url":"%s"}' "$LONGURL")
fi

curl -sS -X POST "https://api-ssl.bitly.com/v4/shorten" \
  -H "Authorization: Bearer $BITLY_TOKEN" \
  -H "Content-Type: application/json" \
  -d "$BODY" | jq '.'
