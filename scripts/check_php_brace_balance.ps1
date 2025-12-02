$file = 'c:\Users\hents\Studio\httpscreateyolide\wp-content\mu-plugins\local-sync-loader.php'
if (-not (Test-Path $file)) { Write-Output "File not found: $file"; exit 2 }
$s = Get-Content -Raw -LiteralPath $file
$lparen = ([regex]::Matches($s,'\(')).Count
$rparen = ([regex]::Matches($s,'\)')).Count
$lbrace = ([regex]::Matches($s,'\{')).Count
$rbrace = ([regex]::Matches($s,'\}')).Count
$single = ([regex]::Matches($s,"'")).Count
$double = ([regex]::Matches($s,'"')).Count
Write-Output "lparen:$lparen rparen:$rparen lbrace:$lbrace rbrace:$rbrace single:$single double:$double"
if ($lparen -ne $rparen) { Write-Output "Mismatch: parentheses count differs"; exit 3 }
if ($lbrace -ne $rbrace) { Write-Output "Mismatch: braces count differs"; exit 4 }
Write-Output "Basic balance check: OK"; exit 0
