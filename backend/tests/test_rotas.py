import re

import db
from conftest import ADMIN, ALUNO, PROFESSOR, enviar, entrar


def texto(resposta):
    return resposta.get_data(as_text=True)


def id_do_idioma(client, nome):
    achou = re.search(re.escape(nome) + r"</td>.*?/idiomas/(\d+)/editar", texto(client.get("/idiomas")), re.S)
    return achou.group(1) if achou else None


# ---------------- paginas publicas ----------------
def test_home_lista_idiomas_do_banco(client):
    r = client.get("/")
    assert r.status_code == 200
    assert "Inglês" in texto(r) and "Espanhol" in texto(r)


def test_listas_publicas(client):
    assert "Espanhol" in texto(client.get("/idiomas"))
    html = texto(client.get("/niveis"))
    assert "A1" in html and "C2" in html


def test_botoes_de_admin_nao_aparecem_sem_login(client):
    assert "Cadastrar idioma" not in texto(client.get("/idiomas"))


# ---------------- seguranca ----------------
def test_post_sem_token_csrf_e_recusado(client):
    assert client.post("/login", data={"email": ADMIN, "senha": "x"}).status_code == 400


def test_rotas_de_admin_exigem_login(client):
    for url in ("/idiomas/novo", "/niveis/novo", "/idiomas/1/editar", "/niveis/1/editar"):
        r = client.get(url)
        assert r.status_code == 302 and r.headers["Location"].endswith("/login"), url
    assert enviar(client, "/idiomas/1/excluir").headers["Location"].endswith("/login")


def test_professor_e_aluno_nao_acessam_area_admin(client):
    for email in (PROFESSOR, ALUNO):
        c = client.application.test_client()
        assert entrar(c, email).status_code == 302
        r = c.get("/idiomas/novo")
        assert r.status_code == 302 and r.headers["Location"].endswith("/"), email


# ---------------- login (tabela usuario) ----------------
def test_login_senha_errada(client):
    assert "inválidos" in texto(entrar(client, ADMIN, "errada"))


def test_login_email_inexistente(client):
    assert "inválidos" in texto(entrar(client, "ninguem@exemplo.com"))


def test_login_admin_do_seed_vai_para_idiomas(client):
    r = entrar(client, ADMIN)
    assert r.status_code == 302 and r.headers["Location"].endswith("/idiomas")
    assert "administrador" in texto(client.get("/idiomas"))


def test_usuario_anonimizado_nao_loga(client):
    # simula conta removida (RF10): ativo = FALSE e senha_hash = '!'
    db.executar("INSERT INTO usuario (nome,email,senha_hash,tipo,ativo,anonimizado_em) "
                "VALUES ('Usuario removido','removido+9999@anonimo.invalid','!','aluno',FALSE,NOW())")
    try:
        assert "inválidos" in texto(entrar(client, "removido+9999@anonimo.invalid", "!"))
    finally:
        db.executar("DELETE FROM usuario WHERE email='removido+9999@anonimo.invalid'")


def test_logout(admin):
    r = enviar(admin, "/logout")
    assert r.status_code == 302
    assert admin.get("/idiomas/novo").status_code == 302


# ---------------- CRUD de idiomas ----------------
def test_crud_idioma(admin):
    try:
        r = enviar(admin, "/idiomas/novo", {"nome": "Francês", "codigo": "fr"})  # minusculo -> vira FR
        assert r.status_code == 302
        id_fr = id_do_idioma(admin, "Francês")
        assert id_fr and "FR" in texto(admin.get("/idiomas"))

        assert "Já existe" in texto(enviar(admin, "/idiomas/novo", {"nome": "Francês", "codigo": "XX"}))
        assert "Já existe" in texto(enviar(admin, "/idiomas/novo", {"nome": "Outro", "codigo": "FR"}))
        assert "duas letras" in texto(enviar(admin, "/idiomas/novo", {"nome": "X", "codigo": "1"}))
        assert "duas letras" in texto(enviar(admin, "/idiomas/novo", {"nome": "X" * 31, "codigo": "ZZ"}))

        assert "Francês" in texto(admin.get(f"/idiomas/{id_fr}/editar"))
        assert enviar(admin, f"/idiomas/{id_fr}/editar", {"nome": "Francês B", "codigo": "FR"}).status_code == 302
        assert id_do_idioma(admin, "Francês B") == id_fr

        assert enviar(admin, f"/idiomas/{id_fr}/excluir").status_code == 302
        assert id_do_idioma(admin, "Francês B") is None
    finally:
        db.executar("DELETE FROM idioma WHERE codigo='FR'")


def test_editar_e_excluir_idioma_inexistente(admin):
    assert admin.get("/idiomas/99999/editar").status_code == 302
    r = enviar(admin, "/idiomas/99999/excluir")
    assert "não encontrado" in texto(admin.get(r.headers["Location"]))


def test_banco_impede_excluir_idioma_em_uso(admin):
    r = enviar(admin, "/idiomas/1/excluir")  # Ingles: tem turmas/professores
    assert "Não é possível excluir" in texto(admin.get(r.headers["Location"]))
    assert "Inglês" in texto(admin.get("/idiomas"))


# ---------------- CRUD de niveis ----------------
def test_nivel_duplicado_e_invalido(admin):
    assert "já está cadastrado" in texto(enviar(admin, "/niveis/novo", {"codigo": "A1", "descricao": "Outra"}))
    assert "Escolha um nível" in texto(enviar(admin, "/niveis/novo", {"codigo": "Z9", "descricao": "x"}))
    assert "Escolha um nível" in texto(enviar(admin, "/niveis/novo", {"codigo": "A1", "descricao": "x" * 61}))


def test_editar_nivel_e_restaurar(admin):
    linha = db.consultar_um("SELECT id_nivel, descricao FROM nivel WHERE codigo='C2'")
    try:
        r = enviar(admin, f"/niveis/{linha['id_nivel']}/editar", {"codigo": "C2", "descricao": "Descrição de teste"})
        assert r.status_code == 302
        assert "Descrição de teste" in texto(admin.get("/niveis"))
    finally:
        db.executar("UPDATE nivel SET descricao=%s WHERE id_nivel=%s", (linha["descricao"], linha["id_nivel"]))


def test_banco_impede_excluir_nivel_em_uso(admin):
    id_a1 = db.consultar_um("SELECT id_nivel FROM nivel WHERE codigo='A1'")["id_nivel"]
    r = enviar(admin, f"/niveis/{id_a1}/excluir")
    assert "Não é possível excluir" in texto(admin.get(r.headers["Location"]))
    assert "A1" in texto(admin.get("/niveis"))
