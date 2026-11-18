"""Testes das telas de cadastro, perfil, turmas e conteudos (banco virtualingua_test)."""
import db
from conftest import ADMIN, ALUNO, PROFESSOR, SENHA_SEED, enviar, entrar


def texto(resposta):
    return resposta.get_data(as_text=True)


# ---------------------------------------------------------------- cadastro
def test_pagina_de_cadastro_abre(client):
    r = client.get("/cadastro")
    assert r.status_code == 200 and "Criar conta" in texto(r)


def test_cadastro_cria_aluno_e_permite_login(client):
    r = enviar(client, "/cadastro", {"nome": "Paula Teste", "email": "Paula.Teste@Exemplo.com",
                                     "senha": "senha1234", "confirmar": "senha1234"})
    assert r.status_code == 302 and r.headers["Location"].endswith("/login")
    usuario = db.consultar_um("SELECT tipo, ativo, senha_hash FROM usuario WHERE email=%s", ("paula.teste@exemplo.com",))
    assert usuario["tipo"] == "aluno" and usuario["ativo"] == 1
    assert usuario["senha_hash"] != "senha1234"                       # senha guardada com hash
    assert entrar(client, "paula.teste@exemplo.com", "senha1234").status_code == 302


def test_cadastro_nao_aceita_escolher_tipo_professor(client):
    enviar(client, "/cadastro", {"nome": "Esperto", "email": "esperto@exemplo.com", "tipo": "administrador",
                                 "senha": "senha1234", "confirmar": "senha1234"})
    assert db.consultar_um("SELECT tipo FROM usuario WHERE email=%s", ("esperto@exemplo.com",))["tipo"] == "aluno"


def test_cadastro_rejeita_dados_invalidos(client):
    base = {"nome": "X", "email": "x@exemplo.com", "senha": "senha1234", "confirmar": "senha1234"}
    for alteracao, trecho in [({"senha": "curta", "confirmar": "curta"}, "pelo menos 8"),
                              ({"confirmar": "outra-senha"}, "não confere"),
                              ({"email": "sem-arroba"}, "e-mail válido"),
                              ({"nome": ""}, "seu nome"),
                              ({"email": ALUNO}, "Já existe uma conta")]:
        r = enviar(client, "/cadastro", {**base, **alteracao})
        assert r.status_code == 200 and trecho in texto(r), alteracao
    assert db.consultar_um("SELECT id_usuario FROM usuario WHERE email=%s", ("x@exemplo.com",)) is None


# ------------------------------------------------------------------ perfil
def test_perfil_exige_login(client):
    r = client.get("/perfil")
    assert r.status_code == 302 and "/login" in r.headers["Location"]


def test_editar_nome_e_email_do_perfil(client):
    enviar(client, "/cadastro", {"nome": "Edita Eu", "email": "edita@exemplo.com", "senha": "senha1234", "confirmar": "senha1234"})
    entrar(client, "edita@exemplo.com", "senha1234")
    r = enviar(client, "/perfil", {"nome": "Edita Novo", "email": "edita.novo@exemplo.com"})
    assert r.status_code == 302
    assert db.consultar_um("SELECT nome FROM usuario WHERE email=%s", ("edita.novo@exemplo.com",))["nome"] == "Edita Novo"
    assert "Edita Novo" in texto(client.get("/perfil"))


def test_trocar_senha_exige_senha_atual(client):
    enviar(client, "/cadastro", {"nome": "Troca", "email": "troca@exemplo.com", "senha": "senha1234", "confirmar": "senha1234"})
    entrar(client, "troca@exemplo.com", "senha1234")
    errado = enviar(client, "/perfil", {"nome": "Troca", "email": "troca@exemplo.com", "senha_atual": "errada", "nova_senha": "novasenha1"})
    assert "senha atual não confere" in texto(errado)
    certo = enviar(client, "/perfil", {"nome": "Troca", "email": "troca@exemplo.com", "senha_atual": "senha1234", "nova_senha": "novasenha1"})
    assert certo.status_code == 302
    assert entrar(client, "troca@exemplo.com", "novasenha1").status_code == 302


