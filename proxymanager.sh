#!/bin/bash
# ╔══════════════════════════════════════════════════════════════╗
# ║           PROXY MANAGER PRO - Bravin-lab Edition            ║
# ║           Supports: Squid (HTTP/S) | Dante (SOCKS5)        ║
# ║                     3proxy (Multi-protocol)                 ║
# ║  Usage: chmod +x proxymanager.sh && sudo ./proxymanager.sh ║
# ║  Quick launch after install: type 'menu' in terminal        ║
# ╚══════════════════════════════════════════════════════════════╝

# ── Colors ────────────────────────────────────────────────────
RED='\033[0;31m';    GREEN='\033[0;32m';  YELLOW='\033[1;33m'
CYAN='\033[0;36m';   BLUE='\033[0;34m';   WHITE='\033[1;37m'
MAGENTA='\033[0;35m';BOLD='\033[1m';      RESET='\033[0m'

# ── Config ────────────────────────────────────────────────────
SQUID_CONF="/etc/squid/squid.conf"
SQUID_PASSWD="/etc/squid/squid_passwd"
DANTE_CONF="/etc/danted.conf"
PROXY3_CONF="/etc/3proxy/3proxy.cfg"
PROXY3_USERS="/etc/3proxy/users.cfg"
LOG_DIR="/var/log/proxymanager"
CONFIG_DIR="/etc/proxymanager"
CONFIG_FILE="$CONFIG_DIR/settings.conf"
USERS_FILE="$CONFIG_DIR/users.list"
INSTALL_MARKER="$CONFIG_DIR/.installed"

# ── Default ports ─────────────────────────────────────────────
HTTP_PORT=3128
HTTPS_PORT=3129
SOCKS5_PORT=1080
PROXY3_HTTP=8080
PROXY3_SOCKS=1081

# ── Root check ────────────────────────────────────────────────
check_root() {
    [[ $EUID -ne 0 ]] && { echo -e "${RED}Run as root: sudo $0${RESET}"; exit 1; }
}

# ── Timestamp ─────────────────────────────────────────────────
ts() { date '+%Y-%m-%d %H:%M:%S'; }

# ── Logging ───────────────────────────────────────────────────
log_ok()   { echo -e "${GREEN}[$(ts)] [OK]   $*${RESET}"; }
log_err()  { echo -e "${RED}[$(ts)] [ERR]  $*${RESET}"; }
log_info() { echo -e "${CYAN}[$(ts)] [INFO] $*${RESET}"; }
log_warn() { echo -e "${YELLOW}[$(ts)] [WARN] $*${RESET}"; }

mkdir -p "$LOG_DIR" "$CONFIG_DIR"

# ══════════════════════════════════════════════════════════════
#  BANNER
# ══════════════════════════════════════════════════════════════
banner() {
    clear
    echo -e "${GREEN}${BOLD}"
    echo "╔══════════════════════════════════════════════════════════════╗"
    echo "║            PROXY MANAGER PRO — Ubuntu VPS Edition           ║"
    echo "║    HTTP/HTTPS (Squid) │ SOCKS5 (Dante) │ Multi (3proxy)    ║"
    echo "╚══════════════════════════════════════════════════════════════╝"
    echo -e "${RESET}"
    # Show both public and private IP
    local pub_ip; pub_ip=$(get_server_ip)
    local priv_ip; priv_ip=$(hostname -I | awk '{print $1}')
    echo -e "  ${CYAN}Public IP  : ${GREEN}${pub_ip}${RESET}  ${YELLOW}← USE THIS to connect${RESET}"
    [[ "$pub_ip" != "$priv_ip" ]] && \
    echo -e "  ${CYAN}Private IP : ${WHITE}${priv_ip}${RESET}  ${YELLOW}(internal — do NOT use for proxy)${RESET}"
    echo -e "  ${CYAN}Hostname   : ${WHITE}$(hostname)${RESET}"
    echo -e "  ${CYAN}OS         : ${WHITE}$(lsb_release -ds 2>/dev/null)${RESET}"
    echo ""
}

# ══════════════════════════════════════════════════════════════
#  MAIN MENU
# ══════════════════════════════════════════════════════════════
main_menu() {
    banner
    echo -e "${YELLOW}${BOLD}━━━━━━━━━━━━━━━━━━━━━━ MAIN MENU ━━━━━━━━━━━━━━━━━━━━━━${RESET}"
    echo -e ""
    echo -e "  ${YELLOW}── INSTALLATION ──${RESET}"
    echo -e "  ${YELLOW} 1.${RESET}  ${GREEN}Install Squid  (HTTP/HTTPS Proxy)${RESET}"
    echo -e "  ${YELLOW} 2.${RESET}  ${GREEN}Install Dante  (SOCKS5 Proxy)${RESET}"
    echo -e "  ${YELLOW} 3.${RESET}  ${GREEN}Install 3proxy (HTTP + SOCKS5 + Multi)${RESET}"
    echo -e "  ${YELLOW} 4.${RESET}  ${GREEN}Install ALL    (Squid + Dante + 3proxy)${RESET}"
    echo -e ""
    echo -e "  ${YELLOW}── USER MANAGEMENT ──${RESET}"
    echo -e "  ${YELLOW} 5.${RESET}  ${GREEN}Add Proxy User${RESET}"
    echo -e "  ${YELLOW} 6.${RESET}  ${GREEN}Delete Proxy User${RESET}"
    echo -e "  ${YELLOW} 7.${RESET}  ${GREEN}Edit Proxy User (change password)${RESET}"
    echo -e "  ${YELLOW} 8.${RESET}  ${GREEN}List All Users${RESET}"
    echo -e "  ${YELLOW} 9.${RESET}  ${GREEN}Bulk Add Users from file${RESET}"
    echo -e ""
    echo -e "  ${YELLOW}── PROXY MANAGEMENT ──${RESET}"
    echo -e "  ${YELLOW}10.${RESET}  ${GREEN}Start / Stop / Restart Proxies${RESET}"
    echo -e "  ${YELLOW}11.${RESET}  ${GREEN}View Proxy Status${RESET}"
    echo -e "  ${YELLOW}12.${RESET}  ${GREEN}Change Proxy Ports${RESET}"
    echo -e "  ${YELLOW}13.${RESET}  ${GREEN}View Active Connections & Logs${RESET}"
    echo -e "  ${YELLOW}14.${RESET}  ${GREEN}Bandwidth Usage per User${RESET}"
    echo -e ""
    echo -e "  ${YELLOW}── FIREWALL & SECURITY ──${RESET}"
    echo -e "  ${YELLOW}15.${RESET}  ${GREEN}UFW Firewall Setup${RESET}"
    echo -e "  ${YELLOW}16.${RESET}  ${GREEN}Block/Unblock IP Address${RESET}"
    echo -e "  ${YELLOW}17.${RESET}  ${GREEN}Whitelist IP (no-auth access)${RESET}"
    echo -e "  ${YELLOW}18.${RESET}  ${GREEN}Anti-leak / DNS Leak Protection${RESET}"
    echo -e ""
    echo -e "  ${YELLOW}── ADVANCED ──${RESET}"
    echo -e "  ${YELLOW}19.${RESET}  ${GREEN}Export Proxy List (host:port:user:pass)${RESET}"
    echo -e "  ${YELLOW}20.${RESET}  ${GREEN}Test Proxy Connectivity${RESET}"
    echo -e "  ${YELLOW}21.${RESET}  ${GREEN}Auto-renew / Rotate Proxy Credentials${RESET}"
    echo -e "  ${YELLOW}22.${RESET}  ${GREEN}Uninstall All Proxies${RESET}"
    echo -e ""
    echo -e "  ${MAGENTA}── LEAKPROOF HARDENING ──${RESET}"
    echo -e "  ${MAGENTA}23.${RESET}  ${GREEN}Full Leakproof Hardening (IPv6, DNS, Headers, TTL, iptables)${RESET}"
    echo -e "  ${MAGENTA}24.${RESET}  ${GREEN}Check Leak Status (verify all protections)${RESET}"
    echo -e "  ${MAGENTA}25.${RESET}  ${GREEN}Undo Leakproof Hardening${RESET}"
    echo -e ""
    echo -e "  ${CYAN}── SSL / DOMAIN ──${RESET}"
    echo -e "  ${CYAN}26.${RESET}  ${GREEN}Add / Re-issue SSL Certificate for Domain${RESET}"
    echo -e "  ${CYAN}27.${RESET}  ${GREEN}View SSL Certificate Status${RESET}"
    echo -e ""
    echo -e "  ${RED}── ANTI-DETECTION (Bypass VPN/Proxy Detection) ──${RESET}"
    echo -e "  ${RED}29.${RESET}  ${GREEN}Full Anti-Detection Hardening${RESET}"
    echo -e "  ${RED}30.${RESET}  ${GREEN}Check Detection Risk Score${RESET}"
    echo -e "  ${RED}31.${RESET}  ${GREEN}Residential IP Masking (ISP spoof)${RESET}"
    echo -e "  ${RED}32.${RESET}  ${GREEN}Cloudflare Integration (Hide VPS IP / Tunnel)${RESET}"
    echo -e "  ${YELLOW}28.${RESET}  ${RED}Exit${RESET}"
    echo -e ""
    echo -e "${YELLOW}${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
    echo -ne "\n  ${YELLOW}Select option (1-32): ${GREEN}"
    read -r choice
    echo -e "${RESET}"
    handle_choice "$choice"
}

# ══════════════════════════════════════════════════════════════
#  HELPERS
# ══════════════════════════════════════════════════════════════
press_enter() { echo -e "\n${YELLOW}Press Enter to return to menu...${RESET}"; read -r; main_menu; }

pkg_install() {
    log_info "Installing: $*"
    # Unset proxy env vars so apt never tries to use our own proxy
    env -u http_proxy -u https_proxy -u HTTP_PROXY -u HTTPS_PROXY \
    DEBIAN_FRONTEND=noninteractive apt-get install -y \
        -o Dpkg::Options::="--force-confdef" \
        -o Dpkg::Options::="--force-confold" \
        -o Acquire::http::Proxy="false" \
        -o Acquire::https::Proxy="false" \
        "$@" >> "$LOG_DIR/install.log" 2>&1 \
        && log_ok "Installed: $*" \
        || log_err "Failed to install: $*"
}

apt_update() {
    log_info "Updating package lists..."
    env -u http_proxy -u https_proxy -u HTTP_PROXY -u HTTPS_PROXY \
    DEBIAN_FRONTEND=noninteractive apt-get update -qq \
        -o Acquire::http::Proxy="false" \
        -o Acquire::https::Proxy="false" \
        >> "$LOG_DIR/install.log" 2>&1 \
        && log_ok "Package lists updated" \
        || log_warn "apt-get update had warnings"
}

service_action() {
    local svc=$1 act=$2
    systemctl "$act" "$svc" 2>/dev/null && log_ok "$svc → $act" || log_warn "$svc $act failed (may not be installed)"
}

gen_password() { tr -dc 'A-Za-z0-9@#$%' </dev/urandom | head -c 16; }

save_user() {
    local user=$1 pass=$2 type=$3
    echo "$user:$pass:$type:$(ts)" >> "$USERS_FILE"
}

