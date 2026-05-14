#!/bin/bash
set -e

WAZUH_MANAGER="${WAZUH_MANAGER:-172.20.0.30}"
WAZUH_AGENT_NAME="${WAZUH_AGENT_NAME:-vulnerable-app}"

echo "=============================================="
echo " Log4Shell Demo - Sebezhető alkalmazás"
echo " Java verzió: $(java -version 2>&1 | head -1)"
echo " Wazuh Manager: $WAZUH_MANAGER"
echo "=============================================="

# Log könyvtár létrehozása
mkdir -p /var/log/vulnerable-app

# Wazuh agent telepítése és regisztrálása (ha manager elérhető)
echo "[*] Wazuh agent telepítése..."
if ! command -v wazuh-agentd &>/dev/null; then
    # Wazuh 4.7 agent letöltése
    curl -so /tmp/wazuh-agent.deb \
        "https://packages.wazuh.com/4.x/apt/pool/main/w/wazuh-agent/wazuh-agent_4.7.3-1_amd64.deb" \
        --max-time 60 --retry 3 2>/dev/null || true

    if [ -f /tmp/wazuh-agent.deb ]; then
        WAZUH_MANAGER="$WAZUH_MANAGER" \
        WAZUH_MANAGER_PORT="1514" \
        WAZUH_AGENT_NAME="$WAZUH_AGENT_NAME" \
        dpkg -i /tmp/wazuh-agent.deb 2>/dev/null || true
        rm -f /tmp/wazuh-agent.deb
    fi
fi

# Wazuh agent konfiguráció
if command -v wazuh-agentd &>/dev/null; then
    cat > /var/ossec/etc/ossec.conf << EOF
<ossec_config>
  <client>
    <server>
      <address>${WAZUH_MANAGER}</address>
      <port>1514</port>
      <protocol>udp</protocol>
    </server>
    <config-profile>debian, debian12</config-profile>
    <notify_time>10</notify_time>
    <time-reconnect>60</time-reconnect>
    <auto_restart>yes</auto_restart>
    <crypto_method>aes</crypto_method>
  </client>

  <localfile>
    <log_format>syslog</log_format>
    <location>/var/log/vulnerable-app/app.log</location>
  </localfile>

  <localfile>
    <log_format>syslog</log_format>
    <location>/var/log/syslog</location>
  </localfile>
</ossec_config>
EOF

    # Agent regisztráció
    echo "[*] Wazuh agent regisztrálása..."
    /var/ossec/bin/agent-auth -m "$WAZUH_MANAGER" -A "$WAZUH_AGENT_NAME" 2>/dev/null || \
        echo "[!] Agent regisztráció sikertelen (manager esetleg még nem fut) – folytatás..."

    # Agent indítása
    /var/ossec/bin/wazuh-control start 2>/dev/null || true
    echo "[*] Wazuh agent indítva"
else
    echo "[!] Wazuh agent nem telepíthető (offline mód) – logok fájlban lesznek"
fi

echo "[*] Alkalmazás indítása: http://0.0.0.0:8080"
echo "[*] Log fájl: /var/log/vulnerable-app/app.log"
echo ""
echo "  Elérhető endpointok:"
echo "    GET  /api/hello  (sérülékeny – User-Agent logolva)"
echo "    GET  /api/status"
echo "    POST /api/login?username=USER"
echo ""

exec java \
    -Dlog4j2.configurationFile=/app/log4j2.xml \
    -Dcom.sun.jndi.ldap.object.trustURLCodebase=true \
    -Dlog4j2.formatMsgNoLookups=false \
    -jar /app/app.jar \
    --server.port=8080
