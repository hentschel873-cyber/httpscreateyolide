Local Sync — Umgebungsvariablen und Hinweise
=============================================

Diese Datei beschreibt die optionalen Umgebungsvariablen, die der MU-Loader `local-sync-loader.php` nutzt.

Variablen
---------
- `WP_LOCAL_SYNC_SECRET` (empfohlen)
  - Beschreibung: Shared secret (Token), das der Client im Header `Authorization: Bearer <token>` mitsenden muss.
  - Verwendung: `export WP_LOCAL_SYNC_SECRET="mein_sehr_geheimes_token"` (Linux/macOS) oder in `.env`/WP-Umgebung setzen.
  - Hinweise: Niemals ins Repository committen. Rotieren, wenn das Geheimnis kompromittiert ist.

- `WP_LOCAL_SYNC_WHITELIST` (optional)
  - Beschreibung: Kommagetrennte Liste erlaubter Client-IP-Adressen oder CIDR-Subnetze. Beispiel:
    - `127.0.0.1` oder `192.0.2.0/24` oder Kombination: `127.0.0.1,192.0.2.0/24`
  - Wirkung: Wenn gesetzt, werden nur Anfragen von erlaubten IPs akzeptiert.
  - Hinweis: Lokale Entwicklung: `127.0.0.1` oder `::1` je nach Host.

- `WP_LOCAL_SYNC_RATE_LIMIT` (optional)
  - Beschreibung: Maximale Anzahl Requests pro Minute pro Client-IP. Integer.
  - Default: `60` (wenn nicht gesetzt).
  - Beispiel: `WP_LOCAL_SYNC_RATE_LIMIT=120`
  - Hinweis: Implementiert mit WP-Transients (flüchtig, in-memory/DB). Nicht perfekt für verteilte Setups.

- `WP_LOCAL_SYNC_DEBUG` (optional)
  - Beschreibung: Wenn gesetzt (z. B. `1`), werden zusätzliche Fehlermeldungen in `error_log` geschrieben (z. B. fehlende Token, IP-Whitelist-Verletzungen, Rate-Limit-Überschreitungen).
  - Achtung: Aktivieren nur temporär in Entwicklung/Fehlerfällen.

Client-Beispiel (curl)
----------------------

curl-Beispiel, das das erforderliche Authorization-Header mitschickt:

```bash
curl -X POST \
  -H "Authorization: Bearer $WP_LOCAL_SYNC_SECRET" \
  -H "Content-Type: application/json" \
  http://localhost/wp-json/local-sync/v1/sync
```

Sicherheits-Hinweise
--------------------
- Bewahre `WP_LOCAL_SYNC_SECRET` außerhalb des Repos (z. B. `.env`, System-Umgebung, Secrets-Manager). 
- Wenn ein Geheimnis kompromittiert wurde: sofort rotieren (neues Secret setzen, alte ungültig machen). 
- Für Produktions- oder verteilte Setups: erwäge eine robuste Rate-Limit- und Revocation-Lösung (Redis, externe WAF). 

Anmerkung zur Implementierung
-----------------------------
- IP-Whitelist unterstützt Einzel-IPs und einfache CIDR-Notation (IPv4). 
- Rate-Limit nutzt WP-Transients und ist als einfaches Schutzschild gedacht (nicht hochverfügbar über mehrere Hosts hinweg).

Dateien
------
- `local-sync-loader.php` (MU-Plugin-Loader, prüft Header, Whitelist, Rate-Limit)

Wenn du möchtest, erweitere ich die README noch um Beispiel-`.env`-Einträge oder einen Abschnitt für Docker-/CI-Setups.