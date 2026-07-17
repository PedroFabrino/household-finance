# clone-all.ps1
# Sets up all household-finance repositories in the current directory.
# Usage: .\clone-all.ps1

$ErrorActionPreference = "Stop"

$repos = @(
    "git@github.com:PedroFabrino/household-finance-api.git",
    "git@github.com:PedroFabrino/household-finance-web.git"
    # Add new repos here as new apps are created
)

Write-Host "`n==> Cloning household-finance sub-repos..." -ForegroundColor Cyan

foreach ($repo in $repos) {
    $name = ($repo -split "/")[-1] -replace "\.git$", ""
    if (Test-Path $name) {
        Write-Host "  [skip] $name already exists" -ForegroundColor Yellow
    } else {
        Write-Host "  [clone] $name" -ForegroundColor Green
        git clone $repo
    }
}

Write-Host "`n==> Done. Directory layout:" -ForegroundColor Cyan
Get-ChildItem -Directory | Select-Object -ExpandProperty Name | ForEach-Object { Write-Host "  $_" }
Write-Host ""
