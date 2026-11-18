"""Testes das areas por perfil: aluno, professor e administrador (virtualingua_test)."""
import itertools

import pytest

import db
from app import app as flask_app
from conftest import ADMIN, ALUNO, PROFESSOR, enviar, entrar

_n = itertools.count(1)


def texto(r):
    return r.get_data(as_text=True)


def seguir(client, r):
    """Segue o redirect e devolve o HTML (mostra as mensagens flash)."""
    assert r.status_code == 302
    return texto(client.get(r.headers["Location"]))


def cliente(email):
    c = flask_app.test_client()
    assert entrar(c, email).status_code == 302
    return c


def novo_aluno():
    """Cria um aluno novo pelo cadastro e devolve (client logado, id)."""
    email = f"aluno.area{next(_n)}@exemplo.com"
    c = flask_app.test_client()
    enviar(c, "/cadastro", {"nome": "Aluno Area", "email": email, "senha": "senha1234", "confirmar": "senha1234"})
    assert entrar(c, email, "senha1234").status_code == 302
    return c, db.consultar_um("SELECT id_usuario FROM usuario WHERE email=%s", (email,))["id_usuario"]


def nova_turma(vagas=5, idioma=1, nivel=1, professor=None):
    _, id_turma = db.executar(
        "INSERT INTO turma (nome,id_idioma,id_nivel,id_professor,carga_horaria,vagas) VALUES (%s,%s,%s,%s,20,%s)",
        (f"Turma Area {next(_n)}", idioma, nivel, professor, vagas))
    return id_turma


def matricular_e_pagar(c, id_aluno, idioma=1):
    """Matricula o aluno numa turma nova e confirma o pagamento (matricula ativa)."""
    turma = nova_turma(idioma=idioma)
    enviar(c, f"/turmas/{turma}/matricular")
    pag = db.consultar_um("SELECT p.id_pagamento FROM pagamento p JOIN matricula m USING (id_matricula) "
                          "WHERE m.id_aluno=%s AND m.id_turma=%s", (id_aluno, turma))["id_pagamento"]
    adm = cliente(ADMIN)
    enviar(adm, f"/admin/pagamentos/{pag}/pagar")
    return turma, pag


# ------------------------------------------------------------- permissoes/painel
def test_paginas_protegidas_exigem_login(client):
    for url in ("/painel", "/minhas-matriculas", "/desafios", "/ranking", "/admin/usuarios", "/admin/pagamentos",
                "/professor/turmas", "/turmas/nova", "/conteudos/novo"):
        r = client.get(url)
        assert r.status_code == 302 and r.headers["Location"].endswith("/login"), url


def test_perfis_nao_acessam_areas_dos_outros():
    aluno, _ = novo_aluno()
    for url in ("/admin/usuarios", "/admin/pagamentos", "/admin/auditoria", "/turmas/nova", "/professor/turmas", "/conteudos/novo"):
        assert aluno.get(url).status_code == 302, url
    prof = cliente(PROFESSOR)
    for url in ("/admin/usuarios", "/admin/pagamentos", "/minhas-matriculas", "/desafios", "/turmas/nova"):
        assert prof.get(url).status_code == 302, url
    assert cliente(ADMIN).get("/professor/turmas").status_code == 302


def test_painel_e_menu_mudam_por_perfil():
    aluno = cliente(ALUNO); t = texto(aluno.get("/painel"))
    assert "matrícula(s) ativa(s)" in t and "Minhas matrículas" in t and "Auditoria" not in t
    prof = cliente(PROFESSOR); t = texto(prof.get("/painel"))
    assert "turma(s) sob sua responsabilidade" in t and "Pontuações" in t and "Minhas matrículas" not in t
    adm = cliente(ADMIN); t = texto(adm.get("/painel"))
    assert "pagamentos a receber" in t and "Auditoria" in t and "Pontuações" not in t


# ------------------------------------------------------------------------- aluno
def test_aluno_se_matricula_pela_tela_e_ve_pagamento_pendente():
    c, id_aluno = novo_aluno()
    turma = nova_turma()
    assert "Matricular-me" in texto(c.get("/turmas"))
    r = enviar(c, f"/turmas/{turma}/matricular")
    assert r.headers["Location"].endswith("/minhas-matriculas")
    m = db.consultar_um("SELECT status FROM matricula WHERE id_aluno=%s AND id_turma=%s", (id_aluno, turma))
    p = db.consultar_um("SELECT p.status, p.valor FROM pagamento p JOIN matricula m USING (id_matricula) WHERE m.id_aluno=%s", (id_aluno,))
    assert m["status"] == "pendente" and p["status"] == "pendente" and float(p["valor"]) == 300.0
    t = texto(c.get("/minhas-matriculas"))
    assert "pendente" in t and "R$ 300.00" in t