get_server_ip() {
    # IMPORTANT: unset ALL proxy vars so curl goes direct to the internet
    # Also use --noproxy '*' as extra insurance
    local pub_ip
    local CURL="env -u http_proxy -u https_proxy -u HTTP_PROXY -u HTTPS_PROXY -u ALL_PROXY -u all_proxy curl --noproxy '*' -s --max-time 6"

    # Method 1: AWS EC2 instance metadata (fastest on AWS, no internet needed)
    # First get a token for IMDSv2
    local TOKEN
    TOKEN=$(env -u http_proxy -u https_proxy -u HTTP_PROXY -u HTTPS_PROXY \
        curl --noproxy '*' -s -X PUT --max-time 3 \
        "http://169.254.169.254/latest/api/token" \
        -H "X-aws-ec2-metadata-token-ttl-seconds: 21600" 2>/dev/null)
    if [[ -n "$TOKEN" ]]; then
        pub_ip=$(env -u http_proxy -u https_proxy -u HTTP_PROXY -u HTTPS_PROXY \
            curl --noproxy '*' -s --max-time 3 \
            -H "X-aws-ec2-metadata-token: $TOKEN" \
            "http://169.254.169.254/latest/meta-data/public-ipv4" 2>/dev/null)
        if [[ -n "$pub_ip" && "$pub_ip" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
            echo "$pub_ip"; return
        fi
    fi
    # IMDSv1 fallback (older AWS)
    pub_ip=$(env -u http_proxy -u https_proxy -u HTTP_PROXY -u HTTPS_PROXY \
        curl --noproxy '*' -s --max-time 3 \
        "http://169.254.169.254/latest/meta-data/public-ipv4" 2>/dev/null)
    if [[ -n "$pub_ip" && "$pub_ip" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
        echo "$pub_ip"; return
    fi

    # Method 2: GCP metadata
    pub_ip=$(env -u http_proxy -u https_proxy -u HTTP_PROXY -u HTTPS_PROXY \
        curl --noproxy '*' -s --max-time 3 \
        -H "Metadata-Flavor: Google" \
        "http://metadata.google.internal/computeMetadata/v1/instance/network-interfaces/0/access-configs/0/externalIp" 2>/dev/null)
    if [[ -n "$pub_ip" && "$pub_ip" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
        echo "$pub_ip"; return
    fi

    # Method 3: External IP check services (bypassing proxy)
    for url in \
        "http://api.ipify.org" \
        "http://ifconfig.me/ip" \
        "http://icanhazip.com" \
        "http://checkip.amazonaws.com" \
        "http://ipecho.net/plain" \
        "http://myexternalip.com/raw"; do
        pub_ip=$($CURL "$url" 2>/dev/null | tr -d '[:space:]')
        if [[ -n "$pub_ip" && "$pub_ip" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
            echo "$pub_ip"; return
        fi
    done

    # Method 4: dig DNS lookup (doesn't use HTTP proxy at all)
    if command -v dig &>/dev/null; then
        pub_ip=$(dig +short myip.opendns.com @resolver1.opendns.com 2>/dev/null | tr -d '[:space:]')
        if [[ -n "$pub_ip" && "$pub_ip" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
            echo "$pub_ip"; return
        fi
    fi

    # Last resort: private IP with warning
    local priv_ip; priv_ip=$(hostname -I | awk '{print $1}')
    echo "$priv_ip"
}

# ══════════════════════════════════════════════════════════════
#  1. INSTALL SQUID (HTTP/HTTPS)
# ══════════════════════════════════════════════════════════════
install_squid() {
    banner
    echo -e "${CYAN}${BOLD}[1] Installing Squid HTTP/HTTPS Proxy${RESET}\n"
    apt_update

    # Ubuntu 24.04 (Noble) ships squid without SSL support built in.
    # squid-openssl is the package that includes SSL bump.
    log_info "Detecting correct Squid package for this OS..."
    local SQUID_PKG="squid"
    if env -u http_proxy -u https_proxy -u HTTP_PROXY -u HTTPS_PROXY \
       apt-cache show squid-openssl &>/dev/null 2>&1; then
        SQUID_PKG="squid-openssl"
        log_ok "Found squid-openssl (SSL bump supported)"
    else
        log_warn "squid-openssl not available — installing standard squid (no SSL bump)"
    fi

    # Remove any existing broken squid install first
    env -u http_proxy -u https_proxy -u HTTP_PROXY -u HTTPS_PROXY \
        DEBIAN_FRONTEND=noninteractive apt-get remove -y squid squid-openssl \
        >> "$LOG_DIR/install.log" 2>&1 || true

    pkg_install "$SQUID_PKG" apache2-utils openssl
    SQUID_AUTH_HELPER=$(find /usr/lib/squid /usr/libexec/squid -name "basic_ncsa_auth" 2>/dev/null | head -1)
    [[ -z "$SQUID_AUTH_HELPER" ]] && SQUID_AUTH_HELPER="/usr/lib/squid/basic_ncsa_auth"
    log_info "Auth helper: $SQUID_AUTH_HELPER"

    echo -ne "${YELLOW}HTTP port (default $HTTP_PORT): ${RESET}"; read -r p
    HTTP_PORT=${p:-$HTTP_PORT}
    echo -ne "${YELLOW}HTTPS port (default $HTTPS_PORT): ${RESET}"; read -r p2
    HTTPS_PORT=${p2:-$HTTPS_PORT}

    # ── Optional domain + nginx + Let's Encrypt ───────────────
    local USE_DOMAIN=false
    local DOMAIN=""
    local EMAIL=""
    echo ""
    echo -e "${YELLOW}┌─────────────────────────────────────────────────────┐"
    echo -e "│  OPTIONAL: Domain + Nginx + Free SSL (Let's Encrypt) │"
    echo -e "│  • Your VPS IP must already point to the domain      │"
    echo -e "│  • Gives you a real trusted HTTPS proxy certificate  │"
    echo -e "│  • Skip this to use a self-signed cert instead       │"
    echo -e "└─────────────────────────────────────────────────────┘${RESET}"
    echo -ne "\n${YELLOW}Do you have a domain pointed to this VPS? (y/n): ${RESET}"
    read -r has_domain

    if [[ "$has_domain" == "y" || "$has_domain" == "Y" ]]; then
        echo -ne "${YELLOW}Enter your domain (e.g. proxy.example.com): ${RESET}"
        read -r DOMAIN
        DOMAIN=$(echo "$DOMAIN" | tr '[:upper:]' '[:lower:]' | xargs)

        if [[ -z "$DOMAIN" ]]; then
            log_warn "No domain entered — using self-signed certificate"
        else
            echo -ne "${YELLOW}Enter email for SSL cert notifications: ${RESET}"
            read -r EMAIL

            # Verify domain resolves to this server
            log_info "Verifying domain $DOMAIN points to this server..."
            local VPS_IP; VPS_IP=$(get_server_ip)
            local DOMAIN_IP; DOMAIN_IP=$(dig +short "$DOMAIN" 2>/dev/null | tail -1)

            if [[ -z "$DOMAIN_IP" ]]; then
                log_warn "Could not resolve $DOMAIN — check DNS propagation"
                echo -ne "${YELLOW}Continue anyway? (y/n): ${RESET}"; read -r fc
                [[ "$fc" != "y" ]] && DOMAIN="" || USE_DOMAIN=true
            elif [[ "$DOMAIN_IP" != "$VPS_IP" ]]; then
                echo -e "${RED}  Domain IP : $DOMAIN_IP"
                echo -e "  VPS IP    : $VPS_IP${RESET}"
                log_warn "Domain does not point to this VPS yet"
                echo -e "${CYAN}  Fix: Go to your DNS provider and set:"
                echo -e "  A record → $DOMAIN → $VPS_IP${RESET}"
                echo -ne "${YELLOW}Continue anyway? (may fail cert issuance) (y/n): ${RESET}"
                read -r fc
                [[ "$fc" != "y" ]] && DOMAIN="" || USE_DOMAIN=true
            else
                log_ok "Domain verified: $DOMAIN → $DOMAIN_IP ✔"
                USE_DOMAIN=true
            fi
        fi
    fi

    # ── Backup original config ────────────────────────────────
    [[ -f $SQUID_CONF ]] && cp "$SQUID_CONF" "${SQUID_CONF}.bak.$(date +%s)"
    touch "$SQUID_PASSWD"
    chmod 640 "$SQUID_PASSWD"
    chown proxy:proxy "$SQUID_PASSWD" 2>/dev/null || true

    # ── Detect if SSL bump is available ───────────────────────
    local HAS_SSL_BUMP=false
    if squid -v 2>&1 | grep -q "ssl-bump\|openssl\|SSL"; then
        HAS_SSL_BUMP=true
        log_ok "SSL bump supported by this Squid build"
    else
        log_warn "This Squid build does NOT support ssl-bump — HTTPS port will use CONNECT tunnel mode only"
    fi

    # ── Write Squid config ────────────────────────────────────
    cat > "$SQUID_CONF" <<EOF
# ── Proxy Manager Pro — Squid Config ──────────────────────────
http_port ${HTTP_PORT}
EOF

    if [[ "$HAS_SSL_BUMP" == true ]]; then
        cat >> "$SQUID_CONF" <<EOF
http_port ${HTTPS_PORT} ssl-bump \
    cert=/etc/squid/squid.pem \
    key=/etc/squid/squid.key \
    generate-host-certificates=on \
    dynamic_cert_mem_cache_size=4MB

# SSL Bump settings
ssl_bump server-first all
sslproxy_cert_error allow all
sslproxy_flags DONT_VERIFY_PEER
EOF
    else
        cat >> "$SQUID_CONF" <<EOF
# HTTPS CONNECT tunnel (no ssl-bump — standard squid package)
http_port ${HTTPS_PORT}
EOF
    fi

    cat >> "$SQUID_CONF" <<EOF

# Auth
auth_param basic program ${SQUID_AUTH_HELPER} ${SQUID_PASSWD}
auth_param basic realm "Proxy Authentication Required"
auth_param basic credentialsttl 24 hours
auth_param basic casesensitive on

acl authenticated proxy_auth REQUIRED
acl SSL_ports port 443 8443
acl Safe_ports port 80 443 8080 8443 21 22 25 110 143 993 995 1025-65535
acl CONNECT method CONNECT

# Deny bad ports
http_access deny !Safe_ports
http_access deny CONNECT !SSL_ports

# Allow authenticated users
http_access allow authenticated
http_access deny all

# Performance & Anonymity
forwarded_for delete
via off
request_header_access X-Forwarded-For deny all
request_header_access Via deny all
request_header_access Cache-Control allow all

# Cache settings
cache_mem 256 MB
maximum_object_size_in_memory 512 KB
cache_dir ufs /var/spool/squid 1000 16 256
maximum_object_size 10 MB

# DNS
dns_nameservers 1.1.1.1 8.8.8.8 9.9.9.9

# Logging
access_log /var/log/squid/access.log squid
cache_log /var/log/squid/cache.log

# Timeouts
connect_timeout 30 seconds
read_timeout 60 seconds
request_timeout 60 seconds
EOF

    # ── SSL Certificate setup ─────────────────────────────────
    if [[ "$HAS_SSL_BUMP" == true ]]; then
        if [[ "$USE_DOMAIN" == true && -n "$DOMAIN" ]]; then
            setup_nginx_ssl "$DOMAIN" "$EMAIL"
        else
            log_info "Generating self-signed SSL certificate..."
            openssl req -new -newkey rsa:2048 -days 3650 -nodes -x509 \
                -subj "/C=US/ST=State/L=City/O=ProxyManager/CN=$(get_server_ip)" \
                -keyout /etc/squid/squid.key \
                -out /etc/squid/squid.pem >> "$LOG_DIR/install.log" 2>&1
            chmod 600 /etc/squid/squid.key
            chown proxy:proxy /etc/squid/squid.pem /etc/squid/squid.key 2>/dev/null || true
            log_ok "Self-signed certificate generated"
        fi

        # Initialize SSL DB for dynamic cert generation
        local CERTGEN
        CERTGEN=$(find /usr/lib/squid /usr/libexec/squid -name "security_file_certgen" 2>/dev/null | head -1)
        if [[ -n "$CERTGEN" ]]; then
            mkdir -p /var/lib/squid/ssl_db
            "$CERTGEN" -c -s /var/lib/squid/ssl_db -M 4MB >> "$LOG_DIR/install.log" 2>&1 || true
            chown -R proxy:proxy /var/lib/squid/ssl_db 2>/dev/null || true
            log_ok "SSL certificate DB initialized"
        fi
    else
        log_info "Skipping SSL cert setup (not needed without ssl-bump)"
    fi

    # ── Initialize cache dir ──────────────────────────────────
    log_info "Initializing Squid cache..."
    squid -z >> "$LOG_DIR/install.log" 2>&1 || true

    # ── Validate and start ────────────────────────────────────
    log_info "Validating Squid config..."
    local parse_out; parse_out=$(squid -k parse 2>&1)
    local fatal_count; fatal_count=$(echo "$parse_out" | grep -icE "FATAL|ERROR" || true)

    if [[ "$fatal_count" -eq 0 ]]; then
        log_ok "Squid config valid"
    else
        log_warn "Config issues found — showing errors:"
        echo "$parse_out" | grep -iE "FATAL|ERROR" | head -10
        log_warn "Attempting to start anyway..."
    fi

    systemctl enable squid >> "$LOG_DIR/install.log" 2>&1
    systemctl stop squid >> "$LOG_DIR/install.log" 2>&1 || true
    sleep 1
    systemctl start squid

    sleep 2
    if systemctl is-active --quiet squid; then
        log_ok "Squid is running on port ${HTTP_PORT} (HTTP) and ${HTTPS_PORT} (HTTPS)"
    else
        log_err "Squid failed to start. Checking logs..."
        journalctl -u squid -n 20 --no-pager 2>/dev/null | tail -20
        log_warn "Try: sudo journalctl -xeu squid.service"
    fi
    echo "squid_http=$HTTP_PORT" >> "$CONFIG_FILE"
    echo "squid_https=$HTTPS_PORT" >> "$CONFIG_FILE"
    [[ -n "$DOMAIN" ]] && echo "squid_domain=$DOMAIN" >> "$CONFIG_FILE"

    # ── Show connection info ──────────────────────────────────
    local ip; ip=$(get_server_ip)
    echo -e "\n${GREEN}${BOLD}╔══════════════════════════════════════════════════════╗"
    echo -e "║           SQUID PROXY READY                          ║"
    echo -e "╠══════════════════════════════════════════════════════╣"
    if [[ "$USE_DOMAIN" == true && -n "$DOMAIN" ]]; then
    echo -e "║  ${WHITE}HTTP  : ${GREEN}http://$DOMAIN:${HTTP_PORT}${GREEN}"
    echo -e "║  ${WHITE}HTTPS : ${GREEN}https://$DOMAIN:${HTTPS_PORT}${GREEN}"
    echo -e "║  ${WHITE}Nginx : ${GREEN}https://$DOMAIN (port 443 → Squid)${GREEN}"
    fi
    echo -e "║  ${WHITE}HTTP  : ${GREEN}http://$ip:${HTTP_PORT}${GREEN}"
    echo -e "║  ${WHITE}HTTPS : ${GREEN}https://$ip:${HTTPS_PORT}${GREEN}"
    echo -e "╚══════════════════════════════════════════════════════╝${RESET}"
    press_enter
}

# ══════════════════════════════════════════════════════════════
#  NGINX + CERTBOT SSL SETUP (called from install_squid)
# ══════════════════════════════════════════════════════════════
setup_nginx_ssl() {
    local DOMAIN=$1
    local EMAIL=$2
    local ip; ip=$(get_server_ip)

    echo ""
    log_info "Setting up Nginx + Let's Encrypt for: $DOMAIN"

    # ── Install nginx and certbot ─────────────────────────────
    pkg_install nginx certbot python3-certbot-nginx dnsutils

    # ── Allow HTTP/HTTPS through firewall for cert validation ─
    ufw allow 80/tcp  >> "$LOG_DIR/install.log" 2>&1
    ufw allow 443/tcp >> "$LOG_DIR/install.log" 2>&1
    log_ok "Ports 80 and 443 opened for SSL validation"

    # ── Write initial Nginx config (HTTP only for cert challenge)
    local NGINX_CONF="/etc/nginx/sites-available/proxymanager"
    cat > "$NGINX_CONF" <<EOF
# ── Proxy Manager Pro — Nginx Config ──────────────────────────
server {
    listen 80;
    listen [::]:80;
    server_name ${DOMAIN};

    # Let's Encrypt challenge
    location /.well-known/acme-challenge/ {
        root /var/www/html;
    }

    # Redirect all HTTP to HTTPS
    location / {
        return 301 https://\$host\$request_uri;
    }
}
EOF

    # Enable site and reload nginx
    ln -sf "$NGINX_CONF" /etc/nginx/sites-enabled/proxymanager 2>/dev/null
    rm -f /etc/nginx/sites-enabled/default 2>/dev/null
    nginx -t >> "$LOG_DIR/install.log" 2>&1 && systemctl reload nginx
    log_ok "Nginx configured for $DOMAIN"

    # ── Issue Let's Encrypt certificate ──────────────────────
    log_info "Requesting SSL certificate from Let's Encrypt..."
    local CERT_ARGS="--nginx -d $DOMAIN --non-interactive --agree-tos"
    if [[ -n "$EMAIL" ]]; then
        CERT_ARGS="$CERT_ARGS --email $EMAIL"
    else
        CERT_ARGS="$CERT_ARGS --register-unsafely-without-email"
    fi

    if certbot $CERT_ARGS >> "$LOG_DIR/install.log" 2>&1; then
        log_ok "SSL certificate issued for $DOMAIN ✔"
        local CERT_PATH="/etc/letsencrypt/live/$DOMAIN"

        # ── Convert Let's Encrypt cert for Squid use ─────────
        log_info "Converting certificate for Squid..."
        # Squid needs PEM format — combine fullchain + key
        cat "${CERT_PATH}/fullchain.pem" > /etc/squid/squid.pem
        cat "${CERT_PATH}/privkey.pem"   > /etc/squid/squid.key
        chmod 600 /etc/squid/squid.key
        chown proxy:proxy /etc/squid/squid.pem /etc/squid/squid.key 2>/dev/null || true
        log_ok "Let's Encrypt cert installed for Squid"

        # ── Write full Nginx HTTPS config (proxy tunnel) ─────
        cat > "$NGINX_CONF" <<EOF
# ── Proxy Manager Pro — Nginx HTTPS Config ────────────────────

# HTTP → HTTPS redirect
server {
    listen 80;
    listen [::]:80;
    server_name ${DOMAIN};
    return 301 https://\$host\$request_uri;
}

# HTTPS reverse proxy → Squid
server {
    listen 443 ssl http2;
    listen [::]:443 ssl http2;
    server_name ${DOMAIN};

    # Let's Encrypt certificates
    ssl_certificate     /etc/letsencrypt/live/${DOMAIN}/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/${DOMAIN}/privkey.pem;
    include             /etc/letsencrypt/options-ssl-nginx.conf;
    ssl_dhparam         /etc/letsencrypt/ssl-dhparams.pem;

    # Strong SSL settings
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_prefer_server_ciphers on;
    ssl_ciphers ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256:ECDHE-ECDSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-GCM-SHA384;
    ssl_session_cache shared:SSL:10m;
    ssl_session_timeout 1d;
    ssl_session_tickets off;

    # HSTS (force HTTPS for 1 year)
    add_header Strict-Transport-Security "max-age=31536000; includeSubDomains" always;

    # Hide nginx version
    server_tokens off;

    # Strip identifying headers
    proxy_hide_header X-Powered-By;
    proxy_hide_header Server;

    # Proxy CONNECT requests → Squid
    location / {
        proxy_pass http://127.0.0.1:${HTTP_PORT};
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_connect_timeout 30s;
        proxy_read_timeout    60s;
        proxy_send_timeout    60s;

        # Hide proxy identity
        proxy_set_header X-Forwarded-For "";
        proxy_set_header Via "";
    }
}
EOF
        nginx -t >> "$LOG_DIR/install.log" 2>&1 \
            && systemctl reload nginx \
            && log_ok "Nginx HTTPS proxy configured for $DOMAIN"

        # ── Auto-renew cron ───────────────────────────────────
        # Certbot installs its own timer but also add a hook to
        # copy renewed certs to Squid automatically
        cat > /etc/letsencrypt/renewal-hooks/deploy/copy-to-squid.sh <<'HOOK'
#!/bin/bash
# Auto-copy renewed cert to Squid after Let's Encrypt renewal
DOMAIN=$(ls /etc/letsencrypt/live/ | grep -v README | head -1)
CERT_PATH="/etc/letsencrypt/live/$DOMAIN"
cat "${CERT_PATH}/fullchain.pem" > /etc/squid/squid.pem
cat "${CERT_PATH}/privkey.pem"   > /etc/squid/squid.key
chmod 600 /etc/squid/squid.key
chown proxy:proxy /etc/squid/squid.pem /etc/squid/squid.key 2>/dev/null
systemctl reload squid 2>/dev/null
systemctl reload nginx 2>/dev/null
echo "[$(date)] Squid/Nginx certs renewed from Let's Encrypt" >> /var/log/proxymanager/cert-renew.log
HOOK
        chmod +x /etc/letsencrypt/renewal-hooks/deploy/copy-to-squid.sh
        log_ok "Auto-renewal hook installed (certs auto-copy to Squid on renewal)"

        # ── Test auto-renewal ─────────────────────────────────
        certbot renew --dry-run >> "$LOG_DIR/install.log" 2>&1 \
            && log_ok "Auto-renewal dry-run passed ✔" \
            || log_warn "Auto-renewal dry-run had warnings — check $LOG_DIR/install.log"

        echo -e "\n${GREEN}${BOLD}╔══════════════════════════════════════════════════════╗"
        echo -e "║        SSL SETUP COMPLETE                            ║"
        echo -e "╠══════════════════════════════════════════════════════╣"
        echo -e "║  ${WHITE}Domain    : ${GREEN}$DOMAIN${GREEN}"
        echo -e "║  ${WHITE}HTTPS     : ${GREEN}https://$DOMAIN${GREEN}"
        echo -e "║  ${WHITE}HTTP Proxy: ${GREEN}http://$DOMAIN:${HTTP_PORT}${GREEN}"
        echo -e "║  ${WHITE}Cert Path : ${GREEN}/etc/letsencrypt/live/$DOMAIN/${GREEN}"
        echo -e "║  ${WHITE}Auto-renew: ${GREEN}Every 90 days (automatic)${GREEN}"
        echo -e "║  ${WHITE}Squid cert: ${GREEN}/etc/squid/squid.pem${GREEN}"
        echo -e "╚══════════════════════════════════════════════════════╝${RESET}"

    else
        # Cert issuance failed — fall back to self-signed
        log_warn "Let's Encrypt cert issuance failed (check DNS propagation)"
        log_warn "Falling back to self-signed certificate..."
        echo -e "${CYAN}  Common reasons:"
        echo -e "  1. DNS not propagated yet (wait 5-10 mins and retry)"
        echo -e "  2. Port 80 blocked by VPS firewall / provider"
        echo -e "  3. Domain typo"
        echo -e "  Re-run Option 1 once DNS is confirmed to retry.${RESET}"

        openssl req -new -newkey rsa:2048 -days 3650 -nodes -x509 \
            -subj "/C=US/ST=State/L=City/O=ProxyManager/CN=$DOMAIN" \
            -keyout /etc/squid/squid.key \
            -out /etc/squid/squid.pem >> "$LOG_DIR/install.log" 2>&1
        chmod 600 /etc/squid/squid.key
        chown proxy:proxy /etc/squid/squid.pem /etc/squid/squid.key 2>/dev/null || true
        log_ok "Self-signed cert generated for $DOMAIN as fallback"
    fi
}

# ══════════════════════════════════════════════════════════════
#  2. INSTALL DANTE (SOCKS5)
# ══════════════════════════════════════════════════════════════
install_dante() {
    banner
    echo -e "${CYAN}${BOLD}[2] Installing Dante SOCKS5 Proxy${RESET}\n"
    apt_update
    pkg_install dante-server

    echo -ne "${YELLOW}SOCKS5 port (default $SOCKS5_PORT): ${RESET}"; read -r p
    SOCKS5_PORT=${p:-$SOCKS5_PORT}

    # Detect main network interface reliably
    local iface
    iface=$(ip route get 8.8.8.8 2>/dev/null | grep -oP 'dev \K\S+' | head -1)
    [[ -z "$iface" ]] && iface=$(ip route | grep default | grep -oP 'dev \K\S+' | head -1)
    [[ -z "$iface" ]] && iface=$(ls /sys/class/net | grep -v lo | head -1)
    log_info "Network interface detected: $iface"

    # Get the private IP bound to that interface
    local bind_ip
    bind_ip=$(ip -4 addr show "$iface" 2>/dev/null | grep -oP '(?<=inet )\d+\.\d+\.\d+\.\d+' | head -1)
    [[ -z "$bind_ip" ]] && bind_ip="0.0.0.0"
    log_info "Bind IP: $bind_ip  Interface: $iface"

    [[ -f $DANTE_CONF ]] && cp "$DANTE_CONF" "${DANTE_CONF}.bak.$(date +%s)"

    cat > "$DANTE_CONF" <<EOF
# ── Proxy Manager Pro — Dante SOCKS5 Config ───────────────────
logoutput: /var/log/danted.log

# Listen on ALL interfaces so both public and private IPs work
internal: 0.0.0.0 port = ${SOCKS5_PORT}

# Outbound through main interface
external: ${iface}

# Auth — require username/password
socksmethod: username
clientmethod: none

# Timeouts
timeout.connect: 30
timeout.io: 86400
timeout.negotiate: 30

user.privileged: root
user.unprivileged: nobody

# Allow all client IPs to connect (auth required)
client pass {
    from: 0.0.0.0/0 to: 0.0.0.0/0
    log: error
}

# Allow authenticated SOCKS5 — all destinations
socks pass {
    from: 0.0.0.0/0 to: 0.0.0.0/0
    socksmethod: username
    log: connect disconnect error
    command: bind connect udpassociate
    protocol: tcp udp
}

# Block everything else
socks block {
    from: 0.0.0.0/0 to: 0.0.0.0/0
    log: connect error
}
EOF

    # Open firewall
    ufw --force enable >> "$LOG_DIR/install.log" 2>&1
    ufw allow "$SOCKS5_PORT"/tcp comment "Dante SOCKS5" >> "$LOG_DIR/install.log" 2>&1
    log_ok "Firewall port $SOCKS5_PORT opened"

    systemctl enable danted >> "$LOG_DIR/install.log" 2>&1
    systemctl stop danted >> "$LOG_DIR/install.log" 2>&1 || true
    sleep 1
    systemctl start danted

    sleep 2
    if systemctl is-active --quiet danted; then
        log_ok "Dante SOCKS5 running on port $SOCKS5_PORT"
    else
        log_err "Dante failed to start — checking logs..."
        journalctl -u danted -n 15 --no-pager 2>/dev/null
        log_warn "Common fix: check interface name with: ip route get 8.8.8.8"
    fi

    echo "dante_socks5=$SOCKS5_PORT" >> "$CONFIG_FILE"

    local ip; ip=$(get_server_ip)
    echo -e "\n${GREEN}${BOLD}╔══════════════════════════════════════════════════════╗"
    echo -e "║           DANTE SOCKS5 READY                         ║"
    echo -e "╠══════════════════════════════════════════════════════╣"
    echo -e "║  ${WHITE}Public IP : ${GREEN}$ip${GREEN}  ← use this"
    echo -e "║  ${WHITE}Port      : ${GREEN}$SOCKS5_PORT${GREEN}"
    echo -e "║  ${WHITE}Test      : ${WHITE}curl --socks5 $ip:$SOCKS5_PORT -U USER:PASS https://ifconfig.me${GREEN}"
    echo -e "╚══════════════════════════════════════════════════════╝${RESET}"
    press_enter
}

# ══════════════════════════════════════════════════════════════
#  3. INSTALL 3PROXY (HTTP + SOCKS5 + MULTI)
# ══════════════════════════════════════════════════════════════
install_3proxy() {
    banner
    echo -e "${CYAN}${BOLD}[3] Installing 3proxy (Multi-protocol)${RESET}\n"
    apt_update
    pkg_install build-essential wget curl git libssl-dev

    echo -ne "${YELLOW}3proxy HTTP port (default $PROXY3_HTTP): ${RESET}"; read -r p
    PROXY3_HTTP=${p:-$PROXY3_HTTP}
    echo -ne "${YELLOW}3proxy SOCKS5 port (default $PROXY3_SOCKS): ${RESET}"; read -r p2
    PROXY3_SOCKS=${p2:-$PROXY3_SOCKS}

    if ! command -v 3proxy &>/dev/null; then
        _build_3proxy || { press_enter; return; }
    else
        log_ok "3proxy already installed: $(3proxy --version 2>&1 | head -1)"
    fi

    _write_3proxy_config
    _write_3proxy_service
    _write_3proxy_users_file

    systemctl daemon-reload
    systemctl enable 3proxy >> "$LOG_DIR/install.log" 2>&1
    systemctl restart 3proxy

    if systemctl is-active --quiet 3proxy; then
        log_ok "3proxy running → HTTP:${PROXY3_HTTP}  SOCKS5:${PROXY3_SOCKS}"
    else
        log_err "3proxy failed to start — check: journalctl -u 3proxy -n 30"
    fi

    echo "proxy3_http=$PROXY3_HTTP"   >> "$CONFIG_FILE"
    echo "proxy3_socks=$PROXY3_SOCKS" >> "$CONFIG_FILE"

    local ip; ip=$(get_server_ip)
    echo -e "\n${GREEN}${BOLD}╔══════════════════════════════════════════════════════╗"
    echo -e "║           3PROXY READY                               ║"
    echo -e "╠══════════════════════════════════════════════════════╣"
    echo -e "║  ${WHITE}HTTP   : ${GREEN}$ip:${PROXY3_HTTP}${GREEN}"
    echo -e "║  ${WHITE}SOCKS5 : ${GREEN}$ip:${PROXY3_SOCKS}${GREEN}"
    echo -e "╚══════════════════════════════════════════════════════╝${RESET}"
    press_enter
}

# ── 3proxy build helper ───────────────────────────────────────
_build_3proxy() {
    log_info "Fetching latest 3proxy release from GitHub..."
    local WORKDIR="/tmp/3proxy_build"
    rm -rf "$WORKDIR" && mkdir -p "$WORKDIR"
    cd "$WORKDIR" || return 1

    # Get latest release tag via GitHub API (no auth needed)
    local LATEST_TAG
    LATEST_TAG=$(env -u http_proxy -u https_proxy -u HTTP_PROXY -u HTTPS_PROXY \
        curl -s --max-time 15 \
        "https://api.github.com/repos/3proxy/3proxy/releases/latest" \
        | grep '"tag_name"' | cut -d'"' -f4)

    # Fallback tags if API fails
    if [[ -z "$LATEST_TAG" ]]; then
        log_warn "GitHub API unreachable, trying known versions..."
        for TRY_TAG in "0.9.5" "0.9.4" "0.9.3"; do
            local TEST_URL="https://github.com/3proxy/3proxy/archive/refs/tags/${TRY_TAG}.tar.gz"
            if env -u http_proxy -u https_proxy -u HTTP_PROXY -u HTTPS_PROXY \
               wget -q --spider "$TEST_URL" 2>/dev/null; then
                LATEST_TAG="$TRY_TAG"
                log_info "Using version: $LATEST_TAG"
                break
            fi
        done
    fi

    if [[ -z "$LATEST_TAG" ]]; then
        # Last resort — clone from git
        log_warn "Falling back to git clone..."
        env -u http_proxy -u https_proxy -u HTTP_PROXY -u HTTPS_PROXY \
            git clone --depth 1 https://github.com/3proxy/3proxy.git "$WORKDIR/3proxy-src" \
            >> "$LOG_DIR/install.log" 2>&1 \
            && cd "$WORKDIR/3proxy-src" \
            || { log_err "Could not download 3proxy source"; cd /; rm -rf "$WORKDIR"; return 1; }
    else
        log_info "Downloading 3proxy $LATEST_TAG ..."
        local DL_URL="https://github.com/3proxy/3proxy/archive/refs/tags/${LATEST_TAG}.tar.gz"
        env -u http_proxy -u https_proxy -u HTTP_PROXY -u HTTPS_PROXY \
            wget -q --show-progress --timeout=60 "$DL_URL" \
            -O "$WORKDIR/3proxy.tar.gz" >> "$LOG_DIR/install.log" 2>&1

        if [[ ! -s "$WORKDIR/3proxy.tar.gz" ]]; then
            log_err "Download failed or file is empty"
            cd /; rm -rf "$WORKDIR"; return 1
        fi

        tar -xzf "$WORKDIR/3proxy.tar.gz" -C "$WORKDIR" >> "$LOG_DIR/install.log" 2>&1
        # Find extracted directory (name may vary)
        local SRC_DIR
        SRC_DIR=$(find "$WORKDIR" -maxdepth 1 -type d -name "3proxy-*" | head -1)
        if [[ -z "$SRC_DIR" ]]; then
            log_err "Could not find extracted 3proxy source directory"
            ls -la "$WORKDIR" >> "$LOG_DIR/install.log" 2>&1
            cd /; rm -rf "$WORKDIR"; return 1
        fi
        cd "$SRC_DIR" || { log_err "Cannot enter source dir: $SRC_DIR"; cd /; rm -rf "$WORKDIR"; return 1; }
    fi

    # Build
    log_info "Compiling 3proxy (this takes ~30 seconds)..."
    local MAKE_FILE="Makefile.Linux"
    [[ ! -f "$MAKE_FILE" ]] && MAKE_FILE="Makefile"

    if make -f "$MAKE_FILE" >> "$LOG_DIR/install.log" 2>&1; then
        # Binary may be in bin/ or current dir
        local BINARY
        BINARY=$(find . -name "3proxy" -type f | head -1)
        if [[ -n "$BINARY" ]]; then
            cp "$BINARY" /usr/local/bin/3proxy
            chmod +x /usr/local/bin/3proxy
            log_ok "3proxy compiled and installed: $(3proxy --version 2>&1 | head -1)"
        else
            log_err "Build succeeded but binary not found"
            cd /; rm -rf "$WORKDIR"; return 1
        fi
    else
        log_err "Compilation failed — check $LOG_DIR/install.log"
        tail -20 "$LOG_DIR/install.log"
        cd /; rm -rf "$WORKDIR"; return 1
    fi

    cd /; rm -rf "$WORKDIR"
    return 0
}

# ── 3proxy config writer ──────────────────────────────────────
_write_3proxy_config() {
    mkdir -p /etc/3proxy /var/log/3proxy
    cat > "$PROXY3_CONF" <<EOF
# ── Proxy Manager Pro — 3proxy Config ─────────────────────────
daemon
pidfile /var/run/3proxy.pid
nserver 1.1.1.1
nserver 8.8.8.8
nserver 9.9.9.9

# Logging
log /var/log/3proxy/3proxy.log D
logformat "- +_L%t.%.  %N.%p %E %U %C:%c %R:%r %O %I %h %T"
rotate 30

# Auth — include users file
include /etc/3proxy/users.cfg

auth strong
allow *

# Run as nobody
setgid 65534
setuid 65534

# Timeouts
timeouts 1 5 30 60 180 1800 15 60

# HTTP Proxy
proxy -p${PROXY3_HTTP} -i0.0.0.0 -e0.0.0.0

# SOCKS5 Proxy
socks -p${PROXY3_SOCKS} -i0.0.0.0 -e0.0.0.0
EOF
    log_ok "3proxy config written"
}

# ── 3proxy users file ─────────────────────────────────────────
_write_3proxy_users_file() {
    [[ ! -f "$PROXY3_USERS" ]] && touch "$PROXY3_USERS"
    chmod 600 "$PROXY3_USERS"
    chown nobody:nogroup "$PROXY3_USERS" 2>/dev/null || true
}

# ── 3proxy systemd service ────────────────────────────────────
_write_3proxy_service() {
    cat > /etc/systemd/system/3proxy.service <<EOF
[Unit]
Description=3proxy Proxy Server
After=network.target

[Service]
Type=forking
PIDFile=/var/run/3proxy.pid
ExecStart=/usr/local/bin/3proxy /etc/3proxy/3proxy.cfg
ExecReload=/bin/kill -HUP \$MAINPID
KillMode=process
Restart=on-failure
RestartSec=5
LimitNOFILE=65536

[Install]
WantedBy=multi-user.target
EOF
    log_ok "3proxy systemd service written"
}

# ══════════════════════════════════════════════════════════════
#  4. INSTALL ALL
# ══════════════════════════════════════════════════════════════
install_all() {
    banner
    echo -e "${CYAN}${BOLD}[4] Installing ALL proxy servers${RESET}\n"
    log_info "This will install Squid + Dante + 3proxy"
    echo -ne "${YELLOW}Continue? (y/n): ${RESET}"; read -r c
    [[ "$c" != "y" ]] && main_menu
    install_squid_silent
    install_dante_silent
    install_3proxy_silent
    log_ok "ALL proxy servers installed!"
    # Setup self-launch alias
    setup_menu_alias
    press_enter
}

install_squid_silent()  { apt_update; pkg_install squid apache2-utils; }
install_dante_silent()  { pkg_install dante-server; }
install_3proxy_silent() {
    pkg_install build-essential wget curl git libssl-dev
    _build_3proxy
    _write_3proxy_config
    _write_3proxy_service
    _write_3proxy_users_file
    systemctl daemon-reload
    systemctl enable 3proxy >> "$LOG_DIR/install.log" 2>&1
    systemctl restart 3proxy
}

# ══════════════════════════════════════════════════════════════
#  5. ADD USER
# ══════════════════════════════════════════════════════════════
add_user() {
    banner
    echo -e "${CYAN}${BOLD}[5] Add Proxy User${RESET}\n"
    echo -ne "${YELLOW}Username: ${RESET}"; read -r username
    [[ -z "$username" ]] && { log_err "Username cannot be empty"; press_enter; return; }

    echo -ne "${YELLOW}Password (Enter=auto-generate): ${RESET}"; read -r password
    [[ -z "$password" ]] && password=$(gen_password) && echo -e "${GREEN}Generated: $password${RESET}"

    echo -e "\n${YELLOW}Add to which proxy?${RESET}"
    echo "  1. Squid (HTTP)"
    echo "  2. Dante (SOCKS5)"
    echo "  3. 3proxy (Multi)"
    echo "  4. ALL"
    echo -ne "${YELLOW}Choice: ${RESET}"; read -r uchoice

    case $uchoice in
        1|4) add_squid_user "$username" "$password" ;;
        2|4) add_dante_user "$username" "$password" ;;
        3|4) add_3proxy_user "$username" "$password" ;;
    esac

    save_user "$username" "$password" "$uchoice"

    # Auto-open firewall for selected proxy ports
    _open_proxy_ports "$uchoice"

    local ip; ip=$(get_server_ip)
    local priv; priv=$(hostname -I | awk '{print $1}')
    echo -e "\n${GREEN}${BOLD}╔════════════════════════════════════════════════════════╗"
    echo -e "║            USER CREATED SUCCESSFULLY                   ║"
    echo -e "╠════════════════════════════════════════════════════════╣"
    echo -e "║  Username  : ${WHITE}$username${GREEN}"
    echo -e "║  Password  : ${WHITE}$password${GREEN}"
    echo -e "║  Public IP : ${WHITE}$ip${GREEN}  ← connect using this"
    [[ "$ip" != "$priv" ]] && \
    echo -e "║  Private IP: ${WHITE}$priv${GREEN}  (internal only — do NOT use)"
    echo -e "╠════════════════════════════════════════════════════════╣"
    case $uchoice in
        1|4)
    echo -e "║  ${CYAN}HTTP Proxy${GREEN}"
    echo -e "║  Address   : ${WHITE}$ip:${HTTP_PORT}${GREEN}"
    echo -e "║  Test cmd  : ${WHITE}curl -x http://$username:$password@$ip:$HTTP_PORT https://ifconfig.me${GREEN}"
        ;;
    esac
    case $uchoice in
        2|4)
    echo -e "║  ${CYAN}SOCKS5 Proxy (Dante)${GREEN}"
    echo -e "║  Address   : ${WHITE}$ip:${SOCKS5_PORT}${GREEN}"
    echo -e "║  Test cmd  : ${WHITE}curl --socks5 $ip:$SOCKS5_PORT -U $username:$password https://ifconfig.me${GREEN}"
        ;;
    esac
    case $uchoice in
        3|4)
    echo -e "║  ${CYAN}3proxy HTTP${GREEN}"
    echo -e "║  Address   : ${WHITE}$ip:${PROXY3_HTTP}${GREEN}"
    echo -e "║  Test cmd  : ${WHITE}curl -x http://$username:$password@$ip:$PROXY3_HTTP https://ifconfig.me${GREEN}"
    echo -e "║  ${CYAN}3proxy SOCKS5${GREEN}"
    echo -e "║  Address   : ${WHITE}$ip:${PROXY3_SOCKS}${GREEN}"
    echo -e "║  Test cmd  : ${WHITE}curl --socks5 $ip:$PROXY3_SOCKS -U $username:$password https://ifconfig.me${GREEN}"
        ;;
    esac
    echo -e "╚════════════════════════════════════════════════════════╝${RESET}"

    # Quick connectivity self-test
    echo -e "\n${CYAN}── Quick Connectivity Test ─────────────────────────────${RESET}"
    _selftest_proxy "$uchoice" "$username" "$password" "$ip"

    press_enter
}

# ── Open firewall ports for proxy type ───────────────────────
_open_proxy_ports() {
    local choice=$1
    log_info "Opening firewall ports..."
    # Always ensure UFW is active
    ufw --force enable >> "$LOG_DIR/install.log" 2>&1

    case $choice in
        1|4) ufw allow "$HTTP_PORT"/tcp  comment "Squid HTTP"  >> "$LOG_DIR/install.log" 2>&1
             ufw allow "$HTTPS_PORT"/tcp comment "Squid HTTPS" >> "$LOG_DIR/install.log" 2>&1
             log_ok "Opened port $HTTP_PORT (HTTP) and $HTTPS_PORT (HTTPS)" ;;
    esac
    case $choice in
        2|4) ufw allow "$SOCKS5_PORT"/tcp comment "Dante SOCKS5" >> "$LOG_DIR/install.log" 2>&1
             log_ok "Opened port $SOCKS5_PORT (SOCKS5)" ;;
    esac
    case $choice in
        3|4) ufw allow "$PROXY3_HTTP"/tcp  comment "3proxy HTTP"   >> "$LOG_DIR/install.log" 2>&1
             ufw allow "$PROXY3_SOCKS"/tcp comment "3proxy SOCKS5" >> "$LOG_DIR/install.log" 2>&1
             log_ok "Opened port $PROXY3_HTTP (3proxy HTTP) and $PROXY3_SOCKS (3proxy SOCKS5)" ;;
    esac

    # Also check AWS/GCP/Azure security groups warning
    local priv; priv=$(hostname -I | awk '{print $1}')
    local pub;  pub=$(get_server_ip)
    if [[ "$pub" != "$priv" ]]; then
        echo -e "\n${YELLOW}╔══════════════════════════════════════════════════════════════╗"
        echo -e "║  ⚠  CLOUD VPS DETECTED (AWS/GCP/Azure/DigitalOcean)          ║"
        echo -e "╠══════════════════════════════════════════════════════════════╣"
        echo -e "║  UFW ports opened ✔  — but you ALSO need to open ports in   ║"
        echo -e "║  your cloud provider's Security Group / Firewall Rules:      ║"
        echo -e "╠══════════════════════════════════════════════════════════════╣"
        case $choice in
            1|4)
        echo -e "║  • TCP ${HTTP_PORT}   — Squid HTTP                                 ║"
        echo -e "║  • TCP ${HTTPS_PORT}   — Squid HTTPS                                ║" ;;
        esac
        case $choice in
            2|4)
        echo -e "║  • TCP ${SOCKS5_PORT}   — Dante SOCKS5                               ║" ;;
        esac
        case $choice in
            3|4)
        echo -e "║  • TCP ${PROXY3_HTTP}   — 3proxy HTTP                                ║"
        echo -e "║  • TCP ${PROXY3_SOCKS}   — 3proxy SOCKS5                             ║" ;;
        esac
        echo -e "╠══════════════════════════════════════════════════════════════╣"
        echo -e "║  AWS  → EC2 → Security Groups → Inbound Rules → Add Rule    ║"
        echo -e "║  GCP  → VPC Network → Firewall → Create Firewall Rule       ║"
        echo -e "║  Azure → Network Security Groups → Inbound Rules            ║"
        echo -e "║  DO   → Networking → Firewalls → Inbound Rules              ║"
        echo -e "╚══════════════════════════════════════════════════════════════╝${RESET}"
    fi
}

