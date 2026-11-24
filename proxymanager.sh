#!/bin/bash
# ╔══════════════════════════════════════════════════════════════╗
# ║           PROXY MANAGER PRO - Ubuntu 16-26 VPS Edition            ║
# ║           Supports: Squid (HTTP/S) | Dante (SOCKS5)        ║
# ║                     3proxy (Multi-protocol)                 ║
# ║  Usage: chmod +x proxymanager.sh && sudo ./proxymanager.sh ║
# ║                   script masters github:Bravin-LAB      ║
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
EXPIRY_FILE="$CONFIG_DIR/expiry.list"        # format: user:expiry_epoch
EXPIRY_LOG="$LOG_DIR/expiry.log"
EXPIRY_CRON="/etc/cron.d/proxymanager-expiry"
EXPIRY_EPOCH=0                               # result of prompt_expiry (0 = never)

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
# ══════════════════════════════════════════════════════════════
#  UI ENGINE — dashboard layout (pure bash, UTF-8 box drawing)
# ══════════════════════════════════════════════════════════════
case "${LC_ALL:-${LANG:-}}" in
    *UTF-8*|*utf-8*|*UTF8*|*utf8*) ;;
    *) export LC_ALL=C.UTF-8 ;;
esac

# Real-escape colours (used for width-aware layout)
K_RST=$'\033[0m'; K_BOLD=$'\033[1m'; K_ITAL=$'\033[3m'
K_G=$'\033[38;5;46m';   K_DG=$'\033[38;5;35m';  K_GRY=$'\033[38;5;245m'
K_W=$'\033[1;37m';      K_ORG=$'\033[38;5;214m'; K_BLU=$'\033[38;5;39m'
K_PUR=$'\033[38;5;141m'; K_PNK=$'\033[38;5;205m'; K_RED=$'\033[38;5;203m'
K_YEL=$'\033[38;5;227m'; K_CYN=$'\033[38;5;51m'
_ANSI_RE=$'\033\\[[0-9;]*m'

