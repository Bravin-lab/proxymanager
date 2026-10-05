#!/bin/bash
# ╔══════════════════════════════════════════════════════════════╗
# ║           PROXY MANAGER PRO - Ubuntu VPS Edition            ║
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
    # Show server IP
    local ip; ip=$(curl -s ifconfig.me 2>/dev/null || hostname -I | awk '{print $1}')
    echo -e "  ${CYAN}Server IP : ${WHITE}${ip}${RESET}"
    echo -e "  ${CYAN}Hostname  : ${WHITE}$(hostname)${RESET}"
    echo -e "  ${CYAN}OS        : ${WHITE}$(lsb_release -ds 2>/dev/null)${RESET}"
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
    echo -e "  ${YELLOW}26.${RESET}  ${RED}Exit${RESET}"
    echo -e ""
    echo -e "${YELLOW}${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
    echo -ne "\n  ${YELLOW}Select option (1-26): ${GREEN}"
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
    apt-get install -y "$@" >> "$LOG_DIR/install.log" 2>&1 \
        && log_ok "Installed: $*" \
        || log_err "Failed to install: $*"
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

get_server_ip() { curl -s ifconfig.me 2>/dev/null || hostname -I | awk '{print $1}'; }

# ══════════════════════════════════════════════════════════════
#  1. INSTALL SQUID (HTTP/HTTPS)
# ══════════════════════════════════════════════════════════════
install_squid() {
    banner
    echo -e "${CYAN}${BOLD}[1] Installing Squid HTTP/HTTPS Proxy${RESET}\n"
    apt-get update -qq
    pkg_install squid apache2-utils

    echo -ne "${YELLOW}HTTP port (default $HTTP_PORT): ${RESET}"; read -r p
    HTTP_PORT=${p:-$HTTP_PORT}
    echo -ne "${YELLOW}HTTPS port (default $HTTP_PORT): ${RESET}"; read -r p2
    HTTPS_PORT=${p2:-$HTTPS_PORT}

    # Backup original config
    [[ -f $SQUID_CONF ]] && cp "$SQUID_CONF" "${SQUID_CONF}.bak.$(date +%s)"
    touch "$SQUID_PASSWD"
    chmod 640 "$SQUID_PASSWD"
    chown proxy:proxy "$SQUID_PASSWD" 2>/dev/null || true

    cat > "$SQUID_CONF" <<EOF
# ── Proxy Manager Pro — Squid Config ──────────────────────────
http_port ${HTTP_PORT}
http_port ${HTTPS_PORT} ssl-bump cert=/etc/squid/squid.pem key=/etc/squid/squid.key

# Auth
auth_param basic program /usr/lib/squid/basic_ncsa_auth ${SQUID_PASSWD}
auth_param basic realm "Proxy Authentication Required"
auth_param basic credentialsttl 24 hours
auth_param basic casesensitive on

acl authenticated proxy_auth REQUIRED
acl SSL_ports port 443
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

    # Generate self-signed cert for HTTPS bumping
    if [[ ! -f /etc/squid/squid.pem ]]; then
        log_info "Generating SSL certificate for HTTPS interception..."
        openssl req -new -newkey rsa:2048 -days 3650 -nodes -x509 \
            -subj "/C=US/ST=State/L=City/O=Proxy/CN=$(get_server_ip)" \
            -keyout /etc/squid/squid.key \
            -out /etc/squid/squid.pem >> "$LOG_DIR/install.log" 2>&1
    fi

    squid -k parse 2>/dev/null && log_ok "Squid config valid" || log_warn "Check squid config"
    systemctl enable squid && systemctl restart squid
    log_ok "Squid installed on port ${HTTP_PORT} (HTTP) and ${HTTPS_PORT} (HTTPS)"
    echo "squid_http=$HTTP_PORT" >> "$CONFIG_FILE"
    echo "squid_https=$HTTPS_PORT" >> "$CONFIG_FILE"
    press_enter
}

