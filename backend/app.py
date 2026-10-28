import os
import re
import secrets
from functools import wraps

from dotenv import load_dotenv

load_dotenv()  # le o arquivo .env (se existir) antes de qualquer configuracao

from flask import Flask, abort, flash, redirect, render_template, request, session, url_for  # noqa: E402
from mysql.connector import Error  # noqa: E402
from werkzeug.security import check_password_hash  # noqa: E402

import db  # noqa: E402

app = Flask(__name__)
# Sem FLASK_SECRET_KEY no .env, uma chave aleatoria e gerada a cada inicio (o login cai ao reiniciar).
app.secret_key = os.getenv("FLASK_SECRET_KEY") or secrets.token_hex(32)
app.config.update(SESSION_COOKIE_HTTPONLY=True, SESSION_COOKIE_SAMESITE="Lax")

NIVEIS_VALIDOS = ("A1", "A2", "B1", "B2", "C1", "C2")


# ----------------------------------------------------------------------
# Seguranca: CSRF e controle de acesso
# ----------------------------------------------------------------------
def token_csrf():
    if "csrf_token" not in session:
        session["csrf_token"] = secrets.token_hex(16)
    return session["csrf_token"]


app.jinja_env.globals["csrf_token"] = token_csrf


@app.context_processor
def variaveis_globais():
    return {"eh_admin": session.get("tipo") == "administrador"}


@app.before_request
def verificar_csrf():
    if request.method == "POST":
        enviado = request.form.get("csrf_token", "").encode()
        esperado = session.get("csrf_token", "").encode()
        if not esperado or not secrets.compare_digest(enviado, esperado):
            abort(400)


def perfil_requerido(*tipos):
    """Exige login e um dos perfis (tipo) informados."""
    def decorador(funcao):
        @wraps(funcao)
        def wrapper(*args, **kwargs):
            if not session.get("id_usuario"):
                flash("Faça login para acessar essa página.", "erro")
                return redirect(url_for("login"))
            if session.get("tipo") not in tipos:
                flash("Você não tem permissão para acessar essa página.", "erro")
                return redirect(url_for("home"))
            return funcao(*args, **kwargs)
        return wrapper
    return decorador


@app.errorhandler(400)
def erro_400(_):
    return render_template("erro.html", mensagem="Requisição inválida ou sessão expirada. Volte e tente de novo."), 400


@app.errorhandler(Error)
def erro_banco(erro):
    app.logger.exception("Erro de banco de dados: %s", erro)
    return render_template(
        "erro.html",
        mensagem="Não foi possível acessar o banco de dados. Confira se o MySQL está ligado e se o arquivo .env está correto.",
    ), 503


# ----------------------------------------------------------------------
# Inicio e autenticacao (login consulta a tabela usuario)
# ----------------------------------------------------------------------
@app.route("/")
def home():
    idiomas = db.consultar("SELECT id_idioma, nome, codigo FROM idioma ORDER BY nome")
    return render_template("home.html", idiomas=idiomas)


@app.route("/login", methods=["GET", "POST"])
def login():
    if request.method == "POST":
        email = request.form.get("email", "").strip().lower()
        senha = request.form.get("senha", "")
        usuario = db.consultar_um(
            "SELECT id_usuario, nome, email, senha_hash, tipo, ativo FROM usuario WHERE email = %s",
            (email,),
        )
        if usuario and usuario["ativo"] and check_password_hash(usuario["senha_hash"], senha):
            session.clear()
            session["id_usuario"] = usuario["id_usuario"]
            session["nome"] = usuario["nome"]
            session["email"] = usuario["email"]
            session["tipo"] = usuario["tipo"]
            flash(f"Bem-vindo(a), {usuario['nome']}.", "sucesso")
            return redirect(url_for("listar_idiomas"))
        flash("E-mail ou senha inválidos.", "erro")
    return render_template("login.html")


@app.route("/logout", methods=["POST"])
def logout():
    session.clear()
    flash("Você saiu do sistema.", "sucesso")
    return redirect(url_for("home"))


# ----------------------------------------------------------------------
# Idiomas
# ----------------------------------------------------------------------
def ler_formulario_idioma():
    nome = request.form.get("nome", "").strip()
    codigo = request.form.get("codigo", "").strip().upper()
    valores = {"nome": nome, "codigo": codigo}
    valido = bool(nome) and len(nome) <= 30 and re.fullmatch(r"[A-Z]{2}", codigo) is not None
    return valores, valido


@app.route("/idiomas")
def listar_idiomas():
    idiomas = db.consultar("SELECT id_idioma, nome, codigo FROM idioma ORDER BY nome")
    return render_template("idiomas.html", idiomas=idiomas)


@app.route("/idiomas/novo", methods=["GET", "POST"])
@perfil_requerido("administrador")
def cadastrar_idioma():
    valores = {"nome": "", "codigo": ""}
    if request.method == "POST":
        valores, valido = ler_formulario_idioma()
        if not valido:
            flash("Informe um nome (até 30 caracteres) e um código de duas letras, como EN ou ES.", "erro")
        else:
            try:
                db.executar("INSERT INTO idioma (nome, codigo) VALUES (%s, %s)",
                            (valores["nome"], valores["codigo"]))
                flash("Idioma cadastrado com sucesso.", "sucesso")
                return redirect(url_for("listar_idiomas"))
            except Error as erro:
                flash(db.mensagem_erro(erro, duplicado="Já existe um idioma com esse nome ou código."), "erro")
    return render_template("formulario_idioma.html", idioma=valores, editando=False)


