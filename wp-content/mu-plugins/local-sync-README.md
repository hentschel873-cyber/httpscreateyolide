local-sync MU-Plugin — Hinweise

Kurz (Deutsch):
- Dieses MU-Plugin lädt lokal das `local-sync`-Plugin und schützt die Sync-REST-Route mittels eines `Bearer`-Tokens.
- Konfiguration:
  - `WP_LOCAL_SYNC_SECRET` sollte als Umgebungsvariable gesetzt werden (oder als PHP-Konstante `WP_LOCAL_SYNC_SECRET`).
  - Optional: `WP_LOCAL_SYNC_DEBUG=true` (nur lokal aktivieren) erzeugt bei fehlgeschlagener Authentifizierung einen `error_log`-Eintrag mit Route und Quell-IP.

Empfehlungen:
- Secrets niemals in die Git-History committen. Falls das Secret zuvor committed wurde: rotiere das Secret (tausche es aus) und entferne es aus der Repo-History.
- Aktiviere `WP_LOCAL_SYNC_DEBUG` nur in Entwicklungsumgebungen.

How it works (English):
- The loader includes `plugins/local-sync/local-sync.php` when present.
- The `rest_pre_dispatch` filter validates requests to `/local-sync/v1/sync` (and sub-paths) by checking `Authorization: Bearer <token>` against `WP_LOCAL_SYNC_SECRET`.
- Use `WP_LOCAL_SYNC_DEBUG` to get a simple error_log line on auth failures for debugging.

Example `.env` entries (local development):
WP_LOCAL_SYNC_SECRET=your_local_secret_here
WP_LOCAL_SYNC_DEBUG=true

If you want, I can add a short CLI snippet to rotate secrets or scan git history for occurrences of `WP_LOCAL_SYNC_SECRET`.
