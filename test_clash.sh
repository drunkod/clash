#!/bin/bash

# --- Configuration ---
# These should match your Clash config.yml
CLASH_HTTP_PROXY="http://127.0.0.1:7890"
CLASH_SOCKS_PROXY="socks5://127.0.0.1:7891"
CLASH_DNS_SERVER="127.0.0.1"
CLASH_DNS_PORT="1053"

# A known external domain to test proxying
EXTERNAL_TEST_DOMAIN="ifconfig.me"

# A domain from your 'DIRECT' rules in config.yml
INTERNAL_TEST_DOMAIN="chelib.ru"

# --- Colors for prettier output ---
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo "=== Clash Proxy Test Suite ==="

# --- Test 1: Get Real Public IP (Baseline) ---
echo -e "\n${YELLOW}--- Test 1: Checking Real Public IP (no proxy) ---${NC}"
real_ip=$(curl -s --connect-timeout 5 ${EXTERNAL_TEST_DOMAIN})

if [[ -n "$real_ip" ]]; then
  echo "Your real public IP is: ${GREEN}${real_ip}${NC}"
else
  echo -e "${RED}Error: Could not fetch real public IP. Check your internet connection.${NC}"
  exit 1
fi

# --- Test 2: Test HTTP Proxy ---
echo -e "\n${YELLOW}--- Test 2: Checking IP via HTTP Proxy (${CLASH_HTTP_PROXY}) ---${NC}"
proxy_ip_http=$(curl -s -x ${CLASH_HTTP_PROXY} --connect-timeout 5 ${EXTERNAL_TEST_DOMAIN})

if [[ -z "$proxy_ip_http" ]]; then
  echo -e "${RED}FAILURE: Request via HTTP proxy failed. Is Clash running?${NC}"
else
  echo "IP seen by the server is: ${GREEN}${proxy_ip_http}${NC}"
  if [[ "$proxy_ip_http" != "$real_ip" ]]; then
    echo -e "${GREEN}SUCCESS: IP through proxy is different from your real IP.${NC}"
  else
    echo -e "${RED}FAILURE: IP through proxy is the SAME as your real IP. Proxying is not working as expected.${NC}"
  fi
fi

# --- Test 3: Test SOCKS5 Proxy ---
echo -e "\n${YELLOW}--- Test 3: Checking IP via SOCKS5 Proxy (${CLASH_SOCKS_PROXY}) ---${NC}"
proxy_ip_socks=$(curl -s -x ${CLASH_SOCKS_PROXY} --connect-timeout 5 ${EXTERNAL_TEST_DOMAIN})

if [[ -z "$proxy_ip_socks" ]]; then
  echo -e "${RED}FAILURE: Request via SOCKS5 proxy failed. Is Clash running?${NC}"
else
  echo "IP seen by the server is: ${GREEN}${proxy_ip_socks}${NC}"
  if [[ "$proxy_ip_socks" != "$real_ip" ]]; then
    echo -e "${GREEN}SUCCESS: IP through proxy is different from your real IP.${NC}"
  else
    echo -e "${RED}FAILURE: IP through proxy is the SAME as your real IP. Proxying is not working as expected.${NC}"
  fi
fi

# --- Test 4: Test 'DIRECT' Rule ---
echo -e "\n${YELLOW}--- Test 4: Verifying 'DIRECT' rule for '${INTERNAL_TEST_DOMAIN}' ---${NC}"
echo "Clash should bypass the proxy for this domain..."
# We check the verbose output. If it connects to 127.0.0.1, the rule failed.
connection_info=$(curl -v -x ${CLASH_HTTP_PROXY} --connect-timeout 5 http://${INTERNAL_TEST_DOMAIN} 2>&1 | grep "Connected to")

if echo "$connection_info" | grep -q "127.0.0.1"; then
  echo -e "${RED}FAILURE: Connection was routed to the local proxy (127.0.0.1). The DIRECT rule did not work.${NC}"
  echo "  Details: $connection_info"
else
  echo -e "${GREEN}SUCCESS: Connection was not routed to the local proxy. The DIRECT rule is working.${NC}"
  echo "  Details: $connection_info"
fi

# --- Test 5: Test DNS Fake-IP ---
echo -e "\n${YELLOW}--- Test 5: Verifying DNS 'fake-ip' mode ---${NC}"
# Check if 'dig' command exists
if ! command -v dig &> /dev/null; then
    echo -e "${RED}SKIPPED: 'dig' command not found. Please install dnsutils (Debian/Ubuntu) or bind-utils (CentOS/Fedora).${NC}"
else
    echo "Querying 'google.com' through Clash DNS at ${CLASH_DNS_SERVER}:${CLASH_DNS_PORT}..."
    # We query google.com and expect an IP from the 198.18.0.1/16 range
    dns_result=$(dig @${CLASH_DNS_SERVER} -p ${CLASH_DNS_PORT} google.com +short | head -n 1)

    if [[ "$dns_result" == "198.18."* ]]; then
        echo -e "${GREEN}SUCCESS: DNS returned a fake-ip ($dns_result) from the correct range.${NC}"
    else
        echo -e "${RED}FAILURE: DNS did not return a fake-ip. Received: '$dns_result'${NC}"
    fi
fi

echo -e "\n=== Test Complete ==="