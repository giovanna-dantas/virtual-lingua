"""Areas por perfil (aluno, professor, administrador) - Semana 3, front-end.

As regras de negocio continuam no banco: aqui so chamamos as procedures
(sp_matricular_aluno, sp_registrar_pontuacao), as views e fazemos
INSERT/UPDATE/DELETE que passam pelos triggers e constraints.
Registrado em app.py por registrar(app, perfil_requerido, filtros_catalogo).
"""
import os
import re
from datetime import date, timedelta
from decimal import Decimal, InvalidOperation

from flask import flash, redirect, render_template, request, session, url_for
from mysql.connector import Error
from werkzeug.security import generate_password_hash

import db

PRECO_MATRICULA = Decimal(os.getenv("PRECO_MATRICULA", "300.00"))
DIAS_VENCIMENTO = 7
REGEX_EMAIL = r"[^@\s]+@[^@\s]+\.[^@\s]+"
ADMIN, PROFESSOR, ALUNO = "administrador", "professor", "aluno"


def _inteiro(nome, minimo=1):
    """Le um inteiro do formulario; devolve None se invalido."""
    try:
        valor = int(request.form.get(nome, "").strip())
    except ValueError:
        return None
    return valor if valor >= minimo else None


def _idiomas():
    return db.consultar("SELECT id_idioma, nome FROM idioma ORDER BY nome")


def _niveis():
    return db.consultar("SELECT id_nivel, codigo, descricao FROM nivel ORDER BY codigo")


def _professores():
    return db.consultar("SELECT id_usuario, nome FROM usuario WHERE tipo='professor' AND ativo=TRUE ORDER BY nome")