def test_email_duplicado_no_perfil_e_recusado(client):
    entrar(client, ALUNO)
    r = enviar(client, "/perfil", {"nome": "Ana", "email": PROFESSOR})
    assert "Já existe uma conta" in texto(r)


def test_excluir_conta_anonimiza_e_exige_confirmacao(client):
    enviar(client, "/cadastro", {"nome": "Vai Sair", "email": "saira@exemplo.com", "senha": "senha1234", "confirmar": "senha1234"})
    entrar(client, "saira@exemplo.com", "senha1234")
    uid = db.consultar_um("SELECT id_usuario FROM usuario WHERE email=%s", ("saira@exemplo.com",))["id_usuario"]
    sem = enviar(client, "/perfil/excluir", {"confirmar": "nao"})
    assert sem.status_code == 302 and db.consultar_um("SELECT ativo FROM usuario WHERE id_usuario=%s", (uid,))["ativo"] == 1
    com = enviar(client, "/perfil/excluir", {"confirmar": "excluir"})
    assert com.status_code == 302
    u = db.consultar_um("SELECT ativo, anonimizado_em, nome, email FROM usuario WHERE id_usuario=%s", (uid,))
    assert u["ativo"] == 0 and u["anonimizado_em"] is not None and u["nome"] == "Usuario removido"
    assert "saira" not in u["email"]
    assert entrar(client, "saira@exemplo.com", "senha1234").status_code == 200   # nao entra mais


def test_administrador_nao_exclui_a_propria_conta(client):
    entrar(client, ADMIN)
    enviar(client, "/perfil/excluir", {"confirmar": "EXCLUIR"})
    assert db.consultar_um("SELECT ativo FROM usuario WHERE email=%s", (ADMIN,))["ativo"] == 1


# ------------------------------------------------------------------ turmas
def test_turmas_publicas_listam_todas(client):
    html = texto(client.get("/turmas"))
    total = db.consultar_um("SELECT COUNT(*) n FROM turma")["n"]      # outros testes tambem criam turmas
    assert "Inglês A1 Manhã" in html and "Espanhol A1 Intensivo" in html and f"{total} turma(s)" in html


def test_turmas_filtro_por_idioma_nivel_e_busca(client):
    es = texto(client.get("/turmas?idioma=2"))
    assert "Espanhol A1 Manhã" in es and "Inglês B1 Noite" not in es
    b1 = texto(client.get("/turmas?nivel=B1"))
    assert "Inglês B1 Noite" in b1 and "Espanhol B1 Noite" in b1 and "Inglês A1 Manhã" not in b1
    busca = texto(client.get("/turmas?q=Carlos"))
    assert "Inglês A1 Manhã" in busca and "Espanhol A1 Manhã" not in busca
    assert "Nenhuma turma encontrada" in texto(client.get("/turmas?q=zzzz"))


def test_turmas_mostra_lotada_e_ignora_filtros_maliciosos(client):
    assert "Lotada" in texto(client.get("/turmas?q=Intensivo"))
    r = client.get("/turmas?nivel=A1'%20OR%201=1--&idioma=abc&q=%25%27")
    assert r.status_code == 200                                         # nada de erro 500 / SQL injetado


# ---------------------------------------------------------------- conteudos
def test_conteudos_exigem_login(client):
    r = client.get("/conteudos")
    assert r.status_code == 302 and "/login" in r.headers["Location"]


def test_conteudos_listam_e_filtram(client):
    entrar(client, ALUNO)
    todos = texto(client.get("/conteudos"))
    assert "6 conteúdo(s)" in todos
    es = texto(client.get("/conteudos?idioma=2"))
    assert "3 conteúdo(s)" in es
    a1 = texto(client.get("/conteudos?nivel=A1"))
    assert "Nenhum conteúdo" not in a1 and "conteúdo(s) encontrado" in a1


def test_menu_mostra_links_conforme_login(client):
    assert "Criar conta" in texto(client.get("/")) and "/conteudos" not in texto(client.get("/"))
    entrar(client, PROFESSOR)
    html = texto(client.get("/"))
    assert "/conteudos" in html and "/perfil" in html and "Criar conta" not in html
