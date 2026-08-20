# ===========================================================================
#  Cierra SOLO las ventanas de Chrome que estan usando el perfil del torneo.
# ---------------------------------------------------------------------------
#  Por que hace falta: Chrome aplica --autoplay-policy solo al arrancar un
#  proceso NUEVO. Si queda una ventana viva con el mismo perfil, la pestana se
#  abre dentro del proceso viejo y el flag se ignora (la intro sale muda).
#
#  Se filtra por linea de comandos para no tocar el Chrome personal. El perfil
#  del torneo vive en %LocalAppData%\MundialALAS\perfil, asi que cualquier
#  proceso cuya linea de comandos mencione "MundialALAS" es nuestro.
#
#  Nota: no se pierde nada al cerrarlo. La app guarda en localStorage con cada
#  cambio, y el localStorage vive DENTRO de ese perfil (por eso el perfil tiene
#  que ser siempre el mismo y no uno nuevo cada vez).
# ===========================================================================

$procesos = Get-CimInstance Win32_Process -Filter "Name='chrome.exe'" -ErrorAction SilentlyContinue |
            Where-Object { $_.CommandLine -like '*MundialALAS*' }

if (-not $procesos) {
  Write-Host "No hay ventanas del torneo abiertas."
  exit 0
}

Write-Host ("Cerrando {0} proceso(s) de Chrome del perfil del torneo..." -f @($procesos).Count)

# Primero un cierre prolijo, para que Chrome vacie lo que tenga pendiente
foreach ($p in $procesos) {
  try {
    $proc = Get-Process -Id $p.ProcessId -ErrorAction Stop
    $null = $proc.CloseMainWindow()
  } catch {}
}
Start-Sleep -Milliseconds 700

# Lo que haya quedado colgado, se fuerza
Get-CimInstance Win32_Process -Filter "Name='chrome.exe'" -ErrorAction SilentlyContinue |
  Where-Object { $_.CommandLine -like '*MundialALAS*' } |
  ForEach-Object {
    try { Stop-Process -Id $_.ProcessId -Force -ErrorAction Stop } catch {}
  }

Start-Sleep -Milliseconds 500
Write-Host "Listo."