def registrar(app, perfil_requerido, filtros_catalogo):
    # ------------------------------------------------------------------ painel
    @app.route("/painel")
    @perfil_requerido(ALUNO, PROFESSOR, ADMIN)
    def painel():
        uid, tipo = session["id_usuario"], session["tipo"]
        um = db.consultar_um
        if tipo == ALUNO:
            dados = {
                "ativas": um("SELECT COUNT(*) n FROM matricula WHERE id_aluno=%s AND status='ativa'", (uid,))["n"],
                "pendentes": um("SELECT COUNT(*) n FROM matricula WHERE id_aluno=%s AND status='pendente'", (uid,))["n"],
                "a_pagar": um("SELECT COUNT(*) n FROM pagamento p JOIN matricula m USING (id_matricula) "
                              "WHERE m.id_aluno=%s AND p.status IN ('pendente','atrasado')", (uid,))["n"],
                "desafios": um("SELECT COUNT(*) n FROM pontuacao WHERE id_aluno=%s", (uid,))["n"],
                "media": um("SELECT fn_media_aluno(%s) m", (uid,))["m"],
            }
        elif tipo == PROFESSOR:
            dados = {
                "turmas": um("SELECT COUNT(*) n FROM turma WHERE id_professor=%s", (uid,))["n"],
                "alunos": um("SELECT COUNT(*) n FROM matricula m JOIN turma t USING (id_turma) "
                             "WHERE t.id_professor=%s AND m.status IN ('pendente','ativa')", (uid,))["n"],
                "conteudos": um("SELECT COUNT(*) n FROM conteudo WHERE id_professor=%s", (uid,))["n"],
                "desafios": um("SELECT COUNT(*) n FROM desafio d JOIN conteudo c USING (id_conteudo) "
                               "WHERE c.id_professor=%s", (uid,))["n"],
            }
        else:
            dados = {
                "usuarios": um("SELECT COUNT(*) n FROM usuario WHERE ativo=TRUE")["n"],
                "turmas": um("SELECT COUNT(*) n FROM turma")["n"],
                "pendentes": um("SELECT COUNT(*) n FROM matricula WHERE status='pendente'")["n"],
                "a_receber": um("SELECT COUNT(*) n FROM vw_pagamentos_pendentes")["n"],
                "vagas": um("SELECT COALESCE(SUM(vagas_disponiveis),0) n FROM vw_turmas_por_idioma")["n"],
            }
        return render_template("painel.html", d=dados)

    # ------------------------------------------------------------------- aluno
    @app.route("/turmas/<int:id_turma>/matricular", methods=["POST"])
    @perfil_requerido(ALUNO)
    def matricular_se(id_turma):
        vencimento = date.today() + timedelta(days=DIAS_VENCIMENTO)
        try:
            r = db.chamar_procedure_saida("sp_matricular_aluno",
                                          (session["id_usuario"], id_turma, PRECO_MATRICULA, vencimento, 0, 0))
        except Error as erro:
            flash(db.mensagem_erro(erro, duplicado="Você já está matriculado nessa turma.",
                                   padrao="Não foi possível concluir a matrícula."), "erro")
            return redirect(url_for("listar_turmas"))
        flash(f"Matrícula nº {r[4]} realizada. O pagamento de R$ {PRECO_MATRICULA:.2f} vence em "
              f"{vencimento:%d/%m/%Y}; a matrícula é ativada quando o pagamento for confirmado.", "sucesso")
        return redirect(url_for("minhas_matriculas"))

    @app.route("/minhas-matriculas")
    @perfil_requerido(ALUNO)
    def minhas_matriculas():
        linhas = db.consultar(
            "SELECT m.id_matricula, m.status, m.data_matricula, t.nome AS turma, i.nome AS idioma, "
            "n.codigo AS nivel, p.valor, p.data_vencimento, p.data_pagamento, p.status AS pagamento "
            "FROM matricula m JOIN turma t ON t.id_turma=m.id_turma JOIN idioma i ON i.id_idioma=t.id_idioma "
            "JOIN nivel n ON n.id_nivel=t.id_nivel LEFT JOIN pagamento p ON p.id_matricula=m.id_matricula "
            "WHERE m.id_aluno=%s ORDER BY m.data_matricula DESC, m.id_matricula DESC", (session["id_usuario"],))
        return render_template("minhas_matriculas.html", matriculas=linhas)

    def _cancelar(id_matricula, id_aluno=None):
        """Cancela a matricula e os pagamentos em aberto, numa so transacao."""
        extra, params = ("", (id_matricula,)) if id_aluno is None else (" AND id_aluno=%s", (id_matricula, id_aluno))
        with db.transacao() as cnx:
            cur = cnx.cursor()
            try:
                cur.execute("UPDATE matricula SET status='cancelada' WHERE id_matricula=%s" + extra, params)
                afetadas = cur.rowcount
                if afetadas:
                    cur.execute("UPDATE pagamento SET status='cancelado' WHERE id_matricula=%s "
                                "AND status IN ('pendente','atrasado')", (id_matricula,))
            finally:
                cur.close()
        return afetadas

    @app.route("/matriculas/<int:id_matricula>/cancelar", methods=["POST"])
    @perfil_requerido(ALUNO, ADMIN)
    def cancelar_matricula(id_matricula):
        destino = "minhas_matriculas" if session["tipo"] == ALUNO else "admin_matriculas"
        try:
            afetadas = _cancelar(id_matricula, session["id_usuario"] if session["tipo"] == ALUNO else None)
            flash("Matrícula cancelada." if afetadas else "Matrícula não encontrada.", "sucesso" if afetadas else "erro")
        except Error as erro:
            flash(db.mensagem_erro(erro, padrao="Não foi possível cancelar a matrícula."), "erro")
        return redirect(url_for(destino))

    @app.route("/desafios")
    @perfil_requerido(ALUNO)
    def listar_desafios():
        q, idioma, nivel = filtros_catalogo()
        condicoes, params = [], [session["id_usuario"], session["id_usuario"]]
        if q:
            condicoes.append("(d.titulo LIKE %s OR c.titulo LIKE %s)")
            params += [f"%{q}%", f"%{q}%"]
        if idioma:
            condicoes.append("c.id_idioma = %s")
            params.append(idioma)
        if nivel:
            condicoes.append("n.codigo = %s")
            params.append(nivel)
        onde = (" WHERE " + " AND ".join(condicoes)) if condicoes else ""
        desafios = db.consultar(
            "SELECT d.id_desafio, d.titulo, d.descricao, d.pontuacao_maxima, c.titulo AS conteudo, i.nome AS idioma, "
            "n.codigo AS nivel, p.pontos, EXISTS(SELECT 1 FROM matricula m JOIN turma t ON t.id_turma=m.id_turma "
            "WHERE m.id_aluno=%s AND m.status IN ('ativa','concluida') AND t.id_idioma=c.id_idioma) AS liberado "
            "FROM desafio d JOIN conteudo c ON c.id_conteudo=d.id_conteudo JOIN idioma i ON i.id_idioma=c.id_idioma "
            "JOIN nivel n ON n.id_nivel=c.id_nivel LEFT JOIN pontuacao p ON p.id_desafio=d.id_desafio AND p.id_aluno=%s"
            + onde + " ORDER BY i.nome, n.codigo, c.titulo, d.titulo", tuple(params))
        media = db.consultar_um("SELECT fn_media_aluno(%s) m", (session["id_usuario"],))["m"]
        return render_template("desafios.html", desafios=desafios, media=media,
                               filtros={"q": q, "idioma": idioma, "nivel": nivel}, idiomas=_idiomas(),
                               niveis=[n["codigo"] for n in _niveis()])

    def _mensagem_pontuacao(resultado):
        return {"INSERIDA": "Pontuação registrada.",
                "ATUALIZADA": "Nova nota maior que a anterior: pontuação atualizada.",
                "MANTIDA": "Você já tinha nota maior ou igual; a melhor nota foi mantida."}.get(resultado, "Pontuação processada.")

    def _ler_pontos():
        try:
            pontos = Decimal(request.form.get("pontos", "").replace(",", ".").strip())
        except InvalidOperation:
            return None
        return pontos if pontos >= 0 else None

    @app.route("/desafios/<int:id_desafio>/pontuar", methods=["POST"])
    @perfil_requerido(ALUNO)
    def pontuar_desafio(id_desafio):
        pontos = _ler_pontos()
        if pontos is None:
            flash("Informe uma pontuação válida (número maior ou igual a zero).", "erro")
            return redirect(url_for("listar_desafios"))
        try:
            r = db.chamar_procedure_saida("sp_registrar_pontuacao", (session["id_usuario"], id_desafio, pontos, ""))
            flash(_mensagem_pontuacao(r[3]), "sucesso")
        except Error as erro:
            flash(db.mensagem_erro(erro, padrao="Não foi possível registrar a pontuação."), "erro")
        return redirect(url_for("listar_desafios"))

    @app.route("/ranking")
    @perfil_requerido(ALUNO, PROFESSOR, ADMIN)
    def ranking():
        idioma = request.args.get("idioma", type=int)
        onde, params = ("WHERE id_idioma=%s", (idioma,)) if idioma else ("", ())
        linhas = db.consultar("SELECT id_idioma, idioma, id_aluno, aluno, total_pontos, desafios_realizados, posicao "
                              "FROM vw_ranking_por_idioma " + onde + " ORDER BY idioma, posicao, aluno", params)
        grupos = {}
        for l in linhas:
            if l["posicao"] <= 10:
                grupos.setdefault(l["idioma"], []).append(l)
        return render_template("ranking.html", grupos=grupos, idiomas=_idiomas(), idioma=idioma)

    # ------------------------------------------------------- admin: usuarios
    @app.route("/admin/usuarios")
    @perfil_requerido(ADMIN)
    def admin_usuarios():
        tipo = request.args.get("tipo", "")
        onde, params = ("WHERE u.tipo=%s", (tipo,)) if tipo in (ALUNO, PROFESSOR, ADMIN) else ("", ())
        usuarios = db.consultar(
            "SELECT u.id_usuario, u.nome, u.email, u.tipo, u.ativo, u.criado_em, "
            "(SELECT GROUP_CONCAT(i.nome ORDER BY i.nome SEPARATOR ', ') FROM professor_idioma pi "
            " JOIN idioma i ON i.id_idioma=pi.id_idioma WHERE pi.id_professor=u.id_usuario) AS idiomas "
            "FROM usuario u " + onde + " ORDER BY u.tipo, u.nome", params)
        return render_template("admin_usuarios.html", usuarios=usuarios, tipo=tipo)

    @app.route("/admin/usuarios/novo", methods=["GET", "POST"])
    @perfil_requerido(ADMIN)
    def admin_novo_usuario():
        valores = {"nome": "", "email": "", "tipo": PROFESSOR, "idiomas": []}
        if request.method == "POST":
            nome = request.form.get("nome", "").strip()
            email = request.form.get("email", "").strip().lower()
            tipo = request.form.get("tipo", "")
            senha = request.form.get("senha", "")
            idiomas = [int(x) for x in request.form.getlist("idiomas") if x.isdigit()]
            valores = {"nome": nome, "email": email, "tipo": tipo, "idiomas": idiomas}
            if not nome or len(nome) > 100:
                flash("Informe o nome (até 100 caracteres).", "erro")
            elif not re.fullmatch(REGEX_EMAIL, email) or len(email) > 120:
                flash("Informe um e-mail válido.", "erro")
            elif tipo not in (ALUNO, PROFESSOR, ADMIN):
                flash("Escolha o tipo de usuário.", "erro")
            elif len(senha) < 8:
                flash("A senha deve ter pelo menos 8 caracteres.", "erro")
            elif tipo == PROFESSOR and not idiomas:
                flash("Marque ao menos um idioma que o professor leciona.", "erro")
            else:
                operacoes = [("INSERT INTO usuario (nome, email, senha_hash, tipo) VALUES (%s,%s,%s,%s)",
                              (nome, email, generate_password_hash(senha), tipo))]
                try:
                    with db.transacao() as cnx:
                        cur = cnx.cursor()
                        cur.execute(*operacoes[0])
                        novo = cur.lastrowid
                        if tipo == PROFESSOR:
                            for i in idiomas:
                                cur.execute("INSERT INTO professor_idioma (id_professor, id_idioma) VALUES (%s,%s)", (novo, i))
                        cur.close()
                    flash(f"Usuário {nome} ({tipo}) criado.", "sucesso")
                    return redirect(url_for("admin_usuarios"))
                except Error as erro:
                    flash(db.mensagem_erro(erro, duplicado="Já existe uma conta com esse e-mail."), "erro")
        return render_template("usuario_form.html", v=valores, idiomas=_idiomas())

    # ---------------------------------------------------------- admin: turmas
    def _ler_turma():
        v = {"nome": request.form.get("nome", "").strip(), "id_idioma": _inteiro("id_idioma"),
             "id_nivel": _inteiro("id_nivel"), "id_professor": _inteiro("id_professor"),
             "carga_horaria": _inteiro("carga_horaria"), "vagas": _inteiro("vagas")}
        if not v["nome"] or len(v["nome"]) > 80:
            return v, "Informe o nome da turma (até 80 caracteres)."
        if not v["id_idioma"] or not v["id_nivel"]:
            return v, "Escolha o idioma e o nível."
        if not v["carga_horaria"] or not v["vagas"]:
            return v, "Carga horária e vagas devem ser números maiores que zero."
        return v, None

    def _form_turma(v, titulo, acao):
        return render_template("turma_form.html", v=v, titulo=titulo, acao=acao, idiomas=_idiomas(),
                               niveis=_niveis(), professores=_professores())

    @app.route("/turmas/nova", methods=["GET", "POST"])
    @perfil_requerido(ADMIN)
    def nova_turma():
        v = {"nome": "", "id_idioma": None, "id_nivel": None, "id_professor": None, "carga_horaria": 40, "vagas": 20}
        if request.method == "POST":
            v, erro_campo = _ler_turma()
            if erro_campo:
                flash(erro_campo, "erro")
            else:
                try:
                    db.executar("INSERT INTO turma (nome,id_idioma,id_nivel,id_professor,carga_horaria,vagas) "
                                "VALUES (%s,%s,%s,%s,%s,%s)",
                                (v["nome"], v["id_idioma"], v["id_nivel"], v["id_professor"], v["carga_horaria"], v["vagas"]))
                    flash("Turma criada.", "sucesso")
                    return redirect(url_for("listar_turmas"))
                except Error as erro:
                    flash(db.mensagem_erro(erro, duplicado="Já existe uma turma com esse nome."), "erro")
        return _form_turma(v, "Nova turma", url_for("nova_turma"))

    @app.route("/turmas/<int:id_turma>/editar", methods=["GET", "POST"])
    @perfil_requerido(ADMIN)
    def editar_turma(id_turma):
        atual = db.consultar_um("SELECT nome,id_idioma,id_nivel,id_professor,carga_horaria,vagas FROM turma WHERE id_turma=%s", (id_turma,))
        if not atual:
            flash("Turma não encontrada.", "erro")
            return redirect(url_for("listar_turmas"))
        v = atual
        if request.method == "POST":
            v, erro_campo = _ler_turma()
            if erro_campo:
                flash(erro_campo, "erro")
            else:
                try:
                    db.executar("UPDATE turma SET nome=%s,id_idioma=%s,id_nivel=%s,id_professor=%s,carga_horaria=%s,vagas=%s "
                                "WHERE id_turma=%s", (v["nome"], v["id_idioma"], v["id_nivel"], v["id_professor"],
                                                      v["carga_horaria"], v["vagas"], id_turma))
                    flash("Turma atualizada.", "sucesso")
                    return redirect(url_for("listar_turmas"))
                except Error as erro:
                    flash(db.mensagem_erro(erro, duplicado="Já existe uma turma com esse nome."), "erro")
        return _form_turma(v, "Editar turma", url_for("editar_turma", id_turma=id_turma))

    @app.route("/turmas/<int:id_turma>/excluir", methods=["POST"])
    @perfil_requerido(ADMIN)
    def excluir_turma(id_turma):
        try:
            n, _ = db.executar("DELETE FROM turma WHERE id_turma=%s", (id_turma,))
            flash("Turma excluída." if n else "Turma não encontrada.", "sucesso" if n else "erro")
        except Error as erro:
            flash(db.mensagem_erro(erro, em_uso="Não é possível excluir: a turma tem matrículas. Cancele-as ou mantenha a turma."), "erro")
        return redirect(url_for("listar_turmas"))

    # ----------------------------------------- admin: matriculas e pagamentos
    @app.route("/admin/matriculas", methods=["GET", "POST"])
    @perfil_requerido(ADMIN)
    def admin_matriculas():
        if request.method == "POST":
            aluno, turma = _inteiro("id_aluno"), _inteiro("id_turma")
            if not aluno or not turma:
                flash("Escolha o aluno e a turma.", "erro")
            else:
                vencimento = date.today() + timedelta(days=DIAS_VENCIMENTO)
                try:
                    r = db.chamar_procedure_saida("sp_matricular_aluno", (aluno, turma, PRECO_MATRICULA, vencimento, 0, 0))
                    flash(f"Matrícula nº {r[4]} criada com pagamento nº {r[5]} (R$ {PRECO_MATRICULA:.2f}).", "sucesso")
                except Error as erro:
                    flash(db.mensagem_erro(erro, duplicado="Esse aluno já está matriculado nessa turma.",
                                           padrao="Não foi possível matricular."), "erro")
            return redirect(url_for("admin_matriculas"))
        status = request.args.get("status", "")
        onde, params = ("WHERE m.status=%s", (status,)) if status in ("pendente", "ativa", "cancelada", "concluida") else ("", ())
        matriculas = db.consultar(
            "SELECT m.id_matricula, m.status, m.data_matricula, u.nome AS aluno, t.nome AS turma, p.status AS pagamento "
            "FROM matricula m JOIN usuario u ON u.id_usuario=m.id_aluno JOIN turma t ON t.id_turma=m.id_turma "
            "LEFT JOIN pagamento p ON p.id_matricula=m.id_matricula " + onde +
            " ORDER BY m.id_matricula DESC LIMIT 200", params)
        alunos = db.consultar("SELECT id_usuario, nome FROM usuario WHERE tipo='aluno' AND ativo=TRUE ORDER BY nome")
        turmas = db.consultar("SELECT id_turma, turma, vagas_disponiveis FROM vw_turmas_por_idioma ORDER BY turma")
        return render_template("admin_matriculas.html", matriculas=matriculas, alunos=alunos, turmas=turmas,
                               status=status, preco=PRECO_MATRICULA)

    @app.route("/admin/pagamentos")
    @perfil_requerido(ADMIN)
    def admin_pagamentos():
        pagamentos = db.consultar("SELECT id_pagamento, aluno, turma, idioma, valor, data_vencimento, dias_em_atraso, "
                                  "situacao, status FROM vw_pagamentos_pendentes ORDER BY dias_em_atraso DESC, data_vencimento")
        return render_template("admin_pagamentos.html", pagamentos=pagamentos)

    @app.route("/admin/pagamentos/<int:id_pagamento>/pagar", methods=["POST"])
    @perfil_requerido(ADMIN)
    def confirmar_pagamento(id_pagamento):
        try:
            n, _ = db.executar("UPDATE pagamento SET status='pago', data_pagamento=CURDATE() "
                               "WHERE id_pagamento=%s AND status IN ('pendente','atrasado')", (id_pagamento,))
        except Error as erro:
            flash(db.mensagem_erro(erro, padrao="Não foi possível confirmar o pagamento."), "erro")
            return redirect(url_for("admin_pagamentos"))
        if not n:
            flash("Pagamento não encontrado ou já quitado.", "erro")
        else:
            m = db.consultar_um("SELECT m.status FROM pagamento p JOIN matricula m USING (id_matricula) "
                                "WHERE p.id_pagamento=%s", (id_pagamento,))
            flash("Pagamento confirmado." + (" A matrícula foi ativada automaticamente (trigger)." if m and m["status"] == "ativa" else ""),
                  "sucesso")
        return redirect(url_for("admin_pagamentos"))

    @app.route("/admin/auditoria")
    @perfil_requerido(ADMIN)
    def admin_auditoria():
        tabela = request.args.get("tabela", "")
        onde, params = ("WHERE tabela=%s", (tabela,)) if tabela in ("usuario", "pagamento", "matricula") else ("", ())
        logs = db.consultar("SELECT id_log, tabela, operacao, id_registro, detalhe, usuario_bd, criado_em "
                            "FROM log_auditoria " + onde + " ORDER BY id_log DESC LIMIT 100", params)
        return render_template("admin_auditoria.html", logs=logs, tabela=tabela)

    # --------------------------------- conteudos e desafios (admin/professor)
    def _conteudo_gerenciavel(id_conteudo):
        c = db.consultar_um("SELECT * FROM conteudo WHERE id_conteudo=%s", (id_conteudo,))
        if not c:
            flash("Conteúdo não encontrado.", "erro")
            return None
        if session["tipo"] == PROFESSOR and c["id_professor"] != session["id_usuario"]:
            flash("Você só pode alterar os conteúdos criados por você.", "erro")
            return None
        return c

    def _form_conteudo(v, titulo, acao):
        return render_template("conteudo_form.html", v=v, titulo=titulo, acao=acao, idiomas=_idiomas(),
                               niveis=_niveis(), professores=_professores())

    def _ler_conteudo():
        v = {"titulo": request.form.get("titulo", "").strip(), "descricao": request.form.get("descricao", "").strip(),
             "id_idioma": _inteiro("id_idioma"), "id_nivel": _inteiro("id_nivel"),
             "id_professor": session["id_usuario"] if session["tipo"] == PROFESSOR else _inteiro("id_professor")}
        if not v["titulo"] or len(v["titulo"]) > 120:
            return v, "Informe o título (até 120 caracteres)."
        if not v["id_idioma"] or not v["id_nivel"]:
            return v, "Escolha o idioma e o nível."
        return v, None

    @app.route("/conteudos/novo", methods=["GET", "POST"])
    @perfil_requerido(ADMIN, PROFESSOR)
    def novo_conteudo():
        v = {"titulo": "", "descricao": "", "id_idioma": None, "id_nivel": None, "id_professor": None}
        if request.method == "POST":
            v, erro_campo = _ler_conteudo()
            if erro_campo:
                flash(erro_campo, "erro")
            else:
                try:
                    _, novo = db.executar("INSERT INTO conteudo (titulo,descricao,id_idioma,id_nivel,id_professor) "
                                          "VALUES (%s,%s,%s,%s,%s)", (v["titulo"], v["descricao"] or None, v["id_idioma"],
                                                                      v["id_nivel"], v["id_professor"]))
                    flash("Conteúdo criado. Agora cadastre os desafios dele.", "sucesso")
                    return redirect(url_for("desafios_do_conteudo", id_conteudo=novo))
                except Error as erro:
                    flash(db.mensagem_erro(erro, duplicado="Já existe um conteúdo com esse título, idioma e nível."), "erro")
        return _form_conteudo(v, "Novo conteúdo", url_for("novo_conteudo"))

    @app.route("/conteudos/<int:id_conteudo>/editar", methods=["GET", "POST"])
    @perfil_requerido(ADMIN, PROFESSOR)
    def editar_conteudo(id_conteudo):
        atual = _conteudo_gerenciavel(id_conteudo)
        if not atual:
            return redirect(url_for("listar_conteudos"))
        v = atual
        if request.method == "POST":
            v, erro_campo = _ler_conteudo()
            if session["tipo"] == ADMIN and not v["id_professor"]:
                v["id_professor"] = None
            if erro_campo:
                flash(erro_campo, "erro")
            else:
                try:
                    db.executar("UPDATE conteudo SET titulo=%s,descricao=%s,id_idioma=%s,id_nivel=%s,id_professor=%s "
                                "WHERE id_conteudo=%s", (v["titulo"], v["descricao"] or None, v["id_idioma"], v["id_nivel"],
                                                         v["id_professor"], id_conteudo))
                    flash("Conteúdo atualizado.", "sucesso")
                    return redirect(url_for("listar_conteudos"))
                except Error as erro:
                    flash(db.mensagem_erro(erro, duplicado="Já existe um conteúdo com esse título, idioma e nível."), "erro")
        return _form_conteudo(v, "Editar conteúdo", url_for("editar_conteudo", id_conteudo=id_conteudo))

    @app.route("/conteudos/<int:id_conteudo>/excluir", methods=["POST"])
    @perfil_requerido(ADMIN, PROFESSOR)
    def excluir_conteudo(id_conteudo):
        if _conteudo_gerenciavel(id_conteudo):
            try:
                db.executar("DELETE FROM conteudo WHERE id_conteudo=%s", (id_conteudo,))
                flash("Conteúdo excluído (os desafios e pontuações dele também).", "sucesso")
            except Error as erro:
                flash(db.mensagem_erro(erro), "erro")
        return redirect(url_for("listar_conteudos"))

    @app.route("/conteudos/<int:id_conteudo>/desafios", methods=["GET", "POST"])
    @perfil_requerido(ADMIN, PROFESSOR)
    def desafios_do_conteudo(id_conteudo):
        c = _conteudo_gerenciavel(id_conteudo)
        if not c:
            return redirect(url_for("listar_conteudos"))
        if request.method == "POST":
            titulo, maximo = request.form.get("titulo", "").strip(), _inteiro("pontuacao_maxima")
            if not titulo or len(titulo) > 120 or not maximo:
                flash("Informe o título (até 120 caracteres) e a pontuação máxima (maior que zero).", "erro")
            else:
                try:
                    db.executar("INSERT INTO desafio (id_conteudo,titulo,descricao,pontuacao_maxima) VALUES (%s,%s,%s,%s)",
                                (id_conteudo, titulo, request.form.get("descricao", "").strip() or None, maximo))
                    flash("Desafio criado.", "sucesso")
                except Error as erro:
                    flash(db.mensagem_erro(erro, duplicado="Esse conteúdo já tem um desafio com esse título."), "erro")
            return redirect(url_for("desafios_do_conteudo", id_conteudo=id_conteudo))
        desafios = db.consultar(
            "SELECT d.id_desafio, d.titulo, d.descricao, d.pontuacao_maxima, "
            "(SELECT COUNT(*) FROM pontuacao p WHERE p.id_desafio=d.id_desafio) AS respostas "
            "FROM desafio d WHERE d.id_conteudo=%s ORDER BY d.titulo", (id_conteudo,))
        return render_template("desafios_conteudo.html", c=c, desafios=desafios)

    def _desafio_gerenciavel(id_desafio):
        d = db.consultar_um("SELECT * FROM desafio WHERE id_desafio=%s", (id_desafio,))
        if not d:
            flash("Desafio não encontrado.", "erro")
            return None, None
        return d, _conteudo_gerenciavel(d["id_conteudo"])

    @app.route("/desafios/<int:id_desafio>/editar", methods=["GET", "POST"])
    @perfil_requerido(ADMIN, PROFESSOR)
    def editar_desafio(id_desafio):
        d, c = _desafio_gerenciavel(id_desafio)
        if not d or not c:
            return redirect(url_for("listar_conteudos"))
        if request.method == "POST":
            titulo, maximo = request.form.get("titulo", "").strip(), _inteiro("pontuacao_maxima")
            d = {**d, "titulo": titulo, "descricao": request.form.get("descricao", "").strip(), "pontuacao_maxima": maximo or d["pontuacao_maxima"]}
            if not titulo or len(titulo) > 120 or not maximo:
                flash("Informe o título (até 120 caracteres) e a pontuação máxima (maior que zero).", "erro")
            else:
                try:
                    db.executar("UPDATE desafio SET titulo=%s, descricao=%s, pontuacao_maxima=%s WHERE id_desafio=%s",
                                (titulo, d["descricao"] or None, maximo, id_desafio))
                    flash("Desafio atualizado.", "sucesso")
                    return redirect(url_for("desafios_do_conteudo", id_conteudo=c["id_conteudo"]))
                except Error as erro:
                    flash(db.mensagem_erro(erro, duplicado="Esse conteúdo já tem um desafio com esse título."), "erro")
        return render_template("desafio_form.html", d=d, c=c)

    @app.route("/desafios/<int:id_desafio>/excluir", methods=["POST"])
    @perfil_requerido(ADMIN, PROFESSOR)
    def excluir_desafio(id_desafio):
        d, c = _desafio_gerenciavel(id_desafio)
        if d and c:
            try:
                db.executar("DELETE FROM desafio WHERE id_desafio=%s", (id_desafio,))
                flash("Desafio excluído (as pontuações dele também).", "sucesso")
            except Error as erro:
                flash(db.mensagem_erro(erro), "erro")
            return redirect(url_for("desafios_do_conteudo", id_conteudo=c["id_conteudo"]))
        return redirect(url_for("listar_conteudos"))

    # ------------------------------------------------------------- professor
    @app.route("/professor/turmas")
    @perfil_requerido(PROFESSOR)
    def professor_turmas():
        turmas = db.consultar("SELECT id_turma, turma, idioma, nivel, carga_horaria, vagas, vagas_ocupadas, situacao "
                              "FROM vw_turmas_por_idioma WHERE id_turma IN (SELECT id_turma FROM turma WHERE id_professor=%s) "
                              "ORDER BY idioma, nivel, turma", (session["id_usuario"],))
        return render_template("prof_turmas.html", turmas=turmas)

    @app.route("/professor/turmas/<int:id_turma>")
    @perfil_requerido(PROFESSOR)
    def professor_turma(id_turma):
        turma = db.consultar_um("SELECT t.id_turma, t.nome, i.nome AS idioma, n.codigo AS nivel FROM turma t "
                                "JOIN idioma i ON i.id_idioma=t.id_idioma JOIN nivel n ON n.id_nivel=t.id_nivel "
                                "WHERE t.id_turma=%s AND t.id_professor=%s", (id_turma, session["id_usuario"]))
        if not turma:
            flash("Turma não encontrada entre as suas.", "erro")
            return redirect(url_for("professor_turmas"))
        alunos = db.consultar("SELECT u.nome, m.status, m.data_matricula, fn_media_aluno(u.id_usuario) AS media, "
                              "(SELECT COUNT(*) FROM pontuacao p WHERE p.id_aluno=u.id_usuario) AS desafios "
                              "FROM matricula m JOIN usuario u ON u.id_usuario=m.id_aluno WHERE m.id_turma=%s "
                              "ORDER BY FIELD(m.status,'ativa','pendente','concluida','cancelada'), u.nome", (id_turma,))
        return render_template("prof_turma.html", turma=turma, alunos=alunos)

    @app.route("/professor/pontuacoes", methods=["GET", "POST"])
    @perfil_requerido(PROFESSOR)
    def professor_pontuacoes():
        uid = session["id_usuario"]
        if request.method == "POST":
            aluno, desafio, pontos = _inteiro("id_aluno"), _inteiro("id_desafio"), _ler_pontos()
            if not aluno or not desafio or pontos is None:
                flash("Escolha o aluno, o desafio e informe a pontuação.", "erro")
            elif not db.consultar_um("SELECT 1 x FROM desafio d JOIN conteudo c USING (id_conteudo) "
                                     "WHERE d.id_desafio=%s AND c.id_professor=%s", (desafio, uid)):
                flash("Esse desafio não pertence a um conteúdo seu.", "erro")
            else:
                try:
                    r = db.chamar_procedure_saida("sp_registrar_pontuacao", (aluno, desafio, pontos, ""))
                    flash(_mensagem_pontuacao(r[3]), "sucesso")
                except Error as erro:
                    flash(db.mensagem_erro(erro, padrao="Não foi possível registrar a pontuação."), "erro")
            return redirect(url_for("professor_pontuacoes"))
        alunos = db.consultar("SELECT DISTINCT u.id_usuario, u.nome, t.nome AS turma FROM matricula m "
                              "JOIN turma t ON t.id_turma=m.id_turma JOIN usuario u ON u.id_usuario=m.id_aluno "
                              "WHERE t.id_professor=%s AND m.status IN ('ativa','concluida') ORDER BY u.nome", (uid,))
        desafios = db.consultar("SELECT d.id_desafio, d.titulo, d.pontuacao_maxima, c.titulo AS conteudo, i.nome AS idioma "
                                "FROM desafio d JOIN conteudo c USING (id_conteudo) JOIN idioma i ON i.id_idioma=c.id_idioma "
                                "WHERE c.id_professor=%s ORDER BY c.titulo, d.titulo", (uid,))
        recentes = db.consultar("SELECT u.nome AS aluno, d.titulo AS desafio, p.pontos, d.pontuacao_maxima, p.data_registro "
                                "FROM pontuacao p JOIN desafio d USING (id_desafio) JOIN conteudo c USING (id_conteudo) "
                                "JOIN usuario u ON u.id_usuario=p.id_aluno WHERE c.id_professor=%s "
                                "ORDER BY p.data_registro DESC, p.id_pontuacao DESC LIMIT 20", (uid,))
        return render_template("prof_pontuacoes.html", alunos=alunos, desafios=desafios, recentes=recentes)
