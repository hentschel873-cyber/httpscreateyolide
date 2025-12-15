# Quick Reference: Environment Variables Setup

## 🚀 Quick Start (< 2 minutes)

### 1. Generate a Secret
```bash
openssl rand -base64 32
```

### 2. Create Local Environment File
```bash
cp .env.local.example .env.local
```

### 3. Edit `.env.local`
Replace `your_secret_token_here_replace_me` with the generated token.

### 4. Load Variables

**Bash/Linux/macOS**:
```bash
export $(grep -v '^#' .env.local | xargs)
```

**PowerShell**:
```powershell
Get-Content .env.local | ForEach-Object {
  if ($_ -match '^([^=]+)=(.*)$') {
    [System.Environment]::SetEnvironmentVariable($matches[1], $matches[2])
  }
}
```

### 5. Verify Setup
```bash
# Bash
bash scripts/validate_env_vars.sh

# PowerShell
pwsh -File scripts/validate_env_vars.ps1
```

---

## 📋 Required Variables

| Variable | Description | Example |
|----------|-------------|---------|
| `WP_LOCAL_SYNC_SECRET` | API authentication token | `h8fK2mP9xL4v...` |

## 🔧 Optional Variables

| Variable | Description | Default | Example |
|----------|-------------|---------|---------|
| `WP_LOCAL_SYNC_WHITELIST` | IP whitelist (CIDR) | _(none)_ | `127.0.0.1,192.168.1.0/24` |
| `WP_LOCAL_SYNC_RATE_LIMIT` | Requests/min per IP | `60` | `120` |
| `WP_LOCAL_SYNC_TRUST_PROXY` | Trust X-Forwarded-For | `0` | `1` |
| `WP_LOCAL_SYNC_DEBUG` | Enable debug logs | `0` | `1` |

---

## 🔒 GitHub Actions Setup

### Add Secret to Repository

1. Go to: **Settings** → **Secrets and variables** → **Actions**
2. Click **"New repository secret"**
3. Name: `WP_LOCAL_SYNC_SECRET`
4. Value: _(paste generated token)_
5. Click **"Add secret"**

### Use in Workflow

```yaml
jobs:
  test:
    runs-on: ubuntu-latest
    env:
      WP_LOCAL_SYNC_SECRET: ${{ secrets.WP_LOCAL_SYNC_SECRET }}
    steps:
      - name: Run tests
        run: echo "Secret is set"
```

---

## 🧪 Testing

### Test Endpoint
```bash
curl -X POST \
  -H "Authorization: Bearer $WP_LOCAL_SYNC_SECRET" \
  -H "Content-Type: application/json" \
  http://localhost/wp-json/local-sync/v1/sync
```

### Expected: `200 OK` (authenticated)
### Wrong token: `401 Unauthorized`

---

## 📚 Documentation

- **Full Setup Guide**: [ENV_SETUP.md](ENV_SETUP.md)
- **Local Sync README**: [wp-content/mu-plugins/local-sync-README.md](wp-content/mu-plugins/local-sync-README.md)
- **ENV Variables Reference**: [wp-content/mu-plugins/local-sync-env.md](wp-content/mu-plugins/local-sync-env.md)
- **CI Workflow Example**: [.github/workflows/local-sync-ci.yml](.github/workflows/local-sync-ci.yml)

---

## ❓ Troubleshooting

### "WP_LOCAL_SYNC_SECRET is not set"
```bash
# Check if exported
echo $WP_LOCAL_SYNC_SECRET  # Should show token

# If empty, reload
export $(grep -v '^#' .env.local | xargs)
```

### "401 Unauthorized"
- Verify token matches: `echo $WP_LOCAL_SYNC_SECRET`
- Check header format: `Authorization: Bearer <token>`
- Enable debug: `export WP_LOCAL_SYNC_DEBUG=1`

### Validation Fails
```bash
# Run with verbose output
bash scripts/validate_env_vars.sh --verbose

# Or PowerShell
pwsh -File scripts/validate_env_vars.ps1 -Verbose
```

---

## 🔐 Security Reminders

- ✅ Never commit `.env.local` (already in `.gitignore`)
- ✅ Use strong tokens (32+ characters)
- ✅ Rotate secrets every 90 days
- ✅ Use GitHub Secrets for CI/CD
- ❌ Don't share secrets in plain text
- ❌ Don't enable debug in production

---

**Need more help?** See [ENV_SETUP.md](ENV_SETUP.md) for detailed instructions.