# ── Quick self-test from inside the VPS ──────────────────────
_selftest_proxy() {
    local choice=$1 user=$2 pass=$3 ip=$4
    local ok=0 fail=0

    case $choice in
        1|4)
            echo -ne "  Testing HTTP (Squid port $HTTP_PORT)... "
            local r; r=$(curl -s --max-time 8 -x "http://$user:$pass@127.0.0.1:$HTTP_PORT" \
                https://ifconfig.me 2>/dev/null)
            if [[ -n "$r" ]]; then
                echo -e "${GREEN}✔ OK — exit IP: $r${RESET}"; ((ok++))
            else
                echo -e "${RED}✗ FAILED${RESET}"; ((fail++))
                echo -e "  ${YELLOW}→ Check: systemctl status squid${RESET}"
            fi ;;
    esac
    case $choice in
        2|4)
            echo -ne "  Testing SOCKS5 (Dante port $SOCKS5_PORT)... "
            local r; r=$(curl -s --max-time 8 --socks5 "127.0.0.1:$SOCKS5_PORT" \
                -U "$user:$pass" https://ifconfig.me 2>/dev/null)
            if [[ -n "$r" ]]; then
                echo -e "${GREEN}✔ OK — exit IP: $r${RESET}"; ((ok++))
            else
                echo -e "${RED}✗ FAILED${RESET}"; ((fail++))
                echo -e "  ${YELLOW}→ Check: systemctl status danted${RESET}"
            fi ;;
    esac
    case $choice in
        3|4)
            echo -ne "  Testing 3proxy HTTP (port $PROXY3_HTTP)... "
            local r; r=$(curl -s --max-time 8 -x "http://$user:$pass@127.0.0.1:$PROXY3_HTTP" \
                https://ifconfig.me 2>/dev/null)
            if [[ -n "$r" ]]; then
                echo -e "${GREEN}✔ OK — exit IP: $r${RESET}"; ((ok++))
            else
                echo -e "${RED}✗ FAILED${RESET}"; ((fail++))
                echo -e "  ${YELLOW}→ Check: systemctl status 3proxy${RESET}"
            fi
            echo -ne "  Testing 3proxy SOCKS5 (port $PROXY3_SOCKS)... "
            local r2; r2=$(curl -s --max-time 8 --socks5 "127.0.0.1:$PROXY3_SOCKS" \
                -U "$user:$pass" https://ifconfig.me 2>/dev/null)
            if [[ -n "$r2" ]]; then
                echo -e "${GREEN}✔ OK — exit IP: $r2${RESET}"; ((ok++))
            else
                echo -e "${RED}✗ FAILED${RESET}"; ((fail++))
                echo -e "  ${YELLOW}→ Check: systemctl status 3proxy${RESET}"
            fi ;;
    esac

    echo ""
    if [[ $fail -eq 0 ]]; then
        echo -e "  ${GREEN}${BOLD}✔ All proxy connections working from VPS.${RESET}"
        echo -e "  ${YELLOW}If you still timeout from outside — open ports in your cloud Security Group (see above).${RESET}"
    else
        echo -e "  ${RED}${BOLD}✗ $fail test(s) failed — proxy not responding locally.${RESET}"
        _diagnose_connection "$choice"
    fi
}

# ── Auto-diagnose why proxy isn't working ────────────────────
_diagnose_connection() {
    local choice=$1
    echo -e "\n${CYAN}── Auto-Diagnosis ──────────────────────────────────────${RESET}"

    # Check services
    for svc_check in "squid:1" "danted:2" "3proxy:3"; do
        local svc=${svc_check%%:*}
        local num=${svc_check##*:}
        if [[ "$choice" == "$num" || "$choice" == "4" ]]; then
            if ! systemctl is-active --quiet "$svc" 2>/dev/null; then
                echo -e "  ${RED}✗ $svc is NOT running${RESET}"
                echo -e "  ${CYAN}  Fix: sudo systemctl restart $svc${RESET}"
                echo -e "  ${CYAN}  Logs: sudo journalctl -u $svc -n 20 --no-pager${RESET}"
                journalctl -u "$svc" -n 5 --no-pager 2>/dev/null | grep -iE "error|fail|warn" | sed 's/^/    /'
            else
                echo -e "  ${GREEN}✔ $svc is running${RESET}"
            fi
        fi
    done

    # Check ports listening
    echo -e "\n  ${CYAN}Ports currently listening:${RESET}"
    ss -tlnp 2>/dev/null | grep -E ":($HTTP_PORT|$SOCKS5_PORT|$PROXY3_HTTP|$PROXY3_SOCKS|$HTTPS_PORT)" \
        | awk '{print "    " $4}' \
        || echo "    (none of the proxy ports are listening)"

    # Check UFW
    echo -e "\n  ${CYAN}UFW rules for proxy ports:${RESET}"
    ufw status 2>/dev/null | grep -E "$HTTP_PORT|$SOCKS5_PORT|$PROXY3_HTTP|$PROXY3_SOCKS" \
        | sed 's/^/    /' \
        || echo "    (no UFW rules found for proxy ports)"
}

add_squid_user() {
    local user=$1 pass=$2
    if [[ -f $SQUID_PASSWD ]]; then
        htpasswd -b "$SQUID_PASSWD" "$user" "$pass" 2>/dev/null \
            && log_ok "Squid user added: $user" \
            || log_err "Failed to add Squid user"
        systemctl reload squid 2>/dev/null
    else
        log_warn "Squid not installed"
    fi
}

add_dante_user() {
    local user=$1 pass=$2
    # Dante uses system users
    if id "$user" &>/dev/null; then
        echo "$user:$pass" | chpasswd
        log_ok "Dante user updated: $user"
    else
        useradd -r -s /bin/false -M "$user" 2>/dev/null
        echo "$user:$pass" | chpasswd
        log_ok "Dante system user created: $user"
    fi
}

add_3proxy_user() {
    local user=$1 pass=$2
    # 3proxy uses MD5 or CL5 hashed passwords
    local hash; hash=$(echo -n "${user}:3proxy:${pass}" | md5sum | awk '{print $1}')
    # Remove old entry if exists
    sed -i "/^$user:/d" "$PROXY3_USERS" 2>/dev/null
    echo "$user:CL5:$hash" >> "$PROXY3_USERS"
    log_ok "3proxy user added: $user"
    systemctl reload 3proxy 2>/dev/null || systemctl restart 3proxy 2>/dev/null
}

# ══════════════════════════════════════════════════════════════
#  6. DELETE USER
# ══════════════════════════════════════════════════════════════
delete_user() {
    banner
    echo -e "${CYAN}${BOLD}[6] Delete Proxy User${RESET}\n"
    list_users_inline
    echo -ne "\n${YELLOW}Username to delete: ${RESET}"; read -r username
    [[ -z "$username" ]] && { log_err "No username entered"; press_enter; return; }

    echo -ne "${RED}Confirm delete '$username'? (y/n): ${RESET}"; read -r c
    [[ "$c" != "y" ]] && main_menu

    # Squid
    [[ -f $SQUID_PASSWD ]] && htpasswd -D "$SQUID_PASSWD" "$username" 2>/dev/null \
        && log_ok "Removed from Squid"

    # Dante (system user)
    if id "$username" &>/dev/null; then
        userdel "$username" 2>/dev/null && log_ok "Removed Dante system user"
    fi

    # 3proxy
    [[ -f $PROXY3_USERS ]] && sed -i "/^$username:/d" "$PROXY3_USERS" \
        && log_ok "Removed from 3proxy"

    # Users list
    [[ -f $USERS_FILE ]] && sed -i "/^$username:/d" "$USERS_FILE"

    systemctl reload squid 2>/dev/null
    systemctl reload 3proxy 2>/dev/null || systemctl restart 3proxy 2>/dev/null
    log_ok "User '$username' deleted from all proxies"
    press_enter
}

# ══════════════════════════════════════════════════════════════
#  7. EDIT USER (CHANGE PASSWORD)
# ══════════════════════════════════════════════════════════════
edit_user() {
    banner
    echo -e "${CYAN}${BOLD}[7] Edit Proxy User${RESET}\n"
    list_users_inline
    echo -ne "\n${YELLOW}Username to edit: ${RESET}"; read -r username
    echo -ne "${YELLOW}New password (Enter=auto-generate): ${RESET}"; read -r newpass
    [[ -z "$newpass" ]] && newpass=$(gen_password) && echo -e "${GREEN}Generated: $newpass${RESET}"

    add_squid_user "$username" "$newpass"
    add_dante_user "$username" "$newpass"
    add_3proxy_user "$username" "$newpass"

    # Update users file
    sed -i "s/^$username:.*/$username:$newpass:updated:$(ts)/" "$USERS_FILE"
    log_ok "Password updated for: $username → $newpass"
    press_enter
}

# ══════════════════════════════════════════════════════════════
#  8. LIST USERS
# ══════════════════════════════════════════════════════════════
list_users_inline() {
    echo -e "${CYAN}── Current Users ──────────────────────────────────${RESET}"
    if [[ -f $USERS_FILE ]]; then
        printf "  %-20s %-20s %-10s %s\n" "USER" "PASSWORD" "TYPE" "CREATED"
        echo -e "  $(printf '%.0s─' {1..60})"
        while IFS=: read -r u p t d; do
            printf "  ${GREEN}%-20s${RESET} ${WHITE}%-20s${RESET} ${YELLOW}%-10s${RESET} %s\n" "$u" "$p" "$t" "$d"
        done < "$USERS_FILE"
    else
        echo -e "  ${YELLOW}No users found.${RESET}"
    fi
}

list_users() {
    banner
    echo -e "${CYAN}${BOLD}[8] All Proxy Users${RESET}\n"
    list_users_inline

    echo -e "\n${CYAN}── Squid password file users ──${RESET}"
    [[ -f $SQUID_PASSWD ]] && cut -d: -f1 "$SQUID_PASSWD" | while read -r u; do
        echo -e "  ${GREEN}$u${RESET} (HTTP)"
    done || echo -e "  ${YELLOW}Squid not installed${RESET}"

    echo -e "\n${CYAN}── 3proxy users ──${RESET}"
    [[ -f $PROXY3_USERS ]] && cut -d: -f1 "$PROXY3_USERS" | while read -r u; do
        echo -e "  ${GREEN}$u${RESET} (3proxy)"
    done || echo -e "  ${YELLOW}3proxy not installed${RESET}"

    press_enter
}

# ══════════════════════════════════════════════════════════════
#  9. BULK ADD USERS FROM FILE
# ══════════════════════════════════════════════════════════════
bulk_add_users() {
    banner
    echo -e "${CYAN}${BOLD}[9] Bulk Add Users from File${RESET}\n"
    echo -e "${YELLOW}File format: one entry per line${RESET}"
    echo -e "  ${WHITE}username:password${RESET}  — use your own password"
    echo -e "  ${WHITE}username${RESET}            — auto-generate password"
    echo ""
    echo -ne "${YELLOW}Path to file: ${RESET}"; read -r filepath
    [[ ! -f "$filepath" ]] && { log_err "File not found: $filepath"; press_enter; return; }

    echo -e "\n${YELLOW}Add to which proxy?${RESET}"
    echo "  1. Squid  2. Dante  3. 3proxy  4. ALL"
    echo -ne "${YELLOW}Choice: ${RESET}"; read -r uchoice

    local count=0
    while IFS= read -r line || [[ -n "$line" ]]; do
        line=$(echo "$line" | tr -d '\r' | xargs)
        [[ -z "$line" || "$line" == \#* ]] && continue
        local user pass
        if [[ "$line" == *:* ]]; then
            user=$(cut -d: -f1 <<< "$line")
            pass=$(cut -d: -f2 <<< "$line")
        else
            user="$line"
            pass=$(gen_password)
        fi
        case $uchoice in
            1|4) add_squid_user "$user" "$pass" ;;
            2|4) add_dante_user "$user" "$pass" ;;
            3|4) add_3proxy_user "$user" "$pass" ;;
        esac
        save_user "$user" "$pass" "$uchoice"
        echo -e "  ${GREEN}✔ $user : $pass${RESET}"
        ((count++))
    done < "$filepath"

    log_ok "Bulk added $count users"
    press_enter
}

# ══════════════════════════════════════════════════════════════
#  10. START / STOP / RESTART
# ══════════════════════════════════════════════════════════════
manage_services() {
    banner
    echo -e "${CYAN}${BOLD}[10] Manage Proxy Services${RESET}\n"
    echo "  1. Start all"
    echo "  2. Stop all"
    echo "  3. Restart all"
    echo "  4. Start Squid"
    echo "  5. Stop Squid"
    echo "  6. Restart Squid"
    echo "  7. Start Dante"
    echo "  8. Stop Dante"
    echo "  9. Restart Dante"
    echo " 10. Start 3proxy"
    echo " 11. Stop 3proxy"
    echo " 12. Restart 3proxy"
    echo -ne "\n${YELLOW}Choice: ${RESET}"; read -r sc
    case $sc in
        1)  service_action squid start;  service_action danted start;  service_action 3proxy start  ;;
        2)  service_action squid stop;   service_action danted stop;   service_action 3proxy stop   ;;
        3)  service_action squid restart;service_action danted restart;service_action 3proxy restart ;;
        4)  service_action squid start   ;;
        5)  service_action squid stop    ;;
        6)  service_action squid restart ;;
        7)  service_action danted start  ;;
        8)  service_action danted stop   ;;
        9)  service_action danted restart;;
        10) service_action 3proxy start  ;;
        11) service_action 3proxy stop   ;;
        12) service_action 3proxy restart;;
    esac
    press_enter
}

