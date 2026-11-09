"""Testes das regras de banco da Semana 3 (triggers 09/10, procedures 11).

Roda no banco descartavel virtualingua_test (test_support.py carrega
os scripts 01-05 e 08-11 nele). Nao toca no banco virtualingua.
"""
import itertools
import threading
import time

import pytest
from mysql.connector import Error

import db

_contador = itertools.count(1)


def _turma(vagas=5):
    nome = f"Turma Teste S3 {next(_contador)}"
    _, id_turma = db.executar(
        "INSERT INTO turma (nome,id_idioma,id_nivel,id_professor,carga_horaria,vagas) VALUES (%s,1,1,NULL,20,%s)",
        (nome, vagas))
    return id_turma


def _aluno(n):
    """ids 5..19 sao alunos do seed."""
    return 4 + n


def _chamar(nome, args):
    with db.conexao() as cnx:
        cur = cnx.cursor()
        try:
            resultado = cur.callproc(nome, args)
            linhas = [r.fetchall() for r in cur.stored_results()]
            cnx.commit()
            return resultado, linhas
        finally:
            cur.close()


def _erro(sql, params=()):
    with pytest.raises(Error) as e:
        db.executar(sql, params)
    return e.value


# ---------------------------------------------------------------- procedures
def test_sp_matricular_aluno_cria_matricula_e_pagamento():
    turma = _turma()
    res, _ = _chamar("sp_matricular_aluno", (_aluno(1), turma, 300, "2026-12-10", 0, 0))
    id_mat, id_pag = res[4], res[5]
    mat = db.consultar_um("SELECT status FROM matricula WHERE id_matricula=%s", (id_mat,))
    pag = db.consultar_um("SELECT status, id_matricula FROM pagamento WHERE id_pagamento=%s", (id_pag,))
    assert mat["status"] == "pendente"
    assert pag["status"] == "pendente" and pag["id_matricula"] == id_mat


def test_sp_matricular_aluno_duplicada_nao_deixa_lixo():
    turma = _turma()
    _chamar("sp_matricular_aluno", (_aluno(2), turma, 300, "2026-12-10", 0, 0))
    with pytest.raises(Error) as e:
        _chamar("sp_matricular_aluno", (_aluno(2), turma, 300, "2026-12-10", 0, 0))
    assert e.value.errno == 1644 and "já matriculado" in e.value.msg
    n = db.consultar_um("SELECT COUNT(*) n FROM pagamento p JOIN matricula m USING(id_matricula) WHERE m.id_turma=%s", (turma,))
    assert n["n"] == 1


def test_sp_matricular_aluno_turma_lotada_faz_rollback():
    turma = _turma(vagas=1)
    _chamar("sp_matricular_aluno", (_aluno(3), turma, 300, "2026-12-10", 0, 0))
    with pytest.raises(Error) as e:
        _chamar("sp_matricular_aluno", (_aluno(4), turma, 300, "2026-12-10", 0, 0))
    assert e.value.errno == 1644 and "sem vagas" in e.value.msg
    assert db.consultar_um("SELECT COUNT(*) n FROM matricula WHERE id_turma=%s", (turma,))["n"] == 1


def test_sp_matricular_lote_usa_savepoint_por_aluno():
    turma = _turma()
    _, linhas = _chamar("sp_matricular_lote", (turma, "[5, 6, 5, 1, 999]", 300, "2026-12-10"))
    resultado = {r[0]: r[1] for r in linhas[0]}
    assert resultado[6] == "OK"
    assert resultado[1] == "ERRO" and resultado[999] == "ERRO"
    # aluno 5 aparece duas vezes: 1a OK, 2a ERRO (duplicada) - so uma matricula fica
    assert db.consultar_um("SELECT COUNT(*) n FROM matricula WHERE id_turma=%s", (turma,))["n"] == 2
    assert db.consultar_um("SELECT COUNT(*) n FROM pagamento p JOIN matricula m USING(id_matricula) WHERE m.id_turma=%s", (turma,))["n"] == 2


def test_sp_registrar_pontuacao_inserida_mantida_atualizada():
    # aluno 8 (Daniel) tem matricula ativa em Ingles; desafio 1 (ingles, max 10)
    # aluno 7 ainda nao tem pontuacao no desafio 2 (max 20)
    r, _ = _chamar("sp_registrar_pontuacao", (7, 2, 10, ""))
    assert r[3] == "INSERIDA"
    r, _ = _chamar("sp_registrar_pontuacao", (7, 2, 5, ""))
    assert r[3] == "MANTIDA"
    r, _ = _chamar("sp_registrar_pontuacao", (7, 2, 15, ""))
    assert r[3] == "ATUALIZADA"
    assert float(db.consultar_um("SELECT pontos FROM pontuacao WHERE id_aluno=7 AND id_desafio=2")["pontos"]) == 15.0


