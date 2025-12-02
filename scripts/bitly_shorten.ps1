<#
PowerShell helper to shorten a URL using Bitly API v4.
Usage:
  $env:BITLY_TOKEN = 'xxxxx'
  .\bitly_shorten.ps1 -LongUrl 'https://example.com/very/long/url'
#>
param(
    [Parameter(Mandatory=$true)][string]$LongUrl,
    [string]$Domain
)

# Read token from environment
$token = $env:BITLY_TOKEN
if (-not $token) {
    Write-Error "Bitte setze die Umgebungsvariable BITLY_TOKEN mit einem gültigen Bitly-Token."
    exit 1
}

# Build request body as hashtable and convert to JSON
$body = @{ long_url = $LongUrl }
if ($PSBoundParameters.ContainsKey('Domain') -and $Domain) { $body.domain = $Domain }
$json = $body | ConvertTo-Json -Depth 5

try {
    $res = Invoke-RestMethod -Uri 'https://api-ssl.bitly.com/v4/shorten' -Method Post -Headers @{ Authorization = "Bearer $token"; 'Content-Type' = 'application/json' } -Body $json -ErrorAction Stop
    # Ausgabe: gesamtes JSON (lesbar) und die kurze URL separat
    $res | ConvertTo-Json -Depth 5
    if ($res.link) { Write-Output "SHORT_URL: $($res.link)" }
    exit 0
} catch {
    Write-Error "Bitly API error: $($_.Exception.Message)"
    # Falls eine Response-Body vorhanden ist, versuche sie auszugeben
    if ($_.Exception.Response -and $_.Exception.Response.GetResponseStream()) {
        try {
            $reader = New-Object System.IO.StreamReader($_.Exception.Response.GetResponseStream())
            $bodyText = $reader.ReadToEnd()
            Write-Output "Response body: $bodyText"
        } catch { }
    }
    exit 2
}
