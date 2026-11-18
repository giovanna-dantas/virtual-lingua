#!/usr/bin/env bash
# VirtuaLingua - TESTE DE RESTORE (Linux/macOS/Git Bash).
# Restaura um backup em um banco SEPARADO (virtualingua_restore).
# O banco virtualingua original NÃO é tocado.
# Uso: ./restaurar_teste.sh backups/virtualingua_AAAAMMDD_HHMMSS.sql
set -euo pipefail
[ $# -eq 1 ] || { echo "Uso: $0 arquivo_de_backup.sql"; exit 1; }
echo "Senha do root (ou outro administrador) será pedida duas vezes."
mysql -uroot -p --default-character-set=utf8mb4 \
  -e "DROP DATABASE IF EXISTS virtualingua_restore; CREATE DATABASE virtualingua_restore CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;"
mysql -uroot -p --default-character-set=utf8mb4 virtualingua_restore < "$1"
echo "Restore concluído em virtualingua_restore. Rode 16_verificar_backup_restore.sql no Workbench."
