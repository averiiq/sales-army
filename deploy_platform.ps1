# Deploys the SalesArmy platform API (payments, signup, staff, backups) as the
# Supabase Edge Function "platform". No Render / PC server needed.
#
# First time only:   npx supabase login
# Then (from the sales_army folder):
#   powershell -ExecutionPolicy Bypass -File .\deploy_platform.ps1
#
# Razorpay keys are read from apps\web-admin\.env and stored as Supabase
# secrets (never printed, never put in the app).
# 'Continue': Windows PowerShell 5.1 turns a native tool's stderr status lines
# into terminating errors under 'Stop'. Exit codes are checked explicitly.
$ErrorActionPreference = 'Continue'
Set-Location $PSScriptRoot
$ref = 'ivwvqpeivnltshrxjhjx'

Write-Host '1/3 Syncing API code into the function...' -ForegroundColor Cyan
node apps\web-admin\scripts\sync-edge.mjs
if ($LASTEXITCODE -ne 0) { throw 'sync failed' }

Write-Host '2/3 Setting Razorpay secrets...' -ForegroundColor Cyan
$envFile = 'apps\web-admin\.env'
$vals = @{}
foreach ($line in Get-Content $envFile) {
  if ($line -match '^\s*(RAZORPAY_KEY_ID|RAZORPAY_KEY_SECRET|RAZORPAY_WEBHOOK_SECRET)\s*=\s*(.+?)\s*$') { $vals[$Matches[1]] = $Matches[2] }
}
if (-not $vals.RAZORPAY_KEY_ID -or -not $vals.RAZORPAY_KEY_SECRET) { throw "RAZORPAY_KEY_ID / RAZORPAY_KEY_SECRET missing in $envFile" }
$secretArgs = $vals.GetEnumerator() | ForEach-Object { "$($_.Key)=$($_.Value)" }
$out = npx --yes supabase secrets set --yes --remote=$ref @secretArgs 2>&1 | ForEach-Object { "$_" }
foreach ($v in $vals.Values) { $out = $out -replace [regex]::Escape($v), '***' }
$out | Select-Object -Last 5
if ($LASTEXITCODE -ne 0) { throw 'Setting secrets failed (see above). If it says not logged in, run: npx supabase login' }
Write-Host "   set: $($vals.Keys -join ', ')"

Write-Host '3/3 Deploying function "platform"...' -ForegroundColor Cyan
npx --yes supabase functions deploy platform --yes --no-verify-jwt --remote=$ref --use-api
if ($LASTEXITCODE -ne 0) { throw 'Deploy failed' }

$url = "https://$ref.supabase.co/functions/v1/platform/api/health"
Write-Host "`nChecking $url" -ForegroundColor Cyan
Invoke-RestMethod $url | ConvertTo-Json -Compress
Write-Host "`nDone. Razorpay webhook URL (optional): https://$ref.supabase.co/functions/v1/platform/api/checkout/webhook" -ForegroundColor Green