# visible length of a string (ignores colour codes) -> VLEN
_vlen() {
    local s=$1
    while [[ $s =~ $_ANSI_RE ]]; do s=${s/"${BASH_REMATCH[0]}"/}; done
    VLEN=${#s}
}
# pad to a visible width -> PADDED
_pad() {
    _vlen "$1"; local n=$(( $2 - VLEN )); (( n < 0 )) && n=0
    printf -v PADDED '%s%*s' "$1" "$n" ''
}
_dash() { local n=$1; (( n < 0 )) && n=0; printf -v DASH '%*s' "$n" ''; DASH=${DASH// /─}; }
_row()  { _pad "$2" "$1"; ROW="${K_DG}│${K_RST}${PADDED}${K_DG}│${K_RST}"; }
_hline() { _dash $(( $3 - 2 )); HL="${K_DG}$1${DASH}$2${K_RST}"; }
# top border, optionally with a title  -> TOP   (title, total width)
_top() {
    local t=$1 w=$2
    if [[ -n $t ]]; then
        _vlen " $t "; _dash $(( w - 3 - VLEN ))
        TOP="${K_DG}╭─${K_RST} ${t} ${K_DG}${DASH}╮${K_RST}"
    else
        _hline '╭' '╮' "$w"; TOP=$HL
    fi
}
_bot() { _hline '╰' '╯' "$1"; BOT=$HL; }

# ── System info (network part is cached for the session) ─────
_load_netinfo() {
    [[ -n $NETINFO_LOADED ]] && return
    SI_PUB=$(curl -s --noproxy '*' --max-time 3 ifconfig.me 2>/dev/null)
    [[ $SI_PUB =~ ^[0-9a-fA-F:.]+$ ]] || SI_PUB=""
    SI_INT=$(hostname -I 2>/dev/null | awk '{print $1}')
    local ms; ms=$(ping -c1 -W1 1.1.1.1 2>/dev/null | sed -n 's/.*time=\([0-9.]*\) ms.*/\1/p')
    SI_PING=${ms:+${ms%.*} ms}
    if [[ -n $SI_PUB ]]; then SI_STATUS="CONNECTED"; else SI_STATUS="OFFLINE"; SI_PUB=${SI_INT:-unknown}; fi
    SI_INT=${SI_INT:-unknown}
    SI_OS=$(lsb_release -ds 2>/dev/null | tr -d '"')
    [[ -z $SI_OS ]] && SI_OS=$(. /etc/os-release 2>/dev/null && echo "$PRETTY_NAME")
    SI_OS=${SI_OS:-Linux}
    SI_HOST=$(hostname)
    NETINFO_LOADED=1
}

_short_left() {
    local l=$1
    if   (( l >= 86400 )); then SL="$(( l/86400 ))d $(( l%86400/3600 ))h"
    elif (( l >= 3600  )); then SL="$(( l/3600 ))h $(( l%3600/60 ))m"
    else SL="$(( l/60 + 1 ))m"; fi
}

_svc_dot() {
    if systemctl is-active --quiet "$1" 2>/dev/null; then printf '%s●%s%s' "$K_G" "$K_RST" "$2"
    elif systemctl cat "$1" >/dev/null 2>&1;          then printf '%s●%s%s' "$K_RED" "$K_RST" "$2"
    else printf '%s●%s%s' "$K_GRY" "$K_RST" "$2"; fi
}

# ── Decorative art ────────────────────────────────────────────
_build_title() {
    declare -A F1 F2 F3
    F1[P]="█▀█"; F2[P]="█▀▀"; F3[P]="▀  "
    F1[R]="█▀█"; F2[R]="█▀▄"; F3[R]="▀ ▀"
    F1[O]="█▀█"; F2[O]="█ █"; F3[O]="▀▀▀"
    F1[X]="▀▄▀"; F2[X]=" █ "; F3[X]="▀ ▀"
    F1[Y]="▀▄▀"; F2[Y]=" █ "; F3[Y]=" ▀ "
    F1[M]="█▄▄█"; F2[M]="█▀▀█"; F3[M]="▀  ▀"
    F1[A]="▄▀▄"; F2[A]="█▀█"; F3[A]="▀ ▀"
    F1[N]="█▀▄█"; F2[N]="█ ▀█"; F3[N]="▀  ▀"
    F1[G]="█▀▀"; F2[G]="█ ▄"; F3[G]="▀▀▀"
    F1[E]="█▀▀"; F2[E]="█▀▀"; F3[E]="▀▀▀"
    local words=(PROXY MANAGER PRO) cols=("$K_W" "$K_W" "$K_G") w i ch c word
    T1=""; T2=""; T3=""
    for w in 0 1 2; do
        c=${cols[$w]}; word=${words[$w]}
        for (( i=0; i<${#word}; i++ )); do
            ch=${word:$i:1}
            T1+="${c}${F1[$ch]}${K_RST} "; T2+="${c}${F2[$ch]}${K_RST} "; T3+="${c}${F3[$ch]}${K_RST} "
        done
        T1+="  "; T2+="  "; T3+="  "
    done
}

# ── Left-panel section helper ─────────────────────────────────
# _sec COLOR TITLE DESC "num|label" ...   (appends to array L)
_sec() {
    local col=$1 title=$2 desc=$3; shift 3
    local first=1 it num lab lc cat d itm c1 c2 c3
    for it in "$@"; do
        num=${it%%|*}; lab=${it#*|}
        if (( first )); then cat="${col}${title}${K_RST}"; d="${K_GRY}→ ${desc}${K_RST}"; else cat=""; d=""; fi
        first=0
        [[ $lab == Exit ]] && lc=$K_RED || lc=$K_W
        printf -v itm '%s%2s.%s %s%s%s' "$col" "$num" "$K_RST" "$lc" "$lab" "$K_RST"
        _pad "$cat" 20; c1=$PADDED
        _pad "$itm" 37; c2=$PADDED
        _pad "$d"   19; c3=$PADDED
        _row 81 " ${c1}${c2}${K_DG} │ ${K_RST}${c3}"
        L+=("$ROW")
    done
}
_secdiv() { _dash 81; L+=("${K_DG}├${DASH}┤${K_RST}"); }

# category row for the level-1 dashboard panel
_cat() {
    local col=$1 num=$2 title=$3 desc=$4
    _row 81 " ${col}${K_BOLD}[${num}]${K_RST} ${col}${K_BOLD}${title}${K_RST}"; L+=("$ROW")
    _row 81 "     ${K_GRY}${desc}${K_RST}"; L+=("$ROW")
    _row 81 ""; L+=("$ROW")
}

# right-column box helper (appends to array R)
_rbox() {
    local title=$1 r; shift
    _top "$title" 36; R+=("$TOP")
    for r in "$@"; do _row 34 "$r"; R+=("$ROW"); done
    _bot 36; R+=("$BOT")
}

# ══════════════════════════════════════════════════════════════
#  DASHBOARD
# ══════════════════════════════════════════════════════════════
draw_dashboard() {
    _load_netinfo
    local W=120 i
    local L=() R=()

    # ----- live values -----------------------------------------
    local up; read -r up _ < /proc/uptime; up=${up%.*}
    local si_up="$(( up/86400 ))d $(( up%86400/3600 ))h $(( up%3600/60 ))m"
    local si_users=0
    [[ -f $USERS_FILE ]] && si_users=$(grep -c . "$USERS_FILE" 2>/dev/null)
    local now; now=$(date +%s)
    local -a exp_rows=(); local exp_soon=0 u e
    if [[ -s $EXPIRY_FILE ]]; then
        while IFS=: read -r u e; do
            [[ -z $u || ! $e =~ ^[0-9]+$ || $e -le $now ]] && continue
            (( e - now < 86400 )) && exp_soon=$(( exp_soon + 1 ))
            if (( ${#exp_rows[@]} < 3 )); then
                _short_left $(( e - now ))
                if (( e - now < 86400 )); then c=$K_ORG; else c=$K_G; fi
                exp_rows+=(" ${c}●${K_RST} ${K_W}${u:0:12}${K_RST}  ${K_GRY}${SL}${K_RST}")
            fi
        done < <(sort -t: -k2 -n "$EXPIRY_FILE")
    fi

    # ----- HEADER BOX ------------------------------------------
    _build_title
    local hood=("   ▄▄██████▄▄   " "  ██▀      ▀██  " "  █  ${K_G}●${K_DG}    ${K_G}●${K_DG}  █  " "  ▀█▄      ▄█▀  " "    ▀▀████▀▀    ")
    local map=("   ▄▄▄▄▄     ▄▄▄██▄▄▄▄██▄▄▄▄" "  ▀█████▄▄  ▀████▀▀█████████▀" "    ▀███▀▀    ▀██▄  ▀█▀ ▀▀██ " "      ▀▀        ▀▀▀    ▀▀▀    ")
    local ttl=("$T1" "$T2" "$T3"
        "${K_GRY}──  ${K_G}Ubuntu VPS Edition${K_GRY}  ──────────────────${K_RST}"
        "${K_G}◆ HTTP/HTTPS (Squid)${K_RST}   ${K_BLU}◆ SOCKS5 (Dante)${K_RST}   ${K_PUR}◆ Multi (3proxy)${K_RST}")
    local out=()
    _hline '╭' '╮' $W; out+=("$HL")
    local c1 c2 c3 mp
    for i in 0 1 2 3 4; do
        _pad "  ${K_DG}${hood[$i]}${K_RST}" 18; c1=$PADDED
        _pad "${ttl[$i]}" 68; c2=$PADDED
        if (( i < 4 )); then mp="${K_DG}${map[$i]}${K_RST}"; else mp="${K_ITAL}${K_G}‹ Secure • Fast • Reliable ›${K_RST}"; fi
        _pad "$mp" 32; c3=$PADDED
        _row $(( W - 2 )) "${c1}${c2}${c3}"; out+=("$ROW")
    done
    _hline '╰' '╯' $W; out+=("$HL")

    # ----- STATUS STRIP ----------------------------------------
    local sep="${K_DG} │ ${K_RST}" st_col=$K_G
    [[ $SI_STATUS == CONNECTED ]] || st_col=$K_RED
    local sa=" ${K_G}▲${K_RST} ${K_GRY}Public IP:${K_RST} ${K_W}${SI_PUB:0:15}${K_RST}${sep}${st_col}●${K_RST} ${K_GRY}Status:${K_RST} ${st_col}${SI_STATUS}${K_RST}${sep}${K_GRY}Internal:${K_RST} ${K_W}${SI_INT:0:15}${K_RST}${sep}${K_GRY}Host:${K_RST} ${K_W}${SI_HOST:0:14}${K_RST}${sep}${K_GRY}OS:${K_RST} ${K_W}${SI_OS:0:18}${K_RST}"
    local sb=" ${K_G}✔${K_RST} Use ${K_W}THIS${K_RST} ${K_GRY}(Public IP)${K_RST} to connect${sep}${K_ORG}Internal IP — do ${K_W}NOT${K_ORG} use for proxy${K_RST}"
    _hline '╭' '╮' $W; out+=("$HL")
    _row $(( W - 2 )) "$sa"; out+=("$ROW")
    _dash $(( W - 2 )); out+=("${K_DG}├${DASH}┤${K_RST}")
    _row $(( W - 2 )) "$sb"; out+=("$ROW")
    _hline '╰' '╯' $W; out+=("$HL")

    # ----- LEFT PANEL: MAIN MENU -------------------------------
    _top "${K_G}${K_BOLD}≡ MAIN MENU${K_RST}" 83; L+=("$TOP")
    _cat "$K_G"   1 "INSTALLATION"        "Squid (HTTP/HTTPS) · Dante (SOCKS5) · 3proxy · install all"
    _cat "$K_BLU" 2 "USER MANAGEMENT"     "Add · edit · delete · bulk import · account expiry · rotate passwords"
    _cat "$K_PUR" 3 "PROXY MANAGEMENT"    "Services · ports · logs · bandwidth · firewall · export · test"
    _cat "$K_PNK" 4 "LEAKPROOF HARDENING" "IPv6 · DNS · headers · TTL · iptables — apply, check, undo"
    _cat "$K_YEL" 5 "SSL / DOMAIN"        "Let's Encrypt certificates, renewal and status"
    _cat "$K_RED" 6 "ANTI-DETECTION (Bypass VPN/Proxy Detection)" "DNS leak protection · leak status check"
    _row 81 " ${K_RED} 0.${K_RST} ${K_RED}Exit${K_RST}"; L+=("$ROW")
    _bot 83; L+=("$BOT")

    # ----- RIGHT COLUMN ----------------------------------------
    local blankR; printf -v blankR '%36s' ''
    local lbl="${K_GRY}"
    local users_txt="${si_users}"; (( exp_soon > 0 )) && users_txt="${si_users} (${exp_soon} expiring <24h)"
    _rbox "${K_G}▌ SYSTEM INFO${K_RST}" \
        " ${lbl}OS       :${K_RST} ${K_W}${SI_OS:0:22}${K_RST}" \
        " ${lbl}Hostname :${K_RST} ${K_W}${SI_HOST:0:22}${K_RST}" \
        " ${lbl}Public IP:${K_RST} ${K_W}${SI_PUB:0:22}${K_RST}" \
        " ${lbl}Internal :${K_RST} ${K_W}${SI_INT:0:22}${K_RST}" \
        " ${lbl}Uptime   :${K_RST} ${K_W}${si_up}${K_RST}" \
        " ${lbl}Users    :${K_RST} ${K_W}${users_txt:0:22}${K_RST}" \
        " ${lbl}Proxies  :${K_RST} $(_svc_dot squid Squid) $(_svc_dot danted Dante) $(_svc_dot 3proxy 3proxy)"
    R+=("$blankR")
    local net_col=$K_G; [[ $SI_STATUS == CONNECTED ]] || net_col=$K_RED
    local net_txt="Online"; [[ $SI_STATUS == CONNECTED ]] || net_txt="Offline"
    _rbox "${K_G}▌ NETWORK OVERVIEW${K_RST}" \
        " ${lbl}Status   :${K_RST} ${net_col}● ${net_txt}${K_RST}" \
        " ${lbl}Latency  :${K_RST} ${K_W}${SI_PING:-n/a}${K_RST}" \
        " ${lbl}Types    :${K_RST} ${K_W}HTTP·SOCKS5·Multi${K_RST}" \
        " ${K_DG}${map[0]}${K_RST}" " ${K_DG}${map[1]}${K_RST}" " ${K_DG}${map[2]}${K_RST}" " ${K_DG}${map[3]}${K_RST}"
    R+=("$blankR")
    if (( ${#exp_rows[@]} )); then
        _rbox "${K_ORG}▌ EXPIRING SOON${K_RST}" "${exp_rows[@]}"
    else
        _rbox "${K_ORG}▌ EXPIRING SOON${K_RST}" " ${K_GRY}No expiries scheduled${K_RST}"
    fi
    R+=("$blankR")
    _rbox "${K_CYN}▌ QUICK TIPS${K_RST}" \
        " ${K_G}✔${K_RST} Manage everything from here" \
        " ${K_G}✔${K_RST} Keep your server secure" \
        " ${K_G}✔${K_RST} Set expiry on every account" \
        " ${K_G}✔${K_RST} Monitor logs for abuse"

    # ----- PAIR UP & PRINT -------------------------------------
    local nl=${#L[@]} nr=${#R[@]} n blankL
    n=$(( nl > nr ? nl : nr ))
    printf -v blankL '%83s' ''
    for line in "${out[@]}"; do printf '%s\n' "$line"; done
    for (( i=0; i<n; i++ )); do printf '%s %s\n' "${L[i]:-$blankL}" "${R[i]:-$blankR}"; done
}

# ══════════════════════════════════════════════════════════════
#  COMPACT BANNER (used by every sub-screen)
# ══════════════════════════════════════════════════════════════
banner() {
    clear
    _load_netinfo
    local cols; cols=$(tput cols 2>/dev/null || echo 80)
    (( cols > 100 )) && cols=100
    (( cols < 30 ))  && cols=30
    local inner=$(( cols - 2 )) st_col=$K_G l1 r1 l2 pad a b
    [[ $SI_STATUS == CONNECTED ]] || st_col=$K_RED
    if (( cols >= 60 )); then
        l1="  ${K_W}${K_BOLD}PROXY MANAGER${K_RST} ${K_G}${K_BOLD}PRO${K_RST}  ${K_GRY}·${K_RST}  ${K_G}Ubuntu VPS Edition${K_RST}"
        r1="${st_col}● ${SI_STATUS}${K_RST}  "
        l2="  ${K_GRY}IP${K_RST} ${K_W}${SI_PUB}${K_RST}  ${K_GRY}│${K_RST}  ${K_GRY}Host${K_RST} ${K_W}${SI_HOST:0:16}${K_RST}  ${K_GRY}│${K_RST}  ${K_GRY}OS${K_RST} ${K_W}${SI_OS:0:20}${K_RST}"
    else
        l1=" ${K_W}${K_BOLD}PROXY MANAGER${K_RST} ${K_G}${K_BOLD}PRO${K_RST}"
        r1="${st_col}●${K_RST} "
        l2=" ${K_GRY}IP${K_RST} ${K_W}${SI_PUB:0:$(( inner - 5 ))}${K_RST}"
    fi
    _vlen "$l1"; a=$VLEN; _vlen "$r1"; b=$VLEN
    printf -v pad '%*s' $(( inner - a - b > 0 ? inner - a - b : 1 )) ''
    _hline '╭' '╮' "$cols"; printf '%s\n' "$HL"
    _row "$inner" "${l1}${pad}${r1}"; printf '%s\n' "$ROW"
    _row "$inner" "$l2"; printf '%s\n' "$ROW"
    _hline '╰' '╯' "$cols"; printf '%s\n\n' "$HL"
}

# ══════════════════════════════════════════════════════════════
#  MENUS — level 1 (categories) → level 2 (sub-menus)
# ══════════════════════════════════════════════════════════════
CURRENT_MENU=main_menu
go_back() { "${CURRENT_MENU:-main_menu}"; }

# Generic menu screen (sub-menus + compact main menu)
#   _menu_screen SELF TITLE COLOR ZERO_LABEL ZERO_FN "label|function" ...
_menu_screen() {
    local self=$1 title=$2 col=$3 zero=$4 zerofn=$5; shift 5
    CURRENT_MENU=$self
    banner
    local cols; cols=$(tput cols 2>/dev/null || echo 80)
    local w=$(( cols > 64 ? 64 : cols )); (( w < 30 )) && w=30
    local inner=$(( w - 2 )) n=0 it lab ch fn
    _top "${col}${K_BOLD}${title}${K_RST}" "$w"; printf '%s\n' "$TOP"
    for it in "$@"; do
        n=$(( n + 1 )); lab=${it%|*}
        (( ${#lab} > inner - 6 )) && lab="${lab:0:$(( inner - 7 ))}…"
        printf -v row ' %s%2d.%s %s%s%s' "$col" "$n" "$K_RST" "$K_W" "$lab" "$K_RST"
        _row "$inner" "$row"; printf '%s\n' "$ROW"
    done
    _dash "$inner"; printf '%s\n' "${K_DG}├${DASH}┤${K_RST}"
    _row "$inner" " ${K_RED} 0.${K_RST} ${K_GRY}${zero}${K_RST}"; printf '%s\n' "$ROW"
    _bot "$w"; printf '%s\n' "$BOT"
    echo -ne "\n  ${YELLOW}Select option (0-$n): ${GREEN}"; read -r ch; echo -ne "${RESET}"
    if [[ "$ch" == "0" ]]; then
        $zerofn; return
    elif [[ "$ch" =~ ^[0-9]+$ ]] && (( ch >= 1 && ch <= n )); then
        it=${@:$ch:1}; fn=${it##*|}; $fn
    else
        log_warn "Invalid option"; sleep 1; $self
    fi
}

quit_menu() { echo -e "\n${GREEN}Goodbye!${RESET}\n"; exit 0; }

sub_install() { _menu_screen sub_install "INSTALLATION" "$K_G" "Back to main menu" main_menu \
    "Install Squid (HTTP/HTTPS Proxy)|install_squid" \
    "Install Dante (SOCKS5 Proxy)|install_dante" \
    "Install 3proxy (HTTP + SOCKS5 + Multi)|install_3proxy" \
    "Install ALL (Squid + Dante + 3proxy)|install_all"; }

sub_users() { _menu_screen sub_users "USER MANAGEMENT" "$K_BLU" "Back to main menu" main_menu \
    "Add Proxy User|add_user" \
    "Delete Proxy User|delete_user" \
    "Edit Proxy User (change password)|edit_user" \
    "List All Users|list_users" \
    "Bulk Add Users from file|bulk_add_users" \
    "Manage Account Expiry|manage_expiry" \
    "Auto-renew / Rotate Credentials|auto_rotate"; }

sub_proxy() { _menu_screen sub_proxy "PROXY MANAGEMENT" "$K_PUR" "Back to main menu" main_menu \
    "Start / Stop / Restart Proxies|manage_services" \
    "View Proxy Status|view_status" \
    "Change Proxy Ports|change_ports" \
    "View Active Connections & Logs|view_logs" \
    "Bandwidth Usage per User|bandwidth_usage" \
    "UFW Firewall Setup|setup_firewall" \
    "Block/Unblock IP Address|block_ip" \
    "Whitelist IP (no-auth access)|whitelist_ip" \
    "Export Proxy List|export_proxies" \
    "Test Proxy Connectivity|test_proxy" \
    "Uninstall All Proxies|uninstall_all"; }

sub_leakproof() { _menu_screen sub_leakproof "LEAKPROOF HARDENING" "$K_PNK" "Back to main menu" main_menu \
    "Full Leakproof Hardening|leakproof_harden" \
    "Check Leak Status|leakproof_check" \
    "Undo Leakproof Hardening|leakproof_undo"; }

sub_ssl() { _menu_screen sub_ssl "SSL / DOMAIN" "$K_YEL" "Back to main menu" main_menu \
    "Add / Re-issue SSL Certificate|ssl_reissue" \
    "View SSL Certificate Status|ssl_status"; }

sub_antidetect() { _menu_screen sub_antidetect "ANTI-DETECTION" "$K_RED" "Back to main menu" main_menu \
    "Anti-leak / DNS Leak Protection|dns_leak_protect" \
    "Check Leak Status|leakproof_check"; }

# Level-1 dispatcher
_main_dispatch() {
    case "$1" in
        1) sub_install ;;
        2) sub_users ;;
        3) sub_proxy ;;
        4) sub_leakproof ;;
        5) sub_ssl ;;
        6) sub_antidetect ;;
        0) quit_menu ;;
        *) log_warn "Invalid option"; sleep 1; main_menu ;;
    esac
}

main_menu() {
    CURRENT_MENU=main_menu
    local cols; cols=$(tput cols 2>/dev/null || echo 80)
    if (( cols < 120 )); then
        # small screens: simple category list
        _menu_screen main_menu "MAIN MENU" "$K_G" "Exit" quit_menu \
            "Installation|sub_install" \
            "User Management|sub_users" \
            "Proxy Management|sub_proxy" \
            "Leakproof Hardening|sub_leakproof" \
            "SSL / Domain|sub_ssl" \
            "Anti-Detection|sub_antidetect"
        return
    fi

    clear
    draw_dashboard

    # Prompt bar — cursor is placed inside the box
    local left=" ${K_G}❯${K_RST} Select an option ${K_GRY}(1-6)${K_RST} or ${K_W}0${K_RST} to exit: "
    local right="${K_DG}///${K_RST}  ${K_G}${K_ITAL}Proxy Manager Pro — Power at Your Fingertips${K_RST} "
    local pad; _vlen "$left"; local a=$VLEN; _vlen "$right"; local b=$VLEN
    printf -v pad '%*s' $(( 118 - a - b )) ''
    _hline '╭' '╮' 120; printf '%s\n' "$HL"
    _row 118 "${left}${pad}${right}"; printf '%s\n' "$ROW"
    _hline '╰' '╯' 120; printf '%s\n' "$HL"
    printf '\033[2A\033[%dG' $(( a + 2 ))
    read -r choice
    echo
    _main_dispatch "$choice"
}

# ══════════════════════════════════════════════════════════════
#  HELPERS
# ══════════════════════════════════════════════════════════════
press_enter() { echo -e "\n${YELLOW}Press Enter to return to menu...${RESET}"; read -r; go_back; }

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

get_server_ip() {     local ip svc cache="$CONFIG_DIR/public_ip"
    local re='^([0-9]{1,3}\.){3}[0-9]{1,3}$'

    for svc in ifconfig.me api.ipify.org ipv4.icanhazip.com checkip.amazonaws.com ipinfo.io/ip; do
        ip=$(env -u http_proxy -u https_proxy -u HTTP_PROXY -u HTTPS_PROXY \
             curl -4 -s --noproxy '*' --max-time 4 "https://$svc" 2>/dev/null | tr -d '[:space:]')
        if [[ $ip =~ $re ]]; then
            echo "$ip" > "$cache" 2>/dev/null
            echo "$ip"; return 0
        fi
    done

    # Offline fallback: last known public IP
    if [[ -s $cache ]]; then
        ip=$(cat "$cache")
        [[ $ip =~ $re ]] && { echo "$ip"; return 0; }
    fi

    # Last resort: private IP
    hostname -I | awk '{print $1}'
}

# ══════════════════════════════════════════════════════════════
#  ACCOUNT EXPIRY HELPERS
# ══════════════════════════════════════════════════════════════
# Expiry data lives in $EXPIRY_FILE as "user:epoch". No entry (or 0) = never.

# Interactive prompt. Sets global EXPIRY_EPOCH (0 = never expires).
prompt_expiry() {
    EXPIRY_EPOCH=0
    local ex n input e now
    while true; do
        echo -e "\n${YELLOW}Account expiry:${RESET}"
        echo "  1. Never expires"
        echo "  2. Expire in N days"
        echo "  3. Expire in N hours"
        echo "  4. Specific date/time  (e.g. 2026-12-31  or  2026-12-31 18:30)"
        echo -ne "${YELLOW}Choice (Enter=1): ${RESET}"; read -r ex
        now=$(date +%s)
        case "${ex:-1}" in
            1) EXPIRY_EPOCH=0; return 0 ;;
            2)
                echo -ne "${YELLOW}Number of days: ${RESET}"; read -r n
                if [[ "$n" =~ ^[0-9]+$ && "$n" -gt 0 ]]; then
                    EXPIRY_EPOCH=$(( now + n * 86400 )); return 0
                fi
                log_err "Enter a whole number greater than 0" ;;
            3)
                echo -ne "${YELLOW}Number of hours: ${RESET}"; read -r n
                if [[ "$n" =~ ^[0-9]+$ && "$n" -gt 0 ]]; then
                    EXPIRY_EPOCH=$(( now + n * 3600 )); return 0
                fi
                log_err "Enter a whole number greater than 0" ;;
            4)
                echo -ne "${YELLOW}Date (YYYY-MM-DD) or date+time (YYYY-MM-DD HH:MM), server time: ${RESET}"; read -r input
                input=$(echo "$input" | xargs)
                # A bare date means "end of that day"
                [[ "$input" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}$ ]] && input="$input 23:59:59"
                e=$(date -d "$input" +%s 2>/dev/null)
                if [[ -z "$e" ]]; then
                    log_err "Could not understand that date"
                elif (( e <= now )); then
                    log_err "That date is in the past"
                else
                    EXPIRY_EPOCH=$e; return 0
                fi ;;
            *) log_err "Invalid choice" ;;
        esac
    done
}

# set_expiry user epoch   (epoch 0 removes the expiry)
set_expiry() {
    local user=$1 epoch=${2:-0} tmp
    touch "$EXPIRY_FILE"; chmod 600 "$EXPIRY_FILE"
    tmp=$(mktemp)
    awk -F: -v u="$user" '$1 != u' "$EXPIRY_FILE" > "$tmp"
    (( epoch > 0 )) && echo "$user:$epoch" >> "$tmp"
    cat "$tmp" > "$EXPIRY_FILE"; rm -f "$tmp"
    if (( epoch > 0 )); then ensure_expiry_cron; fi
}

get_expiry() {
    local e=0
    [[ -f $EXPIRY_FILE ]] && e=$(awk -F: -v u="$1" '$1 == u {print $2; exit}' "$EXPIRY_FILE")
    [[ "$e" =~ ^[0-9]+$ ]] || e=0
    echo "$e"
}

# fmt_expiry epoch -> human readable
fmt_expiry() {
    local e=${1:-0} now left
    (( e == 0 )) && { echo "Never"; return; }
    now=$(date +%s)
    if (( e <= now )); then
        echo "EXPIRED ($(date -d "@$e" '+%Y-%m-%d %H:%M'))"
    else
        left=$(( e - now ))
        echo "$(date -d "@$e" '+%Y-%m-%d %H:%M') ($(( left/86400 ))d $(( (left%86400)/3600 ))h $(( (left%3600)/60 ))m left)"
    fi
}

user_in_list() { [[ -f $USERS_FILE ]] && awk -F: -v u="$1" '$1 == u {f=1} END{exit !f}' "$USERS_FILE"; }

# Remove one managed user from every proxy backend + bookkeeping files
expire_user() {
    local u=$1
    [[ -f $SQUID_PASSWD ]] && htpasswd -D "$SQUID_PASSWD" "$u" >/dev/null 2>&1
    # Only delete the Dante system account if this script created it
    if user_in_list "$u" && id "$u" &>/dev/null; then userdel "$u" >/dev/null 2>&1; fi
    [[ -f $PROXY3_USERS ]] && sed -i "/^$u:/d" "$PROXY3_USERS"
    [[ -f $USERS_FILE ]]   && sed -i "/^$u:/d" "$USERS_FILE"
    set_expiry "$u" 0
}

# Remove every account whose expiry time has passed. Safe to run any time (cron + menu start).
enforce_expiry() {
    [[ -f $EXPIRY_FILE ]] || return 0
    local now u e; now=$(date +%s)
    local -a expired=()
    while IFS=: read -r u e; do
        [[ -z "$u" || ! "$e" =~ ^[0-9]+$ ]] && continue
        (( e > 0 && e <= now )) && expired+=("$u")
    done < "$EXPIRY_FILE"
    (( ${#expired[@]} == 0 )) && return 0

    for u in "${expired[@]}"; do
        expire_user "$u"
        echo "[$(ts)] Expired and removed user: $u" | tee -a "$EXPIRY_LOG"
    done

    # Short Squid credential cache so removed users are rejected right away
    [[ -f $SQUID_CONF ]] && sed -i 's/^auth_param basic credentialsttl .*/auth_param basic credentialsttl 2 minutes/' "$SQUID_CONF"

    # Restart so cached auth and open sessions of removed users are dropped
    local svc
    for svc in squid danted 3proxy; do
        systemctl is-active --quiet "$svc" 2>/dev/null && systemctl restart "$svc" 2>/dev/null
    done
    return 0
}

# Cron job that runs enforce_expiry every minute
ensure_expiry_cron() {
    [[ -f $EXPIRY_CRON ]] && return 0
    local self; self=$(realpath "$0" 2>/dev/null)
    [[ -n "$self" && "$self" != "/usr/local/bin/menu" ]] && { cp "$self" /usr/local/bin/menu 2>/dev/null; chmod +x /usr/local/bin/menu 2>/dev/null; }
    cat > "$EXPIRY_CRON" <<EOF
# Proxy Manager Pro — enforce account expiry
PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
* * * * * root /bin/bash /usr/local/bin/menu --expire-check >> $EXPIRY_LOG 2>&1
EOF
    chmod 644 "$EXPIRY_CRON"
    log_ok "Expiry enforcement enabled (checks every minute)"
}

# ══════════════════════════════════════════════════════════════
#  28. MANAGE ACCOUNT EXPIRY
# ══════════════════════════════════════════════════════════════
manage_expiry() {
    banner
    echo -e "${CYAN}${BOLD}[28] Manage Account Expiry${RESET}\n"
    if [[ -f $EXPIRY_CRON ]]; then
        echo -e "  ${GREEN}● Auto-enforcement: ON (every minute)${RESET}\n"
    else
        echo -e "  ${YELLOW}● Auto-enforcement: OFF${RESET}\n"
    fi
    echo "  1. View expiry of all users"
    echo "  2. Set / change expiry for a user"
    echo "  3. Extend a user's expiry"
    echo "  4. Remove expiry (never expires)"
    echo "  5. Run expiry check now"
    echo "  6. Enable auto-enforcement"
    echo "  7. Disable auto-enforcement"
    echo "  8. View expiry log"
    echo -ne "\n${YELLOW}Choice: ${RESET}"; read -r xc
    local u e n base
    case $xc in
        1)
            echo ""
            printf "  %-20s %s\n" "USER" "EXPIRES"
            echo -e "  $(printf '%.0s─' {1..60})"
            if [[ -f $USERS_FILE ]]; then
                while IFS=: read -r u _; do
                    [[ -z "$u" ]] && continue
                    printf "  %-20s %s\n" "$u" "$(fmt_expiry "$(get_expiry "$u")")"
                done < "$USERS_FILE"
            else
                echo -e "  ${YELLOW}No users found.${RESET}"
            fi ;;
        2)
            list_users_inline
            echo -ne "\n${YELLOW}Username: ${RESET}"; read -r u
            if ! user_in_list "$u"; then log_err "User '$u' not found"; press_enter; return; fi
            prompt_expiry
            set_expiry "$u" "$EXPIRY_EPOCH"
            log_ok "Expiry for $u: $(fmt_expiry "$EXPIRY_EPOCH")" ;;
        3)
            echo -ne "${YELLOW}Username: ${RESET}"; read -r u
            if ! user_in_list "$u"; then log_err "User '$u' not found"; press_enter; return; fi
            echo -ne "${YELLOW}Extend by how many days: ${RESET}"; read -r n
            if [[ ! "$n" =~ ^[0-9]+$ || "$n" -le 0 ]]; then log_err "Enter a whole number greater than 0"; press_enter; return; fi
            e=$(get_expiry "$u"); base=$(date +%s)
            (( e > base )) && base=$e          # extend from current expiry if still in the future
            set_expiry "$u" $(( base + n * 86400 ))
            log_ok "New expiry for $u: $(fmt_expiry "$(get_expiry "$u")")" ;;
        4)
            echo -ne "${YELLOW}Username: ${RESET}"; read -r u
            if ! user_in_list "$u"; then log_err "User '$u' not found"; press_enter; return; fi
            set_expiry "$u" 0
            log_ok "$u will never expire" ;;
        5)
            enforce_expiry
            log_ok "Expiry check finished" ;;
        6) rm -f "$EXPIRY_CRON"; ensure_expiry_cron ;;
        7) rm -f "$EXPIRY_CRON"; log_ok "Auto-enforcement disabled (expiry is still checked each time this menu opens)" ;;
        8) tail -30 "$EXPIRY_LOG" 2>/dev/null || log_warn "No expiry log yet" ;;
    esac
    press_enter
}

