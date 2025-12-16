#!/usr/bin/env pwsh
# validate_env_vars.ps1
# Validates that required environment variables for local-sync are properly set
# Usage: pwsh -File scripts/validate_env_vars.ps1

param(
    [switch]$Strict = $false,  # Exit with error if required vars are missing
    [switch]$Verbose = $false  # Show detailed information
)

$ErrorActionPreference = "Continue"

# ANSI color codes for output
$RED = "`e[31m"
$GREEN = "`e[32m"
$YELLOW = "`e[33m"
$BLUE = "`e[34m"
$RESET = "`e[0m"

# Check if running in a terminal that supports colors
if (-not $env:TERM -or $env:TERM -eq "dumb") {
    $RED = $GREEN = $YELLOW = $BLUE = $RESET = ""
}

Write-Host "${BLUE}============================================${RESET}"
Write-Host "${BLUE}Local Sync Environment Variables Validator${RESET}"
Write-Host "${BLUE}============================================${RESET}"
Write-Host ""

$errors = @()
$warnings = @()
$success = @()

# Function to check environment variable
function Test-EnvVar {
    param(
        [string]$VarName,
        [bool]$Required = $true,
        [string]$Description = "",
        [scriptblock]$Validator = $null
    )
    
    $value = [System.Environment]::GetEnvironmentVariable($VarName)
    
    if ([string]::IsNullOrWhiteSpace($value)) {
        if ($Required) {
            $script:errors += "${RED}✗${RESET} $VarName - ${RED}NOT SET${RESET} (REQUIRED)"
            if ($Description) {
                $script:errors += "  ℹ $Description"
            }
        } else {
            $script:warnings += "${YELLOW}⚠${RESET} $VarName - not set (optional)"
            if ($Description) {
                $script:warnings += "  ℹ $Description"
            }
        }
    } else {
        $maskedValue = if ($VarName -match "SECRET|TOKEN|PASSWORD") {
            "****" + $value.Substring([Math]::Max(0, $value.Length - 4))
        } else {
            $value
        }
        
        $validationMsg = ""
        if ($Validator) {
            try {
                $validationResult = & $Validator $value
                if ($validationResult -ne $true) {
                    $validationMsg = " ${YELLOW}(Warning: $validationResult)${RESET}"
                }
            } catch {
                $validationMsg = " ${RED}(Validation error: $_)${RESET}"
            }
        }
        
        $script:success += "${GREEN}✓${RESET} $VarName = $maskedValue$validationMsg"
        if ($Verbose -and $Description) {
            $script:success += "  ℹ $Description"
        }
    }
}

# Validate WP_LOCAL_SYNC_SECRET (REQUIRED)
Test-EnvVar -VarName "WP_LOCAL_SYNC_SECRET" -Required $true `
    -Description "Shared secret for API authentication. Generate with: openssl rand -base64 32" `
    -Validator {
        param($val)
        if ($val.Length -lt 16) {
            return "Token is too short (< 16 chars). Recommend at least 32 characters."
        }
        return $true
    }

# Validate WP_LOCAL_SYNC_WHITELIST (optional)
Test-EnvVar -VarName "WP_LOCAL_SYNC_WHITELIST" -Required $false `
    -Description "Comma-separated IP whitelist. Example: 127.0.0.1,192.168.1.0/24" `
    -Validator {
        param($val)
        $ips = $val -split ',' | ForEach-Object { $_.Trim() }
        foreach ($ip in $ips) {
            if ($ip -match '/') {
                # CIDR notation
                $parts = $ip -split '/'
                if ($parts.Count -ne 2) {
                    return "Invalid CIDR notation: $ip"
                }
                $subnet = $parts[0]
                $mask = $parts[1]
                # Validate IPv4 with octet range 0-255
                if (-not ($subnet -match '^(?:(?:25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.){3}(?:25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)$')) {
                    return "Invalid subnet IP: $subnet"
                }
                if (-not ($mask -match '^\d+$') -or [int]$mask -lt 0 -or [int]$mask -gt 32) {
                    return "Invalid CIDR mask: $mask (must be 0-32)"
                }
            } else {
                # Single IP - validate IPv4 with octet range 0-255 or IPv6 localhost
                if (-not ($ip -match '^(?:(?:25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.){3}(?:25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)$') -and $ip -ne '::1') {
                    return "Invalid IP address: $ip"
                }
            }
        }
        return $true
    }

