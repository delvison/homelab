#!/bin/bash
# Caddy Security Hardening Validation Script
# Run this after deployment to verify security measures are active

echo "=== Caddy Security Hardening Validation ==="
echo ""

DOMAIN="${1:-yourdomain.com}"
echo "Testing domain: $DOMAIN"
echo ""

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

check_pass() {
    echo -e "${GREEN}✓ PASS${NC}: $1"
}

check_fail() {
    echo -e "${RED}✗ FAIL${NC}: $1"
}

check_warn() {
    echo -e "${YELLOW}⚠ WARN${NC}: $1"
}

echo "1. Testing Admin API Security (should NOT be accessible externally)"
if curl -s -o /dev/null -w "%{http_code}" "http://$DOMAIN:2019/config" 2>/dev/null | grep -q "000\|7"; then
    check_pass "Admin API not accessible externally"
else
    check_fail "Admin API might be accessible - verify binding to localhost"
fi
echo ""

echo "2. Testing Security Headers"
HEADERS=$(curl -s -I "https://joplin.$DOMAIN" 2>/dev/null)

if echo "$HEADERS" | grep -qi "strict-transport-security.*includeSubDomains.*preload"; then
    check_pass "HSTS with preload enabled"
else
    check_fail "HSTS header missing or misconfigured"
fi

if echo "$HEADERS" | grep -qi "x-frame-options.*deny"; then
    check_pass "X-Frame-Options: DENY"
else
    check_fail "X-Frame-Options header missing"
fi

if echo "$HEADERS" | grep -qi "x-content-type-options.*nosniff"; then
    check_pass "X-Content-Type-Options: nosniff"
else
    check_fail "X-Content-Type-Options header missing"
fi

if echo "$HEADERS" | grep -qi "content-security-policy"; then
    check_pass "Content-Security-Policy present"
else
    check_fail "CSP header missing"
fi

if echo "$HEADERS" | grep -qi "referrer-policy"; then
    check_pass "Referrer-Policy present"
else
    check_fail "Referrer-Policy header missing"
fi

if echo "$HEADERS" | grep -q "^Server:"; then
    check_warn "Server header present (should be removed)"
else
    check_pass "Server header removed"
fi
echo ""

echo "3. Testing Attack Path Blocking"
ATTACK_PATHS=("/.env" "/.git/config" "/wp-config.php" "/phpmyadmin/" "/config.json")
BLOCKED_COUNT=0

for path in "${ATTACK_PATHS[@]}"; do
    RESPONSE=$(curl -s -o /dev/null -w "%{http_code}" "https://$DOMAIN$path" 2>/dev/null)
    if [ "$RESPONSE" == "403" ] || [ "$RESPONSE" == "000" ]; then
        ((BLOCKED_COUNT++))
    fi
done

if [ $BLOCKED_COUNT -eq ${#ATTACK_PATHS[@]} ]; then
    check_pass "All attack paths properly blocked ($BLOCKED_COUNT/${#ATTACK_PATHS[@]})"
else
    check_warn "Some attack paths accessible ($BLOCKED_COUNT/${#ATTACK_PATHS[@]} blocked)"
fi
echo ""

echo "4. Testing Rate Limiting"
echo "Sending 25 rapid requests..."
REQUESTS_MADE=0
REQUESTS_BLOCKED=0

for i in {1..25}; do
    RESPONSE=$(curl -s -o /dev/null -w "%{http_code}" "https://joplin.$DOMAIN" 2>/dev/null)
    ((REQUESTS_MADE++))
    if [ "$RESPONSE" == "429" ]; then
        ((REQUESTS_BLOCKED++))
    fi
done

if [ $REQUESTS_BLOCKED -gt 0 ]; then
    check_pass "Rate limiting active ($REQUESTS_BLOCKED/25 requests blocked with 429)"
else
    check_warn "Rate limiting may not be active (no 429 responses)"
fi
echo ""

echo "5. Testing HTTPS Redirection"
HTTP_RESPONSE=$(curl -s -o /dev/null -w "%{http_code}" "http://$DOMAIN" 2>/dev/null)
if [ "$HTTP_RESPONSE" == "301" ] || [ "$HTTP_RESPONSE" == "308" ] || [ "$HTTP_RESPONSE" == "000" ]; then
    check_pass "HTTP to HTTPS redirection active"
else
    check_warn "HTTPS redirection may not be working (got HTTP $HTTP_RESPONSE)"
fi
echo ""

echo "6. Testing Bot User-Agent Blocking"
MALICIOUS_UA="sqlmap/1.0"
RESPONSE=$(curl -s -o /dev/null -w "%{http_code}" -A "$MALICIOUS_UA" "https://$DOMAIN" 2>/dev/null)
if [ "$RESPONSE" == "403" ] || [ "$RESPONSE" == "000" ]; then
    check_pass "Malicious user-agents blocked"
else
    check_warn "Malicious user-agent not blocked (response: $RESPONSE)"
fi
echo ""

echo "7. Checking Log Files"
if [ -f "/var/log/caddy/${DOMAIN}.access.log" ]; then
    LOG_SIZE=$(du -h "/var/log/caddy/${DOMAIN}.access.log" | cut -f1)
    check_pass "Access log exists ($LOG_SIZE)"
else
    check_warn "Access log not found at expected location"
fi

if command -v jq &> /dev/null; then
    if head -1 "/var/log/caddy/${DOMAIN}.access.log" 2>/dev/null | jq -e . &> /dev/null; then
        check_pass "Logs are valid JSON format"
    else
        check_warn "Logs may not be in JSON format"
    fi
else
    check_warn "jq not installed, cannot verify JSON format"
fi
echo ""

echo "8. Testing Fail2ban Protection"
if command -v fail2ban-client &> /dev/null; then
    if sudo fail2ban-client status caddy-scan &> /dev/null; then
        check_pass "Fail2ban Caddy jails active"
        
        # Check specific jails
        for jail in caddy-scan caddy-attack caddy-invalid caddy-aggressive; do
            if sudo fail2ban-client status $jail &> /dev/null; then
                BANNED_IPS=$(sudo fail2ban-client status $jail | grep "Currently banned:" | awk '{print $3}')
                if [ "$BANNED_IPS" != "0" ]; then
                    check_warn "$jail has $BANNED_IPS banned IPs (potential attacks detected)"
                fi
            fi
        done
    else
        check_fail "Fail2ban Caddy jails not active"
    fi
else
    check_warn "fail2ban-client not found, cannot verify fail2ban status"
fi
echo ""

echo "=== Validation Complete ==="
echo ""
echo "Next steps:"
echo "1. Review any FAILED checks above"
echo "2. Monitor Caddy logs: tail -f /var/log/caddy/${DOMAIN}.access.log"
echo "3. Monitor fail2ban: sudo tail -f /var/log/fail2ban.log"
echo "4. Test your applications to ensure CSP headers don't break functionality"
