"""Quiz: o aluno responde, o SERVIDOR calcula a nota (virtualingua_test).

Seed: todos os desafios tem as mesmas 3 perguntas padrao (17_quiz.sql).
Desafio 1 = EN, max 10 (prof. Carlos): cada acerto vale 10/3. Desafio 7 = ES, max 10.
O desafio "sem quiz" e criado dentro do teste correspondente.
"""
import json

import db
from conftest import ADMIN, PROFESSOR, enviar
from test_areas_perfis import cliente, matricular_e_pagar, novo_aluno, seguir, texto

QUIZ_EN = 1          # 3 questoes, max 10 -> 3,33 por acerto
DESAFIO_MANUAL = 2   # tem perguntas, mas aqui o professor tambem pode lancar nota
QUIZ_ES = 7
OUTRO_PROFESSOR = "marina.duarte@virtualingua.com.br"


def api(c, metodo, url, corpo=None):
    with c.session_transaction() as sessao:
        sessao["csrf_token"] = "token-api"
    return getattr(c, metodo)(url, json=corpo, headers={"X-CSRF-Token": "token-api"})


def marcar(id_desafio, acertos):
    """Monta {id_questao: id_alternativa} acertando as `acertos` primeiras questoes e errando o resto."""
    qs = db.consultar("SELECT id_questao FROM questao WHERE id_desafio=%s ORDER BY ordem", (id_desafio,))
    resp = {}
    for i, q in enumerate(qs):
        quer_certa = 1 if i < acertos else 0
        alt = db.consultar_um("SELECT id_alternativa FROM alternativa WHERE id_questao=%s AND correta=%s "
                              "ORDER BY id_alternativa LIMIT 1", (q["id_questao"], quer_certa))
        resp[str(q["id_questao"])] = alt["id_alternativa"]
    return resp


def aluno_ativo(idioma=1):
    c, id_aluno = novo_aluno()
    matricular_e_pagar(c, id_aluno, idioma=idioma)
    return c, id_aluno


def nota(id_aluno, id_desafio):
    r = db.consultar_um("SELECT pontos FROM pontuacao WHERE id_aluno=%s AND id_desafio=%s", (id_aluno, id_desafio))
    return float(r["pontos"]) if r else None


# ------------------------------------------------- as brechas estao fechadas
def test_aluno_nao_consegue_lancar_a_propria_nota():
    c, id_aluno = aluno_ativo()
    # rota web antiga: nao existe mais
    assert enviar(c, f"/desafios/{QUIZ_EN}/pontuar", {"pontos": "10"}).status_code == 404
    # API de lancamento manual: so professor/admin
    r = api(c, "post", "/api/pontuacoes", {"id_desafio": QUIZ_EN, "pontos": 10})
    assert r.status_code == 403
    r = api(c, "post", "/api/pontuacoes", {"id_aluno": id_aluno, "id_desafio": QUIZ_EN, "pontos": 10})
    assert r.status_code == 403
    assert nota(id_aluno, QUIZ_EN) is None


def test_professor_e_admin_continuam_lancando_nota_manual():
    c, id_aluno = aluno_ativo()
    prof = cliente(PROFESSOR)
    r = api(prof, "post", "/api/pontuacoes", {"id_aluno": id_aluno, "id_desafio": DESAFIO_MANUAL, "pontos": 12})
    assert r.status_code == 201 and nota(id_aluno, DESAFIO_MANUAL) == 12.0
    r = api(cliente(ADMIN), "post", "/api/pontuacoes", {"id_aluno": id_aluno, "id_desafio": DESAFIO_MANUAL, "pontos": 15})
    assert r.status_code == 201 and nota(id_aluno, DESAFIO_MANUAL) == 15.0


# ----------------------------------------------------------- gabarito oculto
def test_quiz_nao_vaza_o_gabarito():
    c, _ = aluno_ativo()
    pagina = texto(c.get(f"/desafios/{QUIZ_EN}/quiz"))
    assert "Quantos dias tem uma semana?" in pagina and "correta" not in pagina.lower().replace("corretas", "")
    corpo = api(c, "get", f"/api/desafios/{QUIZ_EN}/quiz")
    assert corpo.status_code == 200
    dados = corpo.get_json()["dados"]
    assert len(dados["questoes"]) == 3
    assert "correta" not in json.dumps(dados)
    assert all(set(a) == {"id_alternativa", "texto"} for q in dados["questoes"] for a in q["alternativas"])


