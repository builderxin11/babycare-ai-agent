#!/bin/bash
# Intercept rod's --user-data-dir and replace with persistent profile directory
# This ensures XHS login session survives across xhs-mcp process restarts
ARGS=()
for arg in "$@"; do
  if [[ "$arg" == --user-data-dir=* ]]; then
    ARGS+=("--user-data-dir=/opt/xhs-mcp/chrome-profile")
  else
    ARGS+=("$arg")
  fi
done
exec google-chrome-stable "${ARGS[@]}"