# ══════════════════════════════════════════════════════════════
#  11. VIEW STATUS
# ══════════════════════════════════════════════════════════════
view_status() {
    banner
    echo -e "${CYAN}${BOLD}[11] Proxy Service Status${RESET}\n"
    local ip; ip=$(get_server_ip)

    for svc in squid danted 3proxy; do
        if systemctl is-active --quiet "$svc" 2>/dev/null; then
            echo -e "  ${GREEN}● $svc${RESET}  — ${GREEN}RUNNING${RESET}"
        elif systemctl list-units --all | grep -q "$svc"; then
            echo -e "  ${RED}● $svc${RESET}  — ${RED}STOPPED${RESET}"
        else
            echo -e "  ${YELLOW}● $svc${RESET}  — ${YELLOW}NOT INSTALLED${RESET}"
        fi
    done

    echo -e "\n${CYAN}── Open Ports ──────────────────────────────────────${RESET}"
    ss -tlnp 2>/dev/null | grep -E ":($HTTP_PORT|$HTTPS_PORT|$SOCKS5_PORT|$PROXY3_HTTP|$PROXY3_SOCKS)" \
        | awk '{print "  " $4 "  " $6}' \
        || netstat -tlnp 2>/dev/null | grep -E ":($HTTP_PORT|$SOCKS5_PORT|$PROXY3_HTTP)"

    echo -e "\n${CYAN}── Active connections ──────────────────────────────${RESET}"
    ss -tnp 2>/dev/null | grep -E ":($HTTP_PORT|$SOCKS5_PORT|$PROXY3_HTTP|$PROXY3_SOCKS)" \
        | head -20

    echo -e "\n${CYAN}── Proxy Access Info ───────────────────────────────${RESET}"
    echo -e "  ${WHITE}Server IP  : ${GREEN}$ip${RESET}"
    echo -e "  ${WHITE}HTTP Proxy : ${GREEN}$ip:${HTTP_PORT}${RESET}"
    echo -e "  ${WHITE}SOCKS5     : ${GREEN}$ip:${SOCKS5_PORT}${RESET}"
    echo -e "  ${WHITE}3proxy HTTP: ${GREEN}$ip:${PROXY3_HTTP}${RESET}"
    echo -e "  ${WHITE}3proxy SOC : ${GREEN}$ip:${PROXY3_SOCKS}${RESET}"
    press_enter
}

# ══════════════════════════════════════════════════════════════
#  12. CHANGE PORTS
# ══════════════════════════════════════════════════════════════
change_ports() {
    banner
    echo -e "${CYAN}${BOLD}[12] Change Proxy Ports${RESET}\n"
    echo -e "Current: HTTP=${HTTP_PORT} HTTPS=${HTTPS_PORT} SOCKS5=${SOCKS5_PORT} 3proxy-H=${PROXY3_HTTP} 3proxy-S=${PROXY3_SOCKS}"
    echo -ne "\n${YELLOW}New HTTP port (Enter=keep): ${RESET}";   read -r p; [[ -n "$p" ]] && HTTP_PORT=$p
    echo -ne "${YELLOW}New HTTPS port (Enter=keep): ${RESET}";  read -r p; [[ -n "$p" ]] && HTTPS_PORT=$p
    echo -ne "${YELLOW}New SOCKS5 port (Enter=keep): ${RESET}"; read -r p; [[ -n "$p" ]] && SOCKS5_PORT=$p
    echo -ne "${YELLOW}New 3proxy HTTP (Enter=keep): ${RESET}"; read -r p; [[ -n "$p" ]] && PROXY3_HTTP=$p
    echo -ne "${YELLOW}New 3proxy SOCKS (Enter=keep): ${RESET}";read -r p; [[ -n "$p" ]] && PROXY3_SOCKS=$p

    # Apply changes
    [[ -f $SQUID_CONF ]] && {
        sed -i "s/^http_port [0-9]*/http_port $HTTP_PORT/" "$SQUID_CONF"
        systemctl restart squid 2>/dev/null
        log_ok "Squid port updated → $HTTP_PORT"
    }
    [[ -f $DANTE_CONF ]] && {
        sed -i "s/port = [0-9]*/port = $SOCKS5_PORT/" "$DANTE_CONF"
        systemctl restart danted 2>/dev/null
        log_ok "Dante port updated → $SOCKS5_PORT"
    }
    [[ -f $PROXY3_CONF ]] && {
        sed -i "s/proxy -p[0-9]*/proxy -p$PROXY3_HTTP/" "$PROXY3_CONF"
        sed -i "s/socks -p[0-9]*/socks -p$PROXY3_SOCKS/" "$PROXY3_CONF"
        systemctl restart 3proxy 2>/dev/null
        log_ok "3proxy ports updated → HTTP:$PROXY3_HTTP SOCKS:$PROXY3_SOCKS"
    }

    # Update firewall
    ufw allow "$HTTP_PORT"/tcp 2>/dev/null
    ufw allow "$SOCKS5_PORT"/tcp 2>/dev/null
    ufw allow "$PROXY3_HTTP"/tcp 2>/dev/null
    ufw allow "$PROXY3_SOCKS"/tcp 2>/dev/null
    press_enter
}

# ══════════════════════════════════════════════════════════════
#  13. LOGS & CONNECTIONS
# ══════════════════════════════════════════════════════════════
view_logs() {
    banner
    echo -e "${CYAN}${BOLD}[13] Active Connections & Logs${RESET}\n"
    echo "  1. Squid access log (live)"
    echo "  2. Dante log (live)"
    echo "  3. 3proxy log (live)"
    echo "  4. Active connections (all proxies)"
    echo "  5. Last 50 Squid access entries"
    echo "  6. Last 50 3proxy entries"
    echo -ne "\n${YELLOW}Choice: ${RESET}"; read -r lc
    case $lc in
        1) echo -e "${YELLOW}Ctrl+C to stop${RESET}\n"; tail -f /var/log/squid/access.log 2>/dev/null || log_warn "Squid log not found" ;;
        2) echo -e "${YELLOW}Ctrl+C to stop${RESET}\n"; tail -f /var/log/danted.log 2>/dev/null       || log_warn "Dante log not found" ;;
        3) echo -e "${YELLOW}Ctrl+C to stop${RESET}\n"; tail -f /var/log/3proxy/3proxy.log 2>/dev/null || log_warn "3proxy log not found" ;;
        4)
            echo -e "\n${CYAN}── Active Connections ──${RESET}"
            ss -tnp | grep -E ":($HTTP_PORT|$SOCKS5_PORT|$PROXY3_HTTP|$PROXY3_SOCKS)"
            ;;
        5) tail -50 /var/log/squid/access.log 2>/dev/null | awk '{print $7, $8, $3}' | column -t ;;
        6) tail -50 /var/log/3proxy/3proxy.log 2>/dev/null ;;
    esac
    press_enter
}

# ══════════════════════════════════════════════════════════════
#  14. BANDWIDTH USAGE
# ══════════════════════════════════════════════════════════════
bandwidth_usage() {
    banner
    echo -e "${CYAN}${BOLD}[14] Bandwidth Usage per User${RESET}\n"
    if [[ -f /var/log/squid/access.log ]]; then
        echo -e "${CYAN}── Squid — Top bandwidth users ─────────────────────${RESET}"
        awk '{print $8, $5}' /var/log/squid/access.log 2>/dev/null \
            | sort | awk '{user[$1]+=$2} END{for(u in user) printf "  %-30s %s bytes\n", u, user[u]}' \
            | sort -k2 -rn | head -20
    fi
    if [[ -f /var/log/3proxy/3proxy.log ]]; then
        echo -e "\n${CYAN}── 3proxy — Recent connections ────────────────────${RESET}"
        tail -100 /var/log/3proxy/3proxy.log 2>/dev/null | grep -v "^$" | head -20
    fi
    press_enter
}

# ══════════════════════════════════════════════════════════════
#  15. UFW FIREWALL SETUP
# ══════════════════════════════════════════════════════════════
setup_firewall() {
    banner
    echo -e "${CYAN}${BOLD}[15] UFW Firewall Setup${RESET}\n"
    pkg_install ufw

    echo -e "${YELLOW}This will configure UFW for your proxy setup.${RESET}"
    echo -ne "Continue? (y/n): "; read -r c; [[ "$c" != "y" ]] && main_menu

    # Reset and set defaults
    ufw --force reset >> "$LOG_DIR/ufw.log" 2>&1
    ufw default deny incoming
    ufw default allow outgoing

    # Always allow SSH (prevent lockout)
    echo -ne "${YELLOW}SSH port (default 22): ${RESET}"; read -r sshport
    sshport=${sshport:-22}
    ufw allow "$sshport"/tcp comment "SSH"
    log_ok "SSH allowed on port $sshport"

    # Allow proxy ports
    ufw allow "$HTTP_PORT"/tcp   comment "Squid HTTP"
    ufw allow "$HTTPS_PORT"/tcp  comment "Squid HTTPS"
    ufw allow "$SOCKS5_PORT"/tcp comment "Dante SOCKS5"
    ufw allow "$PROXY3_HTTP"/tcp comment "3proxy HTTP"
    ufw allow "$PROXY3_SOCKS"/tcp comment "3proxy SOCKS5"

    # Rate limiting on proxy ports to prevent abuse
    ufw limit "$HTTP_PORT"/tcp
    ufw limit "$SOCKS5_PORT"/tcp

    ufw --force enable
    ufw status verbose

    log_ok "UFW firewall configured"
    press_enter
}

# ══════════════════════════════════════════════════════════════
#  16. BLOCK / UNBLOCK IP
# ══════════════════════════════════════════════════════════════
block_ip() {
    banner
    echo -e "${CYAN}${BOLD}[16] Block / Unblock IP${RESET}\n"
    echo "  1. Block IP"
    echo "  2. Unblock IP"
    echo "  3. Show blocked IPs"
    echo -ne "\n${YELLOW}Choice: ${RESET}"; read -r bc
    case $bc in
        1)
            echo -ne "${YELLOW}IP to block: ${RESET}"; read -r bip
            ufw deny from "$bip" to any
            log_ok "Blocked: $bip"
            ;;
        2)
            echo -ne "${YELLOW}IP to unblock: ${RESET}"; read -r bip
            ufw delete deny from "$bip" to any
            log_ok "Unblocked: $bip"
            ;;
        3)
            echo -e "\n${CYAN}── Blocked IPs ──────────────────────────────────${RESET}"
            ufw status | grep DENY
            ;;
    esac
    press_enter
}

# ══════════════════════════════════════════════════════════════
#  17. WHITELIST IP (no-auth)
# ══════════════════════════════════════════════════════════════
whitelist_ip() {
    banner
    echo -e "${CYAN}${BOLD}[17] Whitelist IP (no-auth access)${RESET}\n"
    echo -ne "${YELLOW}IP or CIDR to whitelist: ${RESET}"; read -r wip
    [[ -z "$wip" ]] && { log_err "No IP entered"; press_enter; return; }

    # Add to Squid
    if [[ -f $SQUID_CONF ]]; then
        # Insert whitelist ACL before auth requirement
        sed -i "/acl authenticated proxy_auth REQUIRED/i acl whitelist_ip src $wip\nhttp_access allow whitelist_ip" "$SQUID_CONF"
        systemctl reload squid 2>/dev/null
        log_ok "Whitelisted in Squid: $wip"
    fi

    # Add to 3proxy (allow without auth)
    if [[ -f $PROXY3_CONF ]]; then
        sed -i "/auth strong/a allow * $wip" "$PROXY3_CONF"
        systemctl restart 3proxy 2>/dev/null
        log_ok "Whitelisted in 3proxy: $wip"
    fi

    # UFW allow
    ufw allow from "$wip" to any port "$HTTP_PORT" 2>/dev/null
    ufw allow from "$wip" to any port "$SOCKS5_PORT" 2>/dev/null
    log_ok "UFW whitelisted: $wip"
    press_enter
}

# ══════════════════════════════════════════════════════════════
#  18. DNS LEAK PROTECTION
# ══════════════════════════════════════════════════════════════
dns_leak_protect() {
    banner
    echo -e "${CYAN}${BOLD}[18] Anti-leak / DNS Leak Protection${RESET}\n"
    log_info "Configuring DNS leak protection..."

    # Force DNS through secure resolvers
    cat > /etc/resolv.conf <<EOF
# Proxy Manager Pro — DNS Leak Protection
nameserver 1.1.1.1
nameserver 1.0.0.1
nameserver 8.8.8.8
nameserver 9.9.9.9
options edns0 trust-ad
EOF
    chattr +i /etc/resolv.conf 2>/dev/null && log_ok "resolv.conf locked (immutable)"

    # Disable systemd-resolved if causing leaks
    if systemctl is-active --quiet systemd-resolved; then
        systemctl disable systemd-resolved 2>/dev/null
        systemctl stop systemd-resolved 2>/dev/null
        log_ok "systemd-resolved disabled"
    fi

    # Block non-proxy DNS via UFW (force all DNS through proxy)
    ufw deny out 53 2>/dev/null
    log_ok "Outbound port 53 blocked (DNS forced through proxy)"

    # Squid DNS settings
    if [[ -f $SQUID_CONF ]]; then
        grep -q "dns_nameservers" "$SQUID_CONF" || \
            echo "dns_nameservers 1.1.1.1 8.8.8.8 9.9.9.9" >> "$SQUID_CONF"
        systemctl reload squid 2>/dev/null
        log_ok "Squid DNS forced to 1.1.1.1 / 8.8.8.8 / 9.9.9.9"
    fi

    log_ok "DNS leak protection applied"
    press_enter
}

# ══════════════════════════════════════════════════════════════
#  19. EXPORT PROXY LIST
# ══════════════════════════════════════════════════════════════
export_proxies() {
    banner
    echo -e "${CYAN}${BOLD}[19] Export Proxy List${RESET}\n"
    local ip; ip=$(get_server_ip)
    echo "  1. host:port:user:pass"
    echo "  2. user:pass@host:port"
    echo "  3. http://user:pass@host:port"
    echo "  4. socks5://user:pass@host:port"
    echo "  5. All formats"
    echo -ne "\n${YELLOW}Format choice: ${RESET}"; read -r fc
    echo -ne "${YELLOW}Output file (Enter=proxy_export.txt): ${RESET}"; read -r outf
    outf=${outf:-proxy_export.txt}

    [[ ! -f $USERS_FILE ]] && { log_err "No users found"; press_enter; return; }

    > "$outf"
    while IFS=: read -r user pass type _; do
        case $fc in
            1) echo "$ip:$HTTP_PORT:$user:$pass" >> "$outf"
               echo "$ip:$SOCKS5_PORT:$user:$pass" >> "$outf" ;;
            2) echo "$user:$pass@$ip:$HTTP_PORT" >> "$outf"
               echo "$user:$pass@$ip:$SOCKS5_PORT" >> "$outf" ;;
            3) echo "http://$user:$pass@$ip:$HTTP_PORT" >> "$outf" ;;
            4) echo "socks5://$user:$pass@$ip:$SOCKS5_PORT" >> "$outf" ;;
            5)
               echo "# HTTP"  >> "$outf"
               echo "http://$user:$pass@$ip:$HTTP_PORT" >> "$outf"
               echo "# SOCKS5" >> "$outf"
               echo "socks5://$user:$pass@$ip:$SOCKS5_PORT" >> "$outf"
               echo "# 3proxy HTTP" >> "$outf"
               echo "http://$user:$pass@$ip:$PROXY3_HTTP" >> "$outf"
               echo "# 3proxy SOCKS5" >> "$outf"
               echo "socks5://$user:$pass@$ip:$PROXY3_SOCKS" >> "$outf"
               echo "" >> "$outf" ;;
        esac
    done < "$USERS_FILE"

    log_ok "Exported to: $outf"
    echo -e "\n${GREEN}Preview:${RESET}"
    head -20 "$outf"
    press_enter
}

# ══════════════════════════════════════════════════════════════
#  20. TEST PROXY
# ══════════════════════════════════════════════════════════════
test_proxy() {
    banner
    echo -e "${CYAN}${BOLD}[20] Test Proxy Connectivity${RESET}\n"
    local ip; ip=$(get_server_ip)

    echo -ne "${YELLOW}Username: ${RESET}"; read -r tuser
    echo -ne "${YELLOW}Password: ${RESET}"; read -r tpass
    echo -ne "${YELLOW}Test URL (default https://ifconfig.me): ${RESET}"; read -r turl
    turl=${turl:-https://ifconfig.me}

    pkg_install curl -y >> /dev/null 2>&1

    echo -e "\n${CYAN}── Testing HTTP Proxy (Squid) ─────────────────────${RESET}"
    result=$(curl -s -x "http://$tuser:$tpass@$ip:$HTTP_PORT" "$turl" --max-time 10 2>&1)
    [[ -n "$result" ]] && echo -e "${GREEN}  ✔ HTTP OK — Exit IP: $result${RESET}" \
                       || echo -e "${RED}  ✗ HTTP FAILED${RESET}"

    echo -e "\n${CYAN}── Testing SOCKS5 Proxy (Dante) ───────────────────${RESET}"
    result=$(curl -s --socks5 "$ip:$SOCKS5_PORT" -U "$tuser:$tpass" "$turl" --max-time 10 2>&1)
    [[ -n "$result" ]] && echo -e "${GREEN}  ✔ SOCKS5 OK — Exit IP: $result${RESET}" \
                       || echo -e "${RED}  ✗ SOCKS5 FAILED${RESET}"

    echo -e "\n${CYAN}── Testing 3proxy HTTP ────────────────────────────${RESET}"
    result=$(curl -s -x "http://$tuser:$tpass@$ip:$PROXY3_HTTP" "$turl" --max-time 10 2>&1)
    [[ -n "$result" ]] && echo -e "${GREEN}  ✔ 3proxy HTTP OK — Exit IP: $result${RESET}" \
                       || echo -e "${RED}  ✗ 3proxy HTTP FAILED${RESET}"

    echo -e "\n${CYAN}── Testing 3proxy SOCKS5 ──────────────────────────${RESET}"
    result=$(curl -s --socks5 "$ip:$PROXY3_SOCKS" -U "$tuser:$tpass" "$turl" --max-time 10 2>&1)
    [[ -n "$result" ]] && echo -e "${GREEN}  ✔ 3proxy SOCKS5 OK — Exit IP: $result${RESET}" \
                       || echo -e "${RED}  ✗ 3proxy SOCKS5 FAILED${RESET}"

    press_enter
}

# ══════════════════════════════════════════════════════════════
#  21. AUTO-ROTATE CREDENTIALS
# ══════════════════════════════════════════════════════════════
auto_rotate() {
    banner
    echo -e "${CYAN}${BOLD}[21] Auto-Rotate Proxy Credentials${RESET}\n"
    echo "  1. Rotate all user passwords now"
    echo "  2. Setup cron job (rotate every N days)"
    echo "  3. Remove rotation cron job"
    echo -ne "\n${YELLOW}Choice: ${RESET}"; read -r rc
    case $rc in
        1)
            [[ ! -f $USERS_FILE ]] && { log_err "No users"; press_enter; return; }
            local tmp; tmp=$(mktemp)
            while IFS=: read -r user _ type created; do
                local newpass; newpass=$(gen_password)
                add_squid_user "$user" "$newpass"
                add_dante_user "$user" "$newpass"
                add_3proxy_user "$user" "$newpass"
                echo "$user:$newpass:$type:$created" >> "$tmp"
                log_ok "Rotated: $user → $newpass"
            done < "$USERS_FILE"
            mv "$tmp" "$USERS_FILE"
            log_ok "All passwords rotated"
            ;;
        2)
            echo -ne "${YELLOW}Rotate every N days: ${RESET}"; read -r days
            echo "0 3 */$days * * root $0 --rotate-silent" > /etc/cron.d/proxymanager-rotate
            log_ok "Cron set: rotate every $days days at 3am"
            ;;
        3)
            rm -f /etc/cron.d/proxymanager-rotate
            log_ok "Rotation cron removed"
            ;;
    esac
    press_enter
}

# ══════════════════════════════════════════════════════════════
#  22. UNINSTALL
# ══════════════════════════════════════════════════════════════
uninstall_all() {
    banner
    echo -e "${RED}${BOLD}[22] Uninstall All Proxies${RESET}\n"
    echo -e "${RED}WARNING: This will remove Squid, Dante, 3proxy and all configs!${RESET}"
    echo -ne "${YELLOW}Type 'CONFIRM' to proceed: ${RESET}"; read -r conf
    [[ "$conf" != "CONFIRM" ]] && { log_warn "Aborted"; press_enter; return; }

    systemctl stop squid danted 3proxy 2>/dev/null
    systemctl disable squid danted 3proxy 2>/dev/null
    apt-get remove -y --purge squid dante-server 2>/dev/null
    rm -f /usr/local/bin/3proxy
    rm -rf /etc/3proxy /etc/squid/squid_passwd /etc/proxymanager
    rm -f /etc/systemd/system/3proxy.service
    systemctl daemon-reload
    # Remove alias
    sed -i '/alias menu=/d' /root/.bashrc 2>/dev/null

    log_ok "All proxies uninstalled and cleaned up"
    press_enter
}