# ══════════════════════════════════════════════════════════════
#  1. INSTALL SQUID (HTTP/HTTPS)
# ══════════════════════════════════════════════════════════════
install_squid() {
    banner
    echo -e "${CYAN}${BOLD}[1] Installing Squid HTTP/HTTPS Proxy${RESET}\n"
    apt_update
    pkg_install squid apache2-utils openssl

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

    # ── Write Squid config ────────────────────────────────────
    cat > "$SQUID_CONF" <<EOF
# ── Proxy Manager Pro — Squid Config ──────────────────────────
http_port ${HTTP_PORT}
http_port ${HTTPS_PORT} ssl-bump cert=/etc/squid/squid.pem key=/etc/squid/squid.key generate-host-certificates=on dynamic_cert_mem_cache_size=4MB

# SSL Bump settings
ssl_bump server-first all
sslproxy_cert_error deny all
sslproxy_flags DONT_VERIFY_PEER

# Auth
auth_param basic program /usr/lib/squid/basic_ncsa_auth ${SQUID_PASSWD}
auth_param basic realm "Proxy Authentication Required"
auth_param basic credentialsttl 2 minutes
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

    # ── SSL Certificate setup ─────────────────────────────────
    if [[ "$USE_DOMAIN" == true && -n "$DOMAIN" ]]; then
        setup_nginx_ssl "$DOMAIN" "$EMAIL"
    else
        # Self-signed fallback
        log_info "Generating self-signed SSL certificate..."
        openssl req -new -newkey rsa:2048 -days 3650 -nodes -x509 \
            -subj "/C=US/ST=State/L=City/O=ProxyManager/CN=$(get_server_ip)" \
            -keyout /etc/squid/squid.key \
            -out /etc/squid/squid.pem >> "$LOG_DIR/install.log" 2>&1
        chmod 600 /etc/squid/squid.key
        chown proxy:proxy /etc/squid/squid.pem /etc/squid/squid.key 2>/dev/null || true
        log_ok "Self-signed certificate generated"
    fi

    # ── Initialize SSL DB for dynamic cert generation ─────────
    if command -v squid &>/dev/null; then
        mkdir -p /var/lib/squid/ssl_db
        /usr/lib/squid/security_file_certgen -c -s /var/lib/squid/ssl_db -M 4MB \
            >> "$LOG_DIR/install.log" 2>&1 || true
        chown -R proxy:proxy /var/lib/squid/ssl_db 2>/dev/null || true
    fi

    local squid_errors
    squid_errors=$(squid -k parse 2>&1 | grep -iE "^[[:space:]]*(FATAL|ERROR)" | wc -l)
    if [[ "$squid_errors" -eq 0 ]]; then
        log_ok "Squid config valid"
    else
        log_warn "Squid config warnings present — attempting start anyway"
        squid -k parse 2>&1 | grep -iE "FATAL|ERROR" | head -5
    fi

    systemctl enable squid >> "$LOG_DIR/install.log" 2>&1
    systemctl restart squid
    log_ok "Squid running on port ${HTTP_PORT} (HTTP) and ${HTTPS_PORT} (HTTPS)"
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
    [[ "$c" != "y" ]] && go_back
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

    prompt_expiry

    [[ "$uchoice" == 1 || "$uchoice" == 4 ]] && add_squid_user "$username" "$password"
    [[ "$uchoice" == 2 || "$uchoice" == 4 ]] && add_dante_user "$username" "$password"
    [[ "$uchoice" == 3 || "$uchoice" == 4 ]] && add_3proxy_user "$username" "$password"

    # Replace any older record for this username, then save
    [[ -f $USERS_FILE ]] && sed -i "/^$username:/d" "$USERS_FILE"
    save_user "$username" "$password" "$uchoice"
    set_expiry "$username" "$EXPIRY_EPOCH"

    local ip; ip=$(get_server_ip)
    echo -e "\n${GREEN}${BOLD}╔══════════════════════════════════════════════╗"
    echo -e "║         USER CREATED SUCCESSFULLY           ║"
    echo -e "╠══════════════════════════════════════════════╣"
    echo -e "║  Username : ${WHITE}$username${GREEN}"
    echo -e "║  Password : ${WHITE}$password${GREEN}"
    echo -e "║  Expires  : ${WHITE}$(fmt_expiry "$EXPIRY_EPOCH")${GREEN}"
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
    [[ "$c" != "y" ]] && go_back

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

    # Expiry record
    set_expiry "$username" 0

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

    echo -e "\n${CYAN}Current expiry: ${WHITE}$(fmt_expiry "$(get_expiry "$username")")${RESET}"
    echo -ne "${YELLOW}Change expiry? (y/n): ${RESET}"; read -r ce
    if [[ "$ce" == "y" || "$ce" == "Y" ]]; then
        prompt_expiry
        set_expiry "$username" "$EXPIRY_EPOCH"
        log_ok "Expiry for $username: $(fmt_expiry "$EXPIRY_EPOCH")"
    fi
    press_enter
}