# ------------------------------------------------------------------ correcao
def test_nota_e_calculada_pelo_servidor_pelos_acertos():
    c, id_aluno = aluno_ativo()
    r = api(c, "post", f"/api/desafios/{QUIZ_EN}/responder", {"respostas": marcar(QUIZ_EN, 2)})
    assert r.status_code == 201
    dados = r.get_json()["dados"]
    assert (dados["acertos"], dados["total"], dados["nota"]) == (2, 3, 6.67)
    assert nota(id_aluno, QUIZ_EN) == 6.67


def test_tela_do_quiz_corrige_e_mostra_a_nota():
    c, id_aluno = aluno_ativo()
    form = {f"q{q}": a for q, a in marcar(QUIZ_EN, 3).items()}
    pagina = seguir(c, enviar(c, f"/desafios/{QUIZ_EN}/quiz", form))
    assert "3 de 3" in pagina and "nota é 10" in pagina
    assert nota(id_aluno, QUIZ_EN) == 10.0


def test_todas_erradas_da_zero():
    c, id_aluno = aluno_ativo()
    assert api(c, "post", f"/api/desafios/{QUIZ_EN}/responder", {"respostas": marcar(QUIZ_EN, 0)}).status_code == 201
    assert nota(id_aluno, QUIZ_EN) == 0.0


def test_campos_de_nota_enviados_pelo_aluno_sao_ignorados():
    c, id_aluno = aluno_ativo()
    corpo = {"respostas": marcar(QUIZ_EN, 0), "pontos": 10, "nota": 10, "id_aluno": 1}
    assert api(c, "post", f"/api/desafios/{QUIZ_EN}/responder", corpo).status_code == 201
    assert nota(id_aluno, QUIZ_EN) == 0.0                       # valeu o gabarito, nao o "pontos"
    assert nota(1, QUIZ_EN) is None                              # e nada foi gravado para outro aluno
    # mesmo truque no formulario web
    c2, id2 = aluno_ativo()
    form = {f"q{q}": a for q, a in marcar(QUIZ_EN, 0).items()} | {"pontos": "10", "id_aluno": "1"}
    seguir(c2, enviar(c2, f"/desafios/{QUIZ_EN}/quiz", form))
    assert nota(id2, QUIZ_EN) == 0.0


# ------------------------------------------------------------------- regras
def test_uma_tentativa_por_desafio():
    c, id_aluno = aluno_ativo()
    assert api(c, "post", f"/api/desafios/{QUIZ_EN}/responder", {"respostas": marcar(QUIZ_EN, 1)}).status_code == 201
    r = api(c, "post", f"/api/desafios/{QUIZ_EN}/responder", {"respostas": marcar(QUIZ_EN, 3)})
    assert r.status_code == 409 and "já respondeu" in r.get_json()["mensagem"]
    assert nota(id_aluno, QUIZ_EN) == 3.33                       # a segunda tentativa nao mexeu
    assert api(c, "get", f"/api/desafios/{QUIZ_EN}/quiz").status_code == 409
    assert "nota registrada" in texto(c.get("/desafios"))


def test_exige_matricula_ativa_no_idioma_do_desafio():
    c, id_aluno = novo_aluno()                                   # sem matricula
    assert api(c, "post", f"/api/desafios/{QUIZ_EN}/responder", {"respostas": marcar(QUIZ_EN, 3)}).status_code == 403
    assert "matrícula ativa" in seguir(c, c.get(f"/desafios/{QUIZ_EN}/quiz"))
    assert nota(id_aluno, QUIZ_EN) is None
    c2, id2 = aluno_ativo(idioma=1)                              # ativo so em ingles
    assert api(c2, "post", f"/api/desafios/{QUIZ_ES}/responder", {"respostas": marcar(QUIZ_ES, 2)}).status_code == 403
    assert nota(id2, QUIZ_ES) is None