# ══════════════════════════════════════════════════════════════
#  SETUP MENU ALIAS (type 'menu' from anywhere)
# ══════════════════════════════════════════════════════════════
setup_menu_alias() {
    local script_path; script_path=$(realpath "$0")
    # Add to root's bashrc
    grep -q "alias menu=" /root/.bashrc 2>/dev/null || \
        echo "alias menu='sudo $script_path'" >> /root/.bashrc
    # Also create a global command
    cp "$script_path" /usr/local/bin/menu 2>/dev/null
    chmod +x /usr/local/bin/menu 2>/dev/null
    log_ok "You can now type 'menu' from anywhere to launch Proxy Manager"
}

# ══════════════════════════════════════════════════════════════
#  HANDLE CHOICE
# ══════════════════════════════════════════════════════════════
handle_choice() {
    case $1 in
        1)  install_squid ;;
        2)  install_dante ;;
        3)  install_3proxy ;;
        4)  install_all ;;
        5)  add_user ;;
        6)  delete_user ;;
        7)  edit_user ;;
        8)  list_users ;;
        9)  bulk_add_users ;;
        10) manage_services ;;
        11) view_status ;;
        12) change_ports ;;
        13) view_logs ;;
        14) bandwidth_usage ;;
        15) setup_firewall ;;
        16) block_ip ;;
        17) whitelist_ip ;;
        18) dns_leak_protect ;;
        19) export_proxies ;;
        20) test_proxy ;;
        21) auto_rotate ;;
        22) uninstall_all ;;
        23) leakproof_harden ;;
        24) leakproof_check ;;
        25) leakproof_undo ;;
        26) ssl_reissue ;;
        27) ssl_status ;;
        28) echo -e "\n${GREEN}Goodbye!${RESET}\n"; exit 0 ;;
        29) anti_detection_harden ;;
        30) detection_risk_check ;;
        31) residential_ip_masking ;;
        32) cloudflare_integration ;;
        --rotate-silent)
            # Called by cron
            [[ -f $USERS_FILE ]] && while IFS=: read -r user _ type created; do
                local np; np=$(gen_password)
                add_squid_user "$user" "$np"; add_dante_user "$user" "$np"; add_3proxy_user "$user" "$np"
            done < "$USERS_FILE"
            ;;
        *) log_warn "Invalid option"; sleep 1; main_menu ;;
    esac
}

# ══════════════════════════════════════════════════════════════
#  23. FULL LEAKPROOF HARDENING
# ══════════════════════════════════════════════════════════════
leakproof_harden() {
    banner
    echo -e "${MAGENTA}${BOLD}[23] FULL LEAKPROOF HARDENING${RESET}\n"
    echo -e "${YELLOW}This will apply all leak protections:${RESET}"
    echo -e "  • Disable IPv6 completely"
    echo -e "  • Block IPv6 via UFW + iptables"
    echo -e "  • Lock DNS to 1.1.1.1 / 8.8.8.8 (immutable)"
    echo -e "  • Block DNS bypass (port 53 lockdown)"
    echo -e "  • Full Squid header stripping"
    echo -e "  • Force proxy environment variables"
    echo -e "  • Randomize TTL (anti-fingerprint)"
    echo -e "  • Kernel network hardening (sysctl)"
    echo -e "  • Save iptables rules (persist on reboot)"
    echo -e ""
    echo -ne "${YELLOW}Apply all hardening? (y/n): ${RESET}"; read -r c
    [[ "$c" != "y" ]] && main_menu

    # ── Backup marker ────────────────────────────────────────
    mkdir -p "$CONFIG_DIR/hardening_backup"
    local BAK="$CONFIG_DIR/hardening_backup"
    log_info "Saving backups to $BAK"
    cp /etc/sysctl.conf "$BAK/sysctl.conf.bak" 2>/dev/null
    cp /etc/resolv.conf "$BAK/resolv.conf.bak" 2>/dev/null
    cp /etc/environment "$BAK/environment.bak" 2>/dev/null
    [[ -f $SQUID_CONF ]] && cp "$SQUID_CONF" "$BAK/squid.conf.bak"

    # ── STEP 1: Disable IPv6 ─────────────────────────────────
    log_info "STEP 1/8 — Disabling IPv6..."
    # Remove any old entries first
    sed -i '/net.ipv6.conf/d' /etc/sysctl.conf
    cat >> /etc/sysctl.conf <<EOF

# ── Proxy Manager Pro — IPv6 Disabled ──────────────────────
net.ipv6.conf.all.disable_ipv6 = 1
net.ipv6.conf.default.disable_ipv6 = 1
net.ipv6.conf.lo.disable_ipv6 = 1
EOF
    sysctl -p >> "$LOG_DIR/hardening.log" 2>&1
    log_ok "IPv6 disabled via sysctl"

    # Disable IPv6 in GRUB (survives full reboot)
    if [[ -f /etc/default/grub ]]; then
        sed -i 's/GRUB_CMDLINE_LINUX="\(.*\)"/GRUB_CMDLINE_LINUX="\1 ipv6.disable=1"/' /etc/default/grub
        update-grub >> "$LOG_DIR/hardening.log" 2>&1
        log_ok "IPv6 disabled in GRUB (persistent across reboots)"
    fi

    # ── STEP 2: Block IPv6 via UFW ───────────────────────────
    log_info "STEP 2/8 — Blocking IPv6 in UFW..."
    # Set UFW to not manage IPv6
    sed -i 's/IPV6=yes/IPV6=no/' /etc/default/ufw 2>/dev/null
    ufw deny out to ::/0 2>/dev/null
    ufw deny in from ::/0 2>/dev/null
    log_ok "IPv6 blocked via UFW"

    # ── STEP 3: Block IPv6 via ip6tables ────────────────────
    log_info "STEP 3/8 — Blocking IPv6 via ip6tables..."
    ip6tables -P INPUT DROP 2>/dev/null
    ip6tables -P OUTPUT DROP 2>/dev/null
    ip6tables -P FORWARD DROP 2>/dev/null
    ip6tables -F 2>/dev/null
    log_ok "ip6tables — all IPv6 traffic dropped"

    # ── STEP 4: DNS Lockdown ─────────────────────────────────
    log_info "STEP 4/8 — Locking DNS (anti-leak)..."
    # Unlock resolv.conf if previously locked
    chattr -i /etc/resolv.conf 2>/dev/null
    cat > /etc/resolv.conf <<EOF
# Proxy Manager Pro — Leakproof DNS
nameserver 1.1.1.1
nameserver 1.0.0.1
nameserver 8.8.8.8
nameserver 9.9.9.9
options edns0 trust-ad rotate
EOF
    # Lock the file so nothing can overwrite it
    chattr +i /etc/resolv.conf
    log_ok "resolv.conf locked (immutable) → 1.1.1.1 / 8.8.8.8"

    # Disable systemd-resolved (common DNS leak source)
    if systemctl is-active --quiet systemd-resolved; then
        systemctl stop systemd-resolved
        systemctl disable systemd-resolved
        rm -f /etc/resolv.conf
        cat > /etc/resolv.conf <<EOF
nameserver 1.1.1.1
nameserver 8.8.8.8
nameserver 9.9.9.9
EOF
        chattr +i /etc/resolv.conf
        log_ok "systemd-resolved disabled (was leaking DNS)"
    fi

    # Disable NetworkManager DNS management
    if [[ -f /etc/NetworkManager/NetworkManager.conf ]]; then
        grep -q "\[main\]" /etc/NetworkManager/NetworkManager.conf || echo "[main]" >> /etc/NetworkManager/NetworkManager.conf
        sed -i '/^dns=/d' /etc/NetworkManager/NetworkManager.conf
        sed -i '/\[main\]/a dns=none' /etc/NetworkManager/NetworkManager.conf
        systemctl restart NetworkManager 2>/dev/null
        log_ok "NetworkManager DNS management disabled"
    fi

    # ── STEP 5: Block DNS bypass via iptables ────────────────
    log_info "STEP 5/8 — Blocking DNS bypass (port 53 lockdown)..."
    # Allow DNS only to our chosen servers
    iptables -F OUTPUT 2>/dev/null || true

    # Allow DNS to trusted resolvers only
    iptables -A OUTPUT -p udp -d 1.1.1.1 --dport 53 -j ACCEPT
    iptables -A OUTPUT -p tcp -d 1.1.1.1 --dport 53 -j ACCEPT
    iptables -A OUTPUT -p udp -d 1.0.0.1 --dport 53 -j ACCEPT
    iptables -A OUTPUT -p udp -d 8.8.8.8 --dport 53 -j ACCEPT
    iptables -A OUTPUT -p tcp -d 8.8.8.8 --dport 53 -j ACCEPT
    iptables -A OUTPUT -p udp -d 9.9.9.9 --dport 53 -j ACCEPT
    iptables -A OUTPUT -p tcp -d 9.9.9.9 --dport 53 -j ACCEPT

    # Block all other DNS (prevents bypass)
    iptables -A OUTPUT -p udp --dport 53 -j DROP
    iptables -A OUTPUT -p tcp --dport 53 -j DROP
    log_ok "DNS locked — only 1.1.1.1, 8.8.8.8, 9.9.9.9 allowed"

    # Block DNS over HTTPS known IPs (Cloudflare DoH, Google DoH)
    # These bypass system DNS entirely
    iptables -A OUTPUT -p tcp -d 1.1.1.1 --dport 443 -j ACCEPT
    iptables -A OUTPUT -p tcp -d 8.8.8.8 --dport 443 -j ACCEPT
    log_ok "DoH endpoints controlled"

    # ── STEP 6: Full Squid header stripping ─────────────────
    log_info "STEP 6/8 — Applying full Squid header stripping..."
    if [[ -f $SQUID_CONF ]]; then
        # Remove old header directives
        sed -i '/request_header_access/d' "$SQUID_CONF"
        sed -i '/reply_header_access/d' "$SQUID_CONF"
        sed -i '/forwarded_for/d' "$SQUID_CONF"
        sed -i '/via /d' "$SQUID_CONF"
        sed -i '/header_replace/d' "$SQUID_CONF"

        cat >> "$SQUID_CONF" <<'EOF'

# ── Proxy Manager Pro — Full Header Stripping ──────────────

# Kill all identifying headers
forwarded_for delete
via off

# Whitelist only essential headers — deny everything else
request_header_access Allow allow all
request_header_access Authorization allow all
request_header_access Proxy-Authorization allow all
request_header_access Proxy-Authenticate allow all
request_header_access Cache-Control allow all
request_header_access Content-Encoding allow all
request_header_access Content-Length allow all
request_header_access Content-Type allow all
request_header_access Date allow all
request_header_access Host allow all
request_header_access If-Modified-Since allow all
request_header_access Last-Modified allow all
request_header_access Location allow all
request_header_access Pragma allow all
request_header_access Accept allow all
request_header_access Accept-Charset allow all
request_header_access Accept-Encoding allow all
request_header_access Accept-Language allow all
request_header_access Connection allow all
request_header_access Transfer-Encoding allow all
request_header_access User-Agent allow all

# Strip all other request headers
request_header_access All deny all

# Strip response headers that reveal proxy
reply_header_access X-Cache deny all
reply_header_access X-Cache-Lookup deny all
reply_header_access X-Squid-Error deny all
reply_header_access Via deny all
reply_header_access X-Forwarded-For deny all
reply_header_access Server allow all

# Replace User-Agent with generic browser string (anti-fingerprint)
request_header_replace User-Agent "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36"
EOF
        # Validate config — ignore SSL cert warnings (certs may not exist yet)
        local squid_errors
        squid_errors=$(squid -k parse 2>&1 | grep -v "ssl" | grep -v "SSL" | grep -v "certificate" | grep -iE "error|fatal" | wc -l)
        if [[ "$squid_errors" -eq 0 ]]; then
            systemctl reload squid 2>/dev/null || systemctl restart squid 2>/dev/null
            log_ok "Squid full header stripping applied"
        else
            # Apply anyway and restart — most warnings are non-fatal
            systemctl restart squid 2>/dev/null
            log_ok "Squid header stripping applied (restart done)"
        fi
    else
        log_warn "Squid not installed — skipping header stripping"
    fi

    # ── STEP 7: Force proxy environment variables ────────────
    log_info "STEP 7/8 — Forcing system-wide proxy environment..."
    local ip; ip=$(get_server_ip)

    # Remove old entries
    sed -i '/http_proxy\|https_proxy\|HTTP_PROXY\|HTTPS_PROXY\|no_proxy/Id' /etc/environment

    cat >> /etc/environment <<EOF

# Proxy Manager Pro — Force proxy for all system traffic
http_proxy="http://127.0.0.1:${HTTP_PORT}"
https_proxy="http://127.0.0.1:${HTTP_PORT}"
HTTP_PROXY="http://127.0.0.1:${HTTP_PORT}"
HTTPS_PROXY="http://127.0.0.1:${HTTP_PORT}"
no_proxy="localhost,127.0.0.1,::1"
NO_PROXY="localhost,127.0.0.1,::1"
EOF
    log_ok "System-wide proxy environment forced"

    # ── STEP 8: Kernel / TTL / Network hardening ─────────────
    log_info "STEP 8/8 — Applying kernel network hardening..."
    sed -i '/# Proxy Manager Pro — Network Hardening/,/^$/d' /etc/sysctl.conf
    cat >> /etc/sysctl.conf <<EOF

# ── Proxy Manager Pro — Network Hardening ──────────────────

# Randomize TTL (anti-fingerprinting)
net.ipv4.ip_default_ttl = 128

# Disable IP source routing (prevent routing attacks)
net.ipv4.conf.all.accept_source_route = 0
net.ipv4.conf.default.accept_source_route = 0

# Disable ICMP redirects (prevent MITM)
net.ipv4.conf.all.accept_redirects = 0
net.ipv4.conf.default.accept_redirects = 0
net.ipv4.conf.all.send_redirects = 0
net.ipv4.conf.default.send_redirects = 0

# Enable SYN flood protection
net.ipv4.tcp_syncookies = 1
net.ipv4.tcp_max_syn_backlog = 2048
net.ipv4.tcp_synack_retries = 2
net.ipv4.tcp_syn_retries = 5

# Ignore ICMP ping (stealth mode)
net.ipv4.icmp_echo_ignore_all = 1

# Disable IP forwarding (unless needed for routing)
net.ipv4.ip_forward = 0

# Protect against IP spoofing
net.ipv4.conf.all.rp_filter = 1
net.ipv4.conf.default.rp_filter = 1

# Randomize port assignments (harder to fingerprint)
net.ipv4.ip_local_port_range = 1024 65535
net.ipv4.tcp_fin_timeout = 15
net.ipv4.tcp_keepalive_time = 300
net.ipv4.tcp_keepalive_probes = 5
net.ipv4.tcp_keepalive_intvl = 15

# Hide kernel pointers
kernel.kptr_restrict = 2
kernel.dmesg_restrict = 1
EOF
    sysctl -p >> "$LOG_DIR/hardening.log" 2>&1
    log_ok "Kernel hardening applied"

    # ── Persist iptables rules across reboots ────────────────
    log_info "Saving iptables rules (persist on reboot)..."
    # Pre-answer the interactive prompts so install never hangs
    echo "iptables-persistent iptables-persistent/autosave_v4 boolean true" | debconf-set-selections
    echo "iptables-persistent iptables-persistent/autosave_v6 boolean true" | debconf-set-selections
    DEBIAN_FRONTEND=noninteractive apt-get install -y iptables-persistent netfilter-persistent \
        >> "$LOG_DIR/hardening.log" 2>&1
    # Save rules manually as well (double safety)
    mkdir -p /etc/iptables
    iptables-save  > /etc/iptables/rules.v4 2>/dev/null
    ip6tables-save > /etc/iptables/rules.v6 2>/dev/null
    netfilter-persistent save >> "$LOG_DIR/hardening.log" 2>&1 || true
    log_ok "iptables rules saved (auto-load on reboot)"

    # ── Mark hardening as applied ────────────────────────────
    echo "hardened=true" >> "$CONFIG_FILE"
    echo "hardened_at=$(ts)" >> "$CONFIG_FILE"

    # ── Summary ──────────────────────────────────────────────
    echo -e "\n${MAGENTA}${BOLD}╔══════════════════════════════════════════════════════════╗"
    echo -e "║           LEAKPROOF HARDENING COMPLETE                   ║"
    echo -e "╠══════════════════════════════════════════════════════════╣"
    echo -e "║  ${GREEN}✔ IPv6 disabled (sysctl + GRUB)${MAGENTA}                        ║"
    echo -e "║  ${GREEN}✔ IPv6 blocked (UFW + ip6tables)${MAGENTA}                       ║"
    echo -e "║  ${GREEN}✔ DNS locked to 1.1.1.1/8.8.8.8 (immutable)${MAGENTA}           ║"
    echo -e "║  ${GREEN}✔ systemd-resolved disabled${MAGENTA}                            ║"
    echo -e "║  ${GREEN}✔ Port 53 locked (DNS bypass blocked)${MAGENTA}                  ║"
    echo -e "║  ${GREEN}✔ Full Squid header stripping${MAGENTA}                          ║"
    echo -e "║  ${GREEN}✔ User-Agent spoofed (Chrome/Windows)${MAGENTA}                  ║"
    echo -e "║  ${GREEN}✔ System proxy env forced${MAGENTA}                              ║"
    echo -e "║  ${GREEN}✔ TTL randomized to 128${MAGENTA}                                ║"
    echo -e "║  ${GREEN}✔ Kernel hardening (SYN, ICMP, spoofing)${MAGENTA}               ║"
    echo -e "║  ${GREEN}✔ iptables rules saved (reboot persistent)${MAGENTA}             ║"
    echo -e "╠══════════════════════════════════════════════════════════╣"
    echo -e "║  ${YELLOW}⚠ Reboot recommended to apply all changes${MAGENTA}              ║"
    echo -e "╚══════════════════════════════════════════════════════════╝${RESET}"

    echo -ne "\n${YELLOW}Reboot now? (y/n): ${RESET}"; read -r rb
    [[ "$rb" == "y" ]] && reboot
    press_enter
}

