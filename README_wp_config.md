# WP config security notes

This project uses an environment-variable-based `wp-config.php` to avoid
committing database credentials or authentication salts into source control.

Quick steps

- Generate salts and an `.env.example` with the helper script:
  ```powershell
  pwsh ./scripts/generate_wp_secrets.ps1 -OutEnvPath ./.env.example
  ```

- Store sensitive values in your host (e.g., hosting panel, GitHub Actions secrets)
  using the variable names shown in `.env.example` (prefix `WP_`).

- To remove an accidentally committed `wp-config.php` from git history, first
  rotate/replace secrets, then remove the file from the index and commit:
  ```powershell
  git rm --cached wp-config.php
  git commit -m "Remove tracked wp-config.php; use env-based config"
  git push
  ```

- If you must erase the secret from history, use `git filter-repo` or `bfg` —
  this rewrites history and requires coordination with collaborators.

Security recommendations

- Do not commit real passwords or salts. Use the `.env.example` as a template.
- Rotate secrets immediately if they were exposed.
- In production, set `WP_DEBUG` to `false` and ensure debug logs are not world-readable.