def test_matricula_duplicada_e_turma_lotada_mostram_mensagem_do_banco():
    c1, _ = novo_aluno(); c2, _ = novo_aluno()
    turma = nova_turma(vagas=1)
    enviar(c1, f"/turmas/{turma}/matricular")
    assert "matriculado" in seguir(c1, enviar(c1, f"/turmas/{turma}/matricular"))
    assert "sem vagas" in seguir(c2, enviar(c2, f"/turmas/{turma}/matricular")).lower()
    assert db.consultar_um("SELECT COUNT(*) n FROM matricula WHERE id_turma=%s", (turma,))["n"] == 1


def test_admin_confirma_pagamento_e_matricula_fica_ativa_com_auditoria():
    c, id_aluno = novo_aluno()
    turma = nova_turma()
    enviar(c, f"/turmas/{turma}/matricular")
    pag = db.consultar_um("SELECT p.id_pagamento FROM pagamento p JOIN matricula m USING (id_matricula) WHERE m.id_aluno=%s", (id_aluno,))["id_pagamento"]
    adm = cliente(ADMIN)
    assert "ativada automaticamente" in seguir(adm, enviar(adm, f"/admin/pagamentos/{pag}/pagar"))
    assert db.consultar_um("SELECT status FROM matricula WHERE id_aluno=%s", (id_aluno,))["status"] == "ativa"
    assert "ALTERACAO" in texto(adm.get("/admin/auditoria?tabela=pagamento"))
    assert "já quitado" in seguir(adm, enviar(adm, f"/admin/pagamentos/{pag}/pagar"))


def test_aluno_cancela_propria_matricula_e_nao_a_dos_outros():
    c, id_aluno = novo_aluno(); outro, id_outro = novo_aluno()
    turma = nova_turma()
    enviar(c, f"/turmas/{turma}/matricular"); enviar(outro, f"/turmas/{turma}/matricular")
    mat_outro = db.consultar_um("SELECT id_matricula FROM matricula WHERE id_aluno=%s", (id_outro,))["id_matricula"]
    mat = db.consultar_um("SELECT id_matricula FROM matricula WHERE id_aluno=%s", (id_aluno,))["id_matricula"]
    assert "não encontrada" in seguir(c, enviar(c, f"/matriculas/{mat_outro}/cancelar"))
    assert db.consultar_um("SELECT status FROM matricula WHERE id_matricula=%s", (mat_outro,))["status"] == "pendente"
    assert db.consultar_um("SELECT status FROM pagamento WHERE id_matricula=%s", (mat_outro,))["status"] == "pendente"
    assert "cancelada" in seguir(c, enviar(c, f"/matriculas/{mat}/cancelar")).lower()
    assert db.consultar_um("SELECT status FROM matricula WHERE id_matricula=%s", (mat,))["status"] == "cancelada"
    assert db.consultar_um("SELECT status FROM pagamento WHERE id_matricula=%s", (mat,))["status"] == "cancelado"


def test_desafios_exigem_matricula_ativa_e_mantem_a_maior_nota():
    c, id_aluno = novo_aluno()
    assert "precisa de matrícula ativa" in texto(c.get("/desafios"))
    r = enviar(c, "/desafios/1/pontuar", {"pontos": "5"})
    assert "sem matrícula ativa" in seguir(c, r)
    matricular_e_pagar(c, id_aluno, idioma=1)
    assert "Pontuação registrada" in seguir(c, enviar(c, "/desafios/1/pontuar", {"pontos": "6"}))
    assert "maior ou igual" in seguir(c, enviar(c, "/desafios/1/pontuar", {"pontos": "4"}))
    assert "atualizada" in seguir(c, enviar(c, "/desafios/1/pontuar", {"pontos": "9,5"}))
    assert float(db.consultar_um("SELECT pontos FROM pontuacao WHERE id_aluno=%s AND id_desafio=1", (id_aluno,))["pontos"]) == 9.5
    seguir(c, enviar(c, "/desafios/1/pontuar", {"pontos": "11"}))          # acima do maximo (10)
    assert float(db.consultar_um("SELECT pontos FROM pontuacao WHERE id_aluno=%s AND id_desafio=1", (id_aluno,))["pontos"]) == 9.5
    assert "pontuação válida" in seguir(c, enviar(c, "/desafios/1/pontuar", {"pontos": "abc"}))
    assert "Sua média" in texto(c.get("/desafios"))


