<#
Create a public Gist (requires GitHub CLI `gh`) from a local file and shorten the resulting Gist URL with Bitly.
Usage:
  # Requires: gh authenticated OR GITHUB_TOKEN available to gh
  .\bitly_gist_and_shorten.ps1 -FilePath 'wp-content/mu-plugins/local-sync-loader.php' -Description 'local-sync-loader' -Public
#>
param(
    [Parameter(Mandatory=$true)][string]$FilePath,
    [string]$Description = "created via bitly_gist_and_shorten.ps1",
    [switch]$Public
)

if (-not (Test-Path $FilePath)) { Write-Error "File not found: $FilePath"; exit 1 }

# Check for gh
if (-not (Get-Command gh -ErrorAction SilentlyContinue)) {
    Write-Error "GitHub CLI 'gh' not found. Install and authenticate with 'gh auth login', or create a gist manually."
    exit 2
}

# Create the gist
$pubFlag = $null
if ($Public) { $pubFlag = "--public" }
try {
    $out = gh gist create $FilePath --desc $Description $pubFlag --web --json url -q
    # gh with --json url should emit JSON with url property; try to parse
    $json = $out | ConvertFrom-Json -ErrorAction SilentlyContinue
    if ($json -and $json.url) { $gistUrl = $json.url } else { $gistUrl = $out.Trim() }
    Write-Output "Gist created: $gistUrl"
} catch {
    Write-Error "Failed to create gist: $($_.Exception.Message)"
    exit 3
}

# Shorten with local helper
$script = Join-Path (Split-Path -Parent $MyInvocation.MyCommand.Path) 'bitly_shorten.ps1'
if (-not (Test-Path $script)) {
    Write-Error "bitly_shorten.ps1 not found in scripts directory."
    exit 4
}

# Call the helper
& $script -LongUrl $gistUrl