def test_respostas_incompletas_ou_invalidas_sao_rejeitadas():
    c, id_aluno = aluno_ativo()
    url = f"/api/desafios/{QUIZ_EN}/responder"
    completas = marcar(QUIZ_EN, 3)
    faltando = dict(list(completas.items())[:2])
    assert api(c, "post", url, {"respostas": faltando}).status_code == 400
    assert api(c, "post", url, {"respostas": {"abc": "x"}}).status_code == 400
    assert api(c, "post", url, {"respostas": []}).status_code == 400
    assert api(c, "post", url, {}).status_code == 400
    # alternativa que pertence a OUTRA questao
    ids = list(completas)
    trocada = dict(completas)
    trocada[ids[0]] = completas[ids[1]]
    assert api(c, "post", url, {"respostas": trocada}).status_code == 400
    assert nota(id_aluno, QUIZ_EN) is None                       # nenhuma tentativa foi consumida


def test_desafio_sem_perguntas_nao_e_quiz():
    c, id_aluno = aluno_ativo()
    _, id_desafio = db.executar("INSERT INTO desafio (id_conteudo,titulo,pontuacao_maxima) VALUES (1,'Desafio manual sem quiz',10)")
    r = api(c, "post", f"/api/desafios/{id_desafio}/responder", {"respostas": {"1": 1}})
    assert r.status_code == 409
    assert api(c, "get", "/api/desafios/99999/quiz").status_code == 404
    linha = texto(c.get("/desafios")).split("Desafio manual sem quiz")[1].split("</tr>")[0]
    assert "Fazer quiz" not in linha and "lançada pelo professor" in linha
    assert nota(id_aluno, id_desafio) is None


def test_responder_exige_csrf_e_perfil_aluno():
    c, _ = aluno_ativo()
    sem_token = c.post(f"/api/desafios/{QUIZ_EN}/responder", json={"respostas": marcar(QUIZ_EN, 3)})
    assert sem_token.status_code == 400
    prof = cliente(PROFESSOR)
    assert api(prof, "post", f"/api/desafios/{QUIZ_EN}/responder", {"respostas": marcar(QUIZ_EN, 3)}).status_code == 403
    assert api(prof, "get", f"/api/desafios/{QUIZ_EN}/quiz").status_code == 403
    anonimo = api(__import__("app").app.test_client(), "get", f"/api/desafios/{QUIZ_EN}/quiz")
    assert anonimo.status_code == 401


# ----------------------------------------------- professor cadastra perguntas
def _nova_questao(**extra):
    base = {"enunciado": "Pergunta de teste?", "alt1": "Certa", "alt2": "Errada", "alt3": "", "alt4": "", "correta": "1"}
    return base | extra


def test_professor_cadastra_e_exclui_perguntas_do_proprio_desafio():
    prof = cliente(PROFESSOR)
    _, id_conteudo = db.executar("INSERT INTO conteudo (titulo,id_idioma,id_nivel,id_professor) VALUES ('Quiz T',1,1,2)")
    _, id_desafio = db.executar("INSERT INTO desafio (id_conteudo,titulo,pontuacao_maxima) VALUES (%s,'D quiz',9)", (id_conteudo,))
    assert "ainda não tem perguntas" in texto(prof.get(f"/desafios/{id_desafio}/questoes"))
    assert "adicionada" in seguir(prof, enviar(prof, f"/desafios/{id_desafio}/questoes", _nova_questao()))
    assert "adicionada" in seguir(prof, enviar(prof, f"/desafios/{id_desafio}/questoes",
                                               _nova_questao(enunciado="Outra?", alt3="Talvez", correta="3")))
    assert db.consultar_um("SELECT COUNT(*) n FROM questao WHERE id_desafio=%s", (id_desafio,))["n"] == 2
    assert db.consultar_um("SELECT COUNT(*) n FROM alternativa a JOIN questao q USING (id_questao) "
                           "WHERE q.id_desafio=%s AND a.correta", (id_desafio,))["n"] == 2
    assert "Outra?" in texto(prof.get(f"/desafios/{id_desafio}/questoes"))
    q = db.consultar_um("SELECT id_questao FROM questao WHERE id_desafio=%s ORDER BY ordem LIMIT 1", (id_desafio,))
    assert "excluída" in seguir(prof, enviar(prof, f"/questoes/{q['id_questao']}/excluir"))
    assert db.consultar_um("SELECT COUNT(*) n FROM questao WHERE id_desafio=%s", (id_desafio,))["n"] == 1
    assert db.consultar_um("SELECT COUNT(*) n FROM alternativa WHERE id_questao=%s", (q["id_questao"],))["n"] == 0  # cascade


