<#
Interactive helper to set BITLY_TOKEN securely for the session and optionally persist for the user.

Usage:
  # Run in PowerShell (pwsh)
  .\set_bitly_token.ps1

This script will:
- Prompt you for the token (SecureString).
- Set `$env:BITLY_TOKEN` for the current session.
- Offer to persist it for the current Windows user using `setx` (persists after new shells).

Security notes:
- The token will be converted to plain text only to set environment variables.
- Do NOT commit tokens. If you persist, they live in your user environment variables.
#>

Write-Host "Setze BITLY_TOKEN (Eingabe wird versteckt)" -ForegroundColor Cyan
$secure = Read-Host -AsSecureString "BITLY_TOKEN eingeben"
if (-not $secure) {
    Write-Error "Keine Eingabe erhalten. Abbruch."
    exit 1
}

# Convert SecureString to plain text (for setting env var). This lives only in process memory briefly.
$ptr = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($secure)
try {
    $plain = [System.Runtime.InteropServices.Marshal]::PtrToStringBSTR($ptr)
} finally {
    [System.Runtime.InteropServices.Marshal]::ZeroFreeBSTR($ptr)
}

if (-not $plain) { Write-Error "Konnte Token nicht lesen."; exit 2 }

# Set for current session
$env:BITLY_TOKEN = $plain
Write-Host "BITLY_TOKEN gesetzt für diese PowerShell-Session." -ForegroundColor Green

# Ask whether to persist for the user account
$choice = Read-Host "Persistieren (dauerhaft für diesen Benutzer)? (y/N)"
if ($choice -and $choice.ToLower().StartsWith('y')) {
    try {
        # setx stores as user environment variable; available in new shells
        setx BITLY_TOKEN "$plain" | Out-Null
        Write-Host "BITLY_TOKEN wurde per setx als Nutzer-Variable gesetzt. Neu öffnen der Shell erforderlich." -ForegroundColor Yellow
    } catch {
        Write-Error "Fehler beim Setzen mit setx: $($_.Exception.Message)"
    }
}

Write-Host "Führe jetzt einen Test aus, z.B. .\scripts\bitly_shorten.ps1 -LongUrl 'https://example.com'" -ForegroundColor Cyan

# Zero plain variable
[System.GC]::Collect(); [System.GC]::WaitForPendingFinalizers();
$plain = $null

exit 0