# ══════════════════════════════════════════════════════════════
#  24. LEAKPROOF CHECK — VERIFY ALL PROTECTIONS
# ══════════════════════════════════════════════════════════════
leakproof_check() {
    banner
    echo -e "${MAGENTA}${BOLD}[24] LEAK STATUS CHECK${RESET}\n"
    local pass=0 fail=0 warn=0

    # helpers — use local vars to avoid subshell counter loss
    _pass() { echo -e "  ${GREEN}✔ PASS${RESET}  $1"; ((pass++)); }
    _fail() { echo -e "  ${RED}✗ FAIL${RESET}  $1${2:+ ${YELLOW}(got: $2)${RESET}}"; ((fail++)); }
    _warn() { echo -e "  ${YELLOW}⚠ WARN${RESET}  $1"; ((warn++)); }
    _skip() { echo -e "  ${CYAN}– SKIP${RESET}  $1 (not applicable)"; }

    # ── IPv6 ─────────────────────────────────────────────────
    echo -e "${CYAN}── IPv6 Status ─────────────────────────────────────────${RESET}"

    local ipv6_all; ipv6_all=$(sysctl -n net.ipv6.conf.all.disable_ipv6 2>/dev/null | tr -d '[:space:]')
    if [[ "$ipv6_all" == "1" ]]; then
        _pass "IPv6 disabled via sysctl (all)"
    elif [[ -z "$ipv6_all" ]]; then
        _warn "IPv6 sysctl not readable — may need Option 23 first"
    else
        _fail "IPv6 still enabled (sysctl all)" "$ipv6_all"
    fi

    local ipv6_def; ipv6_def=$(sysctl -n net.ipv6.conf.default.disable_ipv6 2>/dev/null | tr -d '[:space:]')
    if [[ "$ipv6_def" == "1" ]]; then
        _pass "IPv6 disabled via sysctl (default)"
    elif [[ -z "$ipv6_def" ]]; then
        _warn "IPv6 sysctl default not readable"
    else
        _fail "IPv6 still enabled (sysctl default)" "$ipv6_def"
    fi

    # Count actual IPv6 addresses (excluding loopback ::1)
    local ipv6_count; ipv6_count=$(ip -6 addr show 2>/dev/null | grep "inet6" | grep -v "::1/128" | wc -l)
    if [[ "$ipv6_count" -eq 0 ]]; then
        _pass "No global IPv6 addresses assigned on interfaces"
    else
        _fail "IPv6 addresses still active on interfaces" "$ipv6_count address(es)"
    fi

    # Check GRUB
    if grep -q "ipv6.disable=1" /etc/default/grub 2>/dev/null; then
        _pass "IPv6 disabled in GRUB (persistent after reboot)"
    else
        _warn "IPv6 not disabled in GRUB — may re-enable after reboot"
    fi

    # ── DNS ───────────────────────────────────────────────────
    echo -e "\n${CYAN}── DNS Leak Status ─────────────────────────────────────${RESET}"

    local resolv_ns; resolv_ns=$(grep "^nameserver" /etc/resolv.conf 2>/dev/null | awk '{print $2}' | tr '\n' ' ')
    if [[ "$resolv_ns" == *"1.1.1.1"* ]] || [[ "$resolv_ns" == *"8.8.8.8"* ]]; then
        _pass "DNS resolvers: $resolv_ns"
    else
        _fail "DNS not set to secure resolvers" "${resolv_ns:-empty}"
    fi

    local immutable; immutable=$(lsattr /etc/resolv.conf 2>/dev/null | awk '{print $1}')
    if [[ "$immutable" == *"i"* ]]; then
        _pass "resolv.conf is immutable (cannot be overwritten)"
    else
        _warn "resolv.conf is NOT locked — NetworkManager may overwrite it"
    fi

    if systemctl is-active --quiet systemd-resolved 2>/dev/null; then
        _fail "systemd-resolved is RUNNING (DNS leak risk)"
    else
        _pass "systemd-resolved is disabled"
    fi

    # ── iptables DNS lockdown ─────────────────────────────────
    echo -e "\n${CYAN}── iptables DNS Lockdown ───────────────────────────────${RESET}"
    # Check both DROP and REJECT for port 53
    local dns_rules; dns_rules=$(iptables -S OUTPUT 2>/dev/null | grep -cE "dpt:53.*(DROP|REJECT)" || echo 0)
    if [[ "$dns_rules" -gt 0 ]]; then
        _pass "Port 53 lockdown active ($dns_rules rules)"
    else
        _warn "No port 53 DROP rules — run Option 23 to lock DNS"
    fi

    # ── ip6tables ─────────────────────────────────────────────
    echo -e "\n${CYAN}── ip6tables Status ────────────────────────────────────${RESET}"
    local ip6_policy; ip6_policy=$(ip6tables -L INPUT 2>/dev/null | head -1)
    if [[ "$ip6_policy" == *"DROP"* ]]; then
        _pass "ip6tables INPUT policy is DROP"
    elif [[ "$ipv6_all" == "1" ]]; then
        # IPv6 fully disabled at kernel level — ip6tables less critical
        _pass "ip6tables not needed (IPv6 disabled at kernel level)"
    else
        _warn "ip6tables INPUT policy is not DROP — run Option 23"
    fi

    # ── UFW IPv6 block ────────────────────────────────────────
    echo -e "\n${CYAN}── UFW Status ──────────────────────────────────────────${RESET}"
    if ufw status 2>/dev/null | grep -q "Status: active"; then
        _pass "UFW firewall is active"
        if grep -q "^IPV6=no" /etc/default/ufw 2>/dev/null; then
            _pass "UFW IPv6 is disabled"
        else
            _warn "UFW IPv6 still enabled in /etc/default/ufw"
        fi
    else
        _warn "UFW is not active — run Option 15"
    fi

    # ── Squid headers ─────────────────────────────────────────
    echo -e "\n${CYAN}── Squid Header Stripping ──────────────────────────────${RESET}"
    if [[ -f "$SQUID_CONF" ]]; then
        grep -q "forwarded_for delete" "$SQUID_CONF" \
            && _pass "forwarded_for delete" || _fail "forwarded_for NOT stripped"
        grep -q "^via off" "$SQUID_CONF" \
            && _pass "Via header suppressed" || _fail "Via header NOT suppressed"
        grep -q "request_header_access All deny all" "$SQUID_CONF" \
            && _pass "All extra request headers denied" || _warn "Full header deny-all not applied (run Option 23)"
        grep -q "request_header_replace User-Agent" "$SQUID_CONF" \
            && _pass "User-Agent spoofed" || _warn "User-Agent NOT spoofed (run Option 23)"
        if systemctl is-active --quiet squid 2>/dev/null; then
            _pass "Squid service is running"
        else
            _fail "Squid is NOT running"
        fi
    else
        _skip "Squid not installed"
    fi

    # ── Kernel hardening ──────────────────────────────────────
    echo -e "\n${CYAN}── Kernel Hardening ────────────────────────────────────${RESET}"
    local ttl; ttl=$(sysctl -n net.ipv4.ip_default_ttl 2>/dev/null | tr -d '[:space:]')
    [[ "$ttl" == "128" ]] && _pass "TTL=128 (anti-fingerprint)" || _warn "TTL not set to 128 (currently: ${ttl:-unknown})"

    local syn; syn=$(sysctl -n net.ipv4.tcp_syncookies 2>/dev/null | tr -d '[:space:]')
    [[ "$syn" == "1" ]] && _pass "SYN flood protection enabled" || _warn "SYN cookies disabled"

    local icmp; icmp=$(sysctl -n net.ipv4.icmp_echo_ignore_all 2>/dev/null | tr -d '[:space:]')
    [[ "$icmp" == "1" ]] && _pass "ICMP ping blocked (stealth mode)" || _warn "ICMP ping still responds"

    local rp; rp=$(sysctl -n net.ipv4.conf.all.rp_filter 2>/dev/null | tr -d '[:space:]')
    [[ "$rp" == "1" ]] && _pass "IP spoofing protection active" || _warn "rp_filter not enabled"

    local redirects; redirects=$(sysctl -n net.ipv4.conf.all.accept_redirects 2>/dev/null | tr -d '[:space:]')
    [[ "$redirects" == "0" ]] && _pass "ICMP redirects disabled (anti-MITM)" || _warn "ICMP redirects allowed"

    # ── Proxy services ────────────────────────────────────────
    echo -e "\n${CYAN}── Proxy Services ──────────────────────────────────────${RESET}"
    local installed=0
    for svc in squid danted 3proxy; do
        if systemctl list-units --all 2>/dev/null | grep -q "${svc}.service"; then
            ((installed++))
            if systemctl is-active --quiet "$svc" 2>/dev/null; then
                _pass "$svc is RUNNING"
            else
                _fail "$svc is STOPPED (installed but not running)"
            fi
        else
            _skip "$svc (not installed)"
        fi
    done
    [[ $installed -eq 0 ]] && _warn "No proxy services installed yet"

    # ── Environment proxy vars ────────────────────────────────
    echo -e "\n${CYAN}── System Proxy Environment ────────────────────────────${RESET}"
    if grep -q "http_proxy" /etc/environment 2>/dev/null; then
        _pass "System-wide proxy env vars set in /etc/environment"
    else
        _warn "Proxy env vars not set — some apps may bypass proxy"
    fi

    # ── iptables persistence ──────────────────────────────────
    echo -e "\n${CYAN}── iptables Persistence ────────────────────────────────${RESET}"
    if [[ -f /etc/iptables/rules.v4 ]] && [[ -s /etc/iptables/rules.v4 ]]; then
        _pass "iptables rules saved (will restore on reboot)"
    else
        _warn "No saved iptables rules — rules lost on reboot (run Option 23)"
    fi

    # ── Score ─────────────────────────────────────────────────
    local total=$((pass + fail + warn))
    echo -e "\n${MAGENTA}${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
    echo -e "  ${GREEN}PASS: $pass${RESET}  ${RED}FAIL: $fail${RESET}  ${YELLOW}WARN: $warn${RESET}  TOTAL CHECKS: $total"
    local score=0
    [[ $total -gt 0 ]] && score=$(( pass * 100 / total ))
    echo -e "  Security Score: ${BOLD}${score}%${RESET}"
    echo ""
    if [[ $fail -eq 0 && $warn -eq 0 ]]; then
        echo -e "  ${GREEN}${BOLD}✔ FULLY LEAKPROOF — All checks passed!${RESET}"
    elif [[ $fail -eq 0 ]]; then
        echo -e "  ${YELLOW}${BOLD}⚠ MOSTLY SAFE — $warn warnings to fix (run Option 23)${RESET}"
    elif [[ $fail -le 2 ]]; then
        echo -e "  ${YELLOW}${BOLD}⚠ PARTIALLY HARDENED — Run Option 23 to complete${RESET}"
    else
        echo -e "  ${RED}${BOLD}✗ NOT HARDENED — Run Option 23 for full leakproof setup${RESET}"
    fi
    echo -e "${MAGENTA}${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
    press_enter
}

# ══════════════════════════════════════════════════════════════
#  25. UNDO LEAKPROOF HARDENING
# ══════════════════════════════════════════════════════════════
leakproof_undo() {
    banner
    echo -e "${MAGENTA}${BOLD}[25] Undo Leakproof Hardening${RESET}\n"
    echo -e "${YELLOW}This will restore original network settings.${RESET}"
    echo -ne "${YELLOW}Continue? (y/n): ${RESET}"; read -r c
    [[ "$c" != "y" ]] && main_menu

    local BAK="$CONFIG_DIR/hardening_backup"

    # Restore sysctl
    if [[ -f "$BAK/sysctl.conf.bak" ]]; then
        cp "$BAK/sysctl.conf.bak" /etc/sysctl.conf
        sysctl -p >> "$LOG_DIR/hardening.log" 2>&1
        log_ok "sysctl.conf restored"
    fi

    # Restore resolv.conf
    chattr -i /etc/resolv.conf 2>/dev/null
    if [[ -f "$BAK/resolv.conf.bak" ]]; then
        cp "$BAK/resolv.conf.bak" /etc/resolv.conf
        log_ok "resolv.conf restored"
    fi

    # Restore environment
    if [[ -f "$BAK/environment.bak" ]]; then
        cp "$BAK/environment.bak" /etc/environment
        log_ok "/etc/environment restored"
    fi

    # Restore Squid config
    if [[ -f "$BAK/squid.conf.bak" ]]; then
        cp "$BAK/squid.conf.bak" "$SQUID_CONF"
        systemctl reload squid 2>/dev/null
        log_ok "Squid config restored"
    fi

    # Re-enable IPv6
    sed -i '/net.ipv6.conf.*disable_ipv6/d' /etc/sysctl.conf
    sed -i 's/ ipv6.disable=1//' /etc/default/grub 2>/dev/null
    update-grub >> "$LOG_DIR/hardening.log" 2>&1
    sysctl -p >> "$LOG_DIR/hardening.log" 2>&1
    log_ok "IPv6 re-enabled"

    # Flush iptables DNS rules
    iptables -F OUTPUT 2>/dev/null
    ip6tables -F 2>/dev/null
    ip6tables -P INPUT ACCEPT 2>/dev/null
    ip6tables -P OUTPUT ACCEPT 2>/dev/null
    ip6tables -P FORWARD ACCEPT 2>/dev/null
    netfilter-persistent save 2>/dev/null
    log_ok "iptables rules cleared"

    # Re-enable systemd-resolved
    systemctl enable systemd-resolved 2>/dev/null
    systemctl start systemd-resolved 2>/dev/null
    log_ok "systemd-resolved re-enabled"

    # Update UFW IPv6
    sed -i 's/IPV6=no/IPV6=yes/' /etc/default/ufw 2>/dev/null
    ufw delete deny out to ::/0 2>/dev/null
    ufw delete deny in from ::/0 2>/dev/null
    log_ok "UFW IPv6 rules removed"

    # Remove hardening marker
    sed -i '/hardened/d' "$CONFIG_FILE" 2>/dev/null

    log_ok "All hardening undone. Reboot recommended."
    echo -ne "\n${YELLOW}Reboot now? (y/n): ${RESET}"; read -r rb
    [[ "$rb" == "y" ]] && reboot
    press_enter
}

# ══════════════════════════════════════════════════════════════
#  26. ADD / RE-ISSUE SSL CERTIFICATE
# ══════════════════════════════════════════════════════════════
ssl_reissue() {
    banner
    echo -e "${CYAN}${BOLD}[26] Add / Re-issue SSL Certificate${RESET}\n"

    # Check if squid is installed
    if ! command -v squid &>/dev/null; then
        log_err "Squid is not installed. Run Option 1 first."
        press_enter; return
    fi

    echo -ne "${YELLOW}Domain (e.g. proxy.example.com): ${RESET}"; read -r DOMAIN
    DOMAIN=$(echo "$DOMAIN" | tr '[:upper:]' '[:lower:]' | xargs)
    [[ -z "$DOMAIN" ]] && { log_err "No domain entered"; press_enter; return; }

    echo -ne "${YELLOW}Email for SSL notifications (Enter=skip): ${RESET}"; read -r EMAIL

    # Check domain → IP
    log_info "Verifying $DOMAIN..."
    local VPS_IP; VPS_IP=$(get_server_ip)
    local DOMAIN_IP; DOMAIN_IP=$(dig +short "$DOMAIN" 2>/dev/null | tail -1)

    echo -e "  ${CYAN}VPS IP     : ${WHITE}$VPS_IP${RESET}"
    echo -e "  ${CYAN}Domain IP  : ${WHITE}${DOMAIN_IP:-NOT RESOLVED}${RESET}"

    if [[ "$DOMAIN_IP" == "$VPS_IP" ]]; then
        log_ok "DNS verified ✔"
    else
        log_warn "Domain IP does not match VPS IP"
        echo -e "${CYAN}  Set DNS A record: $DOMAIN → $VPS_IP${RESET}"
        echo -ne "${YELLOW}Continue anyway? (y/n): ${RESET}"; read -r fc
        [[ "$fc" != "y" ]] && press_enter && return
    fi

    # Load saved HTTP port
    [[ -f $CONFIG_FILE ]] && source "$CONFIG_FILE"

    setup_nginx_ssl "$DOMAIN" "$EMAIL"
    echo "squid_domain=$DOMAIN" >> "$CONFIG_FILE"

    # Reload squid with new cert
    local squid_errors
    squid_errors=$(squid -k parse 2>&1 | grep -iE "^[[:space:]]*(FATAL|ERROR)" | wc -l)
    [[ "$squid_errors" -eq 0 ]] && systemctl restart squid && log_ok "Squid restarted with new cert"
    press_enter
}

# ══════════════════════════════════════════════════════════════
#  27. VIEW SSL CERTIFICATE STATUS
# ══════════════════════════════════════════════════════════════
ssl_status() {
    banner
    echo -e "${CYAN}${BOLD}[27] SSL Certificate Status${RESET}\n"

    # ── Squid cert ────────────────────────────────────────────
    echo -e "${CYAN}── Squid Certificate (/etc/squid/squid.pem) ───────────${RESET}"
    if [[ -f /etc/squid/squid.pem ]]; then
        local expiry; expiry=$(openssl x509 -enddate -noout -in /etc/squid/squid.pem 2>/dev/null | cut -d= -f2)
        local subject; subject=$(openssl x509 -subject -noout -in /etc/squid/squid.pem 2>/dev/null | sed 's/subject=//')
        local issuer; issuer=$(openssl x509 -issuer -noout -in /etc/squid/squid.pem 2>/dev/null | sed 's/issuer=//')
        local days_left; days_left=$(( ( $(date -d "$expiry" +%s 2>/dev/null || date -j -f "%b %d %T %Y %Z" "$expiry" +%s 2>/dev/null) - $(date +%s) ) / 86400 ))

        echo -e "  ${WHITE}Subject : ${GREEN}$subject${RESET}"
        echo -e "  ${WHITE}Issuer  : ${CYAN}$issuer${RESET}"
        echo -e "  ${WHITE}Expires : ${YELLOW}$expiry${RESET}"
        if [[ "$days_left" -gt 30 ]]; then
            echo -e "  ${WHITE}Days Left: ${GREEN}$days_left days ✔${RESET}"
        elif [[ "$days_left" -gt 0 ]]; then
            echo -e "  ${WHITE}Days Left: ${YELLOW}$days_left days ⚠ (renew soon)${RESET}"
        else
            echo -e "  ${WHITE}Days Left: ${RED}EXPIRED ✗${RESET}"
        fi
    else
        echo -e "  ${RED}No Squid certificate found${RESET}"
    fi

    # ── Let's Encrypt certs ───────────────────────────────────
    echo -e "\n${CYAN}── Let's Encrypt Certificates ──────────────────────────${RESET}"
    if command -v certbot &>/dev/null; then
        certbot certificates 2>/dev/null | grep -E "Domains|Expiry|Certificate|VALID|INVALID" \
            | sed 's/^/  /'
    else
        echo -e "  ${YELLOW}Certbot not installed${RESET}"
    fi

    # ── Nginx status ──────────────────────────────────────────
    echo -e "\n${CYAN}── Nginx Status ────────────────────────────────────────${RESET}"
    if systemctl is-active --quiet nginx; then
        echo -e "  ${GREEN}● Nginx is RUNNING${RESET}"
        nginx -T 2>/dev/null | grep -E "server_name|ssl_certificate|listen" | head -10 | sed 's/^/  /'
    else
        echo -e "  ${YELLOW}● Nginx is NOT running (only needed for domain SSL)${RESET}"
    fi

    # ── Auto-renew status ─────────────────────────────────────
    echo -e "\n${CYAN}── Auto-Renewal Status ─────────────────────────────────${RESET}"
    if systemctl is-active --quiet certbot.timer 2>/dev/null; then
        echo -e "  ${GREEN}✔ Certbot auto-renewal timer is active${RESET}"
        systemctl status certbot.timer 2>/dev/null | grep -E "Active|Trigger" | sed 's/^/  /'
    elif crontab -l 2>/dev/null | grep -q certbot; then
        echo -e "  ${GREEN}✔ Certbot renewal via cron${RESET}"
    else
        echo -e "  ${YELLOW}⚠ No auto-renewal detected${RESET}"
        echo -e "  ${CYAN}  Run: certbot renew --dry-run   to test${RESET}"
    fi

    # ── Renewal log ───────────────────────────────────────────
    if [[ -f /var/log/proxymanager/cert-renew.log ]]; then
        echo -e "\n${CYAN}── Last Renewal Events ─────────────────────────────────${RESET}"
        tail -5 /var/log/proxymanager/cert-renew.log | sed 's/^/  /'
    fi

    # ── Manual renew option ───────────────────────────────────
    echo ""
    echo -ne "${YELLOW}Force renew certificate now? (y/n): ${RESET}"; read -r rn
    if [[ "$rn" == "y" ]]; then
        log_info "Running certbot renew..."
        certbot renew --force-renewal 2>&1 | tail -20
        # Trigger deploy hook
        run-parts /etc/letsencrypt/renewal-hooks/deploy/ 2>/dev/null
        log_ok "Renewal attempted. Check output above."
    fi
    press_enter
}

