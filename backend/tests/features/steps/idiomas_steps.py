
from behave import given, when, then
import db


@given('que o administrador entrou no sistema')
def login_admin(context):
    with context.client.session_transaction() as sessao:
        sessao["csrf_token"] = "token-login-bdd"

    resposta = context.client.post(
        "/login",
        data={
            "email": "admin@virtualingua.com.br",
            "senha": "Senha@123",
            "csrf_token": "token-login-bdd"
        }
    )

    assert resposta.status_code == 302, (
        f"Falha no login: HTTP {resposta.status_code}"
    )

    with context.client.session_transaction() as sessao:
        assert sessao.get("tipo") == "administrador"
        sessao["csrf_token"] = "token-cadastro-bdd"


@when('cadastra o idioma "{nome}" com código "{codigo}"')
def cadastrar(context, nome, codigo):
    context.nome_teste = nome

    context.resposta = context.client.post(
        "/idiomas/novo",
        data={
            "nome": nome,
            "codigo": codigo,
            "csrf_token": "token-cadastro-bdd"
        },
        follow_redirects=True
    )

    assert context.resposta.status_code == 200, (
        f"Erro no cadastro: HTTP {context.resposta.status_code}"
    )


@then('o idioma "{nome}" deve existir no banco')
def existe(context, nome):
    idioma = db.consultar_um(
        "SELECT id_idioma FROM idioma WHERE nome=%s",
        (nome,)
    )

    assert idioma is not None, (
        f"O idioma '{nome}' não foi encontrado no banco."
    )

    db.executar(
        "DELETE FROM idioma WHERE id_idioma=%s",
        (idioma["id_idioma"],)
    )


@then('o cadastro deve ser recusado por duplicidade')
def duplicado(context):
    assert context.resposta.status_code == 200

    conteudo = context.resposta.get_data(as_text=True)

    assert "Já existe" in conteudo, (
        "O sistema não apresentou a mensagem de duplicidade."
    )


@then('o idioma "{nome}" não deve existir no banco')
def nao_existe(context, nome):
    idioma = db.consultar_um(
        "SELECT id_idioma FROM idioma WHERE nome=%s",
        (nome,)
    )

    assert idioma is None, (
        f"O idioma '{nome}' foi cadastrado indevidamente."
    )
