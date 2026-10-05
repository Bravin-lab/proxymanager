# 🛡️ PROXY MANAGER PRO — Ubuntu VPS Edition
> Supports: **Squid (HTTP/HTTPS)** | **Dante (SOCKS5)** | **3proxy (Multi-protocol)**  
> Author: t.me/Hackerprime254 | Group: t.me/anyipscannertool

---

## 📋 TABLE OF CONTENTS
1. [Requirements](#requirements)
2. [Installation](#installation)
3. [Launch Commands](#launch-commands)
4. [Menu Options](#menu-options)
5. [User Management Commands](#user-management-commands)
6. [Service Control Commands](#service-control-commands)
7. [Firewall Commands](#firewall-commands)
8. [Log Commands](#log-commands)
9. [Proxy Connection Formats](#proxy-connection-formats)
10. [File Formats](#file-formats)
11. [Troubleshooting](#troubleshooting)
12. [Default Ports](#default-ports)

---

## ⚙️ REQUIREMENTS

| Item | Requirement |
|------|------------|
| OS | Ubuntu 20.04 / 22.04 / 24.04 LTS |
| Access | Root or sudo |
| RAM | Minimum 512MB (1GB+ recommended) |
| Packages | curl, ufw, openssl (auto-installed) |

---

## 🚀 INSTALLATION

### Step 1 — Upload script to your VPS
```bash
# Option A: using scp from your local machine
scp proxymanager.sh root@YOUR_VPS_IP:/root/

# Option B: using wget (if hosted online)
wget -O proxymanager.sh https://your-link/proxymanager.sh

# Option C: create the file directly on VPS
nano proxymanager.sh
# paste the script, then Ctrl+X → Y → Enter
```

### Step 2 — Make it executable
```bash
chmod +x proxymanager.sh
```

### Step 3 — Run for the first time
```bash
sudo ./proxymanager.sh
```

### Step 4 — After first run, use shortcut from anywhere
```bash
menu
```
> The script automatically creates a `menu` command on first launch.

---

## 🖥️ LAUNCH COMMANDS

| Command | Description |
|---------|-------------|
| `sudo ./proxymanager.sh` | Run from current directory |
| `menu` | Launch from anywhere (after first run) |
| `sudo bash proxymanager.sh` | Alternative run method |
| `sudo ./proxymanager.sh --rotate-silent` | Silently rotate all passwords (used by cron) |

---

## 📂 MENU OPTIONS

```
╔══════════════════════════════════════════════════════════════╗
║            PROXY MANAGER PRO — Ubuntu VPS Edition           ║
╚══════════════════════════════════════════════════════════════╝

── INSTALLATION ──
 1.  Install Squid  (HTTP/HTTPS Proxy)
 2.  Install Dante  (SOCKS5 Proxy)
 3.  Install 3proxy (HTTP + SOCKS5 + Multi)
 4.  Install ALL    (Squid + Dante + 3proxy)

── USER MANAGEMENT ──
 5.  Add Proxy User
 6.  Delete Proxy User
 7.  Edit Proxy User (change password)
 8.  List All Users
 9.  Bulk Add Users from file

── PROXY MANAGEMENT ──
10.  Start / Stop / Restart Proxies
11.  View Proxy Status
12.  Change Proxy Ports
13.  View Active Connections & Logs
14.  Bandwidth Usage per User

── FIREWALL & SECURITY ──
15.  UFW Firewall Setup
16.  Block/Unblock IP Address
17.  Whitelist IP (no-auth access)
18.  Anti-leak / DNS Leak Protection

── ADVANCED ──
19.  Export Proxy List (host:port:user:pass)
20.  Test Proxy Connectivity
21.  Auto-renew / Rotate Proxy Credentials
22.  Uninstall All Proxies
23.  Exit
```

---

## 👤 USER MANAGEMENT COMMANDS

### Add a single user manually (outside menu)
```bash
# Add to Squid (HTTP)
sudo htpasswd -b /etc/squid/squid_passwd USERNAME PASSWORD

# Add to Dante (SOCKS5) — creates system user
sudo useradd -r -s /bin/false -M USERNAME
echo "USERNAME:PASSWORD" | sudo chpasswd

# Add to 3proxy
echo "USERNAME:CL5:$(echo -n 'USERNAME:3proxy:PASSWORD' | md5sum | awk '{print $1}')" \
  | sudo tee -a /etc/3proxy/users.cfg
```

### Delete a user manually
```bash
# Remove from Squid
sudo htpasswd -D /etc/squid/squid_passwd USERNAME

# Remove from Dante
sudo userdel USERNAME

# Remove from 3proxy
sudo sed -i '/^USERNAME:/d' /etc/3proxy/users.cfg
```

### Change a user's password manually
```bash
# Squid
sudo htpasswd -b /etc/squid/squid_passwd USERNAME NEWPASSWORD

# Dante
echo "USERNAME:NEWPASSWORD" | sudo chpasswd

# 3proxy
sudo sed -i '/^USERNAME:/d' /etc/3proxy/users.cfg
echo "USERNAME:CL5:$(echo -n 'USERNAME:3proxy:NEWPASSWORD' | md5sum | awk '{print $1}')" \
  | sudo tee -a /etc/3proxy/users.cfg
```

### List all Squid users
```bash
sudo cat /etc/squid/squid_passwd | cut -d: -f1
```

### List all 3proxy users
```bash
sudo cat /etc/3proxy/users.cfg | cut -d: -f1
```

### Bulk add users — file format
```bash
# Create a file: users.txt
# Format: username:password  OR  just username (auto password)
nano users.txt
```
```
john:MyPass123
jane:SecurePass@456
mike
sarah:Admin@789
```
```bash
# Then use Option 9 in the menu and point to this file
```

---

## 🔧 SERVICE CONTROL COMMANDS

### Squid (HTTP/HTTPS)
```bash
sudo systemctl start squid        # Start
sudo systemctl stop squid         # Stop
sudo systemctl restart squid      # Restart
sudo systemctl reload squid       # Reload config (no downtime)
sudo systemctl status squid       # Check status
sudo systemctl enable squid       # Auto-start on boot
sudo systemctl disable squid      # Disable auto-start

# Test config before applying
sudo squid -k parse
```

### Dante (SOCKS5)
```bash
sudo systemctl start danted       # Start
sudo systemctl stop danted        # Stop
sudo systemctl restart danted     # Restart
sudo systemctl status danted      # Check status
sudo systemctl enable danted      # Auto-start on boot
```

### 3proxy
```bash
sudo systemctl start 3proxy       # Start
sudo systemctl stop 3proxy        # Stop
sudo systemctl restart 3proxy     # Restart
sudo systemctl status 3proxy      # Check status
sudo systemctl enable 3proxy      # Auto-start on boot

# Manually run 3proxy
sudo 3proxy /etc/3proxy/3proxy.cfg
```

### Restart ALL proxies at once
```bash
sudo systemctl restart squid danted 3proxy
```

### Check all proxy services at once
```bash
for svc in squid danted 3proxy; do
  echo "── $svc ──"
  systemctl is-active $svc
done
```

---

## 🌐 FIREWALL COMMANDS (UFW)

### Initial setup
```bash
sudo ufw enable                          # Enable firewall
sudo ufw status verbose                  # View all rules
sudo ufw status numbered                 # View rules with numbers
```

### Allow proxy ports
```bash
sudo ufw allow 3128/tcp    # Squid HTTP
sudo ufw allow 3129/tcp    # Squid HTTPS
sudo ufw allow 1080/tcp    # Dante SOCKS5
sudo ufw allow 8080/tcp    # 3proxy HTTP
sudo ufw allow 1081/tcp    # 3proxy SOCKS5
sudo ufw allow 22/tcp      # SSH (never block this!)
```

### Block / Unblock an IP
```bash
sudo ufw deny from 1.2.3.4              # Block IP
sudo ufw delete deny from 1.2.3.4       # Unblock IP
sudo ufw deny from 1.2.3.0/24           # Block entire subnet
```

### Whitelist an IP (allow all ports)
```bash
sudo ufw allow from 1.2.3.4 to any
```

### Rate limiting (anti-abuse)
```bash
sudo ufw limit 3128/tcp    # Limit connections on Squid port
sudo ufw limit 1080/tcp    # Limit connections on SOCKS5 port
```

### Remove a rule by number
```bash
sudo ufw status numbered
sudo ufw delete 3          # Delete rule number 3
```

### Reset firewall completely
```bash
sudo ufw --force reset
```

---

## 📜 LOG COMMANDS

### View live logs
```bash
# Squid access log (live)
sudo tail -f /var/log/squid/access.log

# Squid cache log
sudo tail -f /var/log/squid/cache.log

# Dante log (live)
sudo tail -f /var/log/danted.log

# 3proxy log (live)
sudo tail -f /var/log/3proxy/3proxy.log
```

### Search logs
```bash
# Find specific user activity in Squid
sudo grep "USERNAME" /var/log/squid/access.log

# Find specific IP in Squid
sudo grep "1.2.3.4" /var/log/squid/access.log

# Count requests per user
sudo awk '{print $8}' /var/log/squid/access.log | sort | uniq -c | sort -rn | head -20

# Find failed auth attempts
sudo grep "TCP_DENIED" /var/log/squid/access.log | tail -50
```

### View active connections
```bash
# All active proxy connections
sudo ss -tnp | grep -E ":(3128|1080|8080|1081)"

# Count connections per port
sudo ss -tn | awk '{print $4}' | cut -d: -f2 | sort | uniq -c | sort -rn

# Who is connected right now
sudo netstat -tnp | grep -E ":(3128|1080|8080)"
```

### Clear logs
```bash
sudo truncate -s 0 /var/log/squid/access.log
sudo truncate -s 0 /var/log/danted.log
sudo truncate -s 0 /var/log/3proxy/3proxy.log
```

---

## 🔌 PROXY CONNECTION FORMATS

### HTTP Proxy (Squid)
```
Host     : YOUR_VPS_IP
Port     : 3128
Username : your_username
Password : your_password

# URL format
http://your_username:your_password@YOUR_VPS_IP:3128

# curl test
curl -x http://USERNAME:PASSWORD@YOUR_VPS_IP:3128 https://ifconfig.me
```

### HTTPS Proxy (Squid SSL)
```
Host     : YOUR_VPS_IP
Port     : 3129

# curl test
curl -x https://USERNAME:PASSWORD@YOUR_VPS_IP:3129 https://ifconfig.me --proxy-insecure
```

### SOCKS5 Proxy (Dante)
```
Host     : YOUR_VPS_IP
Port     : 1080
Username : your_username
Password : your_password

# URL format
socks5://your_username:your_password@YOUR_VPS_IP:1080

# curl test
curl --socks5 YOUR_VPS_IP:1080 -U USERNAME:PASSWORD https://ifconfig.me
```

### 3proxy HTTP
```
Host     : YOUR_VPS_IP
Port     : 8080

# curl test
curl -x http://USERNAME:PASSWORD@YOUR_VPS_IP:8080 https://ifconfig.me
```

### 3proxy SOCKS5
```
Host     : YOUR_VPS_IP
Port     : 1081

# curl test
curl --socks5 YOUR_VPS_IP:1081 -U USERNAME:PASSWORD https://ifconfig.me
```

---

## 📄 FILE FORMATS

### Bulk user file (for Option 9)
```
# users.txt
# Format: username:password  or  just username
alice:StrongPass@123
bob:AnotherPass#456
charlie
diana:MyProxy$789
```

### Exported proxy list formats

**Format 1 — host:port:user:pass**
```
203.0.113.1:3128:alice:StrongPass@123
203.0.113.1:1080:alice:StrongPass@123
```

**Format 2 — user:pass@host:port**
```
alice:StrongPass@123@203.0.113.1:3128
alice:StrongPass@123@203.0.113.1:1080
```

**Format 3 — http:// URL**
```
http://alice:StrongPass@123@203.0.113.1:3128
```

**Format 4 — socks5:// URL**
```
socks5://alice:StrongPass@123@203.0.113.1:1080
```

### Config file locations
| File | Path |
|------|------|
| Squid config | `/etc/squid/squid.conf` |
| Squid users | `/etc/squid/squid_passwd` |
| Dante config | `/etc/danted.conf` |
| 3proxy config | `/etc/3proxy/3proxy.cfg` |
| 3proxy users | `/etc/3proxy/users.cfg` |
| PM users list | `/etc/proxymanager/users.list` |
| PM settings | `/etc/proxymanager/settings.conf` |

---

## 🛠️ TROUBLESHOOTING

### Squid not starting
```bash
# Check config syntax
sudo squid -k parse

# Check error logs
sudo journalctl -u squid -n 50

# Check if port is in use
sudo ss -tlnp | grep 3128
```

### Dante not starting
```bash
# Check logs
sudo journalctl -u danted -n 50

# Verify interface name in config
ip route get 8.8.8.8 | awk '{print $5; exit}'

# Make sure the interface in /etc/danted.conf matches
sudo nano /etc/danted.conf
```

### 3proxy not starting
```bash
# Check manually
sudo 3proxy /etc/3proxy/3proxy.cfg

# Check systemd logs
sudo journalctl -u 3proxy -n 50

# Verify binary exists
which 3proxy
```

### Authentication failing
```bash
# Test Squid auth manually
curl -v -x http://USER:PASS@VPS_IP:3128 http://google.com 2>&1 | grep -E "407|200|auth"

# Reload Squid after user changes
sudo systemctl reload squid

# Restart 3proxy after user changes
sudo systemctl restart 3proxy
```

### Port already in use
```bash
# Find what's using the port
sudo ss -tlnp | grep :3128
sudo lsof -i :3128

# Kill the process
sudo kill -9 PID
```

### Can't connect through proxy
```bash
# 1. Check service is running
sudo systemctl status squid

# 2. Check port is open
sudo ss -tlnp | grep 3128

# 3. Check firewall
sudo ufw status

# 4. Test from VPS itself
curl -x http://USER:PASS@127.0.0.1:3128 https://ifconfig.me

# 5. Check if VPS provider blocks ports (contact your VPS host)
```

### DNS not resolving through proxy
```bash
# Force DNS refresh
sudo systemctl restart systemd-resolved

# Or manually set DNS
echo "nameserver 1.1.1.1" | sudo tee /etc/resolv.conf
echo "nameserver 8.8.8.8" | sudo tee -a /etc/resolv.conf
```

---

## 🔒 DEFAULT PORTS

| Proxy | Protocol | Default Port |
|-------|----------|-------------|
| Squid | HTTP | **3128** |
| Squid | HTTPS (SSL) | **3129** |
| Dante | SOCKS5 | **1080** |
| 3proxy | HTTP | **8080** |
| 3proxy | SOCKS5 | **1081** |
| SSH | TCP | **22** |

> All ports can be changed via **Option 12** in the menu.

---

## ⚡ QUICK REFERENCE CHEATSHEET

```bash
# ── LAUNCH ────────────────────────────────────
menu                                    # Open proxy manager menu
sudo ./proxymanager.sh                  # Run directly

# ── SERVICES ──────────────────────────────────
sudo systemctl restart squid            # Restart HTTP proxy
sudo systemctl restart danted           # Restart SOCKS5 proxy
sudo systemctl restart 3proxy           # Restart 3proxy
sudo systemctl restart squid danted 3proxy  # Restart ALL

# ── USERS ─────────────────────────────────────
sudo htpasswd -b /etc/squid/squid_passwd USER PASS   # Add HTTP user
sudo htpasswd -D /etc/squid/squid_passwd USER        # Delete HTTP user
sudo cat /etc/proxymanager/users.list                # View all users

# ── LOGS ──────────────────────────────────────
sudo tail -f /var/log/squid/access.log  # Live HTTP log
sudo tail -f /var/log/danted.log        # Live SOCKS5 log
sudo tail -f /var/log/3proxy/3proxy.log # Live 3proxy log

# ── FIREWALL ──────────────────────────────────
sudo ufw status                         # View firewall rules
sudo ufw allow PORT/tcp                 # Open a port
sudo ufw deny from IP                   # Block an IP

# ── TEST ──────────────────────────────────────
curl -x http://USER:PASS@VPS_IP:3128 https://ifconfig.me    # Test HTTP
curl --socks5 VPS_IP:1080 -U USER:PASS https://ifconfig.me  # Test SOCKS5
```

---

*Proxy Manager Pro — Built for network admins and power users*  
*t.me/Hackerprime254 | t.me/anyipscannertool*