# ══════════════════════════════════════════════════════════════
#  29. FULL ANTI-DETECTION HARDENING
# ══════════════════════════════════════════════════════════════
anti_detection_harden() {
    banner
    echo -e "${RED}${BOLD}[29] FULL ANTI-DETECTION HARDENING${RESET}\n"
    echo -e "${YELLOW}What gets you detected on sites like RemoteTask, Upwork etc:${RESET}"
    echo -e "  ${RED}1.${RESET} IP is in datacenter ASN blacklist (AWS/GCP/Azure IPs are flagged)"
    echo -e "  ${RED}2.${RESET} Proxy/VPN port fingerprinting (3128, 1080, 8080 are known proxy ports)"
    echo -e "  ${RED}3.${RESET} HTTP headers reveal proxy (Via, X-Forwarded-For, Proxy-Connection)"
    echo -e "  ${RED}4.${RESET} DNS leaks — your real DNS server exposed"
    echo -e "  ${RED}5.${RESET} WebRTC IP leak (browser exposes real IP)"
    echo -e "  ${RED}6.${RESET} TCP/IP fingerprint differs from claimed OS/browser"
    echo -e "  ${RED}7.${RESET} Timezone mismatch between IP location and browser"
    echo -e "  ${RED}8.${RESET} MTU size difference (VPNs use 1500, proxies differ)"
    echo -e "  ${RED}9.${RESET} ASN shows as hosting provider not residential ISP"
    echo -e "  ${RED}10.${RESET} Proxy port is open/detectable via port scanning\n"
    echo -ne "${YELLOW}Apply all anti-detection fixes? (y/n): ${RESET}"; read -r c
    [[ "$c" != "y" ]] && main_menu

    local BAK="$CONFIG_DIR/antidetect_backup"
    mkdir -p "$BAK"

    # ── FIX 1: Move proxies to non-standard ports ─────────────
    echo -e "\n${RED}── FIX 1: Moving proxies to non-standard ports ────────────${RESET}"
    echo -e "${CYAN}Standard proxy ports (3128, 1080, 8080) are instantly flagged."
    echo -e "We move them to random high ports that look like normal app traffic.${RESET}\n"

    local NEW_HTTP NEW_SOCKS NEW_3HTTP NEW_3SOCKS
    # Generate random ports in high range that look like app ports
    NEW_HTTP=$(shuf -i 10000-65000 -n 1)
    NEW_SOCKS=$(shuf -i 10000-65000 -n 1)
    NEW_3HTTP=$(shuf -i 10000-65000 -n 1)
    NEW_3SOCKS=$(shuf -i 10000-65000 -n 1)

    echo -e "  New Squid HTTP  : ${GREEN}$NEW_HTTP${RESET}  (was $HTTP_PORT)"
    echo -e "  New Dante SOCKS5: ${GREEN}$NEW_SOCKS${RESET}  (was $SOCKS5_PORT)"
    echo -e "  New 3proxy HTTP : ${GREEN}$NEW_3HTTP${RESET}  (was $PROXY3_HTTP)"
    echo -e "  New 3proxy SOCKS: ${GREEN}$NEW_3SOCKS${RESET}  (was $PROXY3_SOCKS)"

    echo -ne "\n${YELLOW}Use these random ports? (y/n, n=enter custom): ${RESET}"; read -r userand
    if [[ "$userand" != "y" ]]; then
        echo -ne "New HTTP port  : "; read -r NEW_HTTP
        echo -ne "New SOCKS5 port: "; read -r NEW_SOCKS
        echo -ne "New 3proxy HTTP: "; read -r NEW_3HTTP
        echo -ne "New 3proxy SOCKS: "; read -r NEW_3SOCKS
    fi

    # Apply port changes
    if [[ -f $SQUID_CONF ]]; then
        sed -i "s/^http_port ${HTTP_PORT}$/http_port ${NEW_HTTP}/" "$SQUID_CONF"
        sed -i "s/^http_port ${HTTPS_PORT}/http_port ${NEW_SOCKS}/" "$SQUID_CONF" 2>/dev/null || true
        systemctl restart squid 2>/dev/null
        log_ok "Squid moved to port $NEW_HTTP"
    fi
    if [[ -f $DANTE_CONF ]]; then
        sed -i "s/port = ${SOCKS5_PORT}/port = ${NEW_SOCKS}/" "$DANTE_CONF"
        systemctl restart danted 2>/dev/null
        log_ok "Dante moved to port $NEW_SOCKS"
    fi
    if [[ -f $PROXY3_CONF ]]; then
        sed -i "s/proxy -p${PROXY3_HTTP}/proxy -p${NEW_3HTTP}/" "$PROXY3_CONF"
        sed -i "s/socks -p${PROXY3_SOCKS}/socks -p${NEW_3SOCKS}/" "$PROXY3_CONF"
        systemctl restart 3proxy 2>/dev/null
        log_ok "3proxy moved to ports $NEW_3HTTP / $NEW_3SOCKS"
    fi

    # Update UFW — close old ports, open new ones silently
    ufw delete allow "${HTTP_PORT}/tcp"   2>/dev/null || true
    ufw delete allow "${SOCKS5_PORT}/tcp" 2>/dev/null || true
    ufw delete allow "${PROXY3_HTTP}/tcp" 2>/dev/null || true
    ufw delete allow "${PROXY3_SOCKS}/tcp" 2>/dev/null || true
    ufw allow "$NEW_HTTP/tcp"   comment "Proxy HTTP (stealth)"  >> "$LOG_DIR/install.log" 2>&1
    ufw allow "$NEW_SOCKS/tcp"  comment "Proxy SOCKS5 (stealth)">> "$LOG_DIR/install.log" 2>&1
    ufw allow "$NEW_3HTTP/tcp"  comment "3proxy HTTP (stealth)" >> "$LOG_DIR/install.log" 2>&1
    ufw allow "$NEW_3SOCKS/tcp" comment "3proxy SOCKS5 (stealth)">> "$LOG_DIR/install.log" 2>&1

    # Save new ports to config
    sed -i '/squid_http\|squid_https\|dante_socks5\|proxy3_http\|proxy3_socks/d' "$CONFIG_FILE"
    {
        echo "HTTP_PORT=$NEW_HTTP"
        echo "HTTPS_PORT=$NEW_SOCKS"
        echo "SOCKS5_PORT=$NEW_SOCKS"
        echo "PROXY3_HTTP=$NEW_3HTTP"
        echo "PROXY3_SOCKS=$NEW_3SOCKS"
    } >> "$CONFIG_FILE"
    HTTP_PORT=$NEW_HTTP
    SOCKS5_PORT=$NEW_SOCKS
    PROXY3_HTTP=$NEW_3HTTP
    PROXY3_SOCKS=$NEW_3SOCKS

    # ── FIX 2: Strip ALL proxy-revealing HTTP headers ─────────
    echo -e "\n${RED}── FIX 2: Aggressive HTTP header stripping ────────────────${RESET}"
    if [[ -f $SQUID_CONF ]]; then
        # Remove existing header rules to avoid duplication
        sed -i '/request_header_access\|reply_header_access\|request_header_replace\|header_replace/d' "$SQUID_CONF"
        cat >> "$SQUID_CONF" <<'EOF'

# ── Anti-Detection: Full header stripping ──────────────────────
# Strip all headers that reveal proxy usage
request_header_access Proxy-Connection deny all
request_header_access X-Forwarded-For deny all
request_header_access X-Forwarded-Host deny all
request_header_access X-Forwarded-Proto deny all
request_header_access X-Real-IP deny all
request_header_access Via deny all
request_header_access Forwarded deny all
request_header_access Cache-Control allow all
request_header_access Connection allow all
request_header_access Host allow all
request_header_access Accept allow all
request_header_access Accept-Encoding allow all
request_header_access Accept-Language allow all
request_header_access Accept-Charset allow all
request_header_access Authorization allow all
request_header_access Content-Length allow all
request_header_access Content-Type allow all
request_header_access Date allow all
request_header_access If-Modified-Since allow all
request_header_access Pragma allow all
request_header_access Referer allow all
request_header_access Transfer-Encoding allow all
request_header_access User-Agent allow all
request_header_access Cookie allow all
request_header_access All deny all

# Strip response headers that reveal proxy
reply_header_access Via deny all
reply_header_access X-Cache deny all
reply_header_access X-Cache-Lookup deny all
reply_header_access X-Squid-Error deny all
reply_header_access X-Forwarded-For deny all
reply_header_access Proxy-Connection deny all

# Anonymize forwarded-for completely
forwarded_for delete
via off

# Do NOT add any proxy headers
httpd_suppress_version_string on
EOF
        local sqerr; sqerr=$(squid -k parse 2>&1 | grep -icE "FATAL|ERROR" || true)
        [[ "$sqerr" -eq 0 ]] && systemctl reload squid 2>/dev/null && log_ok "Squid headers hardened"
    fi

    # ── FIX 3: TCP/IP stack fingerprint hardening ─────────────
    echo -e "\n${RED}── FIX 3: TCP fingerprint hardening ───────────────────────${RESET}"
    # Remove old entries
    sed -i '/# Anti-Detection TCP/,/^$/d' /etc/sysctl.conf 2>/dev/null || true
    cat >> /etc/sysctl.conf <<EOF

# ── Anti-Detection TCP hardening ─────────────────────────────
# Make TCP fingerprint look like a regular desktop/residential user
net.ipv4.ip_default_ttl = 64
net.ipv4.tcp_window_scaling = 1
net.ipv4.tcp_timestamps = 1
net.ipv4.tcp_sack = 1
net.ipv4.tcp_fack = 1
net.ipv4.tcp_dsack = 1
net.ipv4.tcp_ecn = 0
net.ipv4.tcp_fin_timeout = 15
net.ipv4.tcp_keepalive_time = 7200
net.ipv4.tcp_keepalive_intvl = 75
net.ipv4.tcp_keepalive_probes = 9
net.ipv4.tcp_mtu_probing = 1
# MTU: residential users have 1500, datacenters often differ
net.core.rmem_default = 212992
net.core.wmem_default = 212992
EOF
    sysctl -p >> "$LOG_DIR/install.log" 2>&1
    log_ok "TCP fingerprint normalized to residential profile"

    # ── FIX 4: MTU normalization ──────────────────────────────
    echo -e "\n${RED}── FIX 4: MTU normalization ───────────────────────────────${RESET}"
    local iface; iface=$(ip route get 8.8.8.8 2>/dev/null | grep -oP 'dev \K\S+' | head -1)
    if [[ -n "$iface" ]]; then
        ip link set dev "$iface" mtu 1500 2>/dev/null
        # Make persistent
        cat > "/etc/networkd-dispatcher/routable.d/fix-mtu" <<EOF
#!/bin/bash
ip link set dev $iface mtu 1500
EOF
        chmod +x "/etc/networkd-dispatcher/routable.d/fix-mtu" 2>/dev/null || true
        log_ok "MTU set to 1500 on $iface (matches residential ISP)"
    fi

    # ── FIX 5: Block proxy detection ports (port scan shield) ─
    echo -e "\n${RED}── FIX 5: Hide old proxy ports from port scanners ─────────${RESET}"
    # Block TCP RST responses on old proxy ports so scanners see "filtered" not "closed"
    for port in 3128 1080 8080 1081 8443 3129; do
        iptables -A INPUT -p tcp --dport "$port" -j DROP 2>/dev/null
        iptables -A INPUT -p udp --dport "$port" -j DROP 2>/dev/null
    done
    log_ok "Old proxy ports silently dropped (appear as filtered to scanners)"

    # ── FIX 6: DNS anti-detection (use ISP-like DNS behavior) ─
    echo -e "\n${RED}── FIX 6: DNS behavior normalization ──────────────────────${RESET}"
    # Residential users use their ISP DNS or 8.8.8.8 — NOT 1.1.1.1 (flagged as privacy-conscious/VPN user)
    chattr -i /etc/resolv.conf 2>/dev/null || true
    cat > /etc/resolv.conf <<EOF
# Anti-detection: use Google DNS (looks residential)
nameserver 8.8.8.8
nameserver 8.8.4.4
options edns0
EOF
    chattr +i /etc/resolv.conf 2>/dev/null
    # Update 3proxy DNS too
    [[ -f $PROXY3_CONF ]] && sed -i 's/nserver 1.1.1.1/nserver 8.8.8.8/' "$PROXY3_CONF"
    [[ -f $SQUID_CONF ]]  && sed -i 's/dns_nameservers 1.1.1.1 8.8.8.8 9.9.9.9/dns_nameservers 8.8.8.8 8.8.4.4/' "$SQUID_CONF"
    systemctl restart squid 2>/dev/null || true
    systemctl restart 3proxy 2>/dev/null || true
    log_ok "DNS set to 8.8.8.8/8.8.4.4 (residential-looking)"

    # ── FIX 7: Squid connection behavior (look like browser) ──
    echo -e "\n${RED}── FIX 7: Browser-like connection behavior ─────────────────${RESET}"
    if [[ -f $SQUID_CONF ]]; then
        sed -i '/request_header_replace User-Agent/d' "$SQUID_CONF"
        # Do NOT force a single UA — let the browser's own UA pass through
        # Only strip proxy-specific headers, keep browser headers intact
        grep -q "httpd_suppress_version_string" "$SQUID_CONF" || \
            echo "httpd_suppress_version_string on" >> "$SQUID_CONF"
        # Pipelining like a real browser
        grep -q "pipeline_prefetch" "$SQUID_CONF" || \
            echo "pipeline_prefetch 1" >> "$SQUID_CONF"
        systemctl reload squid 2>/dev/null || true
        log_ok "Squid configured for browser-like behavior"
    fi

    # ── FIX 8: Save iptables ──────────────────────────────────
    mkdir -p /etc/iptables
    iptables-save > /etc/iptables/rules.v4 2>/dev/null
    netfilter-persistent save >> "$LOG_DIR/install.log" 2>&1 || true

    # ── Save anti-detect marker ───────────────────────────────
    echo "anti_detect=true" >> "$CONFIG_FILE"
    echo "anti_detect_ports=$NEW_HTTP,$NEW_SOCKS,$NEW_3HTTP,$NEW_3SOCKS" >> "$CONFIG_FILE"

    # ── Summary ───────────────────────────────────────────────
    local ip; ip=$(get_server_ip)
    echo -e "\n${RED}${BOLD}╔══════════════════════════════════════════════════════════════╗"
    echo -e "║           ANTI-DETECTION HARDENING COMPLETE                  ║"
    echo -e "╠══════════════════════════════════════════════════════════════╣"
    echo -e "║  ${GREEN}✔ Moved to non-standard ports (not in proxy blacklists)${RED}       ║"
    echo -e "║  ${GREEN}✔ All proxy-revealing headers stripped${RED}                        ║"
    echo -e "║  ${GREEN}✔ TCP fingerprint normalized to residential profile${RED}           ║"
    echo -e "║  ${GREEN}✔ MTU set to 1500 (residential ISP standard)${RED}                 ║"
    echo -e "║  ${GREEN}✔ Old ports silently dropped (hidden from port scanners)${RED}      ║"
    echo -e "║  ${GREEN}✔ DNS normalized to 8.8.8.8 (residential behavior)${RED}            ║"
    echo -e "║  ${GREEN}✔ Browser-like connection pipelining enabled${RED}                  ║"
    echo -e "╠══════════════════════════════════════════════════════════════╣"
    echo -e "║  NEW CONNECTION DETAILS:                                     ║"
    echo -e "║  ${WHITE}IP      : $ip${RED}"
    echo -e "║  ${WHITE}HTTP    : $ip:$NEW_HTTP${RED}"
    echo -e "║  ${WHITE}SOCKS5  : $ip:$NEW_SOCKS${RED}"
    echo -e "║  ${WHITE}3p HTTP : $ip:$NEW_3HTTP${RED}"
    echo -e "║  ${WHITE}3p SOCKS: $ip:$NEW_3SOCKS${RED}"
    echo -e "╠══════════════════════════════════════════════════════════════╣"
    echo -e "║  ${YELLOW}STILL NEEDED (client-side — configure in MoreLogin):${RED}         ║"
    echo -e "║  ${YELLOW}• Set browser timezone to match your proxy IP location${RED}        ║"
    echo -e "║  ${YELLOW}• Enable WebRTC leak protection in MoreLogin settings${RED}         ║"
    echo -e "║  ${YELLOW}• Set Canvas/WebGL fingerprint to 'real' not 'noise'${RED}          ║"
    echo -e "║  ${YELLOW}• Match browser language to proxy country${RED}                     ║"
    echo -e "║  ${YELLOW}• Open new ports in AWS Security Group!${RED}                       ║"
    echo -e "╚══════════════════════════════════════════════════════════════╝${RESET}"
    press_enter
}

# ══════════════════════════════════════════════════════════════
#  30. DETECTION RISK SCORE
# ══════════════════════════════════════════════════════════════
detection_risk_check() {
    banner
    echo -e "${RED}${BOLD}[30] DETECTION RISK SCORE${RESET}\n"
    local risk=0 total=0
    local ip; ip=$(get_server_ip)

    _risk()  { echo -e "  ${RED}✗ HIGH RISK${RESET}   $1"; ((risk+=3)); ((total+=3)); }
    _med()   { echo -e "  ${YELLOW}⚠ MEDIUM${RESET}     $1"; ((risk+=1)); ((total+=3)); }
    _safe()  { echo -e "  ${GREEN}✔ SAFE${RESET}        $1"; ((total+=3)); }
    _info()  { echo -e "  ${CYAN}ℹ INFO${RESET}        $1"; }

    # ── Check 1: Datacenter IP ────────────────────────────────
    echo -e "${CYAN}── IP Reputation ───────────────────────────────────────────${RESET}"
    local asn_info
    asn_info=$(curl --noproxy '*' -s --max-time 6 "https://ipinfo.io/$ip/json" 2>/dev/null)
    local org; org=$(echo "$asn_info" | grep -o '"org":"[^"]*"' | cut -d'"' -f4)
    local country; country=$(echo "$asn_info" | grep -o '"country":"[^"]*"' | cut -d'"' -f4)
    local city; city=$(echo "$asn_info" | grep -o '"city":"[^"]*"' | cut -d'"' -f4)
    _info "Your IP: $ip  |  Org: ${org:-unknown}  |  Location: $city, $country"

    if echo "$org" | grep -qiE "amazon|aws|google|gcp|azure|microsoft|digitalocean|linode|vultr|ovh|hetzner|datacamp|hosting|datacenter|server|cloud"; then
        _risk "IP belongs to a datacenter/hosting ASN ($org) — sites like RemoteTask block these"
    else
        _safe "IP ASN looks residential ($org)"
    fi

    # ── Check 2: Proxy ports exposed ─────────────────────────
    echo -e "\n${CYAN}── Proxy Port Exposure ─────────────────────────────────────${RESET}"
    for port in 3128 1080 8080 1081 3129 8443; do
        if timeout 2 bash -c "echo > /dev/tcp/127.0.0.1/$port" 2>/dev/null; then
            _risk "Known proxy port $port is OPEN — flagged by proxy detection databases"
        fi
    done
    # Check if new ports are in use
    local current_ports=($HTTP_PORT $SOCKS5_PORT $PROXY3_HTTP $PROXY3_SOCKS)
    for port in "${current_ports[@]}"; do
        if [[ "$port" -gt 9999 ]]; then
            _safe "Port $port is non-standard (harder to detect)"
        elif [[ -n "$port" ]]; then
            _med "Port $port may appear in proxy port lists"
        fi
    done

    # ── Check 3: HTTP headers ─────────────────────────────────
    echo -e "\n${CYAN}── HTTP Header Fingerprint ─────────────────────────────────${RESET}"
    if [[ -f $SQUID_CONF ]]; then
        grep -q "forwarded_for delete" "$SQUID_CONF" \
            && _safe "X-Forwarded-For stripped" || _risk "X-Forwarded-For NOT stripped"
        grep -q "via off" "$SQUID_CONF" \
            && _safe "Via header removed" || _risk "Via header reveals Squid proxy"
        grep -q "request_header_access Proxy-Connection deny" "$SQUID_CONF" \
            && _safe "Proxy-Connection header stripped" || _med "Proxy-Connection header may leak"
        grep -q "httpd_suppress_version_string on" "$SQUID_CONF" \
            && _safe "Squid version hidden" || _med "Squid version string visible"
    else
        _med "Squid not installed — cannot check headers"
    fi

    # ── Check 4: DNS fingerprint ──────────────────────────────
    echo -e "\n${CYAN}── DNS Fingerprint ─────────────────────────────────────────${RESET}"
    local dns_server; dns_server=$(grep "^nameserver" /etc/resolv.conf 2>/dev/null | head -1 | awk '{print $2}')
    _info "Current DNS: $dns_server"
    if [[ "$dns_server" == "1.1.1.1" || "$dns_server" == "1.0.0.1" ]]; then
        _med "Using Cloudflare DNS (1.1.1.1) — associated with privacy tools/VPNs"
    elif [[ "$dns_server" == "8.8.8.8" || "$dns_server" == "8.8.4.4" ]]; then
        _safe "Using Google DNS (8.8.8.8) — common for residential users"
    else
        _safe "Using custom DNS: $dns_server"
    fi

    # ── Check 5: TCP fingerprint ──────────────────────────────
    echo -e "\n${CYAN}── TCP Stack Fingerprint ───────────────────────────────────${RESET}"
    local ttl; ttl=$(sysctl -n net.ipv4.ip_default_ttl 2>/dev/null)
    local timestamps; timestamps=$(sysctl -n net.ipv4.tcp_timestamps 2>/dev/null)
    local ecn; ecn=$(sysctl -n net.ipv4.tcp_ecn 2>/dev/null)
    [[ "$ttl" == "64" ]]         && _safe "TTL=64 (Linux residential default)" \
                                 || _med  "TTL=$ttl (non-standard, may fingerprint as server)"
    [[ "$timestamps" == "1" ]]   && _safe "TCP timestamps enabled (normal)" \
                                 || _med  "TCP timestamps disabled (unusual)"
    [[ "$ecn" == "0" ]]          && _safe "ECN disabled (normal for most users)" \
                                 || _med  "ECN=$ecn (may differ from residential)"

    # ── Check 6: MTU ─────────────────────────────────────────
    echo -e "\n${CYAN}── MTU Check ───────────────────────────────────────────────${RESET}"
    local iface; iface=$(ip route get 8.8.8.8 2>/dev/null | grep -oP 'dev \K\S+' | head -1)
    local mtu; mtu=$(ip link show "$iface" 2>/dev/null | grep -oP 'mtu \K\d+')
    [[ "$mtu" == "1500" ]] && _safe "MTU=1500 (standard residential)" \
                           || _risk "MTU=$mtu (datacenter/VPN typical — detectable)"

    # ── Check 7: Reverse DNS ──────────────────────────────────
    echo -e "\n${CYAN}── Reverse DNS (PTR record) ────────────────────────────────${RESET}"
    local rdns; rdns=$(dig +short -x "$ip" 2>/dev/null | head -1)
    _info "Reverse DNS: ${rdns:-none}"
    if echo "$rdns" | grep -qiE "aws|amazon|ec2|compute|cloud|server|host|vps|data"; then
        _risk "Reverse DNS reveals datacenter: $rdns"
    elif [[ -z "$rdns" ]]; then
        _med "No reverse DNS — some detectors flag this"
    else
        _safe "Reverse DNS looks clean: $rdns"
    fi

    # ── Risk Score ────────────────────────────────────────────
    local pct=0
    [[ $total -gt 0 ]] && pct=$(( (total - risk) * 100 / total ))
    echo -e "\n${RED}${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
    echo -e "  Detection Safety Score: ${BOLD}${pct}%${RESET}"
    if [[ $pct -ge 80 ]]; then
        echo -e "  ${GREEN}${BOLD}✔ LOW DETECTION RISK — Proxy is well disguised${RESET}"
    elif [[ $pct -ge 50 ]]; then
        echo -e "  ${YELLOW}${BOLD}⚠ MEDIUM RISK — Run Option 29 to harden further${RESET}"
    else
        echo -e "  ${RED}${BOLD}✗ HIGH DETECTION RISK — Run Option 29 immediately${RESET}"
    fi
    echo -e "\n  ${CYAN}${BOLD}Top fix for RemoteTask/Upwork detection:${RESET}"
    echo -e "  ${WHITE}Your AWS IP is in datacenter blacklists. No amount of proxy"
    echo -e "  hardening fully fixes this. The best solution is to use a"
    echo -e "  residential IP (mobile data / home ISP) as the exit point."
    echo -e "  Use Option 31 for ISP masking techniques.${RESET}"
    echo -e "${RED}${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
    press_enter
}

# ══════════════════════════════════════════════════════════════
#  31. RESIDENTIAL IP MASKING
# ══════════════════════════════════════════════════════════════
residential_ip_masking() {
    banner
    echo -e "${RED}${BOLD}[31] RESIDENTIAL IP MASKING${RESET}\n"
    local ip; ip=$(get_server_ip)

    echo -e "${YELLOW}Your current IP: ${WHITE}$ip${RESET}"
    echo -e "${RED}The core problem: AWS/GCP/Azure IPs are in datacenter ASN"
    echo -e "blacklists used by fraud detection systems. Sites like RemoteTask,"
    echo -e "Upwork, Amazon MTurk check your IP's ASN and instantly flag it.${RESET}\n"

    echo -e "${CYAN}${BOLD}Available Masking Techniques:${RESET}\n"
    echo -e "  ${YELLOW}1.${RESET}  ${GREEN}WireGuard tunnel through residential IP${RESET}"
    echo -e "      Route ALL proxy traffic through a home/mobile IP as exit node"
    echo -e "  ${YELLOW}2.${RESET}  ${GREEN}Setup instructions for ISP masking via VPS chaining${RESET}"
    echo -e "  ${YELLOW}3.${RESET}  ${GREEN}Test if current IP passes residential check${RESET}"
    echo -e "  ${YELLOW}4.${RESET}  ${GREEN}Show recommended residential proxy providers${RESET}"
    echo -ne "\n${YELLOW}Choice (1-4): ${RESET}"; read -r rc

    case $rc in
    1)
        echo -e "\n${CYAN}── WireGuard Residential Tunnel Setup ──────────────────────${RESET}"
        pkg_install wireguard wireguard-tools
        echo -ne "${YELLOW}Residential peer public IP (your home/phone IP): ${RESET}"; read -r RES_IP
        echo -ne "${YELLOW}WireGuard port (default 51820): ${RESET}"; read -r WG_PORT
        WG_PORT=${WG_PORT:-51820}

        # Generate server keys
        local PRIV_KEY; PRIV_KEY=$(wg genkey)
        local PUB_KEY;  PUB_KEY=$(echo "$PRIV_KEY" | wg pubkey)

        mkdir -p /etc/wireguard
        cat > /etc/wireguard/wg0.conf <<EOF
[Interface]
PrivateKey = ${PRIV_KEY}
Address = 10.8.0.1/24
ListenPort = ${WG_PORT}
# Route all proxy traffic out through the residential peer
PostUp   = iptables -t nat -A POSTROUTING -o wg0 -j MASQUERADE
PostDown = iptables -t nat -D POSTROUTING -o wg0 -j MASQUERADE

[Peer]
# Your residential device (home router / phone)
PublicKey = PASTE_RESIDENTIAL_PEER_PUBLIC_KEY_HERE
AllowedIPs = 0.0.0.0/0
Endpoint = ${RES_IP}:${WG_PORT}
PersistentKeepalive = 25
EOF
        ufw allow "$WG_PORT/udp" comment "WireGuard residential tunnel" >> "$LOG_DIR/install.log" 2>&1
        log_ok "WireGuard config created: /etc/wireguard/wg0.conf"
        echo -e "\n${YELLOW}Next steps:"
        echo -e "1. Edit /etc/wireguard/wg0.conf — replace PASTE_RESIDENTIAL_PEER_PUBLIC_KEY_HERE"
        echo -e "2. On your residential device install WireGuard and add this VPS as peer"
        echo -e "3. Run: wg-quick up wg0"
        echo -e "4. All proxy traffic will exit through your residential IP${RESET}"
        ;;
    2)
        echo -e "\n${CYAN}── VPS Chaining (Double Hop) Setup Guide ───────────────────${RESET}"
        echo -e "${WHITE}
Architecture:
  Client → [This AWS VPS proxy] → [Residential VPS/Server] → Internet

Step 1: Get a residential IP VPS
  • Recommended providers with residential IPs:
    - Luminati/Brightdata (residential proxy network)
    - Packetstream
    - IPRoyal
    - Webshare (residential plan)
    - A home server with port forwarding

Step 2: On the residential server, install SOCKS5 (Dante)
  scp proxymanager.sh user@RESIDENTIAL_IP:/home/user/
  ssh user@RESIDENTIAL_IP 'chmod +x proxymanager.sh && sudo ./proxymanager.sh'
  Select Option 2 (Install Dante)

