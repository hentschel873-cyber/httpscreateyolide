<#
generate_wp_secrets.ps1

Fetch WordPress salts from the official API and print example environment
variable assignments and a `.env` snippet. Run locally and copy the output
into your host/CI secret store.

Usage:
  pwsh ./scripts/generate_wp_secrets.ps1
#>

param(
    [string]$OutEnvPath = "./.env.example"
)

try {
    Write-Host "Fetching salts from WordPress.org..."
    $saltText = Invoke-RestMethod -Uri 'https://api.wordpress.org/secret-key/1.1/salt/' -Method Get -ErrorAction Stop

    # The API returns PHP define() lines. We'll extract the values.
    $re = "define\(\s*'([^']+)'\s*,\s*'([^']*)'\s*\);"
    $envLines = @()
    foreach ($m in ($saltText -split "`n")) {
        if ($m -match $re) {
            $key = $matches[1]
            $val = $matches[2]
            # Map WP constant name to env var name
            $envName = 'WP_' + ($key -replace "[^A-Za-z0-9_]", '_')
            $envLines += "$envName=`"$val`""
        }
    }

    # Add placeholders for DB vars
    $envLines += "WP_DB_NAME=your_db_name"
    $envLines += "WP_DB_USER=your_db_user"
    $envLines += "WP_DB_PASSWORD=your_db_password"
    $envLines += "WP_DB_HOST=localhost"

    # Write example .env file
    $envContent = $envLines -join "`n"
    Set-Content -Path $OutEnvPath -Value $envContent -Encoding UTF8 -Force
    Write-Host "Wrote example env file to: $OutEnvPath"
    Write-Host "Copy values into your host/CI secret store or a local .env (do not commit secrets)."
    exit 0
} catch {
    Write-Error "Failed to fetch or write salts: $($_.Exception.Message)"
    exit 2
}
