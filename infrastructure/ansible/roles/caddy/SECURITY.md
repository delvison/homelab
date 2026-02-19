# Caddy Security Hardening Documentation

## Overview

This Caddy configuration has been production-hardened with multiple security layers to protect against attackers, bots, and malicious traffic.

## Security Features Implemented

### 1. Admin API Security
- **Binding**: Admin API restricted to `127.0.0.1:2019` (localhost only)
- **Impact**: Prevents external access to Caddy's admin interface

### 2. HTTPS Security Headers (All Services)
- **HSTS**: `max-age=31536000; includeSubDomains; preload`
- **X-Frame-Options**: `DENY` (clickjacking protection)
- **X-Content-Type-Options**: `nosniff` (MIME sniffing protection)
- **X-XSS-Protection**: `1; mode=block`
- **Referrer-Policy**: `strict-origin-when-cross-origin`
- **Permissions-Policy**: Restricts access to device features
- **Server Header**: Removed to prevent version disclosure

### 3. Content Security Policies (Per-Service)
Each service has a tailored CSP to prevent XSS and data injection:
- **Joplin**: Strict CSP for note-taking application
- **Paste**: Allows file uploads with secure defaults
- **RSS**: Allows external image loading for feeds
- **Audiobookshelf**: Media streaming CSP with WebSocket support
- **Mempool**: Bitcoin explorer CSP
- **NC (NextCloud)**: Comprehensive CSP for file management
- **Music**: Media streaming service CSP
- **n**: Standard service CSP

### 4. Rate Limiting
- **Implementation**: Handled by fail2ban via Caddy jails
- **Trigger**: 3+ 429 responses within 60 seconds
- **Ban Duration**: 1-24 hours (progressive)
- **Scope**: Automatic IP blocking at firewall level
- **Note**: Application-level rate limiting requires caddy-rate-limit module

### 5. Request Controls
- **Max Body Size**: 50MB (prevents upload abuse)
- **Header Size**: 1MB limit
- **Timeouts**:
  - Read: 30s
  - Write: 30s
  - Idle: 120s

### 6. Bot & Attack Protection
- **Bad User-Agents**: Blocks 200+ known malicious scanners and bots
- **Attack Paths**: Blocks access to sensitive files:
  - `.env` files
  - `.git` directories
  - Configuration files
  - Admin panels (wp-admin, phpmyadmin, etc.)
  - Docker files
  - Backup directories
- **HTTP Methods**: Blocks CONNECT, TRACE, TRACK, DEBUG, PATCH

### 7. Enhanced Logging
- **Format**: JSON structured logging
- **Rotation**: 100MB files, keep 10, retain for 30 days
- **Fields**: Includes all request details and Tailscale IPs

### 8. Reverse Proxy Headers
All reverse proxies now include:
- `X-Real-IP`: Original client IP
- `X-Forwarded-For`: Client IP chain
- `X-Forwarded-Proto`: Original protocol
- `X-Forwarded-Host`: Original host

### 9. Fail2ban Protection
Four-layer fail2ban protection monitors Caddy logs:

**Jails Configured:**
- **caddy-scan**: Blocks vulnerability scanners (5+ 404s in 60s → 10min ban)
- **caddy-attack**: Blocks attackers hitting protected paths (3+ 403/429s in 60s → 1hr ban)
- **caddy-invalid**: Blocks random domain scanning (5+ invalid hosts in 60s → 10min ban)
- **caddy-aggressive**: Extra protection for persistent attackers (10+ offenses in 5min → 24hr ban)

**Monitoring:**
- Parses JSON access logs at `/var/log/caddy/*.access.log`
- Automatically reloads on Caddy restart
- Ignores legitimate requests (200, 201, 204, 301, 302, 304, 308)

## Tailscale Integration

Internal services (ports 22067, 22026, 22070) are bound to `127.0.0.1` only:
- Accessible only from localhost or Tailscale network
- Not exposed to the public internet
- Your Tailscale IP: `100.64.0.3`

