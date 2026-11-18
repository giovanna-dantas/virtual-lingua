#!/usr/bin/env bash
# VirtuaLingua - backup lógico (Linux/macOS/Git Bash).
# Uso:  ./backup.sh [usuario]      (padrão: vl_backup)
# Pede a senha na hora (não fica gravada no arquivo nem no histórico).
set -euo pipefail
USUARIO="${1:-vl_backup}"
DESTINO="${BACKUP_DIR:-./backups}"
mkdir -p "$DESTINO"
ARQUIVO="$DESTINO/virtualingua_$(date +%Y%m%d_%H%M%S).sql"

mysqldump -u"$USUARIO" -p \
  --single-transaction --routines --triggers --events \
  --set-gtid-purged=OFF --default-character-set=utf8mb4 \
  virtualingua > "$ARQUIVO"

echo "Backup criado: $ARQUIVO ($(wc -c < "$ARQUIVO") bytes)"
