"""Preparacao SEGURA de um banco descartavel para os testes."""
import os
import re
import shutil
import subprocess
import tempfile
from pathlib import Path

from dotenv import load_dotenv

BASE = Path(__file__).resolve().parent
DATABASE = BASE.parent / "database"
TEST_DB = "virtualingua_test"


def configurar_ambiente():
    load_dotenv(BASE / ".env")
    os.environ["DB_NAME"] = TEST_DB
    os.environ["FLASK_DEBUG"] = "0"
    import db
    db._pool = None


def recriar_banco():
    configurar_ambiente()
    if os.getenv("DB_NAME") != TEST_DB:
        raise RuntimeError("Operacao recusada: banco diferente de virtualingua_test")
    mysql = shutil.which("mysql")
    if not mysql:
        raise RuntimeError("Cliente mysql nao encontrado no PATH. Veja GUIA_TESTES.md")
    # Arquivo temporario de opcoes evita expor a senha na linha de comando.
    with tempfile.TemporaryDirectory(prefix="vl_test_") as pasta:
        conf = Path(pasta) / "mysql.cnf"
        valores = [os.getenv("DB_HOST", "localhost"), os.getenv("DB_USER", "root"),
                   os.getenv("DB_PASSWORD", "")]
        if any("\n" in x or "\r" in x for x in valores):
            raise RuntimeError("Credenciais invalidas")
        conf.write_text("[client]\n" +
                        f"host={valores[0]}\nport={int(os.getenv('DB_PORT', '3306'))}\n" +
                        f"user={valores[1]}\npassword={valores[2]}\n" +
                        "default-character-set=utf8mb4\n", encoding="utf-8")
        for arquivo in ("01_schema.sql", "02_indexes.sql", "03_seed.sql",
                        "04_views.sql", "05_rf10_excluir_conta.sql",
                        "08_triggers_regras_negocio.sql", "09_triggers_status_matricula.sql",
                        "10_triggers_auditoria.sql", "11_procedures_funcoes.sql"):
            sql = (DATABASE / arquivo).read_text(encoding="utf-8")
            sql = re.sub(r"(?im)^\s*USE\s+virtualingua\s*;", "USE virtualingua_test;", sql)
            sql = re.sub(r"(?im)CREATE\s+DATABASE\s+IF\s+NOT\s+EXISTS\s+virtualingua\b",
                         "CREATE DATABASE IF NOT EXISTS virtualingua_test", sql)
            if arquivo == "01_schema.sql":
                sql = "DROP DATABASE IF EXISTS virtualingua_test;\n" + sql
            resultado = subprocess.run([mysql, f"--defaults-extra-file={conf}", "--binary-mode"],
                                       input=sql, text=True, encoding="utf-8", capture_output=True)
            if resultado.returncode:
                raise RuntimeError(f"Erro ao executar {arquivo}:\n{resultado.stderr}")
            print(f"[BANCO TESTE] {arquivo}: OK")
    print("[BANCO TESTE] virtualingua_test recriado e populado com sucesso")
