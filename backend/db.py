"""Acesso ao MySQL: pool de conexoes + funcoes de consulta/execucao.

Todas as rotas usam estas funcoes; nenhuma abre conexao por conta propria.
O SQL e sempre parametrizado (%s) para evitar SQL injection.
"""
import os
from contextlib import contextmanager

from mysql.connector import Error, pooling

_pool = None


def _config():
    return {
        "host": os.getenv("DB_HOST", "localhost"),
        "port": int(os.getenv("DB_PORT", "3306")),
        "user": os.getenv("DB_USER", "root"),
        "password": os.getenv("DB_PASSWORD", ""),
        "database": os.getenv("DB_NAME", "virtualingua"),
        "charset": "utf8mb4",
        "collation": "utf8mb4_unicode_ci",
    }


def _obter_pool():
    # Criado so na primeira consulta; se o MySQL estiver desligado, tenta de novo na proxima.
    global _pool
    if _pool is None:
        _pool = pooling.MySQLConnectionPool(
            pool_name="virtualingua",
            pool_size=int(os.getenv("DB_POOL_SIZE", "5")),
            pool_reset_session=True,
            **_config(),
        )
    return _pool


@contextmanager
def conexao():
    """Empresta uma conexao do pool. Sempre faz rollback do que nao foi
    confirmado (commit) e devolve a conexao ao pool."""
    cnx = _obter_pool().get_connection()
    try:
        yield cnx
    finally:
        try:
            cnx.rollback()
        except Error:
            pass
        cnx.close()  # devolve ao pool, nao fecha de verdade


def consultar(sql, params=()):
    """SELECT -> lista de dicionarios."""
    with conexao() as cnx:
        cur = cnx.cursor(dictionary=True)
        try:
            cur.execute(sql, params)
            return cur.fetchall()
        finally:
            cur.close()


def consultar_um(sql, params=()):
    """SELECT -> um dicionario (ou None)."""
    linhas = consultar(sql, params)
    return linhas[0] if linhas else None


def executar(sql, params=()):
    """INSERT/UPDATE/DELETE com commit. Retorna (linhas_afetadas, ultimo_id).
    Em caso de erro levanta mysql.connector.Error (a conexao faz rollback)."""
    with conexao() as cnx:
        cur = cnx.cursor()
        try:
            cur.execute(sql, params)
            cnx.commit()
            return cur.rowcount, cur.lastrowid
        finally:
            cur.close()


def mensagem_erro(erro, duplicado="Já existe um registro com esses dados.",
                  em_uso="Não é possível excluir: o registro está em uso por outros dados.",
                  padrao="Erro ao acessar o banco de dados."):
    """Traduz o erro do MySQL para uma mensagem que o usuario entende."""
    codigo = getattr(erro, "errno", None)
    if codigo == 1062:                      # UNIQUE violada
        return duplicado
    if codigo == 1451:                      # FK impede excluir/alterar (RESTRICT)
        return em_uso
    if codigo == 1452:                      # FK aponta para registro inexistente
        return "Referência inválida: o registro relacionado não existe."
    if codigo == 3819:                      # CHECK violado
        return "Algum valor informado viola uma regra do banco. Revise os campos."
    if codigo in (1406, 1264):              # valor grande demais / fora do intervalo
        return "Algum valor informado é grande demais."
    if codigo == 1644:                      # SIGNAL dos triggers/procedures (regras de negocio)
        return erro.msg
    return padrao
