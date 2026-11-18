@echo off
REM VirtuaLingua - backup logico no Windows (CMD ou duplo clique).
REM Ajuste MYSQLBIN se o seu MySQL estiver em outra versao/pasta.
REM Pede a senha na hora (nao fica gravada em arquivo).
set "MYSQLBIN=C:\Program Files\MySQL\MySQL Server 8.0\bin"
set "USUARIO=vl_backup"
if not "%~1"=="" set "USUARIO=%~1"
if not exist backups mkdir backups

for /f %%i in ('powershell -NoProfile -Command "Get-Date -Format yyyyMMdd_HHmmss"') do set "TS=%%i"
set "ARQUIVO=backups\virtualingua_%TS%.sql"

"%MYSQLBIN%\mysqldump.exe" -u%USUARIO% -p --single-transaction --routines --triggers --events --set-gtid-purged=OFF --default-character-set=utf8mb4 --result-file="%ARQUIVO%" virtualingua
if errorlevel 1 (
  echo ERRO no backup. Confira usuario, senha e o caminho MYSQLBIN no inicio deste arquivo.
  exit /b 1
)
echo Backup criado: %ARQUIVO%
pause