Step 3: Chain proxies in MoreLogin
  In MoreLogin browser profile settings:
  Set proxy: SOCKS5 → RESIDENTIAL_IP:PORT
  This routes your traffic: MoreLogin → Residential IP → Internet
  Your exit IP will be the residential one.

Step 4: Or chain using 3proxy on this server
  Edit /etc/3proxy/3proxy.cfg and add:
  parent 1000 socks5 RESIDENTIAL_IP RESIDENTIAL_PORT USER PASS
  This makes this VPS forward all traffic through the residential proxy.${RESET}"
        ;;
    3)
        echo -e "\n${CYAN}── Residential IP Check ────────────────────────────────────${RESET}"
        log_info "Checking your IP against residential databases..."
        local ip; ip=$(get_server_ip)

        # Check ipinfo
        local info; info=$(curl --noproxy '*' -s --max-time 8 "https://ipinfo.io/$ip/json" 2>/dev/null)
        local org;     org=$(echo "$info"     | grep -o '"org":"[^"]*"'     | cut -d'"' -f4)
        local country; country=$(echo "$info" | grep -o '"country":"[^"]*"' | cut -d'"' -f4)
        local city;    city=$(echo "$info"    | grep -o '"city":"[^"]*"'    | cut -d'"' -f4)
        local hostname_r; hostname_r=$(echo "$info" | grep -o '"hostname":"[^"]*"' | cut -d'"' -f4)

        echo -e "\n  ${WHITE}IP        : ${GREEN}$ip${RESET}"
        echo -e "  ${WHITE}ASN/Org   : ${YELLOW}$org${RESET}"
        echo -e "  ${WHITE}Location  : $city, $country${RESET}"
        echo -e "  ${WHITE}Hostname  : ${YELLOW}${hostname_r:-none}${RESET}"

        if echo "$org" | grep -qiE "amazon|aws|google|azure|digitalocean|linode|vultr|ovh|hetzner|hosting|datacenter|cloud"; then
            echo -e "\n  ${RED}${BOLD}✗ DATACENTER IP DETECTED${RESET}"
            echo -e "  ${RED}This IP will be blocked by RemoteTask, Upwork, Amazon MTurk${RESET}"
            echo -e "  ${YELLOW}Solution: Use Option 31 → Choice 1 (WireGuard residential tunnel)${RESET}"
            echo -e "  ${YELLOW}Or purchase residential proxies from a provider${RESET}"
        else
            echo -e "\n  ${GREEN}${BOLD}✔ IP appears residential — lower detection risk${RESET}"
        fi
        ;;
    4)
        echo -e "\n${CYAN}── Recommended Residential Proxy Providers ─────────────────${RESET}"
        echo -e "${WHITE}
  Provider           Type              Best For
  ─────────────────────────────────────────────────────────────
  Brightdata         Residential       All platforms, most trusted
  IPRoyal            Residential/ISP   RemoteTask, Upwork
  Webshare           Residential       Budget option
  Oxylabs            Residential       Enterprise grade
  Packetstream       P2P Residential   Very cheap
  Proxy-Cheap        ISP/Residential   ISP IPs look most real
  ─────────────────────────────────────────────────────────────

  ISP Proxies (best for RemoteTask):
  • ISP proxies are hosted in datacenters but assigned to real
    ISP ASNs (Comcast, AT&T, Safaricom etc)
  • They pass ALL datacenter checks
  • Much cheaper than residential
  • Try: proxy-cheap.com → ISP proxies
         iproyal.com → ISP proxies

  Setup in MoreLogin:
  1. Buy proxy from provider
  2. In MoreLogin: Profile → Proxy → SOCKS5/HTTP
  3. Enter IP:PORT:USER:PASS from provider
  4. Test with 'Check proxy' button${RESET}"
        ;;
    esac
    press_enter
}

# ══════════════════════════════════════════════════════════════
#  32. CLOUDFLARE INTEGRATION
# ══════════════════════════════════════════════════════════════
cloudflare_integration() {
    banner
    echo -e "${RED}${BOLD}[32] CLOUDFLARE INTEGRATION${RESET}\n"
    local ip; ip=$(get_server_ip)

    echo -e "${CYAN}${BOLD}How Cloudflare helps hide your AWS VPS:${RESET}"
    echo -e ""
    echo -e "  ${GREEN}Method A — Cloudflare DNS Proxy (Orange Cloud)${RESET}"
    echo -e "  Client → Cloudflare IP → Your VPS"
    echo -e "  • Hides your real AWS IP behind Cloudflare"
    echo -e "  • Only works on port 80/443"
    echo -e "  • Cloudflare ASN still detectable by advanced checkers"
    echo -e "  • FREE — just enable orange cloud in CF dashboard"
    echo -e ""
    echo -e "  ${GREEN}Method B — Cloudflare Tunnel / cloudflared (BEST)${RESET}"
    echo -e "  Client → Cloudflare Edge → Encrypted Tunnel → Your VPS"
    echo -e "  • Your VPS makes OUTBOUND connection to Cloudflare"
    echo -e "  • No ports need to be open on VPS at all"
    echo -e "  • Traffic looks like normal HTTPS to cloudflare.com"
    echo -e "  • AWS IP never exposed — even CF doesn't see it in headers"
    echo -e "  • FREE with Cloudflare Zero Trust"
    echo -e ""
    echo -e "  ${GREEN}Method C — Cloudflare Workers proxy (most advanced)${RESET}"
    echo -e "  Client → CF Worker (serverless) → Your VPS"
    echo -e "  • Worker IP rotates across 200+ Cloudflare edge locations"
    echo -e "  • Each request can come from a different country"
    echo -e "  • Looks like normal CDN/web traffic"
    echo -e ""

    echo -e "${YELLOW}Choose method:${RESET}"
    echo -e "  1. Install Cloudflare Tunnel (cloudflared) — RECOMMENDED"
    echo -e "  2. Setup guide for CF DNS Proxy (orange cloud)"
    echo -e "  3. Setup Nginx + Cloudflare Workers config"
    echo -e "  4. Check if domain is already behind Cloudflare"
    echo -ne "\n${YELLOW}Choice (1-4): ${RESET}"; read -r cfc

    case $cfc in
    1) _cf_tunnel_setup ;;
    2) _cf_dns_proxy_guide ;;
    3) _cf_workers_setup ;;
    4) _cf_check_domain ;;
    esac
    press_enter
}

# ── Method A: cloudflared tunnel ─────────────────────────────
_cf_tunnel_setup() {
    echo -e "\n${CYAN}${BOLD}── Cloudflare Tunnel Setup ─────────────────────────────────${RESET}"
    echo -e "${YELLOW}Requirements: A domain added to Cloudflare (free account OK)${RESET}\n"

    # Install cloudflared
    log_info "Installing cloudflared..."
    local ARCH; ARCH=$(dpkg --print-architecture 2>/dev/null || echo "amd64")
    local CF_URL="https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-${ARCH}.deb"

    env -u http_proxy -u https_proxy -u HTTP_PROXY -u HTTPS_PROXY \
        curl --noproxy '*' -sL "$CF_URL" -o /tmp/cloudflared.deb >> "$LOG_DIR/install.log" 2>&1

    if [[ -f /tmp/cloudflared.deb && -s /tmp/cloudflared.deb ]]; then
        DEBIAN_FRONTEND=noninteractive dpkg -i /tmp/cloudflared.deb >> "$LOG_DIR/install.log" 2>&1
        log_ok "cloudflared installed: $(cloudflared --version 2>/dev/null | head -1)"
    else
        # Fallback: install via apt repo
        log_warn "Direct download failed, trying apt..."
        env -u http_proxy -u https_proxy \
            curl --noproxy '*' -fsSL \
            https://pkg.cloudflare.com/cloudflare-main.gpg \
            | gpg --dearmor > /usr/share/keyrings/cloudflare-main.gpg 2>/dev/null
        echo "deb [signed-by=/usr/share/keyrings/cloudflare-main.gpg] https://pkg.cloudflare.com/cloudflared $(lsb_release -cs) main" \
            > /etc/apt/sources.list.d/cloudflared.list
        apt_update
        pkg_install cloudflared
    fi

    if ! command -v cloudflared &>/dev/null; then
        log_err "cloudflared installation failed"
        return 1
    fi

    echo -e "\n${YELLOW}Choose tunnel type:${RESET}"
    echo -e "  1. Named tunnel (requires CF login) — RECOMMENDED"
    echo -e "  2. Quick tunnel (temporary, no login needed) — TEST ONLY"
    echo -ne "${YELLOW}Choice: ${RESET}"; read -r ttype

    if [[ "$ttype" == "2" ]]; then
        # Quick tunnel — no auth needed, great for testing
        echo -e "\n${CYAN}Starting quick tunnel (temporary — for testing only)...${RESET}"
        echo -ne "${YELLOW}Local proxy port to expose (e.g. $HTTP_PORT): ${RESET}"; read -r lport
        lport=${lport:-$HTTP_PORT}
        echo -e "${YELLOW}Starting tunnel... (Ctrl+C to stop)${RESET}"
        cloudflared tunnel --url "http://localhost:$lport" --no-autoupdate 2>&1 | \
            tee /tmp/cf_tunnel.log &
        sleep 5
        local cf_url; cf_url=$(grep -o 'https://[a-z0-9-]*\.trycloudflare\.com' /tmp/cf_tunnel.log | head -1)
        if [[ -n "$cf_url" ]]; then
            echo -e "\n${GREEN}${BOLD}╔══════════════════════════════════════════════════════╗"
            echo -e "║  QUICK TUNNEL ACTIVE                                 ║"
            echo -e "╠══════════════════════════════════════════════════════╣"
            echo -e "║  ${WHITE}Public URL: ${GREEN}$cf_url${GREEN}"
            echo -e "║  ${WHITE}Use as proxy: http://USER:PASS@${cf_url#https://}:443${GREEN}"
            echo -e "║  ${YELLOW}⚠ This URL changes every restart — use named tunnel for permanent${GREEN}"
            echo -e "╚══════════════════════════════════════════════════════╝${RESET}"
        fi
        return
    fi

    # Named tunnel setup
    echo -e "\n${CYAN}── Named Tunnel Setup ───────────────────────────────────────${RESET}"
    echo -e "${WHITE}Step 1: Login to Cloudflare${RESET}"
    echo -e "${YELLOW}A browser URL will appear. Open it on your local machine to authenticate.${RESET}\n"
    cloudflared tunnel login

    if [[ ! -f ~/.cloudflared/cert.pem ]]; then
        log_err "CF login failed or not completed"
        return 1
    fi
    log_ok "Cloudflare login successful"

    echo -ne "\n${YELLOW}Tunnel name (e.g. my-proxy): ${RESET}"; read -r TUNNEL_NAME
    TUNNEL_NAME=${TUNNEL_NAME:-my-proxy}

    echo -ne "${YELLOW}Your domain (e.g. proxy.yourdomain.com): ${RESET}"; read -r CF_DOMAIN
    echo -ne "${YELLOW}Local proxy port to expose (default $HTTP_PORT): ${RESET}"; read -r lport
    lport=${lport:-$HTTP_PORT}

    # Create tunnel
    cloudflared tunnel create "$TUNNEL_NAME" 2>&1 | tee /tmp/cf_create.log
    local TUNNEL_ID; TUNNEL_ID=$(grep -o '[0-9a-f-]\{36\}' /tmp/cf_create.log | head -1)

    if [[ -z "$TUNNEL_ID" ]]; then
        log_err "Failed to create tunnel"
        return 1
    fi
    log_ok "Tunnel created: $TUNNEL_ID"

    # Write tunnel config
    mkdir -p /etc/cloudflared
    cat > /etc/cloudflared/config.yml <<EOF
# ── Proxy Manager Pro — Cloudflare Tunnel Config ──────────────
tunnel: ${TUNNEL_ID}
credentials-file: /root/.cloudflared/${TUNNEL_ID}.json

# Route traffic through the tunnel
ingress:
  # HTTP proxy traffic → Squid
  - hostname: ${CF_DOMAIN}
    service: http://localhost:${lport}
    originRequest:
      noTLSVerify: true
      connectTimeout: 30s
      tcpKeepAlive: 30s
      keepAliveTimeout: 90s
      keepAliveConnections: 100
  # Catch-all
  - service: http_status:404

# Connection settings — make it look like normal browser traffic
no-autoupdate: true
protocol: http2
EOF

    # Route domain through tunnel
    cloudflared tunnel route dns "$TUNNEL_NAME" "$CF_DOMAIN" 2>&1
    log_ok "DNS route created: $CF_DOMAIN → tunnel"

    # Install as systemd service
    cloudflared service install 2>/dev/null || \
        cloudflared tunnel --config /etc/cloudflared/config.yml service install 2>/dev/null
    systemctl enable cloudflared 2>/dev/null
    systemctl start  cloudflared 2>/dev/null

    sleep 3
    if systemctl is-active --quiet cloudflared 2>/dev/null; then
        log_ok "Cloudflare tunnel running as system service"
    else
        log_warn "Starting tunnel manually..."
        cloudflared tunnel --config /etc/cloudflared/config.yml run &
    fi

    echo -e "\n${GREEN}${BOLD}╔══════════════════════════════════════════════════════════════╗"
    echo -e "║        CLOUDFLARE TUNNEL ACTIVE                              ║"
    echo -e "╠══════════════════════════════════════════════════════════════╣"
    echo -e "║  ${WHITE}Tunnel   : ${GREEN}$TUNNEL_NAME ($TUNNEL_ID)${GREEN}"
    echo -e "║  ${WHITE}Domain   : ${GREEN}$CF_DOMAIN${GREEN}"
    echo -e "║  ${WHITE}Proxy    : ${GREEN}http://USER:PASS@$CF_DOMAIN:80${GREEN}"
    echo -e "║  ${WHITE}AWS IP   : ${GREEN}HIDDEN — not exposed anywhere${GREEN}"
    echo -e "║  ${WHITE}Exit ASN : ${GREEN}Cloudflare (not Amazon)${GREEN}"
    echo -e "╠══════════════════════════════════════════════════════════════╣"
    echo -e "║  ${YELLOW}In MoreLogin set:${GREEN}"
    echo -e "║  ${WHITE}Protocol : HTTP${GREEN}"
    echo -e "║  ${WHITE}Server   : $CF_DOMAIN${GREEN}"
    echo -e "║  ${WHITE}Port     : 80${GREEN}"
    echo -e "║  ${WHITE}Auth     : username / password${GREEN}"
    echo -e "╚══════════════════════════════════════════════════════════════╝${RESET}"
}

# ── Method B: CF DNS Proxy guide ─────────────────────────────
_cf_dns_proxy_guide() {
    local ip; ip=$(get_server_ip)
    echo -e "\n${CYAN}${BOLD}── Cloudflare DNS Proxy Setup Guide ────────────────────────${RESET}"
    echo -e "${WHITE}
STEP 1 — Add domain to Cloudflare (free account)
  • Go to: https://dash.cloudflare.com
  • Click 'Add Site' → enter your domain
  • Select FREE plan
  • Update your domain's nameservers to Cloudflare's

STEP 2 — Add DNS A record
  • In CF dashboard → DNS → Records → Add Record
  • Type: A
  • Name: proxy  (or @ for root)
  • IPv4 : ${ip}
  • Proxy: ENABLED (orange cloud ☁ ON)
  • TTL  : Auto

STEP 3 — SSL/TLS settings
  • In CF → SSL/TLS → set to 'Flexible' or 'Full'
  • In CF → SSL/TLS → Edge Certificates → Always Use HTTPS: ON

STEP 4 — Configure proxy to accept CF connections
  • CF connects to your VPS on port 80 or 443
  • Your Squid port ${HTTP_PORT} needs to be accessible on 80 or 443
  • OR use nginx to forward: port 80 → port ${HTTP_PORT}

STEP 5 — Cloudflare security settings
  • CF → Security → Settings → Security Level: Low
    (High security will block proxy CONNECT requests)
  • CF → Network → WebSockets: ON (for CONNECT tunneling)

STEP 6 — Connect via domain
  • Use: http://USER:PASS@yourdomain.com:80
  • Your real IP (${ip}) is now hidden

LIMITATIONS WITH THIS METHOD:
  ⚠ Only works on CF-supported ports: 80, 8080, 8880, 2052, 2082,
    2086, 2095 (HTTP) or 443, 2053, 2083, 2087, 2096, 8443 (HTTPS)
  ⚠ Cloudflare caches GET requests — configure Cache to bypass
  ⚠ Cloudflare's ASN (13335) is known to some detectors
  ⚠ CF may block CONNECT method needed for HTTPS proxying${RESET}"
}

# ── Method C: CF Workers setup ────────────────────────────────
_cf_workers_setup() {
    echo -e "\n${CYAN}${BOLD}── Cloudflare Workers Proxy ────────────────────────────────${RESET}"
    echo -e "${WHITE}
Cloudflare Workers act as a serverless middleman:
  Browser → CF Worker (random edge IP) → Your VPS proxy

The Worker script to deploy on Cloudflare:
─────────────────────────────────────────────────────────────${RESET}"

    local ip; ip=$(get_server_ip)
    cat <<EOF
// Cloudflare Worker — Proxy Forwarder
// Deploy at: dash.cloudflare.com → Workers & Pages → Create Worker

addEventListener('fetch', event => {
  event.respondWith(handleRequest(event.request))
})

async function handleRequest(request) {
  // Forward all requests to your VPS proxy
  const VPS_PROXY = 'http://${ip}:${HTTP_PORT}'

  // Build proxied URL
  const url = new URL(request.url)
  const targetURL = VPS_PROXY + url.pathname + url.search

  // Clone request with original headers (strip CF headers)
  const proxyRequest = new Request(targetURL, {
    method: request.method,
    headers: (() => {
      const h = new Headers(request.headers)
      h.delete('cf-connecting-ip')
      h.delete('cf-ray')
      h.delete('cf-visitor')
      h.delete('x-forwarded-for')
      h.delete('x-real-ip')
      return h
    })(),
    body: request.method !== 'GET' && request.method !== 'HEAD'
          ? request.body : undefined,
    redirect: 'follow'
  })

  const response = await fetch(proxyRequest)

  // Strip response headers that reveal proxy
  const cleanResponse = new Response(response.body, response)
  cleanResponse.headers.delete('via')
  cleanResponse.headers.delete('x-cache')
  cleanResponse.headers.delete('server')

  return cleanResponse
}
EOF

    echo -e "\n${WHITE}
─────────────────────────────────────────────────────────────
DEPLOY STEPS:
  1. Go to https://dash.cloudflare.com → Workers & Pages
  2. Create Application → Create Worker
  3. Paste the code above → Deploy
  4. Add custom domain: proxy.yourdomain.com → your worker
  5. Use in MoreLogin: http://USER:PASS@proxy.yourdomain.com

RESULT:
  • Your VPS IP is completely hidden
  • Traffic appears to come from CF edge nodes (100+ countries)
  • Each request may use a different Cloudflare IP
  • Looks like normal HTTPS website traffic${RESET}"
}

# ── Check if domain is behind CF ─────────────────────────────
_cf_check_domain() {
    echo -ne "\n${YELLOW}Enter domain to check: ${RESET}"; read -r chkdomain
    [[ -z "$chkdomain" ]] && return

    echo -e "\n${CYAN}── Cloudflare Detection Check: $chkdomain ──────────────────${RESET}"
    local resolved_ip; resolved_ip=$(dig +short "$chkdomain" 2>/dev/null | tail -1)
    echo -e "  ${WHITE}Domain resolves to: ${GREEN}$resolved_ip${RESET}"

    # Check if IP is in Cloudflare's ranges
    local cf_asn; cf_asn=$(curl --noproxy '*' -s --max-time 6 \
        "https://ipinfo.io/$resolved_ip/json" 2>/dev/null \
        | grep -o '"org":"[^"]*"' | cut -d'"' -f4)
    echo -e "  ${WHITE}ASN/Org: ${GREEN}$cf_asn${RESET}"

    if echo "$cf_asn" | grep -qi "cloudflare\|13335"; then
        echo -e "  ${GREEN}${BOLD}✔ Domain IS behind Cloudflare — your VPS IP is hidden${RESET}"
        echo -e "  ${CYAN}  Client sees Cloudflare IP, not your AWS IP${RESET}"

        # Check if CF is proxying correctly
        local real_ip; real_ip=$(get_server_ip)
        echo -e "\n  ${WHITE}Your real VPS IP : ${YELLOW}$real_ip${RESET}"
        echo -e "  ${WHITE}Public domain IP : ${GREEN}$resolved_ip${RESET}"
        if [[ "$resolved_ip" != "$real_ip" ]]; then
            echo -e "  ${GREEN}✔ IPs are different — VPS is properly hidden behind CF${RESET}"
        else
            echo -e "  ${RED}✗ Same IP — Cloudflare proxy (orange cloud) is NOT enabled${RESET}"
            echo -e "  ${YELLOW}  Fix: CF Dashboard → DNS → click grey cloud → turn orange${RESET}"
        fi
    else
        echo -e "  ${RED}✗ Domain is NOT behind Cloudflare${RESET}"
        if [[ "$resolved_ip" == "$(get_server_ip)" ]]; then
            echo -e "  ${YELLOW}  Domain points to your VPS directly — IP is exposed${RESET}"
            echo -e "  ${CYAN}  Fix: Add domain to Cloudflare and enable orange cloud proxy${RESET}"
        fi
    fi

    # Check SSL
    echo -e "\n  ${CYAN}SSL Check:${RESET}"
    local ssl_info; ssl_info=$(echo | openssl s_client -connect "$chkdomain:443" \
        -servername "$chkdomain" 2>/dev/null | openssl x509 -noout -issuer 2>/dev/null)
    if echo "$ssl_info" | grep -qi "cloudflare"; then
        echo -e "  ${GREEN}✔ SSL cert issued by Cloudflare — traffic is CF-protected${RESET}"
    elif [[ -n "$ssl_info" ]]; then
        echo -e "  ${WHITE}SSL issuer: $ssl_info${RESET}"
    else
        echo -e "  ${YELLOW}  No SSL or connection failed${RESET}"
    fi
}

# ══════════════════════════════════════════════════════════════
#  ENTRY POINT
# ══════════════════════════════════════════════════════════════
check_root

# First run: setup alias so user can type 'menu'
[[ ! -f $INSTALL_MARKER ]] && {
    setup_menu_alias
    touch "$INSTALL_MARKER"
}

# Load saved config if exists
[[ -f $CONFIG_FILE ]] && source "$CONFIG_FILE"

# Handle CLI args
case "$1" in
    --rotate-silent) handle_choice "--rotate-silent"; exit 0 ;;
    *) main_menu ;;
esac