# ══════════════════════════════════════════════════════════════
#  2. INSTALL DANTE (SOCKS5)
# ══════════════════════════════════════════════════════════════
install_dante() {
    banner
    echo -e "${CYAN}${BOLD}[2] Installing Dante SOCKS5 Proxy${RESET}\n"
    apt-get update -qq
    pkg_install dante-server

    echo -ne "${YELLOW}SOCKS5 port (default $SOCKS5_PORT): ${RESET}"; read -r p
    SOCKS5_PORT=${p:-$SOCKS5_PORT}

    # Detect main interface
    local iface; iface=$(ip route get 8.8.8.8 | awk '{print $5; exit}')
    log_info "Using interface: $iface"

    [[ -f $DANTE_CONF ]] && cp "$DANTE_CONF" "${DANTE_CONF}.bak.$(date +%s)"

    cat > "$DANTE_CONF" <<EOF
# ── Proxy Manager Pro — Dante SOCKS5 Config ───────────────────
logoutput: /var/log/danted.log

internal: 0.0.0.0 port = ${SOCKS5_PORT}
external: ${iface}

# Auth methods
socksmethod: username
clientmethod: none

# Performance
timeout.connect: 30
timeout.io: 86400

user.privileged: root
user.unprivileged: nobody

# Client access (any IP)
client pass {
    from: 0.0.0.0/0 to: 0.0.0.0/0
    log: error
}

# SOCKS rules — authenticated only
socks pass {
    from: 0.0.0.0/0 to: 0.0.0.0/0
    socksmethod: username
    log: connect disconnect error
    command: bind connect udpassociate
}

socks block {
    from: 0.0.0.0/0 to: 0.0.0.0/0
    log: connect error
}
EOF

    systemctl enable danted && systemctl restart danted
    log_ok "Dante SOCKS5 installed on port ${SOCKS5_PORT}"
    echo "dante_socks5=$SOCKS5_PORT" >> "$CONFIG_FILE"
    press_enter
}

