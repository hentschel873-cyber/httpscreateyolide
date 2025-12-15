#!/usr/bin/env bash
# validate_env_vars.sh
# Validates that required environment variables for local-sync are properly set
# Usage: bash scripts/validate_env_vars.sh [--strict] [--verbose]

set -u

# Parse arguments
STRICT=false
VERBOSE=false

for arg in "$@"; do
    case $arg in
        --strict)
            STRICT=true
            shift
            ;;
        --verbose)
            VERBOSE=true
            shift
            ;;
        *)
            ;;
    esac
done

# ANSI color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
RESET='\033[0m'

# Check if terminal supports colors
if [ ! -t 1 ] || [ "$TERM" = "dumb" ]; then
    RED=''
    GREEN=''
    YELLOW=''
    BLUE=''
    RESET=''
fi

echo -e "${BLUE}============================================${RESET}"
echo -e "${BLUE}Local Sync Environment Variables Validator${RESET}"
echo -e "${BLUE}============================================${RESET}"
echo ""

# Counters
SUCCESS_COUNT=0
WARNING_COUNT=0
ERROR_COUNT=0

# Arrays for messages
SUCCESS_MSGS=()
WARNING_MSGS=()
ERROR_MSGS=()

# Function to check environment variable
check_env_var() {
    local var_name="$1"
    local required="$2"
    local description="${3:-}"
    local validator="${4:-}"
    
    local value="${!var_name:-}"
    
    if [ -z "$value" ]; then
        if [ "$required" = "true" ]; then
            ERROR_MSGS+=("${RED}✗${RESET} $var_name - ${RED}NOT SET${RESET} (REQUIRED)")
            if [ -n "$description" ]; then
                ERROR_MSGS+=("  ℹ $description")
            fi
            ((ERROR_COUNT++))
        else
            WARNING_MSGS+=("${YELLOW}⚠${RESET} $var_name - not set (optional)")
            if [ -n "$description" ]; then
                WARNING_MSGS+=("  ℹ $description")
            fi
            ((WARNING_COUNT++))
        fi
    else
        # Mask sensitive values
        if [[ "$var_name" =~ SECRET|TOKEN|PASSWORD ]]; then
            local masked_value="****${value: -4}"
        else
            local masked_value="$value"
        fi
        
        local validation_msg=""
        if [ -n "$validator" ]; then
            local validation_result
            validation_result=$(eval "$validator")
            if [ "$validation_result" != "true" ]; then
                validation_msg=" ${YELLOW}(Warning: $validation_result)${RESET}"
            fi
        fi
        
        SUCCESS_MSGS+=("${GREEN}✓${RESET} $var_name = $masked_value$validation_msg")
        if [ "$VERBOSE" = true ] && [ -n "$description" ]; then
            SUCCESS_MSGS+=("  ℹ $description")
        fi
        ((SUCCESS_COUNT++))
    fi
}

