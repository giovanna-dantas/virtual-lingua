@echo off
REM VirtuaLingua - TESTE DE RESTORE no Windows.
REM Restaura um backup em um banco SEPARADO (virtualingua_restore).
REM O banco virtualingua original NAO e tocado.
REM Uso: restaurar_teste.bat backups\virtualingua_AAAAMMDD_HHMMSS.sql
set "MYSQLBIN=C:\Program Files\MySQL\MySQL Server 8.0\bin"
if "%~1"=="" (
  echo Informe o arquivo de backup. Ex.: restaurar_teste.bat backups\virtualingua_20261109_093000.sql
  exit /b 1
)
echo Digite a senha do usuario root (ou outro administrador) quando pedir.
"%MYSQLBIN%\mysql.exe" -uroot -p --default-character-set=utf8mb4 -e "DROP DATABASE IF EXISTS virtualingua_restore; CREATE DATABASE virtualingua_restore CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;"
if errorlevel 1 exit /b 1
"%MYSQLBIN%\mysql.exe" -uroot -p --default-character-set=utf8mb4 virtualingua_restore < "%~1"
if errorlevel 1 (echo ERRO no restore. & exit /b 1)
echo Restore concluido em virtualingua_restore. Agora rode 16_verificar_backup_restore.sql no Workbench.
pause