def test_validacao_do_cadastro_de_pergunta():
    prof = cliente(PROFESSOR)
    url = f"/desafios/{QUIZ_EN}/questoes"
    antes = db.consultar_um("SELECT COUNT(*) n FROM questao WHERE id_desafio=%s", (QUIZ_EN,))["n"]
    assert "enunciado" in seguir(prof, enviar(prof, url, _nova_questao(enunciado=" ")))
    assert "ao menos 2" in seguir(prof, enviar(prof, url, _nova_questao(alt2="")))
    assert "correta" in seguir(prof, enviar(prof, url, _nova_questao(correta="")))
    assert "correta" in seguir(prof, enviar(prof, url, _nova_questao(correta="4")))     # alternativa 4 esta vazia
    assert "correta" in seguir(prof, enviar(prof, url, _nova_questao(correta="9")))
    assert db.consultar_um("SELECT COUNT(*) n FROM questao WHERE id_desafio=%s", (QUIZ_EN,))["n"] == antes


def test_so_o_dono_ou_admin_gerencia_perguntas_e_aluno_nao_acessa():
    antes = db.consultar_um("SELECT COUNT(*) n FROM questao WHERE id_desafio=%s", (QUIZ_EN,))["n"]
    outro = cliente(OUTRO_PROFESSOR)                              # o desafio 1 e do Carlos
    assert "só pode alterar" in seguir(outro, outro.get(f"/desafios/{QUIZ_EN}/questoes"))
    seguir(outro, enviar(outro, f"/desafios/{QUIZ_EN}/questoes", _nova_questao()))
    q = db.consultar_um("SELECT id_questao FROM questao WHERE id_desafio=%s LIMIT 1", (QUIZ_EN,))
    seguir(outro, enviar(outro, f"/questoes/{q['id_questao']}/excluir"))
    assert db.consultar_um("SELECT COUNT(*) n FROM questao WHERE id_desafio=%s", (QUIZ_EN,))["n"] == antes
    aluno, _ = novo_aluno()
    assert aluno.get(f"/desafios/{QUIZ_EN}/questoes").status_code == 302
    seguir(aluno, enviar(aluno, f"/desafios/{QUIZ_EN}/questoes", _nova_questao()))
    seguir(aluno, enviar(aluno, f"/questoes/{q['id_questao']}/excluir"))
    assert db.consultar_um("SELECT COUNT(*) n FROM questao WHERE id_desafio=%s", (QUIZ_EN,))["n"] == antes
    assert cliente(ADMIN).get(f"/desafios/{QUIZ_EN}/questoes").status_code == 200


def test_professor_pode_liberar_nova_tentativa_apagando_a_pontuacao():
    c, id_aluno = aluno_ativo()
    api(c, "post", f"/api/desafios/{QUIZ_EN}/responder", {"respostas": marcar(QUIZ_EN, 1)})
    prof = cliente(PROFESSOR)
    pid = db.consultar_um("SELECT id_pontuacao FROM pontuacao WHERE id_aluno=%s AND id_desafio=%s", (id_aluno, QUIZ_EN))["id_pontuacao"]
    assert api(prof, "delete", f"/api/pontuacoes/{pid}").status_code == 200
    assert api(c, "post", f"/api/desafios/{QUIZ_EN}/responder", {"respostas": marcar(QUIZ_EN, 3)}).status_code == 201
    assert nota(id_aluno, QUIZ_EN) == 10.0
