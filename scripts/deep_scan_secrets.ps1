# Deep secret scan: regex searches in working tree and commit history
$patterns = @(
    @{ name = 'OpenAI sk keys'; regex = 'sk-[A-Za-z0-9_-]{20,}' },
    @{ name = 'AWS Access Key (AKIA)'; regex = 'AKIA[0-9A-Z]{16}' },
    @{ name = 'Private key PEM header'; regex = '-----BEGIN (RSA )?PRIVATE KEY-----' },
    @{ name = 'Long base64-like strings (40+)'; regex = '[A-Za-z0-9+/]{40,}={0,2}' },
    @{ name = 'Generic API key patterns (api_key, api-key, apikey)'; regex = '(?:api[_-]?key|apikey)["'']?\s*[:=]\s*["'']?[A-Za-z0-9\-_.]{8,}' },
    @{ name = 'DB_PASSWORD literal'; regex = 'DB_PASSWORD' },
    @{ name = 'WP SALTS / AUTH_KEY-like'; regex = 'AUTH_KEY|SECURE_AUTH_KEY|LOGGED_IN_KEY|NONCE_KEY|AUTH_SALT' }
)

$repoRoot = (Resolve-Path "$PSScriptRoot\..").Path
Set-Location $repoRoot
$report = Join-Path $PSScriptRoot 'deep_secret_scan_report.txt'
"Deep secret scan report - $(Get-Date -Format o)" | Out-File -FilePath $report -Encoding utf8

foreach ($p in $patterns) {
    "\n=== Pattern: $($p.name) ===" | Tee-Object -FilePath $report -Append
    "Regex: $($p.regex)" | Tee-Object -FilePath $report -Append

    # grep in working tree (ignore binary)
    Write-Host "Searching working tree for: $($p.name)"
    git grep -n --heading --line-number -E "$($p.regex)" 2>$null | Tee-Object -FilePath $report -Append
    if ($LASTEXITCODE -ne 0) { '(no matches in working tree)' | Tee-Object -FilePath $report -Append }

    # search commit history
    Write-Host "Searching commit history for: $($p.name)"
    git log --all -G "$($p.regex)" --pretty=format:'%h %ad %an %s' --date=short 2>$null | Tee-Object -FilePath $report -Append
    if ($LASTEXITCODE -ne 0) { '(no commits found)' | Tee-Object -FilePath $report -Append }
}

"\nScan complete." | Tee-Object -FilePath $report -Append
Write-Host "Report written to: $report"; Get-Content $report -Raw | Write-Host