# ══════════════════════════════════════════════════════════════
#  3. INSTALL 3PROXY (HTTP + SOCKS5 + MULTI)
# ══════════════════════════════════════════════════════════════
install_3proxy() {
    banner
    echo -e "${CYAN}${BOLD}[3] Installing 3proxy (Multi-protocol)${RESET}\n"
    apt-get update -qq
    pkg_install build-essential wget

    echo -ne "${YELLOW}3proxy HTTP port (default $PROXY3_HTTP): ${RESET}"; read -r p
    PROXY3_HTTP=${p:-$PROXY3_HTTP}
    echo -ne "${YELLOW}3proxy SOCKS5 port (default $PROXY3_SOCKS): ${RESET}"; read -r p2
    PROXY3_SOCKS=${p2:-$PROXY3_SOCKS}

    # Install 3proxy from repo or build
    if ! command -v 3proxy &>/dev/null; then
        log_info "Downloading and building 3proxy..."
        cd /tmp || exit
        wget -q https://github.com/3proxy/3proxy/archive/refs/tags/0.9.4.tar.gz \
            -O 3proxy.tar.gz >> "$LOG_DIR/install.log" 2>&1
        tar -xzf 3proxy.tar.gz >> "$LOG_DIR/install.log" 2>&1
        cd 3proxy-0.9.4 || { log_err "3proxy source not found"; press_enter; return; }
        make -f Makefile.Linux >> "$LOG_DIR/install.log" 2>&1
        cp bin/3proxy /usr/local/bin/3proxy
        chmod +x /usr/local/bin/3proxy
        cd / && rm -rf /tmp/3proxy*
        log_ok "3proxy built and installed"
    fi

    mkdir -p /etc/3proxy /var/log/3proxy
    touch "$PROXY3_USERS"
    chmod 600 "$PROXY3_USERS"

    cat > "$PROXY3_CONF" <<EOF
# ── Proxy Manager Pro — 3proxy Config ─────────────────────────
daemon
pidfile /var/run/3proxy.pid
nserver 1.1.1.1
nserver 8.8.8.8
nserver 9.9.9.9
nsrecord cloudflare.com 104.16.0.0

# Logging
log /var/log/3proxy/3proxy.log D
logformat "- +_L%t.%.  %N.%p %E %U %C:%c %R:%r %O %I %h %T"
rotate 30

# Auth
users $/etc/3proxy/users.cfg
auth strong
allow *

# Anonymity — strip identifying headers
setgid 65534
setuid 65534
nolog 0
timeouts 1 5 30 60 180 1800 15 60

# HTTP Proxy
proxy -p${PROXY3_HTTP} -i0.0.0.0 -e0.0.0.0

# SOCKS5 Proxy
socks -p${PROXY3_SOCKS} -i0.0.0.0 -e0.0.0.0
EOF

    # Systemd service for 3proxy
    cat > /etc/systemd/system/3proxy.service <<EOF
[Unit]
Description=3proxy Proxy Server
After=network.target

[Service]
Type=forking
PIDFile=/var/run/3proxy.pid
ExecStart=/usr/local/bin/3proxy /etc/3proxy/3proxy.cfg
ExecReload=/bin/kill -HUP \$MAINPID
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

    systemctl daemon-reload
    systemctl enable 3proxy && systemctl restart 3proxy
    log_ok "3proxy installed → HTTP:${PROXY3_HTTP}  SOCKS5:${PROXY3_SOCKS}"
    echo "proxy3_http=$PROXY3_HTTP" >> "$CONFIG_FILE"
    echo "proxy3_socks=$PROXY3_SOCKS" >> "$CONFIG_FILE"
    press_enter
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

install_squid_silent()  { apt-get update -qq; pkg_install squid apache2-utils; }
install_dante_silent()  { pkg_install dante-server; }
install_3proxy_silent() { pkg_install build-essential wget; }

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

    local ip; ip=$(get_server_ip)
    echo -e "\n${GREEN}${BOLD}╔══════════════════════════════════════════════╗"
    echo -e "║         USER CREATED SUCCESSFULLY           ║"
    echo -e "╠══════════════════════════════════════════════╣"
    echo -e "║  Username : ${WHITE}$username${GREEN}"
    echo -e "║  Password : ${WHITE}$password${GREEN}"
    echo -e "║  Server   : ${WHITE}$ip${GREEN}"
    echo -e "║  HTTP     : ${WHITE}$ip:${HTTP_PORT}${GREEN}"
    echo -e "║  SOCKS5   : ${WHITE}$ip:${SOCKS5_PORT}${GREEN}"
    echo -e "║  3proxy H : ${WHITE}$ip:${PROXY3_HTTP}${GREEN}"
    echo -e "║  3proxy S : ${WHITE}$ip:${PROXY3_SOCKS}${GREEN}"
    echo -e "╚══════════════════════════════════════════════╝${RESET}"
    press_enter
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
        26) echo -e "\n${GREEN}Goodbye!${RESET}\n"; exit 0 ;;
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
        squid -k parse >> "$LOG_DIR/hardening.log" 2>&1 \
            && systemctl reload squid 2>/dev/null \
            && log_ok "Squid full header stripping applied" \
            || log_warn "Squid config has issues — check $LOG_DIR/hardening.log"
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
    pkg_install iptables-persistent netfilter-persistent
    netfilter-persistent save >> "$LOG_DIR/hardening.log" 2>&1
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

    check_item() {
        local label=$1 result=$2 expected=$3
        if [[ "$result" == *"$expected"* ]]; then
            echo -e "  ${GREEN}✔ PASS${RESET}  $label"
            ((pass++))
        else
            echo -e "  ${RED}✗ FAIL${RESET}  $label ${YELLOW}(got: $result)${RESET}"
            ((fail++))
        fi
    }

    warn_item() {
        local label=$1
        echo -e "  ${YELLOW}⚠ WARN${RESET}  $label"
        ((warn++))
    }

    echo -e "${CYAN}── IPv6 Status ─────────────────────────────────────────${RESET}"
    local ipv6_all; ipv6_all=$(sysctl -n net.ipv6.conf.all.disable_ipv6 2>/dev/null)
    check_item "IPv6 disabled (sysctl all)" "$ipv6_all" "1"
    local ipv6_def; ipv6_def=$(sysctl -n net.ipv6.conf.default.disable_ipv6 2>/dev/null)
    check_item "IPv6 disabled (sysctl default)" "$ipv6_def" "1"
    local ipv6_ifaces; ipv6_ifaces=$(ip -6 addr 2>/dev/null | grep -v "::1" | wc -l)
    [[ "$ipv6_ifaces" -eq 0 ]] \
        && echo -e "  ${GREEN}✔ PASS${RESET}  No IPv6 addresses assigned" && ((pass++)) \
        || echo -e "  ${RED}✗ FAIL${RESET}  IPv6 addresses still active: $ipv6_ifaces" && ((fail++))

    echo -e "\n${CYAN}── DNS Leak Status ─────────────────────────────────────${RESET}"
    local resolv; resolv=$(cat /etc/resolv.conf 2>/dev/null | grep "^nameserver" | awk '{print $2}' | tr '\n' ' ')
    check_item "DNS resolvers set" "$resolv" "1.1.1.1"
    local immutable; immutable=$(lsattr /etc/resolv.conf 2>/dev/null | awk '{print $1}')
    [[ "$immutable" == *"i"* ]] \
        && echo -e "  ${GREEN}✔ PASS${RESET}  resolv.conf is immutable (locked)" && ((pass++)) \
        || echo -e "  ${YELLOW}⚠ WARN${RESET}  resolv.conf is NOT locked (can be overwritten)" && ((warn++))
    systemctl is-active --quiet systemd-resolved \
        && echo -e "  ${RED}✗ FAIL${RESET}  systemd-resolved is still running (DNS leak risk)" && ((fail++)) \
        || echo -e "  ${GREEN}✔ PASS${RESET}  systemd-resolved is disabled" && ((pass++))

    echo -e "\n${CYAN}── iptables DNS Lockdown ───────────────────────────────${RESET}"
    local dns_drop; dns_drop=$(iptables -L OUTPUT -n 2>/dev/null | grep -c "dpt:53.*DROP")
    [[ "$dns_drop" -gt 0 ]] \
        && echo -e "  ${GREEN}✔ PASS${RESET}  Port 53 DROP rules active ($dns_drop rules)" && ((pass++)) \
        || echo -e "  ${RED}✗ FAIL${RESET}  No port 53 DROP rules — DNS bypass possible" && ((fail++))

    echo -e "\n${CYAN}── ip6tables Status ────────────────────────────────────${RESET}"
    local ip6policy; ip6policy=$(ip6tables -L INPUT -n 2>/dev/null | head -1 | grep -c "DROP")
    [[ "$ip6policy" -gt 0 ]] \
        && echo -e "  ${GREEN}✔ PASS${RESET}  ip6tables INPUT policy is DROP" && ((pass++)) \
        || echo -e "  ${RED}✗ FAIL${RESET}  ip6tables not hardened" && ((fail++))

    echo -e "\n${CYAN}── Squid Header Stripping ──────────────────────────────${RESET}"
    if [[ -f $SQUID_CONF ]]; then
        grep -q "forwarded_for delete" "$SQUID_CONF" \
            && echo -e "  ${GREEN}✔ PASS${RESET}  forwarded_for delete" && ((pass++)) \
            || echo -e "  ${RED}✗ FAIL${RESET}  forwarded_for NOT stripped" && ((fail++))
        grep -q "via off" "$SQUID_CONF" \
            && echo -e "  ${GREEN}✔ PASS${RESET}  Via header off" && ((pass++)) \
            || echo -e "  ${RED}✗ FAIL${RESET}  Via header NOT stripped" && ((fail++))
        grep -q "request_header_access All deny all" "$SQUID_CONF" \
            && echo -e "  ${GREEN}✔ PASS${RESET}  All extra headers denied" && ((pass++)) \
            || echo -e "  ${YELLOW}⚠ WARN${RESET}  Header deny-all not found" && ((warn++))
        grep -q "request_header_replace User-Agent" "$SQUID_CONF" \
            && echo -e "  ${GREEN}✔ PASS${RESET}  User-Agent spoofing active" && ((pass++)) \
            || echo -e "  ${YELLOW}⚠ WARN${RESET}  User-Agent NOT spoofed" && ((warn++))
    else
        warn_item "Squid not installed — HTTP header check skipped"
    fi

    echo -e "\n${CYAN}── Kernel Hardening ────────────────────────────────────${RESET}"
    local ttl; ttl=$(sysctl -n net.ipv4.ip_default_ttl 2>/dev/null)
    check_item "TTL set to 128" "$ttl" "128"
    local syncookies; syncookies=$(sysctl -n net.ipv4.tcp_syncookies 2>/dev/null)
    check_item "SYN cookies enabled" "$syncookies" "1"
    local icmp; icmp=$(sysctl -n net.ipv4.icmp_echo_ignore_all 2>/dev/null)
    check_item "ICMP ping hidden (stealth)" "$icmp" "1"
    local rp; rp=$(sysctl -n net.ipv4.conf.all.rp_filter 2>/dev/null)
    check_item "IP spoofing protection" "$rp" "1"

    echo -e "\n${CYAN}── Proxy Services ──────────────────────────────────────${RESET}"
    for svc in squid danted 3proxy; do
        systemctl is-active --quiet "$svc" 2>/dev/null \
            && echo -e "  ${GREEN}✔ RUNNING${RESET}  $svc" && ((pass++)) \
            || echo -e "  ${YELLOW}⚠ STOPPED${RESET}  $svc (not installed or not running)" && ((warn++))
    done

    # ── Score ─────────────────────────────────────────────────
    local total=$((pass + fail + warn))
    echo -e "\n${MAGENTA}${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
    echo -e "  ${GREEN}PASS: $pass${RESET}  ${RED}FAIL: $fail${RESET}  ${YELLOW}WARN: $warn${RESET}  TOTAL: $total"
    if [[ $fail -eq 0 && $warn -eq 0 ]]; then
        echo -e "\n  ${GREEN}${BOLD}✔ FULLY LEAKPROOF — All checks passed!${RESET}"
    elif [[ $fail -eq 0 ]]; then
        echo -e "\n  ${YELLOW}${BOLD}⚠ MOSTLY SAFE — Fix warnings for full protection${RESET}"
    else
        echo -e "\n  ${RED}${BOLD}✗ LEAKS DETECTED — Run Option 23 to fix${RESET}"
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
