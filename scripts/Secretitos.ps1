<#
  La Promesa ERP - Configuración de secretos locales (user-secrets)
  ------------------------------------------------------------------
  Guarda la cadena de conexión, la clave JWT, la clave de la API bancaria
  y la contraseña de los usuarios demo FUERA del repositorio
  (en %APPDATA%\Microsoft\UserSecrets). Nada de esto se sube a GitHub.

  Uso (PowerShell, desde la carpeta del proyecto):
     powershell -ExecutionPolicy Bypass -File .\scripts\configurar-secretos.ps1
#>
$ErrorActionPreference = "Stop"
$raiz  = Split-Path -Parent $PSScriptRoot
$api   = Join-Path $raiz "backend\LaPromesa\LaPromesa.API"
$banco = Join-Path $raiz "backend\LaPromesa\BancoSimulado.API"

function Leer-Secreto($mensaje) {
    $seguro = Read-Host $mensaje -AsSecureString
    $ptr = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($seguro)
    try { [Runtime.InteropServices.Marshal]::PtrToStringBSTR($ptr) }
    finally { [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($ptr) }
}
function Clave-Aleatoria([int]$bytes) {
    $b = New-Object byte[] $bytes
    [Security.Cryptography.RandomNumberGenerator]::Create().GetBytes($b)
    [Convert]::ToBase64String($b)
}

Write-Host "=== La Promesa ERP: configuración de secretos ===" -ForegroundColor Cyan
$servidor = Read-Host "Servidor SQL [localhost,1435]"
if ([string]::IsNullOrWhiteSpace($servidor)) { $servidor = "localhost,1435" }
$usuarioSql = Read-Host "Usuario SQL [sa]"
if ([string]::IsNullOrWhiteSpace($usuarioSql)) { $usuarioSql = "sa" }
$claveSql  = Leer-Secreto "Contraseña de SQL Server"
$claveDemo = Leer-Secreto "Contraseña para los usuarios demo (mínimo 8 caracteres)"
if ($claveDemo.Length -lt 8) { throw "La contraseña demo debe tener al menos 8 caracteres." }

$conexion = "Server=$servidor;Database=LaPromesaERP;User Id=$usuarioSql;Password=$claveSql;TrustServerCertificate=True;Encrypt=True;Application Name=LaPromesaERP.API"
$jwtKey   = Clave-Aleatoria 48
$bancoKey = Clave-Aleatoria 32

Push-Location $api
dotnet user-secrets set "ConnectionStrings:ConexionSQL" "$conexion" | Out-Null
dotnet user-secrets set "Jwt:Key" "$jwtKey" | Out-Null
dotnet user-secrets set "Banco:ApiKey" "$bancoKey" | Out-Null
dotnet user-secrets set "Seed:PasswordDemo" "$claveDemo" | Out-Null
Pop-Location

Push-Location $banco
dotnet user-secrets set "Banco:ApiKey" "$bancoKey" | Out-Null
Pop-Location

Write-Host "Listo. Secretos guardados para LaPromesa.API y BancoSimulado.API." -ForegroundColor Green
Write-Host "Usuarios demo: admin, sara.compras, gerente.general, bodega.central, tesoreria, consulta" -ForegroundColor Green
