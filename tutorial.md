Ah, I understand now! You want two separate proxy ports with different DNS configurations. Unfortunately, Clash doesn't support multiple proxy ports with different DNS settings in a single instance. You'll need to run **two separate Clash instances** with different configurations.

## Solution: Run Two Clash Instances

### Config 1: With DoH (port 7890)
Save as `config-doh.yaml`:

```yaml
# Proxy WITH DoH - Port 7890
port: 7890
socks-port: 7891
mixed-port: 7892
allow-lan: true
mode: rule
log-level: info

# API for management
external-controller: 127.0.0.1:9090
secret: ""

# Bind to USB NIC
interface-name: enx1610c2d100e0

dns:
  enable: true
  ipv6: false
  enhanced-mode: fake-ip
  listen: 127.0.0.1:1053
  
  # Use DoH
  nameserver:
    - https://xbox-dns.ru/dns-query
    # - https://cloudflare-dns.com/dns-query
    # - https://dns.google/dns-query
  
  fake-ip-range: 198.18.0.1/16

proxies:
  - name: "usb-direct"
    type: direct
    udp: true
    interface-name: enx1610c2d100e0

proxy-groups:
  - name: Proxy
    type: select
    proxies:
      - usb-direct
      - DIRECT

rules:
  - MATCH,Proxy

ntp:
  enable: true
  server: time.apple.com
  port: 123
  interval: 30
```

### Config 2: Without DoH (port 7893)
Save as `config-direct.yaml`:

```yaml
# Proxy WITHOUT DoH - Port 7893
port: 7893
socks-port: 7894
mixed-port: 7895
allow-lan: true
mode: rule
log-level: info

# Different API port to avoid conflict
external-controller: 127.0.0.1:9091
secret: ""

# Bind to USB NIC
interface-name: enx1610c2d100e0

dns:
  enable: true
  ipv6: false
  enhanced-mode: redir-host  # Use redir-host for direct DNS
  listen: 127.0.0.1:1054  # Different DNS port
  
  # Use direct DNS servers (no DoH)
  nameserver:
    - 8.8.8.8
    - 8.8.4.4
    - 1.1.1.1
    # Or use system DNS:
    # - system

proxies:
  - name: "usb-direct"
    type: direct
    udp: true
    interface-name: enx1610c2d100e0

proxy-groups:
  - name: Proxy
    type: select
    proxies:
      - usb-direct
      - DIRECT

rules:
  - MATCH,Proxy

ntp:
  enable: true
  server: time.apple.com
  port: 123
  interval: 30
```

## Running Both Instances

### Method 1: Using Screen/Tmux

```bash
# Terminal 1 - DoH proxy
screen -S clash-doh
clash-meta -d ./clash-doh -f config-doh.yaml

# Terminal 2 - Direct proxy
screen -S clash-direct  
clash-meta -d ./clash-direct -f config-direct.yaml
```

### Method 2: Using Systemd Services

Create two systemd services:

**Service 1: `/etc/systemd/system/clash-doh.service`**
```ini
[Unit]
Description=Clash with DoH (port 7890)
After=network.target

[Service]
Type=simple
User=reader
WorkingDirectory=/home/reader/clash-doh
ExecStart=/usr/local/bin/clash-meta -d /home/reader/clash-doh -f /home/reader/clash-doh/config-doh.yaml
Restart=on-failure
RestartSec=5s

[Install]
WantedBy=multi-user.target
```

**Service 2: `/etc/systemd/system/clash-direct.service`**
```ini
[Unit]
Description=Clash without DoH (port 7893)
After=network.target

[Service]
Type=simple
User=reader
WorkingDirectory=/home/reader/clash-direct
ExecStart=/usr/local/bin/clash-meta -d /home/reader/clash-direct -f /home/reader/clash-direct/config-direct.yaml
Restart=on-failure
RestartSec=5s

[Install]
WantedBy=multi-user.target
```

Then start both services:
```bash
sudo systemctl daemon-reload
sudo systemctl enable clash-doh clash-direct
sudo systemctl start clash-doh clash-direct
```

### Method 3: Simple Bash Script

Create `start-both.sh`:
```bash
#!/bin/bash

# Create directories
mkdir -p ~/clash-doh ~/clash-direct

# Copy configs
cp config-doh.yaml ~/clash-doh/
cp config-direct.yaml ~/clash-direct/

# Start both instances
echo "Starting Clash with DoH on port 7890..."
clash-meta -d ~/clash-doh -f ~/clash-doh/config-doh.yaml &
DOH_PID=$!

echo "Starting Clash without DoH on port 7893..."
clash-meta -d ~/clash-direct -f ~/clash-direct/config-direct.yaml &
DIRECT_PID=$!

echo "DoH proxy PID: $DOH_PID"
echo "Direct proxy PID: $DIRECT_PID"

# Wait for both
wait $DOH_PID $DIRECT_PID
```

Run it:
```bash
chmod +x start-both.sh
./start-both.sh
```

## Using the Proxies

Now you have two separate proxies:

1. **App that needs DoH** (to bypass filtering):
   - HTTP Proxy: `127.0.0.1:7890`
   - SOCKS5 Proxy: `127.0.0.1:7891`
   - Mixed: `127.0.0.1:7892`

2. **App that doesn't need DoH** (faster, direct DNS):
   - HTTP Proxy: `127.0.0.1:7893`
   - SOCKS5 Proxy: `127.0.0.1:7894`
   - Mixed: `127.0.0.1:7895`

## Testing

```bash
# Test DoH proxy (port 7890)
curl -x http://127.0.0.1:7890 https://www.youtube.com

# Test Direct proxy (port 7893)
curl -x http://127.0.0.1:7893 https://www.google.com

# Check both are running
netstat -tulpn | grep -E "7890|7893"
```

## Management

Each instance has its own API:
- DoH instance: http://127.0.0.1:9090
- Direct instance: http://127.0.0.1:9091

You can use different Yacd/Dashboard instances to manage each one separately.