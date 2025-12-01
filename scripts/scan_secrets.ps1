# Scan repository working tree and commit history for common secret names
$terms = @('DB_PASSWORD','AUTH_KEY','WP_','LOCAL_SYNC_SECRET','OPENAI_API_KEY')
Set-Location -Path (Resolve-Path "$PSScriptRoot\..")
Write-Host "Repository root: $(Get-Location)"
foreach ($t in $terms) {
    Write-Host "\n--- $t (working tree) ---"
    git grep -n --heading --line-number -- $t 2>$null
    if ($LASTEXITCODE -ne 0) { Write-Host '(no matches in working tree)' }

    Write-Host "--- $t (commit history -S search) ---"
    git log --all -S $t --pretty=format:"%h %ad %an %s" --date=short 2>$null
    if ($LASTEXITCODE -ne 0) { Write-Host '(no commits found)' }
}
Write-Host "\nScan complete."