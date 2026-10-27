# OctagonOS - Asistente de compilacion local para Windows
# Este script prepara tu entorno Windows con WSL para compilar la ISO en tu propio equipo

Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host "   OctagonOS 1.0 - Compilador Local para Windows          " -ForegroundColor White
Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host ""

$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

if (-not $isAdmin) {
    Write-Host "[!] Solicitando permisos de Administrador para instalar WSL..." -ForegroundColor Yellow
    Start-Process powershell.exe -ArgumentList "-NoExit -ExecutionPolicy Bypass -File `"$PSCommandPath`"" -Verb RunAs
    exit
}

Write-Host "[1/3] Instalando el Subsistema de Windows para Linux (Debian)..." -ForegroundColor Green
wsl --install -d Debian

Write-Host ""
Write-Host "[2/3] Si es la primera vez que instalas WSL, reinicia tu PC cuando termine la instalacion." -ForegroundColor Yellow
Write-Host "[3/3] Despues del reinicio, abre Debian desde el menu Inicio y ejecuta:" -ForegroundColor Cyan
Write-Host "      cd /mnt/c/Users/sergi/.gemini/antigravity/scratch/OctagonOS" -ForegroundColor White
Write-Host "      sudo ./build.sh" -ForegroundColor White
Write-Host ""
Write-Host "La ISO 'OctagonOS-1.0-amd64.iso' se guardara directamente en tu carpeta." -ForegroundColor Green
Write-Host "==========================================================" -ForegroundColor Cyan
Read-Host "Presiona Enter para cerrar esta ventana..."
