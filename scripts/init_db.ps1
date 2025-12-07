# Enable verbose output (similar to set -x)
Set-PSDebug -Trace 1

# Stop on errors (similar to set -eo pipefail)
$ErrorActionPreference = "Stop"

# Check if psql is installed
if (-not (Get-Command psql -ErrorAction SilentlyContinue)) {
    Write-Error "Error: psql is not installed."
    exit 1
}

# Check if sqlx is installed
if (-not (Get-Command sqlx -ErrorAction SilentlyContinue)) {
    Write-Error "Error: sqlx is not installed."
    Write-Error "Use:"
    Write-Error "    cargo install --version='~0.7' sqlx-cli --no-default-features --features rustls,postgres"
    Write-Error "to install it."
    exit 1
}

# Check if custom values have been set, otherwise use defaults
$DB_USER = if ($env:POSTGRES_USER) { $env:POSTGRES_USER } else { "postgres" }
$DB_PASSWORD = if ($env:POSTGRES_PASSWORD) { $env:POSTGRES_PASSWORD } else { "password" }
$DB_NAME = if ($env:POSTGRES_DB) { $env:POSTGRES_DB } else { "newsletter" }
$DB_PORT = if ($env:POSTGRES_PORT) { $env:POSTGRES_PORT } else { "5432" }
$DB_HOST = if ($env:POSTGRES_HOST) { $env:POSTGRES_HOST } else { "localhost" }

# Launch postgres using Docker
docker run `
  -e POSTGRES_USER=$DB_USER `
  -e POSTGRES_PASSWORD=$DB_PASSWORD `
  -e POSTGRES_DB=$DB_NAME `
  -p "${DB_PORT}:5432" `
  -d postgres `
  postgres -N 1000
  # ^ Increased maximum number of connections for testing purposes

# Keep pinging Postgres until it's ready to accept commands
$env:PGPASSWORD = $DB_PASSWORD
do {
    $result = psql -h $DB_HOST -U $DB_USER -p $DB_PORT -d "postgres" -c '\q' 2>&1
    if ($LASTEXITCODE -ne 0) {
        Write-Host "Postgres is still unavailable - sleeping" -ForegroundColor Yellow
        Start-Sleep -Seconds 1
    }
} while ($LASTEXITCODE -ne 0)

Write-Host "Postgres is up and running on port ${DB_PORT}!" -ForegroundColor Green

# Set DATABASE_URL and run sqlx
$env:DATABASE_URL = "postgres://${DB_USER}:${DB_PASSWORD}@${DB_HOST}:${DB_PORT}/${DB_NAME}"
sqlx database create
sqlx migrate run

Write-Host "Postgres has been migrated, ready to go!" -ForegroundColor Green
