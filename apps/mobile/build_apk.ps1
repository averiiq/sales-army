# Builds the SalesArmy release APK WITH the Supabase configuration.
#
# A plain `flutter build apk` leaves SUPABASE_ANON_KEY empty (it is read with
# String.fromEnvironment), so the installed app cannot sign in. Always build
# through this script, or pass --dart-define-from-file=dart_defines.json.
#
# Usage (from apps/mobile):
#   .\build_apk.ps1                                   # test activation (no payment server)
#   .\build_apk.ps1 -PlatformUrl https://xxxx.trycloudflare.com   # real Razorpay checkout
#   .\build_apk.ps1 -SplitPerAbi                      # smaller per-phone APKs
#
# -PlatformUrl is the public HTTPS address of apps/web-admin (npm.cmd run live
# prints it). With it, "Buy plan" opens Razorpay; the plan activates only after
# the server confirms payment. The Razorpay SECRET stays on that server.
param(
  [switch]$SplitPerAbi,
  [string]$PlatformUrl = ''
)

$ErrorActionPreference = 'Stop'
Set-Location $PSScriptRoot

if (-not (Test-Path 'dart_defines.json')) {
  throw 'dart_defines.json not found. It must contain SUPABASE_URL and SUPABASE_ANON_KEY.'
}
$defs = Get-Content 'dart_defines.json' -Raw | ConvertFrom-Json
if (-not $defs.SUPABASE_URL -or -not $defs.SUPABASE_ANON_KEY) {
  throw 'dart_defines.json must define SUPABASE_URL and SUPABASE_ANON_KEY.'
}
if ($defs.SUPABASE_SERVICE_ROLE_KEY -or $defs.RAZORPAY_KEY_SECRET) {
  throw 'Remove server secrets (SUPABASE_SERVICE_ROLE_KEY / RAZORPAY_KEY_SECRET) from dart_defines.json - they must never ship inside an app.'
}

$buildArgs = @('build', 'apk', '--release', '--dart-define-from-file=dart_defines.json', '--android-skip-build-dependency-validation')
if ($PlatformUrl) {
  $PlatformUrl = $PlatformUrl.TrimEnd('/')
  if ($PlatformUrl -notmatch '^https://') { throw '-PlatformUrl must start with https://' }
  try {
    $health = Invoke-RestMethod -Uri "$PlatformUrl/api/health" -TimeoutSec 20
    Write-Host "Payment server reachable: $PlatformUrl ($($health.status))" -ForegroundColor Green
  } catch {
    throw "Cannot reach $PlatformUrl/api/health - is 'npm.cmd run live' still running? ($_)"
  }
  $buildArgs += "--dart-define=PLATFORM_API_URL=$PlatformUrl"
} else {
  Write-Host 'No -PlatformUrl given: in-app upgrades use TEST activation (no payment).' -ForegroundColor Yellow
}
if ($SplitPerAbi) { $buildArgs += '--split-per-abi' }

flutter @buildArgs
if ($LASTEXITCODE -ne 0) { throw "flutter build failed ($LASTEXITCODE)" }
Write-Host "`nAPK ready in build\app\outputs\flutter-apk\" -ForegroundColor Green