# Validator functions
validate_secret_length() {
    local value="$1"
    if [ ${#value} -lt 16 ]; then
        echo "Token is too short (< 16 chars). Recommend at least 32 characters."
    else
        echo "true"
    fi
}

validate_whitelist() {
    local value="$1"
    IFS=',' read -ra IPS <<< "$value"
    for ip in "${IPS[@]}"; do
        ip=$(echo "$ip" | xargs)  # trim whitespace
        if [[ "$ip" =~ / ]]; then
            # CIDR notation
            local subnet="${ip%/*}"
            local mask="${ip#*/}"
            if ! [[ "$subnet" =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]; then
                echo "Invalid subnet IP: $subnet"
                return
            fi
            if ! [[ "$mask" =~ ^[0-9]+$ ]] || [ "$mask" -lt 0 ] || [ "$mask" -gt 32 ]; then
                echo "Invalid CIDR mask: $mask (must be 0-32)"
                return
            fi
        else
            # Single IP
            if ! [[ "$ip" =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]] && [ "$ip" != "::1" ]; then
                echo "Invalid IP address: $ip"
                return
            fi
        fi
    done
    echo "true"
}

validate_rate_limit() {
    local value="$1"
    if ! [[ "$value" =~ ^[0-9]+$ ]]; then
        echo "Must be a positive integer"
    elif [ "$value" -lt 1 ]; then
        echo "Must be at least 1"
    elif [ "$value" -gt 10000 ]; then
        echo "Value seems very high ($value). Are you sure?"
    else
        echo "true"
    fi
}

validate_trust_proxy() {
    local value="$1"
    if [[ ! "$value" =~ ^(0|1|true|false|yes|no)$ ]]; then
        echo "Should be 0, 1, true, false, yes, or no"
    else
        echo "true"
    fi
}

validate_debug() {
    local value="$1"
    if [ "$value" = "1" ] || [ "$value" = "true" ]; then
        echo "Debug mode enabled - only use in development!"
    else
        echo "true"
    fi
}

# Check WP_LOCAL_SYNC_SECRET (REQUIRED)
check_env_var "WP_LOCAL_SYNC_SECRET" true \
    "Shared secret for API authentication. Generate with: openssl rand -base64 32" \
    "validate_secret_length \"\$WP_LOCAL_SYNC_SECRET\""

# Check WP_LOCAL_SYNC_WHITELIST (optional)
check_env_var "WP_LOCAL_SYNC_WHITELIST" false \
    "Comma-separated IP whitelist. Example: 127.0.0.1,192.168.1.0/24" \
    "validate_whitelist \"\$WP_LOCAL_SYNC_WHITELIST\""

# Check WP_LOCAL_SYNC_RATE_LIMIT (optional)
check_env_var "WP_LOCAL_SYNC_RATE_LIMIT" false \
    "Max requests per minute per IP. Default: 60" \
    "validate_rate_limit \"\$WP_LOCAL_SYNC_RATE_LIMIT\""

# Check WP_LOCAL_SYNC_TRUST_PROXY (optional)
check_env_var "WP_LOCAL_SYNC_TRUST_PROXY" false \
    "Trust X-Forwarded-For headers. Set to 1 if behind proxy" \
    "validate_trust_proxy \"\$WP_LOCAL_SYNC_TRUST_PROXY\""

# Check WP_LOCAL_SYNC_DEBUG (optional)
check_env_var "WP_LOCAL_SYNC_DEBUG" false \
    "Enable debug logging. Set to 1 for development only" \
    "validate_debug \"\$WP_LOCAL_SYNC_DEBUG\""

# Check LOCAL_SYNC_SECRET (optional, for client scripts)
check_env_var "LOCAL_SYNC_SECRET" false \
    "Client-side secret (used by scripts). Should match WP_LOCAL_SYNC_SECRET"

# Display results
echo ""
echo -e "${GREEN}Successfully configured:${RESET}"
if [ ${#SUCCESS_MSGS[@]} -eq 0 ]; then
    echo "  (none)"
else
    for msg in "${SUCCESS_MSGS[@]}"; do
        echo -e "  $msg"
    done
fi

if [ ${#WARNING_MSGS[@]} -gt 0 ]; then
    echo ""
    echo -e "${YELLOW}Warnings:${RESET}"
    for msg in "${WARNING_MSGS[@]}"; do
        echo -e "  $msg"
    done
fi

if [ ${#ERROR_MSGS[@]} -gt 0 ]; then
    echo ""
    echo -e "${RED}Errors:${RESET}"
    for msg in "${ERROR_MSGS[@]}"; do
        echo -e "  $msg"
    done
fi

# Summary
echo ""
echo -e "${BLUE}============================================${RESET}"
echo -e "Summary: ${GREEN}$SUCCESS_COUNT OK${RESET}, ${YELLOW}$WARNING_COUNT warnings${RESET}, ${RED}$ERROR_COUNT errors${RESET}"
echo -e "${BLUE}============================================${RESET}"

# Additional recommendations
if [ $ERROR_COUNT -gt 0 ]; then
    echo ""
    echo -e "${YELLOW}Quick fix:${RESET}"
    echo "1. Copy .env.local.example to .env.local"
    echo "2. Generate a secret: ${BLUE}openssl rand -base64 32${RESET}"
    echo "3. Add it to WP_LOCAL_SYNC_SECRET in .env.local"
    echo "4. Load variables:"
    echo -e "   ${BLUE}export \$(grep -v '^#' .env.local | xargs)${RESET}"
    echo "5. Verify:"
    echo -e "   ${BLUE}echo \$WP_LOCAL_SYNC_SECRET${RESET}"
fi

# Exit with error if strict mode and errors found
if [ "$STRICT" = true ] && [ $ERROR_COUNT -gt 0 ]; then
    echo ""
    echo -e "${RED}Validation failed in strict mode. Exiting with error.${RESET}"
    exit 1
fi

exit 0
