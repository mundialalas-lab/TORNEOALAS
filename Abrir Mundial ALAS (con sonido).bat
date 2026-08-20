@echo off
REM ===========================================================================
REM  MUNDIAL ALAS 2026 - lanzador con sonido
REM ---------------------------------------------------------------------------
REM  Chrome no deja que un video arranque CON SONIDO si el usuario todavia no
REM  interactuo con la pagina. Es una politica del navegador y NO se puede
REM  desactivar desde el codigo de la pagina: hay que lanzar Chrome con el flag
REM  --autoplay-policy=no-user-gesture-required.
REM
REM  EL DETALLE QUE HACIA FALLAR TODO:
REM  Chrome aplica ese flag SOLO al arrancar un proceso nuevo. Si ya hay una
REM  ventana abierta con el mismo perfil, la pestana se abre dentro del proceso
REM  viejo y el flag SE IGNORA (la intro sale muda). Por eso primero se cierran
REM  las ventanas del perfil del torneo. Tu Chrome personal no se toca.
REM
REM  ABRI SIEMPRE POR ACA. Si abris el HTML con doble clic, o entras por
REM  localhost desde tu Chrome de siempre, la intro se ve pero arranca muda
REM  hasta que toques algo (ahi se activa el sonido solo).
REM ===========================================================================

set "APP=%~dp0ALAS-MUNDIAL.html"
set "PERFIL=%LocalAppData%\MundialALAS\perfil"

REM OJO: la ruta va SIEMPRE entre comillas al mostrarla.
REM Dentro de un bloque if(...) de cmd, un ) sin comillas cierra el bloque antes
REM de tiempo y el .bat muere con "No se esperaba .html en este momento".
REM Por eso la ruta va SIEMPRE entre comillas al mostrarla.
if not exist "%APP%" (
  echo No se encontro el archivo:
  echo   "%APP%"
  echo Deja este .bat en la misma carpeta que el HTML del torneo.
  pause
  exit /b 1
)

set "CHROME=%ProgramFiles%\Google\Chrome\Application\chrome.exe"
if not exist "%CHROME%" set "CHROME=%ProgramFiles(x86)%\Google\Chrome\Application\chrome.exe"
if not exist "%CHROME%" set "CHROME=%LocalAppData%\Google\Chrome\Application\chrome.exe"

if not exist "%CHROME%" (
  echo No se encontro Chrome. Abriendo con el navegador por defecto:
  echo la intro va a arrancar en mudo hasta el primer clic o tecla.
  start "" "%APP%"
  exit /b 0
)

REM --- cerrar solo las ventanas del perfil del torneo -------------------------
if exist "%~dp0_cerrar_chrome_torneo.ps1" (
  powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0_cerrar_chrome_torneo.ps1"
)

REM --autoplay-policy : permite audio sin gesto previo
REM --user-data-dir   : perfil propio del torneo. Tiene que ser SIEMPRE el mismo:
REM                     ahi vive el localStorage con los resultados y los albumes.
start "" "%CHROME%" ^
  --autoplay-policy=no-user-gesture-required ^
  --user-data-dir="%PERFIL%" ^
  --start-maximized ^
  "%APP%"
