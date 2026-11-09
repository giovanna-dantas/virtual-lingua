"""Acesso ao MySQL com pool, consultas parametrizadas e transacoes."""
import os
from contextlib import contextmanager
from mysql.connector import Error, pooling

_pool = None

def _config():
    return {"host": os.getenv("DB_HOST", "localhost"), "port": int(os.getenv("DB_PORT", "3306")),
            "user": os.getenv("DB_USER", "root"), "password": os.getenv("DB_PASSWORD", ""),
            "database": os.getenv("DB_NAME", "virtualingua"), "charset": "utf8mb4",
            "collation": "utf8mb4_unicode_ci"}

def _obter_pool():
    global _pool
    if _pool is None:
        _pool = pooling.MySQLConnectionPool(pool_name="virtualingua_pool", pool_size=int(os.getenv("DB_POOL_SIZE", "5")),
                                           pool_reset_session=True, **_config())
    return _pool

@contextmanager
def conexao():
    cnx = _obter_pool().get_connection()
    try:
        yield cnx
    finally:
        try: cnx.rollback()
        except Error: pass
        cnx.close()

@contextmanager
def transacao():
    """Agrupa várias operações: confirma tudo ou desfaz tudo em caso de erro."""
    with conexao() as cnx:
        try:
            cnx.start_transaction()
            yield cnx
            cnx.commit()
        except Exception:
            cnx.rollback()
            raise

def consultar(sql, params=()):
    with conexao() as cnx:
        cur = cnx.cursor(dictionary=True)
        try:
            cur.execute(sql, params)
            return cur.fetchall()
        finally: cur.close()

def consultar_um(sql, params=()):
    rows = consultar(sql, params)
    return rows[0] if rows else None

def executar(sql, params=()):
    with conexao() as cnx:
        cur = cnx.cursor()
        try:
            cur.execute(sql, params); cnx.commit()
            return cur.rowcount, cur.lastrowid
        finally: cur.close()

def executar_transacao(operacoes):
    """Executa lista [(SQL, parametros)] atomicamente."""
    with transacao() as cnx:
        cur = cnx.cursor()
        try:
            resultados = []
            for sql, params in operacoes:
                cur.execute(sql, params); resultados.append((cur.rowcount, cur.lastrowid))
            return resultados
        finally: cur.close()

def chamar_procedure(nome, parametros=()):
    # Nome da procedure e fixo no código; valores continuam parametrizados.
    with conexao() as cnx:
        cur = cnx.cursor()
        try:
            cur.callproc(nome, parametros)
            for resultado in cur.stored_results(): resultado.fetchall()
            cnx.commit()
        finally: cur.close()

def mensagem_erro(erro, duplicado="Já existe um registro com esses dados.",
                  em_uso="Não é possível excluir: o registro está vinculado a outros dados.",
                  padrao="Erro ao acessar o banco de dados."):
    codigo = getattr(erro, "errno", None)
    if codigo == 1062: return duplicado
    if codigo == 1451: return em_uso
    if codigo == 1452: return "Referência inválida: o registro relacionado não existe."
    if codigo == 3819: return "Algum valor viola uma regra do banco. Revise os campos."
    if codigo in (1406, 1264): return "Algum valor informado é grande demais ou inválido."
    if codigo == 1644: return getattr(erro, "msg", padrao)
    return padrao
