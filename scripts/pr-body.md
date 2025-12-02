Kurzbeschreibung

Härtung des lokalen `local-sync` REST-Endpunkts und Hinzufügen von Entwickler-Tools zum Auffinden von Geheimnissen.

Änderungen

- `wp-content/mu-plugins/local-sync-loader.php`
  - Secrets über Umgebungsvariablen (`WP_LOCAL_SYNC_SECRET` etc.) lesbar machen
  - Bearer-Authentifizierung mit timing-safe Vergleich (`hash_equals`)
  - Optional: CIDR-Whitelist (`WP_LOCAL_SYNC_WHITELIST`)
  - Pro-IP transient-basiertes Rate-Limiting (`WP_LOCAL_SYNC_RATE_LIMIT`)
  - Optional: Trusted-Proxy-Verhalten (`WP_LOCAL_SYNC_TRUST_PROXY`)
  - Debug-gated `error_log`-Ausgaben (`WP_LOCAL_SYNC_DEBUG`)

- `scripts/`
  - PowerShell/Bash Hilfs-Skripte: Bitly-Helfer, Gist+Shorten, interaktiver Token-Setter
  - Secret-scan helper und CI-Beispiel

Wichtige Hinweise

- `reports/` enthält Scan-Artefakte und wurde nicht committet. Bitte triagiere diese lokal (z. B. `reports/extracted_db_password.log`) und rotiere ggf. echte Schlüssel sofort.
- `php -l wp-content/mu-plugins/local-sync-loader.php` wurde hier per Docker geprüft — keine Syntaxfehler.

Checklist

- [ ] `WP_LOCAL_SYNC_SECRET` und andere ENV-Variablen in lokalen/CI-Umgebungen setzen
- [ ] Scan-Reports triagieren; ggf. Secrets rotieren
- [ ] Optional: CI-Job hinzufügen, der Scanner für PRs ausführt

Details / How to test

1. Lokales Linting:
   ```powershell
   php -l "wp-content\mu-plugins\local-sync-loader.php"
   ```
2. Manuelles Testen des Endpunkts (Local):
   - Setze `WP_LOCAL_SYNC_SECRET` in deiner Shell
   - Rufe den Endpunkt mit `Authorization: Bearer <secret>` auf

Wenn du möchtest, kann ich nach dem Push noch einen CI-Workflow hinzufügen, der den Secret-Scan automatisch ausführt und PRs mit kritischen Funden markiert.
