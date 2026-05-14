# !!!! SÉRÜLÉKENY KONFIGURÁCIÓ – CSAK LABOR CÉLRA !!!!
# Java 8 + Log4j 2.14.1 = CVE-2021-44228 reprodukálható

FROM maven:3.8.6-eclipse-temurin-8 AS builder

WORKDIR /build
COPY pom.xml .
# Függőségek cache-elése
RUN mvn dependency:go-offline -q

COPY src/ ./src/
RUN mvn package -DskipTests -q

# Futtatási image
FROM eclipse-temurin:8-jre-focal

LABEL description="Log4Shell demo - Vulnerable Application (CVE-2021-44228)"
LABEL warning="CSAK LABOR CÉLRA! Ne használd éles környezetben!"

# Wazuh agent telepítése
RUN apt-get update && apt-get install -y \
    curl \
    wget \
    gnupg \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

COPY --from=builder /build/target/vulnerable-log4j-app-1.0.0.jar app.jar
COPY config/log4j2.xml /app/log4j2.xml
COPY entrypoint.sh /app/entrypoint.sh

RUN chmod +x /app/entrypoint.sh

EXPOSE 8080

ENTRYPOINT ["/app/entrypoint.sh"]