# Validate WP_LOCAL_SYNC_RATE_LIMIT (optional)
Test-EnvVar -VarName "WP_LOCAL_SYNC_RATE_LIMIT" -Required $false `
    -Description "Max requests per minute per IP. Default: 60" `
    -Validator {
        param($val)
        if (-not ($val -match '^\d+$')) {
            return "Must be a positive integer"
        }
        $num = [int]$val
        if ($num -lt 1) {
            return "Must be at least 1"
        }
        if ($num -gt 10000) {
            return "Value seems very high ($num). Are you sure?"
        }
        return $true
    }

# Validate WP_LOCAL_SYNC_TRUST_PROXY (optional)
Test-EnvVar -VarName "WP_LOCAL_SYNC_TRUST_PROXY" -Required $false `
    -Description "Trust X-Forwarded-For headers. Set to 1 if behind proxy" `
    -Validator {
        param($val)
        if ($val -notin @('0', '1', 'true', 'false', 'yes', 'no')) {
            return "Should be 0, 1, true, false, yes, or no"
        }
        return $true
    }

# Validate WP_LOCAL_SYNC_DEBUG (optional)
Test-EnvVar -VarName "WP_LOCAL_SYNC_DEBUG" -Required $false `
    -Description "Enable debug logging. Set to 1 for development only" `
    -Validator {
        param($val)
        if ($val -eq '1' -or $val -eq 'true') {
            return "Debug mode enabled - only use in development!"
        }
        return $true
    }

# Also check LOCAL_SYNC_SECRET (used by client scripts)
Test-EnvVar -VarName "LOCAL_SYNC_SECRET" -Required $false `
    -Description "Client-side secret (used by scripts). Should match WP_LOCAL_SYNC_SECRET"

# Display results
Write-Host ""
Write-Host "${GREEN}Successfully configured:${RESET}"
if ($success.Count -eq 0) {
    Write-Host "  (none)"
} else {
    foreach ($msg in $success) {
        Write-Host "  $msg"
    }
}

if ($warnings.Count -gt 0) {
    Write-Host ""
    Write-Host "${YELLOW}Warnings:${RESET}"
    foreach ($msg in $warnings) {
        Write-Host "  $msg"
    }
}

if ($errors.Count -gt 0) {
    Write-Host ""
    Write-Host "${RED}Errors:${RESET}"
    foreach ($msg in $errors) {
        Write-Host "  $msg"
    }
}

# Summary
Write-Host ""
Write-Host "${BLUE}============================================${RESET}"
Write-Host "Summary: ${GREEN}$($success.Count) OK${RESET}, ${YELLOW}$($warnings.Count) warnings${RESET}, ${RED}$($errors.Count) errors${RESET}"
Write-Host "${BLUE}============================================${RESET}"

# Additional recommendations
if ($errors.Count -gt 0) {
    Write-Host ""
    Write-Host "${YELLOW}Quick fix:${RESET}"
    Write-Host "1. Copy .env.local.example to .env.local"
    Write-Host "2. Generate a secret: ${BLUE}openssl rand -base64 32${RESET}"
    Write-Host "3. Add it to WP_LOCAL_SYNC_SECRET in .env.local"
    Write-Host "4. Load variables:"
    Write-Host "   ${BLUE}# PowerShell:${RESET}"
    Write-Host "   Get-Content .env.local | ForEach-Object {"
    Write-Host "     if (`$_ -match '^([^=]+)=(.*)$') {"
    Write-Host "       [System.Environment]::SetEnvironmentVariable(`$matches[1], `$matches[2])"
    Write-Host "     }"
    Write-Host "   }"
    Write-Host ""
    Write-Host "   ${BLUE}# Bash/Linux:${RESET}"
    Write-Host "   export `$(grep -v '^#' .env.local | xargs)"
}

# Exit with error if strict mode and errors found
if ($Strict -and $errors.Count -gt 0) {
    Write-Host ""
    Write-Host "${RED}Validation failed in strict mode. Exiting with error.${RESET}"
    exit 1
}

exit 0
