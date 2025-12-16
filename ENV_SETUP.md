# Environment Setup Guide for Local Sync

This guide explains how to configure environment variables for the local-sync security features in both local development and CI/CD environments.

## Table of Contents

- [Required Environment Variables](#required-environment-variables)
- [Optional Environment Variables](#optional-environment-variables)
- [Local Development Setup](#local-development-setup)
- [CI/CD Setup (GitHub Actions)](#cicd-setup-github-actions)
- [Testing Your Configuration](#testing-your-configuration)
- [Security Best Practices](#security-best-practices)
- [Troubleshooting](#troubleshooting)

---

## Required Environment Variables

### `WP_LOCAL_SYNC_SECRET`

**Description**: Shared secret token used for Bearer authentication on the local-sync REST API endpoint.

**Required**: Yes

**How to generate**:
```bash
# Generate a secure 32-character token
openssl rand -base64 32
```

**Example**:
```bash
WP_LOCAL_SYNC_SECRET=h8fK2mP9xL4vN6qR3wT7yU1jC5sA0dF8
```

---

## Optional Environment Variables

### `WP_LOCAL_SYNC_WHITELIST`

**Description**: Comma-separated list of allowed IP addresses or CIDR subnets. Only requests from these IPs will be accepted.

**Required**: No

**Format**: Single IPs or CIDR notation
- Single IP: `127.0.0.1`
- IPv6: `::1`
- CIDR subnet: `192.168.1.0/24`
- Multiple: `127.0.0.1,::1,192.168.1.0/24`

**Example**:
```bash
WP_LOCAL_SYNC_WHITELIST=127.0.0.1,::1
```

### `WP_LOCAL_SYNC_RATE_LIMIT`

**Description**: Maximum number of requests allowed per minute per IP address.

**Required**: No

**Default**: `60` (if not set)

**Example**:
```bash
WP_LOCAL_SYNC_RATE_LIMIT=120
```

### `WP_LOCAL_SYNC_TRUST_PROXY`

**Description**: Trust `X-Forwarded-For` headers when determining client IP. Enable this if running behind a reverse proxy (nginx, Apache, load balancer).

**Required**: No

**Values**: `0` (disabled) or `1` (enabled)

**Default**: `0`

**Example**:
```bash
WP_LOCAL_SYNC_TRUST_PROXY=1
```

### `WP_LOCAL_SYNC_DEBUG`

**Description**: Enable debug logging to `error_log` for troubleshooting authentication and rate-limiting issues.

**Required**: No

**Values**: `0` (disabled) or `1` (enabled)

**Default**: `0`

**⚠️ Warning**: Only enable in development! May expose sensitive information in logs.

**Example**:
```bash
WP_LOCAL_SYNC_DEBUG=1
```

---

## Local Development Setup

### Step 1: Create Local Environment File

```bash
# Copy the example file
cp .env.local.example .env.local
```

### Step 2: Generate a Secure Token

```bash
# Linux/macOS/WSL
openssl rand -base64 32

# PowerShell (if OpenSSL not available)
Add-Type -AssemblyName System.Web
[System.Web.Security.Membership]::GeneratePassword(32, 8)
```

### Step 3: Edit `.env.local`

Open `.env.local` in your editor and set at minimum:

```bash
WP_LOCAL_SYNC_SECRET=your_generated_token_here

# Optional but recommended for local dev:
WP_LOCAL_SYNC_WHITELIST=127.0.0.1,::1
WP_LOCAL_SYNC_DEBUG=1
```

### Step 4: Load Variables into Your Shell

**Bash/Linux/macOS**:
```bash
# Load from .env.local
export $(grep -v '^#' .env.local | xargs)

# Verify
echo $WP_LOCAL_SYNC_SECRET
```

**PowerShell**:
```powershell
# Load from .env.local
Get-Content .env.local | ForEach-Object {
  if ($_ -match '^([^=]+)=(.*)$') {
    [System.Environment]::SetEnvironmentVariable($matches[1], $matches[2])
  }
}

# Verify
$env:WP_LOCAL_SYNC_SECRET
```

**Alternative - Add to Shell Profile** (persists across sessions):

```bash
# Bash: Add to ~/.bashrc or ~/.bash_profile
echo 'export WP_LOCAL_SYNC_SECRET="your_token_here"' >> ~/.bashrc
source ~/.bashrc

# Zsh: Add to ~/.zshrc
echo 'export WP_LOCAL_SYNC_SECRET="your_token_here"' >> ~/.zshrc
source ~/.zshrc
```

### Step 5: Validate Configuration

```bash
# Run the validation script
pwsh -File scripts/validate_env_vars.ps1

# Or with verbose output
pwsh -File scripts/validate_env_vars.ps1 -Verbose

# Or in strict mode (exits with error if validation fails)
pwsh -File scripts/validate_env_vars.ps1 -Strict
```

---

## CI/CD Setup (GitHub Actions)

### Step 1: Add Secrets to GitHub Repository

1. Go to your repository on GitHub
2. Navigate to: **Settings** → **Secrets and variables** → **Actions**
3. Click **"New repository secret"**
4. Add the following secrets:

| Secret Name | Value | Required |
|------------|-------|----------|
| `WP_LOCAL_SYNC_SECRET` | (generated token) | ✅ Yes |
| `WP_LOCAL_SYNC_WHITELIST` | (if needed) | ❌ No |
| `WP_LOCAL_SYNC_RATE_LIMIT` | (if needed) | ❌ No |

**Generating a token for GitHub Secrets**:
```bash
openssl rand -base64 32
```

Copy the output and paste it as the secret value.

### Step 2: Use the Example Workflow

A complete example workflow is provided at `.github/workflows/local-sync-ci.yml`. This workflow:

- ✅ Runs secret scanning
- ✅ Validates PHP syntax
- ✅ Tests environment variable configuration
- ✅ Provides clear error messages if secrets are missing

### Step 3: Reference Secrets in Workflow

```yaml
jobs:
  test:
    runs-on: ubuntu-latest
    env:
      WP_LOCAL_SYNC_SECRET: ${{ secrets.WP_LOCAL_SYNC_SECRET }}
      WP_LOCAL_SYNC_WHITELIST: "127.0.0.1,::1"
    steps:
      - name: Validate environment
        run: |
          if [ -z "$WP_LOCAL_SYNC_SECRET" ]; then
            echo "ERROR: WP_LOCAL_SYNC_SECRET not set!"
            exit 1
          fi
```

### Step 4: Organization-Level Secrets (Optional)

For multiple repositories:

1. Go to **Organization settings** → **Secrets and variables** → **Actions**
2. Create organization secret
3. Select which repositories can access it

---

## Testing Your Configuration

### Test 1: Validate Environment Variables

```bash
# PowerShell
pwsh -File scripts/validate_env_vars.ps1 -Verbose

# Expected output: All required variables shown as ✓ green
```

### Test 2: Check PHP Can Read Variables

```bash
php -r "echo 'WP_LOCAL_SYNC_SECRET: ' . (getenv('WP_LOCAL_SYNC_SECRET') ? 'SET' : 'NOT SET') . PHP_EOL;"
```

### Test 3: Test the Endpoint (Local WordPress)

```bash
# Set the secret
export WP_LOCAL_SYNC_SECRET="your_secret_here"

# Test with correct token (should succeed)
curl -X POST \
  -H "Authorization: Bearer $WP_LOCAL_SYNC_SECRET" \
  -H "Content-Type: application/json" \
  http://localhost/wp-json/local-sync/v1/sync

# Test without token (should fail with 401)
curl -X POST \
  -H "Content-Type: application/json" \
  http://localhost/wp-json/local-sync/v1/sync

# Test with wrong token (should fail with 401)
curl -X POST \
  -H "Authorization: Bearer wrong_token" \
  -H "Content-Type: application/json" \
  http://localhost/wp-json/local-sync/v1/sync
```

---

## Security Best Practices

### 🔐 Secret Management

1. **Never commit secrets to version control**
   - Add `.env.local` to `.gitignore`
   - Use `.env.local.example` for templates only

2. **Use strong, random tokens**
   - Minimum 32 characters
   - Use cryptographically secure random generators
   - Generated with: `openssl rand -base64 32`

3. **Rotate secrets regularly**
   - Recommended: Every 90 days
   - Immediately if compromised or exposed
   - Update in all environments (local, staging, production, CI)

4. **Limit secret exposure**
   - Only share with team members who need access
   - Use environment-specific secrets (dev/staging/prod)
   - Don't include secrets in logs or error messages

### 🛡️ Access Control

1. **Use IP whitelisting** when possible
   ```bash
   WP_LOCAL_SYNC_WHITELIST=10.0.0.0/8,172.16.0.0/12,192.168.0.0/16
   ```

2. **Enable rate limiting** to prevent brute force
   ```bash
   WP_LOCAL_SYNC_RATE_LIMIT=60
   ```

3. **Trust proxies only when necessary**
   ```bash
   # Only enable if behind nginx/Apache/load balancer
   WP_LOCAL_SYNC_TRUST_PROXY=1
   ```

### 🔍 Monitoring & Auditing

1. **Enable debug mode temporarily** for troubleshooting
   ```bash
   WP_LOCAL_SYNC_DEBUG=1
   ```

2. **Monitor logs** for suspicious activity
   - Failed authentication attempts
   - Rate limit violations
   - Unusual IP addresses

3. **Use secret scanning** in CI/CD
   - Run `pwsh -File scripts/scan_secrets.ps1` regularly
   - Review reports in `reports/` directory
   - Rotate any exposed secrets immediately

---

## Troubleshooting

### Issue: "WP_LOCAL_SYNC_SECRET is not set"

**Solution**:
```bash
# Verify the variable is exported
echo $WP_LOCAL_SYNC_SECRET  # Bash
$env:WP_LOCAL_SYNC_SECRET   # PowerShell

# If empty, load from .env.local
export $(grep -v '^#' .env.local | xargs)  # Bash
```

### Issue: "401 Unauthorized" when testing endpoint

**Possible causes**:
1. Secret not set or wrong value
2. Header format incorrect (must be `Authorization: Bearer <token>`)
3. IP not in whitelist (if `WP_LOCAL_SYNC_WHITELIST` is set)

**Solution**:
```bash
# Enable debug mode
export WP_LOCAL_SYNC_DEBUG=1

# Check WordPress error logs
tail -f /path/to/wordpress/wp-content/debug.log

# Verify token matches
echo "Local: $WP_LOCAL_SYNC_SECRET"
# Compare with what's in wp-config.php or server environment
```

### Issue: "Rate limit exceeded"

**Solution**:
```bash
# Increase rate limit
export WP_LOCAL_SYNC_RATE_LIMIT=120

# Or wait 1 minute for the limit to reset
# (Limits are per-minute per-IP using WordPress transients)
```

### Issue: PHP can't read environment variables

**Solution**:
```bash
# Check PHP can access environment
php -r "var_dump(getenv('WP_LOCAL_SYNC_SECRET'));"

# If false, environment variables may not be passed to PHP
# For Apache: Add to .htaccess or vhost config
SetEnv WP_LOCAL_SYNC_SECRET "your_secret_here"

# For nginx with PHP-FPM: Add to pool config
env[WP_LOCAL_SYNC_SECRET] = your_secret_here
```

### Issue: Variables work in shell but not in WordPress

**Solution**:

The web server needs access to environment variables. Options:

**Option 1: Set in `wp-config.php`** (after environment check):
```php
if (!defined('WP_LOCAL_SYNC_SECRET')) {
    define('WP_LOCAL_SYNC_SECRET', getenv('WP_LOCAL_SYNC_SECRET'));
}
```

**Option 2: Use `.env` file with PHP library**:
```bash
composer require vlucas/phpdotenv
```

Then in `wp-config.php`:
```php
$dotenv = Dotenv\Dotenv::createImmutable(__DIR__);
$dotenv->load();
```

**Option 3: Server configuration** (recommended for production):
- Apache: `SetEnv` in vhost
- Nginx: `fastcgi_param` in site config
- Docker: `-e` flag or `docker-compose.yml` environment section

---

## Additional Resources

- [Local Sync Environment Variables Reference](wp-content/mu-plugins/local-sync-env.md)
- [Local Sync README](wp-content/mu-plugins/local-sync-README.md)
- [Example Workflow](.github/workflows/local-sync-ci.yml)
- [Secret Scanner](scripts/scan_secrets.ps1)
- [Validation Script](scripts/validate_env_vars.ps1)

---

## Quick Reference

```bash
# Generate token
openssl rand -base64 32

# Load variables (Bash)
export $(grep -v '^#' .env.local | xargs)

# Load variables (PowerShell)
Get-Content .env.local | ForEach-Object {
  if ($_ -match '^([^=]+)=(.*)$') {
    [System.Environment]::SetEnvironmentVariable($matches[1], $matches[2])
  }
}

# Validate setup
pwsh -File scripts/validate_env_vars.ps1 -Verbose

# Test endpoint
curl -X POST \
  -H "Authorization: Bearer $WP_LOCAL_SYNC_SECRET" \
  http://localhost/wp-json/local-sync/v1/sync
```

---

**Questions or Issues?**

If you encounter problems not covered in this guide, please check the troubleshooting section or open an issue in the repository.
