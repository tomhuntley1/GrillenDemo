# =============================================================================
# reset-demo.ps1 — Full demo reset in ~2 minutes
#
# Usage:  .\scripts\reset-demo.ps1   (run from demo_v2 root)
#
# BEFORE RUNNING:
#   1. Fill in your SQL server name and password in the CONFIGURE section below
#   2. Make sure PostgreSQL is running on this WorkSpace:
#      Get-Service -Name "postgresql*"
# =============================================================================

# ── CONFIGURE THESE ───────────────────────────────────────────────────────────

# From your terraform output
$SQL_SERVER   = "sql-northroute-XXXXXX.database.windows.net"
$SQL_DB       = "northroute-demo"
$SQL_USER     = "northroute_admin"
$SQL_PASSWORD = "YourPasswordHere123!"

# PostgreSQL on this WorkSpace
$PG_BIN       = "C:\Program Files\PostgreSQL\15\bin"   # update version if needed
$PG_USER      = "demo_user"
$PG_PASSWORD  = "Demo1234!"

$SCRIPT_ROOT  = "$PSScriptRoot\..\sql"

# ── Helpers ───────────────────────────────────────────────────────────────────
function Write-Step { param($msg) Write-Host "`n▶ $msg" -ForegroundColor Cyan }
function Write-OK   { param($msg) Write-Host "  ✓ $msg" -ForegroundColor Green }
function Write-Fail { param($msg) Write-Host "  ✗ $msg" -ForegroundColor Red; exit 1 }
function Write-Info { param($msg) Write-Host "  · $msg" -ForegroundColor Gray }

function Invoke-SqlScript {
    param([string]$Path, [string]$Label)
    Write-Info "Running: $Label"
    sqlcmd -S $SQL_SERVER -d $SQL_DB -U $SQL_USER -P $SQL_PASSWORD -i $Path -b 2>&1
    if ($LASTEXITCODE -ne 0) { Write-Fail "Failed: $Label" }
    Write-OK $Label
}

# =============================================================================
Write-Host ""
Write-Host "╔══════════════════════════════════════════╗" -ForegroundColor Yellow
Write-Host "║   NorthRoute Demo — Full Reset           ║" -ForegroundColor Yellow
Write-Host "╚══════════════════════════════════════════╝" -ForegroundColor Yellow

# ── 1. Check Postgres is running ──────────────────────────────────────────────
Write-Step "Checking PostgreSQL service"
$svc = Get-Service -Name "postgresql*" -ErrorAction SilentlyContinue
if (-not $svc) { Write-Fail "PostgreSQL service not found. Is it installed? See sql/source/POSTGRES_SETUP_WORKSPACE.md" }
if ($svc.Status -ne "Running") {
    Write-Info "Service stopped — starting it..."
    Start-Service $svc.Name
    Start-Sleep -Seconds 3
}
Write-OK "PostgreSQL is running ($($svc.Name))"

# ── 2. Drop and recreate the source database ──────────────────────────────────
Write-Step "Resetting source database (PostgreSQL)"

Write-Info "Dropping northroute_erp..."
$env:PGPASSWORD = $PG_PASSWORD
& "$PG_BIN\psql.exe" -U $PG_USER -d postgres -c "DROP DATABASE IF EXISTS northroute_erp;" 2>&1

Write-Info "Recreating from setup script..."
& "$PG_BIN\psql.exe" -U $PG_USER -d postgres -f "$SCRIPT_ROOT\source\01_postgres_setup.sql" 2>&1
if ($LASTEXITCODE -ne 0) { Write-Fail "Postgres setup failed" }

$rows = & "$PG_BIN\psql.exe" -U $PG_USER -d northroute_erp -tAc "SELECT COUNT(*) FROM erp.delivery_orders;" 2>&1
Write-OK "Source data: $($rows.Trim()) delivery orders loaded"

# ── 3. Wipe Azure SQL ─────────────────────────────────────────────────────────
Write-Step "Tearing down Azure SQL"
Invoke-SqlScript "$SCRIPT_ROOT\teardown\06_teardown_azuresql.sql" "Teardown"

# ── 4. Rebuild Azure SQL ──────────────────────────────────────────────────────
Write-Step "Rebuilding Azure SQL"
Invoke-SqlScript "$SCRIPT_ROOT\sink\02_azuresql_setup.sql" "Schema + table setup"
Invoke-SqlScript "$SCRIPT_ROOT\sink\03_sp_brz_to_slv.sql" "usp_brz_to_slv"
Invoke-SqlScript "$SCRIPT_ROOT\sink\04_sp_slv_to_gld.sql" "usp_slv_to_gld"

# ── 5. Verify clean state ─────────────────────────────────────────────────────
Write-Step "Verifying clean state"
sqlcmd -S $SQL_SERVER -d $SQL_DB -U $SQL_USER -P $SQL_PASSWORD -Q `
    "SELECT 'brz.delivery_orders' AS tbl, COUNT(*) AS rows FROM brz.delivery_orders
     UNION ALL SELECT 'slv.delivery_orders', COUNT(*) FROM slv.delivery_orders
     UNION ALL SELECT 'gld.fact_delivery',   COUNT(*) FROM gld.fact_delivery
     UNION ALL SELECT 'pipeline_log',        COUNT(*) FROM dbo.pipeline_log;" -b

# ── Done ──────────────────────────────────────────────────────────────────────
Write-Host ""
Write-Host "╔══════════════════════════════════════════╗" -ForegroundColor Green
Write-Host "║   ✓  Reset complete. Ready to go.        ║" -ForegroundColor Green
Write-Host "╚══════════════════════════════════════════╝" -ForegroundColor Green
Write-Host ""
Write-Host "  Postgres:   73 messy rows loaded and waiting" -ForegroundColor White
Write-Host "  Azure SQL:  Clean schemas, tables, stored procs" -ForegroundColor White
Write-Host "  Next step:  Trigger the ADF pipeline in ADF Studio" -ForegroundColor White
Write-Host ""