def test_sp_registrar_pontuacao_rejeita_acima_do_maximo_e_sem_matricula():
    with pytest.raises(Error) as e:
        _chamar("sp_registrar_pontuacao", (7, 2, 21, ""))
    assert e.value.errno == 1644
    with pytest.raises(Error) as e:
        _chamar("sp_registrar_pontuacao", (19, 1, 5, ""))   # aluno 19 so tem matricula pendente
    assert e.value.errno == 1644 and "sem matrícula ativa" in e.value.msg


def test_fn_media_aluno():
    assert db.consultar_um("SELECT fn_media_aluno(1) m")["m"] is None          # administrador
    media = db.consultar_um("SELECT fn_media_aluno(5) m")["m"]
    assert 0 <= float(media) <= 100


# ------------------------------------------------------------------ triggers
def test_pagamento_pago_ativa_matricula():
    turma = _turma()
    res, _ = _chamar("sp_matricular_aluno", (_aluno(5), turma, 300, "2026-12-10", 0, 0))
    id_mat, id_pag = res[4], res[5]
    db.executar("UPDATE pagamento SET status='pago', data_pagamento=CURDATE() WHERE id_pagamento=%s", (id_pag,))
    assert db.consultar_um("SELECT status FROM matricula WHERE id_matricula=%s", (id_mat,))["status"] == "ativa"


def test_transicoes_invalidas_de_status_da_matricula():
    turma = _turma()
    res, _ = _chamar("sp_matricular_aluno", (_aluno(6), turma, 300, "2026-12-10", 0, 0))
    id_mat = res[4]
    db.executar("UPDATE matricula SET status='ativa' WHERE id_matricula=%s", (id_mat,))
    e = _erro("UPDATE matricula SET status='pendente' WHERE id_matricula=%s", (id_mat,))
    assert e.errno == 1644 and "Transição" in e.msg
    db.executar("UPDATE matricula SET status='concluida' WHERE id_matricula=%s", (id_mat,))
    e = _erro("UPDATE matricula SET status='ativa' WHERE id_matricula=%s", (id_mat,))
    assert e.errno == 1644


def test_auditoria_de_alteracao_de_pagamento():
    antes = db.consultar_um("SELECT COUNT(*) n FROM log_auditoria WHERE tabela='pagamento' AND id_registro=4")["n"]
    db.executar("UPDATE pagamento SET valor=valor+1 WHERE id_pagamento=4")
    log = db.consultar("SELECT operacao, detalhe FROM log_auditoria WHERE tabela='pagamento' AND id_registro=4 ORDER BY id_log DESC")
    assert len(log) == antes + 1
    assert log[0]["operacao"] == "ALTERACAO" and "valor:" in log[0]["detalhe"]
    db.executar("UPDATE pagamento SET valor=valor-1 WHERE id_pagamento=4")


def test_auditoria_de_exclusao_de_conta_sem_dados_pessoais():
    db.chamar_procedure("sp_excluir_conta", (13,))
    log = db.consultar("SELECT operacao, detalhe FROM log_auditoria WHERE tabela='usuario' AND id_registro=13")
    ops = {l["operacao"] for l in log}
    assert {"ANONIMIZACAO", "EXCLUSAO_CONTA"} <= ops
    assert all("@" not in l["detalhe"] for l in log)          # nenhum e-mail no log


# --------------------------------------------------------------- concorrencia
def test_ultima_vaga_nao_e_vendida_duas_vezes():
    turma = _turma(vagas=1)
    resultado = {}
    a_inseriu = threading.Event()

    def sessao_a():
        with db.conexao() as cnx:
            cur = cnx.cursor()
            cnx.start_transaction()
            cur.execute("INSERT INTO matricula (id_aluno,id_turma,status) VALUES (%s,%s,'pendente')", (_aluno(7), turma))
            a_inseriu.set()
            time.sleep(1.5)            # B chega enquanto A ainda nao confirmou
            cnx.commit()
            resultado["a"] = "ok"

    def sessao_b():
        a_inseriu.wait()
        with db.conexao() as cnx:
            cur = cnx.cursor()
            cnx.start_transaction()
            try:
                cur.execute("INSERT INTO matricula (id_aluno,id_turma,status) VALUES (%s,%s,'pendente')", (_aluno(8), turma))
                cnx.commit()
                resultado["b"] = "ok"
            except Error as e:
                resultado["b"] = e.errno

    ta, tb = threading.Thread(target=sessao_a), threading.Thread(target=sessao_b)
    ta.start(); tb.start(); ta.join(); tb.join()
    assert resultado == {"a": "ok", "b": 1644}
    assert db.consultar_um("SELECT COUNT(*) n FROM matricula WHERE id_turma=%s", (turma,))["n"] == 1