@app.route("/idiomas/<int:id_idioma>/editar", methods=["GET", "POST"])
@perfil_requerido("administrador")
def editar_idioma(id_idioma):
    atual = db.consultar_um("SELECT id_idioma, nome, codigo FROM idioma WHERE id_idioma = %s", (id_idioma,))
    if not atual:
        flash("Idioma não encontrado.", "erro")
        return redirect(url_for("listar_idiomas"))
    valores = atual
    if request.method == "POST":
        valores, valido = ler_formulario_idioma()
        if not valido:
            flash("Informe um nome (até 30 caracteres) e um código de duas letras.", "erro")
        else:
            try:
                db.executar("UPDATE idioma SET nome = %s, codigo = %s WHERE id_idioma = %s",
                            (valores["nome"], valores["codigo"], id_idioma))
                flash("Idioma atualizado com sucesso.", "sucesso")
                return redirect(url_for("listar_idiomas"))
            except Error as erro:
                flash(db.mensagem_erro(erro, duplicado="Já existe um idioma com esse nome ou código."), "erro")
    return render_template("formulario_idioma.html", idioma=valores, editando=True, id_idioma=id_idioma)


@app.route("/idiomas/<int:id_idioma>/excluir", methods=["POST"])
@perfil_requerido("administrador")
def excluir_idioma(id_idioma):
    try:
        linhas, _ = db.executar("DELETE FROM idioma WHERE id_idioma = %s", (id_idioma,))
        flash("Idioma excluído com sucesso." if linhas else "Idioma não encontrado.",
              "sucesso" if linhas else "erro")
    except Error as erro:
        flash(db.mensagem_erro(erro, em_uso="Não é possível excluir: o idioma está vinculado a turmas ou professores."), "erro")
    return redirect(url_for("listar_idiomas"))


# ----------------------------------------------------------------------
# Niveis (A1..C2 - independentes de idioma, como no 01_schema.sql)
# ----------------------------------------------------------------------
def ler_formulario_nivel():
    codigo = request.form.get("codigo", "").strip().upper()
    descricao = request.form.get("descricao", "").strip()
    valores = {"codigo": codigo, "descricao": descricao}
    valido = codigo in NIVEIS_VALIDOS and 0 < len(descricao) <= 60
    return valores, valido


@app.route("/niveis")
def listar_niveis():
    niveis = db.consultar("SELECT id_nivel, codigo, descricao FROM nivel ORDER BY codigo")
    return render_template("niveis.html", niveis=niveis)


@app.route("/niveis/novo", methods=["GET", "POST"])
@perfil_requerido("administrador")
def cadastrar_nivel():
    valores = {"codigo": "", "descricao": ""}
    if request.method == "POST":
        valores, valido = ler_formulario_nivel()
        if not valido:
            flash("Escolha um nível (A1 a C2) e informe a descrição (até 60 caracteres).", "erro")
        else:
            try:
                db.executar("INSERT INTO nivel (codigo, descricao) VALUES (%s, %s)",
                            (valores["codigo"], valores["descricao"]))
                flash("Nível cadastrado com sucesso.", "sucesso")
                return redirect(url_for("listar_niveis"))
            except Error as erro:
                flash(db.mensagem_erro(erro, duplicado="Esse nível já está cadastrado."), "erro")
    return render_template("formulario_nivel.html", nivel=valores, editando=False, niveis_validos=NIVEIS_VALIDOS)


@app.route("/niveis/<int:id_nivel>/editar", methods=["GET", "POST"])
@perfil_requerido("administrador")
def editar_nivel(id_nivel):
    atual = db.consultar_um("SELECT id_nivel, codigo, descricao FROM nivel WHERE id_nivel = %s", (id_nivel,))
    if not atual:
        flash("Nível não encontrado.", "erro")
        return redirect(url_for("listar_niveis"))
    valores = atual
    if request.method == "POST":
        valores, valido = ler_formulario_nivel()
        if not valido:
            flash("Escolha um nível (A1 a C2) e informe a descrição (até 60 caracteres).", "erro")
        else:
            try:
                db.executar("UPDATE nivel SET codigo = %s, descricao = %s WHERE id_nivel = %s",
                            (valores["codigo"], valores["descricao"], id_nivel))
                flash("Nível atualizado com sucesso.", "sucesso")
                return redirect(url_for("listar_niveis"))
            except Error as erro:
                flash(db.mensagem_erro(erro, duplicado="Esse nível já está cadastrado."), "erro")
    return render_template("formulario_nivel.html", nivel=valores, editando=True,
                           id_nivel=id_nivel, niveis_validos=NIVEIS_VALIDOS)


@app.route("/niveis/<int:id_nivel>/excluir", methods=["POST"])
@perfil_requerido("administrador")
def excluir_nivel(id_nivel):
    try:
        linhas, _ = db.executar("DELETE FROM nivel WHERE id_nivel = %s", (id_nivel,))
        flash("Nível excluído com sucesso." if linhas else "Nível não encontrado.",
              "sucesso" if linhas else "erro")
    except Error as erro:
        flash(db.mensagem_erro(erro, em_uso="Não é possível excluir: o nível está em uso por turmas, conteúdos ou desafios."), "erro")
    return redirect(url_for("listar_niveis"))


if __name__ == "__main__":
    app.run(debug=os.getenv("FLASK_DEBUG") == "1")
