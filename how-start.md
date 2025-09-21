 ~/nixstatic shell nixpkgs/nixos-25.05#clash-meta --impure -c bash -c "clash-meta -d ./.config/clash"

 chmod +x test_clash.sh

 killall cntlm clash-meta

 cntlm -c ./.config/clash/cntlm.conf -I -M http://example.com