def test_ranking_mostra_top_por_idioma():
    t = texto(cliente(ALUNO).get("/ranking"))
    assert "Ranking por idioma" in t and "top 10" in t and "(você)" in t
    filtrado = texto(cliente(ALUNO).get("/ranking?idioma=1"))
    assert "Inglês · top 10" in filtrado and "Espanhol · top 10" not in filtrado


# -------------------------------------------------------------------------- admin
def test_admin_crud_de_turma_com_regras_do_banco():
    adm = cliente(ADMIN)
    nome = f"Turma CRUD {next(_n)}"
    dados = {"nome": nome, "id_idioma": 1, "id_nivel": 2, "id_professor": 2, "carga_horaria": 30, "vagas": 8}
    assert enviar(adm, "/turmas/nova", dados).status_code == 302
    turma = db.consultar_um("SELECT id_turma, vagas FROM turma WHERE nome=%s", (nome,))
    assert turma["vagas"] == 8
    assert "Já existe uma turma" in texto(enviar(adm, "/turmas/nova", dados))
    assert db.consultar_um("SELECT COUNT(*) n FROM turma WHERE nome=%s", (nome,))["n"] == 1
    # professor 3 so leciona espanhol: o trigger impede turma de ingles com ele
    r = enviar(adm, "/turmas/nova", {**dados, "nome": nome + " X", "id_professor": 3})
    assert db.consultar_um("SELECT COUNT(*) n FROM turma WHERE nome=%s", (nome + " X",))["n"] == 0
    assert r.status_code == 200 and "habilitado" in texto(r).lower()
    # editar e excluir
    enviar(adm, f"/turmas/{turma['id_turma']}/editar", {**dados, "vagas": 9})
    assert db.consultar_um("SELECT vagas FROM turma WHERE id_turma=%s", (turma["id_turma"],))["vagas"] == 9
    enviar(adm, f"/turmas/{turma['id_turma']}/excluir")
    assert db.consultar_um("SELECT COUNT(*) n FROM turma WHERE nome=%s", (nome,))["n"] == 0


def test_admin_nao_exclui_turma_com_matriculas():
    adm = cliente(ADMIN)
    assert "tem matrículas" in seguir(adm, enviar(adm, "/turmas/1/excluir"))
    assert db.consultar_um("SELECT COUNT(*) n FROM turma WHERE id_turma=1")["n"] == 1


def test_admin_cria_professor_com_idiomas_e_valida_campos():
    adm = cliente(ADMIN)
    email = f"prof.novo{next(_n)}@virtualingua.com.br"
    base = {"nome": "Profa Nova", "email": email, "tipo": "professor", "senha": "senha1234", "idiomas": ["1", "2"]}
    assert "pelo menos 8" in texto(enviar(adm, "/admin/usuarios/novo", {**base, "senha": "curta"}))
    assert "ao menos um idioma" in texto(enviar(adm, "/admin/usuarios/novo", {**base, "idiomas": []}))
    assert enviar(adm, "/admin/usuarios/novo", base).status_code == 302
    pid = db.consultar_um("SELECT id_usuario FROM usuario WHERE email=%s", (email,))["id_usuario"]
    assert db.consultar_um("SELECT COUNT(*) n FROM professor_idioma WHERE id_professor=%s", (pid,))["n"] == 2
    assert "já existe" in texto(enviar(adm, "/admin/usuarios/novo", base)).lower()
    assert entrar(flask_app.test_client(), email, "senha1234").status_code == 302
    assert email in texto(adm.get("/admin/usuarios?tipo=professor"))


def test_admin_matricula_aluno_e_lista_pagamentos_pendentes():
    adm = cliente(ADMIN)
    turma = nova_turma()
    assert "criada com pagamento" in seguir(adm, enviar(adm, "/admin/matriculas", {"id_aluno": 16, "id_turma": turma}))
    assert "já" in seguir(adm, enviar(adm, "/admin/matriculas", {"id_aluno": 16, "id_turma": turma})).lower()
    assert db.consultar_um("SELECT COUNT(*) n FROM matricula WHERE id_aluno=16 AND id_turma=%s", (turma,))["n"] == 1
    t = texto(adm.get("/admin/pagamentos"))
    assert "Confirmar pagamento" in t and "Leonardo" in t
    assert "Leonardo" in texto(adm.get("/admin/matriculas?status=pendente"))


