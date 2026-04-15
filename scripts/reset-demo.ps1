# reset-demo.ps1 - Wipes and rebuilds Azure SQL ready for demo
# Usage: .\scripts\reset-demo.ps1

$SQL_SERVER  = "sql-northroute-47xop2.database.windows.net"
$SQL_DB      = "northroute-demo"
$SQL_USER    = "northroute_admin"
$SCRIPT_ROOT = "D:\Projects\Grilllen\demo_v2\sql"

$SQL_PASSWORD = Read-Host "Enter Azure SQL password"

function Write-Step { param($msg) Write-Host "`n>> $msg" -ForegroundColor Cyan }
function Write-OK   { param($msg) Write-Host "   OK: $msg" -ForegroundColor Green }
function Write-Fail { param($msg) Write-Host "   FAILED: $msg" -ForegroundColor Red; exit 1 }
function Write-Info { param($msg) Write-Host "   $msg" -ForegroundColor Gray }

function Invoke-SqlScript {
    param([string]$Path, [string]$Label)
    Write-Info "Running: $Label"
    sqlcmd -S $SQL_SERVER -d $SQL_DB -U $SQL_USER -P $SQL_PASSWORD -i $Path -I -b 2>&1
    if ($LASTEXITCODE -ne 0) { Write-Fail "Failed: $Label" }
    Write-OK $Label
}

Write-Host "============================================" -ForegroundColor Yellow
Write-Host "   NorthRoute Demo - Full Reset            " -ForegroundColor Yellow
Write-Host "============================================" -ForegroundColor Yellow

Write-Step "Tearing down Azure SQL"
Invoke-SqlScript "$SCRIPT_ROOT\teardown\06_teardown_azuresql.sql" "Teardown"

Write-Step "Rebuilding Azure SQL"
Invoke-SqlScript "$SCRIPT_ROOT\sink\02_azuresql_setup.sql" "Schema and table setup"
Invoke-SqlScript "$SCRIPT_ROOT\sink\03_sp_brz_to_slv.sql" "usp_brz_to_slv"
Invoke-SqlScript "$SCRIPT_ROOT\sink\04_sp_slv_to_gld.sql" "usp_slv_to_gld"

Write-Step "Verifying clean state"
sqlcmd -S $SQL_SERVER -d $SQL_DB -U $SQL_USER -P $SQL_PASSWORD -Q "SELECT 'brz.delivery_orders' AS tbl, COUNT(*) AS rows FROM brz.delivery_orders UNION ALL SELECT 'slv.delivery_orders', COUNT(*) FROM slv.delivery_orders UNION ALL SELECT 'gld.fact_delivery', COUNT(*) FROM gld.fact_delivery UNION ALL SELECT 'pipeline_log', COUNT(*) FROM dbo.pipeline_log;" -b

Write-Host ""
Write-Host "============================================" -ForegroundColor Green
Write-Host "   Reset complete. Ready to go.           " -ForegroundColor Green
Write-Host "============================================" -ForegroundColor Green
Write-Host "   Postgres: 73 rows untouched" -ForegroundColor White
Write-Host "   Azure SQL: Clean - trigger ADF pipeline" -ForegroundColor White
