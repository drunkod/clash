#!/bin/bash

CLASH_HTTP_PROXY="http://127.0.0.1:7890"
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m'

echo "--- Running HTTPS Connectivity Test ---"

# We use -s to be silent, and check the exit code ($?)
# A successful connection will have an exit code of 0
curl -s -x ${CLASH_HTTP_PROXY} --connect-timeout 10 https://www.google.com > /dev/null

if [[ $? -eq 0 ]]; then
  echo -e "${GREEN}SUCCESS: Connection to https://www.google.com via Clash proxy was successful!${NC}"
else
  echo -e "${RED}FAILURE: Could not connect to https://www.google.com via Clash proxy.${NC}"
fi