# =============================================================================
# NorthRoute Demo — PostgreSQL Setup on AWS WorkSpace
# =============================================================================
# One-time setup. After this, Postgres runs as a Windows service automatically.
# No Docker. No containers. Just a plain database server.
# =============================================================================

# =============================================================================
# STEP 1 — Download and install PostgreSQL
# =============================================================================
# 1. Go to: https://www.postgresql.org/download/windows/
# 2. Click "Download the installer" (EDB installer)
# 3. Choose the latest PostgreSQL 15 or 16 — click Download
# 4. Run the installer:
#      - Installation directory: leave as default
#      - Components: tick PostgreSQL Server + Command Line Tools (pgAdmin optional)
#      - Data directory: leave as default
#      - Password: set a superuser password — note it down, you'll need it once
#      - Port: 5432 (leave as default)
#      - Locale: leave as default
#      - Click through to finish
#
# PostgreSQL is now installed as a Windows service called "postgresql-x64-15"
# (or similar). It starts automatically when the WorkSpace starts.

# =============================================================================
# STEP 2 — Verify it's running
# =============================================================================
# Open PowerShell and run:
#
#   Get-Service -Name "postgresql*"
#
# You should see Status: Running
#
# If it's stopped:
#   Start-Service -Name "postgresql-x64-15"

# =============================================================================
# STEP 3 — Create the demo user
# =============================================================================
# Open PowerShell and run:
#
#   cd "C:\Program Files\PostgreSQL\15\bin"
#   .\psql.exe -U postgres
#
# Enter the superuser password you set during install.
# You're now in the psql prompt. Run these two commands:
#
#   CREATE USER demo_user WITH PASSWORD 'Demo1234!';
#   ALTER USER demo_user CREATEDB;
#   \q
#
# That creates the demo_user account that the setup script and ADF will use.

# =============================================================================
# STEP 4 — Run the source database setup script
# =============================================================================
# Still in PowerShell, from the sql/source folder:
#
#   cd C:\path\to\demo_v2\sql\source
#   "C:\Program Files\PostgreSQL\15\bin\psql.exe" -U demo_user -f 01_postgres_setup.sql
#
# Enter password: Demo1234!
#
# This creates the northroute_erp database and loads all 73 rows of source data.
#
# Verify:
#   "C:\Program Files\PostgreSQL\15\bin\psql.exe" -U demo_user -d northroute_erp -c "SELECT COUNT(*) FROM erp.delivery_orders;"
#
# Expected: 73

# =============================================================================
# STEP 5 — Allow ADF to connect (pg_hba.conf)
# =============================================================================
# By default Postgres only accepts local connections.
# ADF (running in Azure) needs to reach it over the network.
#
# Find pg_hba.conf — usually at:
#   C:\Program Files\PostgreSQL\15\data\pg_hba.conf
#
# Open it in Notepad (run Notepad as Administrator).
# At the bottom of the file, add this line:
#
#   host    all    all    0.0.0.0/0    md5
#
# Save and close.
#
# Then find postgresql.conf in the same folder.
# Find the line:  #listen_addresses = 'localhost'
# Change it to:   listen_addresses = '*'
# (Remove the # at the start)
#
# Save and close.
#
# Restart the Postgres service to apply:
#   Restart-Service -Name "postgresql-x64-15"

# =============================================================================
# STEP 6 — Note your WorkSpace IP for ADF
# =============================================================================
# ADF needs your WorkSpace's IP address to connect.
# In PowerShell:
#
#   (Invoke-WebRequest -Uri "https://api.ipify.org").Content
#
# This gives your public IP. Use this in the ADF PostgreSQL linked service.
#
# Note: AWS WorkSpaces can have a static or dynamic IP depending on your setup.
# If yours changes, you'll need to update the linked service each time.
# Check with your AWS admin whether you have a persistent IP bundle.

# =============================================================================
# CONNECTION DETAILS (for ADF Linked Service)
# =============================================================================
#   Host:     [your WorkSpace IP from Step 6]
#   Port:     5432
#   Database: northroute_erp
#   Username: demo_user
#   Password: Demo1234!
#   SSL mode: Disable
