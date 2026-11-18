"""Testes isolados: somente virtualingua_test."""
import os
import sys

import pytest

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from test_support import configurar_ambiente, recriar_banco
configurar_ambiente()
from app import app as flask_app  # noqa: E402

@pytest.fixture(scope="session", autouse=True)
def banco_isolado():
    recriar_banco()

SENHA_SEED = "Senha@123"
ADMIN = "admin@virtualingua.com.br"
PROFESSOR = "carlos.mendes@virtualingua.com.br"
ALUNO = "ana.costa@exemplo.com"


@pytest.fixture
def client():
    return flask_app.test_client()


def enviar(client, url, dados=None):
    """POST com o token CSRF valido (o token fica na sessao do cliente)."""
    with client.session_transaction() as sessao:
        sessao["csrf_token"] = "token-de-teste"
    corpo = dict(dados or {})
    corpo["csrf_token"] = "token-de-teste"
    return client.post(url, data=corpo)


def entrar(client, email, senha=SENHA_SEED):
    return enviar(client, "/login", {"email": email, "senha": senha})


@pytest.fixture
def admin(client):
    resposta = entrar(client, ADMIN)
    assert resposta.status_code == 302
    return client
