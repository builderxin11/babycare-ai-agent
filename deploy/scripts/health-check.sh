#!/bin/bash
# Health check script for NurtureMind services
# Run via cron: */5 * * * * /path/to/health-check.sh

set -e

# Configuration
API_URL="${API_URL:-http://localhost:8000}"
MCP_URL="${MCP_URL:-http://localhost:3000}"
ALERT_EMAIL="${ALERT_EMAIL:-}"
LOG_FILE="/var/log/nurturemind/health-check.log"

# Ensure log directory exists
mkdir -p "$(dirname "$LOG_FILE")"

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

send_alert() {
    local subject="$1"
    local body="$2"

    if [ -n "$ALERT_EMAIL" ]; then
        echo "$body" | mail -s "$subject" "$ALERT_EMAIL" 2>/dev/null || true
    fi

    log "ALERT: $subject - $body"
}

# Check FastAPI health
check_api() {
    if curl -sf "${API_URL}/health" > /dev/null 2>&1; then
        log "API: OK"
        return 0
    else
        send_alert "[NurtureMind] API Down" "FastAPI server is not responding at ${API_URL}"
        return 1
    fi
}

# Check MCP health by attempting a simple search
check_mcp() {
    local response
    response=$(curl -sf -X POST "${MCP_URL}" \
        -H "Content-Type: application/json" \
        -d '{
            "jsonrpc": "2.0",
            "id": 1,
            "method": "initialize",
            "params": {
                "protocolVersion": "2024-11-05",
                "capabilities": {},
                "clientInfo": {"name": "healthcheck", "version": "1.0"}
            }
        }' 2>&1) || true

    if echo "$response" | grep -q '"result"'; then
        log "MCP: OK"
        return 0
    else
        send_alert "[NurtureMind] XHS MCP Issue" \
            "Xiaohongshu MCP server may need re-login. Access the desktop at http://YOUR_EC2_IP:6081 to login."
        return 1
    fi
}

# Check if XHS login is valid by testing search
check_xhs_login() {
    local session_id
    local search_response

    # Initialize session
    session_id=$(curl -sf -X POST "${MCP_URL}" \
        -H "Content-Type: application/json" \
        -d '{
            "jsonrpc": "2.0",
            "id": 1,
            "method": "initialize",
            "params": {
                "protocolVersion": "2024-11-05",
                "capabilities": {},
                "clientInfo": {"name": "healthcheck", "version": "1.0"}
            }
        }' 2>&1 | grep -o 'Mcp-Session-Id: [^"]*' | cut -d' ' -f2) || true

    if [ -z "$session_id" ]; then
        log "MCP: Could not get session ID"
        return 1
    fi

    # Try a simple search
    search_response=$(curl -sf -X POST "${MCP_URL}" \
        -H "Content-Type: application/json" \
        -H "Mcp-Session-Id: $session_id" \
        -d '{
            "jsonrpc": "2.0",
            "id": 2,
            "method": "tools/call",
            "params": {
                "name": "search_feeds",
                "arguments": {"keyword": "test"}
            }
        }' 2>&1) || true

    if echo "$search_response" | grep -q '"error"'; then
        send_alert "[NurtureMind] XHS Login Expired" \
            "Xiaohongshu session has expired. Please login again at http://YOUR_EC2_IP:6081"
        return 1
    fi

    log "XHS Login: OK"
    return 0
}

# Main
log "Starting health check..."

api_ok=true
mcp_ok=true

check_api || api_ok=false
check_mcp || mcp_ok=false

if $api_ok && $mcp_ok; then
    # Only check XHS login if MCP is up
    check_xhs_login || true
fi

log "Health check complete."