# ------------------------------------------------------- conteudos e desafios
def test_professor_gerencia_apenas_seus_conteudos_e_desafios():
    prof = cliente(PROFESSOR)                                           # Carlos, id 2
    titulo = f"Conteudo Prof {next(_n)}"
    assert enviar(prof, "/conteudos/novo", {"titulo": titulo, "descricao": "d", "id_idioma": 1, "id_nivel": 1}).status_code == 302
    c = db.consultar_um("SELECT id_conteudo, id_professor FROM conteudo WHERE titulo=%s", (titulo,))
    assert c["id_professor"] == 2                                       # forcado a ser ele mesmo
    # desafio
    assert enviar(prof, f"/conteudos/{c['id_conteudo']}/desafios", {"titulo": "D1", "pontuacao_maxima": "15"}).status_code == 302
    d = db.consultar_um("SELECT id_desafio, pontuacao_maxima FROM desafio WHERE id_conteudo=%s", (c["id_conteudo"],))
    assert d["pontuacao_maxima"] == 15
    assert "D1" in texto(prof.get(f"/conteudos/{c['id_conteudo']}/desafios"))
    enviar(prof, f"/desafios/{d['id_desafio']}/editar", {"titulo": "D1b", "pontuacao_maxima": "20"})
    assert db.consultar_um("SELECT titulo, pontuacao_maxima FROM desafio WHERE id_desafio=%s", (d["id_desafio"],))["pontuacao_maxima"] == 20
    enviar(prof, f"/desafios/{d['id_desafio']}/excluir")
    assert db.consultar_um("SELECT COUNT(*) n FROM desafio WHERE id_conteudo=%s", (c["id_conteudo"],))["n"] == 0
    # conteudo da professora 4 (id 2): Carlos nao mexe
    assert "só pode alterar" in seguir(prof, enviar(prof, "/conteudos/2/excluir"))
    enviar(prof, "/conteudos/2/editar", {"titulo": "Hack", "id_idioma": 1, "id_nivel": 1})
    assert db.consultar_um("SELECT titulo FROM conteudo WHERE id_conteudo=2")["titulo"] != "Hack"
    assert prof.get("/desafios/3/editar").status_code == 302
    enviar(prof, f"/conteudos/{c['id_conteudo']}/excluir")
    assert db.consultar_um("SELECT COUNT(*) n FROM conteudo WHERE id_conteudo=%s", (c["id_conteudo"],))["n"] == 0


def test_admin_edita_conteudo_de_qualquer_professor_e_valida():
    adm = cliente(ADMIN)
    assert "Informe o título" in texto(enviar(adm, "/conteudos/novo", {"titulo": "", "id_idioma": 1, "id_nivel": 1}))
    assert "Já existe" in texto(enviar(adm, "/conteudos/novo", {"titulo": "Greetings and Introductions", "id_idioma": 1, "id_nivel": 1}))
    titulo = f"Conteudo Adm {next(_n)}"
    enviar(adm, "/conteudos/novo", {"titulo": titulo, "id_idioma": 2, "id_nivel": 1, "id_professor": 3})
    cid = db.consultar_um("SELECT id_conteudo, id_professor FROM conteudo WHERE titulo=%s", (titulo,))
    assert cid["id_professor"] == 3
    assert enviar(adm, f"/conteudos/{cid['id_conteudo']}/editar", {"titulo": titulo + "!", "id_idioma": 2, "id_nivel": 1, "id_professor": 3}).status_code == 302
    enviar(adm, f"/conteudos/{cid['id_conteudo']}/excluir")


# ---------------------------------------------------------------------- professor
def test_professor_ve_suas_turmas_e_alunos_com_media():
    prof = cliente(PROFESSOR)
    t = texto(prof.get("/professor/turmas"))
    assert "Inglês A1 Manhã" in t and "Espanhol A1 Manhã" not in t
    t = texto(prof.get("/professor/turmas/1"))
    assert "Bruno" in t and "ativa" in t and "Média" in t
    assert "entre as suas" in seguir(prof, prof.get("/professor/turmas/4"))


def test_professor_lanca_pontuacao_pela_procedure():
    prof = cliente(PROFESSOR)
    # aluno 6 (Bruno) tem matricula ativa em Ingles na turma 1 do Carlos; desafio 6 (max 20) e do conteudo 3 do Carlos
    assert "Pontuação registrada" in seguir(prof, enviar(prof, "/professor/pontuacoes", {"id_aluno": 6, "id_desafio": 6, "pontos": "12"}))
    assert "Bruno" in texto(prof.get("/professor/pontuacoes"))
    assert "não pertence" in seguir(prof, enviar(prof, "/professor/pontuacoes", {"id_aluno": 6, "id_desafio": 3, "pontos": "5"}))
    # desafio de espanhol de conteudo seu inexistente -> aluno de ingles em desafio de ingles acima do maximo
    seguir(prof, enviar(prof, "/professor/pontuacoes", {"id_aluno": 6, "id_desafio": 6, "pontos": "99"}))
    assert float(db.consultar_um("SELECT pontos FROM pontuacao WHERE id_aluno=6 AND id_desafio=6")["pontos"]) == 12.0