## Deployment

### Prerequisites
- Ansible vault file `vars/vault.yml` with:
  - `cloudflare_api_token`
  - `caddy_domain`
  - Server variables (`server1`, `server2`, `server3`, `server4`)

### Deployment Commands
```bash
# Deploy Caddy with hardening
ansible-playbook caddy_server.yaml --ask-vault-pass

# Validate configuration
ansible-playbook caddy_server.yaml --ask-vault-pass --check
```

### Verification
After deployment, verify:
1. Admin API not accessible externally: `curl http://YOUR_SERVER:2019/config` (should fail)
2. Security headers present: `curl -I https://joplin.yourdomain.com`
3. Rate limiting active: Rapid requests should start returning 429
4. Attack paths blocked: `curl https://yourdomain.com/.env` (should return empty)
5. Fail2ban active: `sudo fail2ban-client status caddy-scan`

## Monitoring

### Log Files
- **Access logs**: `/var/log/caddy/{domain}.access.log`
- **Error logs**: `/var/log/caddy/error.log`
- **Fail2ban logs**: `/var/log/fail2ban.log`

### Key Metrics to Monitor
- 429 responses (rate limiting triggers)
- 403 responses (attack blocking)
- Blocked user-agent attempts
- Fail2ban banned IPs per jail
- Repeat offenders (caddy-aggressive jail)

### Automated Updates
- **Caddy**: Manual update via playbook when new versions released

## Troubleshooting

### Rate Limiting Too Aggressive
Increase burst size in global options:
```
rate_limit {
    zone static_zone {
        key static
        window 1s
        events 20
    }
    burst 80  # Increased from 40
}
```

### Legitimate Services Blocked
Add exceptions in the `bot_protection` snippet:
```
@good_bot {
    header User-Agent *legitimate-service*
}
respond @good_bot 200
```

### CSP Breaking Functionality
Check browser console for CSP violations and update per-service CSP headers. Use `Content-Security-Policy-Report-Only` first to test.

### Fail2ban Not Banning
Check fail2ban status and logs:
```bash
# Check if fail2ban is running
sudo systemctl status fail2ban

# Check jail status
sudo fail2ban-client status
sudo fail2ban-client status caddy-scan

# Check fail2ban logs
sudo tail -f /var/log/fail2ban.log

# Test filter against logs
sudo fail2ban-regex /var/log/caddy/YOURDOMAIN.access.log /etc/fail2ban/filter.d/caddy.conf

# Unban an IP manually
sudo fail2ban-client set caddy-scan unbanip 1.2.3.4
```

### Fail2ban Too Aggressive
Adjust thresholds in `/etc/fail2ban/jail.d/caddy.conf`:
- Increase `maxretry` (default: 3-5)
- Increase `findtime` (default: 60s)
- Decrease `bantime` (default: 600-3600s)

Then reload: `sudo systemctl reload fail2ban`

## Security Checklist

- [ ] Admin API bound to localhost
- [ ] HSTS preload enabled
- [ ] All services have CSP headers
- [ ] Rate limiting active (test with `ab` or `wrk`)
- [ ] Attack paths blocked (test with `curl`)
- [ ] Bad user-agents blocked
- [ ] Logs rotating properly
- [ ] Tailscale-only services accessible
- [ ] Firewall rules allow only necessary ports
- [ ] Fail2ban protecting Caddy (check with `sudo fail2ban-client status`)
- [ ] Fail2ban jails catching attacks (check `/var/log/fail2ban.log`)

## References

- [Caddy Security Headers](https://caddyserver.com/docs/caddyfile/directives/header)
- [Caddy Rate Limiting](https://caddyserver.com/docs/json/apps/http/servers/routes/handle/rate_limit/)
- [Content Security Policy](https://developer.mozilla.org/en-US/docs/Web/HTTP/CSP)
- [Tailscale Best Practices](https://tailscale.com/kb/1170/security-hardening)
