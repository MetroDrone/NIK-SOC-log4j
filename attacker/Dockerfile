FROM python:3.11-slim

LABEL description="Log4Shell demo - Attacker (LDAP + HTTP server)"

RUN apt-get update && apt-get install -y \
    default-jdk \
    curl \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /attacker

# Python-alapú LDAP szerver (marshalsec helyett egyszerűbb megközelítés)
RUN pip install ldap3 flask

COPY ldap-server/      ./ldap-server/
COPY http-server/      ./http-server/
COPY entrypoint.sh     ./entrypoint.sh

# Malicious Java class fordítása
COPY Exploit.java      ./Exploit.java
RUN javac Exploit.java -source 8 -target 8 2>/dev/null || \
    javac Exploit.java

RUN mv Exploit.class ./http-server/Exploit.class

RUN chmod +x entrypoint.sh

EXPOSE 1389 8888

CMD ["./entrypoint.sh"]