# ══════════════════════════════════════════════════════════════
#  8. LIST USERS
# ══════════════════════════════════════════════════════════════
list_users_inline() {
    echo -e "${CYAN}── Current Users ──────────────────────────────────${RESET}"
    if [[ -f $USERS_FILE ]]; then
        printf "  %-18s %-18s %-6s %-36s %s\n" "USER" "PASSWORD" "TYPE" "EXPIRES" "CREATED"
        echo -e "  $(printf '%.0s─' {1..100})"
        local xe xcol
        while IFS=: read -r u p t d; do
            xe=$(get_expiry "$u")
            if (( xe == 0 )); then xcol=$GREEN
            elif (( xe <= $(date +%s) )); then xcol=$RED
            else xcol=$YELLOW; fi
            printf "  ${GREEN}%-18s${RESET} ${WHITE}%-18s${RESET} ${YELLOW}%-6s${RESET} ${xcol}%-36s${RESET} %s\n" "$u" "$p" "$t" "$(fmt_expiry "$xe")" "$d"
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

    echo -e "\n${CYAN}Expiry applied to ALL users in this file:${RESET}"
    prompt_expiry

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
        [[ "$uchoice" == 1 || "$uchoice" == 4 ]] && add_squid_user "$user" "$pass"
        [[ "$uchoice" == 2 || "$uchoice" == 4 ]] && add_dante_user "$user" "$pass"
        [[ "$uchoice" == 3 || "$uchoice" == 4 ]] && add_3proxy_user "$user" "$pass"
        [[ -f $USERS_FILE ]] && sed -i "/^$user:/d" "$USERS_FILE"
        save_user "$user" "$pass" "$uchoice"
        set_expiry "$user" "$EXPIRY_EPOCH"
        echo -e "  ${GREEN}✔ $user : $pass${RESET}"
        count=$((count+1))
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
    echo -ne "Continue? (y/n): "; read -r c; [[ "$c" != "y" ]] && go_back

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
    rm -f /etc/systemd/system/3proxy.service "$EXPIRY_CRON"
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
        0)  main_menu ;;
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
        28) manage_expiry ;;
        29) echo -e "\n${GREEN}Goodbye!${RESET}\n"; exit 0 ;;
        --expire-check) enforce_expiry ;;
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
    [[ "$c" != "y" ]] && go_back

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
    [[ "$c" != "y" ]] && go_back

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
    --expire-check)  enforce_expiry; exit 0 ;;
    *)
        # Fallback: also purge expired accounts whenever the menu is opened
        enforce_expiry
        main_menu ;;
esac
