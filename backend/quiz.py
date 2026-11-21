"""Quiz com correção no servidor.

O aluno NUNCA informa nota: ele envia só as alternativas que marcou. O servidor
compara com o gabarito (alternativa.correta), calcula a nota e a grava com
sp_registrar_pontuacao. O id do aluno vem da sessão.

  nota = pontuacao_maxima * acertos / total de questões   (2 casas decimais)

Regras:
  * só aluno com matrícula ativa/concluída no idioma do conteúdo responde;
  * uma tentativa por desafio (quem já tem pontuação não responde de novo;
    o professor pode excluir a pontuação para liberar outra tentativa);
  * desafio sem questões não é quiz: a nota é lançada pelo professor;
  * o gabarito não é enviado ao navegador nem à API do aluno.

As funções preparar_quiz/corrigir_e_registrar são usadas pela tela e pela API.
"""
import random
from decimal import Decimal, ROUND_HALF_UP

from flask import flash, redirect, render_template, request, session, url_for
from mysql.connector import Error

import db

ADMIN, PROFESSOR, ALUNO = "administrador", "professor", "aluno"
MIN_ALTERNATIVAS, MAX_ALTERNATIVAS = 2, 4


class QuizErro(Exception):
    """Erro de regra do quiz; carrega a mensagem e o status HTTP sugerido."""

    def __init__(self, mensagem, status=400):
        super().__init__(mensagem)
        self.mensagem, self.status = mensagem, status


# ----------------------------------------------------------------- leitura
def carregar_quiz(id_desafio, com_gabarito=False):
    """Questões do desafio com suas alternativas.

    Sem gabarito, a coluna `correta` nem é lida do banco e a ordem das
    alternativas é embaralhada (não deixa a certa sempre na mesma posição).
    """
    questoes = db.consultar("SELECT id_questao, ordem, enunciado FROM questao WHERE id_desafio=%s "
                            "ORDER BY ordem, id_questao", (id_desafio,))
    colunas = "a.id_alternativa, a.id_questao, a.texto" + (", a.correta" if com_gabarito else "")
    alternativas = db.consultar(f"SELECT {colunas} FROM alternativa a JOIN questao q ON q.id_questao=a.id_questao "
                                "WHERE q.id_desafio=%s ORDER BY a.id_questao, a.id_alternativa", (id_desafio,))
    por_questao = {}
    for a in alternativas:
        por_questao.setdefault(a["id_questao"], []).append(a)
    for q in questoes:
        q["alternativas"] = por_questao.get(q["id_questao"], [])
        if not com_gabarito:
            random.shuffle(q["alternativas"])
    return questoes


def preparar_quiz(id_aluno, id_desafio):
    """Valida se o aluno pode responder e devolve (desafio, questões sem gabarito)."""
    desafio = db.consultar_um("SELECT d.id_desafio, d.titulo, d.descricao, d.pontuacao_maxima, c.id_idioma "
                              "FROM desafio d JOIN conteudo c ON c.id_conteudo=d.id_conteudo "
                              "WHERE d.id_desafio=%s", (id_desafio,))
    if not desafio:
        raise QuizErro("Desafio não encontrado.", 404)
    questoes = carregar_quiz(id_desafio)
    if not questoes or any(len(q["alternativas"]) < MIN_ALTERNATIVAS for q in questoes):
        raise QuizErro("Este desafio não é um quiz: a nota dele é lançada pelo professor.", 409)
    if not db.consultar_um("SELECT 1 x FROM matricula m JOIN turma t ON t.id_turma=m.id_turma "
                           "WHERE m.id_aluno=%s AND m.status IN ('ativa','concluida') AND t.id_idioma=%s LIMIT 1",
                           (id_aluno, desafio["id_idioma"])):
        raise QuizErro("Você precisa de uma matrícula ativa nesse idioma para responder.", 403)
    anterior = db.consultar_um("SELECT pontos FROM pontuacao WHERE id_aluno=%s AND id_desafio=%s",
                               (id_aluno, id_desafio))
    if anterior:
        raise QuizErro(f"Você já respondeu este quiz (nota {anterior['pontos']:g}). "
                       "Peça ao professor para liberar uma nova tentativa.", 409)
    return desafio, questoes


# --------------------------------------------------------------- correção
def _normalizar(respostas):
    """{'12': '45'} -> {12: 45}. Qualquer coisa fora do formato é erro 400."""
    if not isinstance(respostas, dict) or not respostas:
        raise QuizErro("Envie as respostas no formato {id_questao: id_alternativa}.")
    try:
        return {int(k): int(v) for k, v in respostas.items()}
    except (TypeError, ValueError):
        raise QuizErro("Respostas inválidas: use apenas números de questão e alternativa.")


def corrigir_e_registrar(id_aluno, id_desafio, respostas):
    """Corrige no servidor e grava a nota. Devolve o resumo para exibir ao aluno."""
    respostas = _normalizar(respostas)
    desafio, questoes = preparar_quiz(id_aluno, id_desafio)
    if any(q["id_questao"] not in respostas for q in questoes):
        raise QuizErro("Responda todas as perguntas antes de enviar.")
    gabarito = {q["id_questao"]: q for q in carregar_quiz(id_desafio, com_gabarito=True)}
    acertos, detalhe = 0, []
    for id_questao, q in gabarito.items():
        escolhida = next((a for a in q["alternativas"] if a["id_alternativa"] == respostas[id_questao]), None)
        if escolhida is None:
            raise QuizErro("Uma das alternativas enviadas não pertence à pergunta.")
        acertou = bool(escolhida["correta"])
        acertos += acertou
        detalhe.append({"id_questao": id_questao, "acertou": acertou})
    total = len(gabarito)
    nota = (Decimal(desafio["pontuacao_maxima"]) * acertos / total).quantize(Decimal("0.01"), ROUND_HALF_UP)
    try:
        db.chamar_procedure_saida("sp_registrar_pontuacao", (id_aluno, id_desafio, nota, ""))
    except Error as erro:
        raise QuizErro(db.mensagem_erro(erro, padrao="Não foi possível registrar a pontuação."), 409)
    return {"acertos": acertos, "total": total, "nota": float(nota),
            "pontuacao_maxima": desafio["pontuacao_maxima"], "questoes": detalhe}


def quiz_publico(desafio, questoes):
    """Estrutura enviada ao aluno: sem gabarito."""
    return {"id_desafio": desafio["id_desafio"], "titulo": desafio["titulo"], "descricao": desafio["descricao"],
            "pontuacao_maxima": desafio["pontuacao_maxima"],
            "questoes": [{"id_questao": q["id_questao"], "ordem": q["ordem"], "enunciado": q["enunciado"],
                          "alternativas": [{"id_alternativa": a["id_alternativa"], "texto": a["texto"]}
                                           for a in q["alternativas"]]} for q in questoes]}


# -------------------------------------------------------------- rotas web
def registrar(app, perfil_requerido):
    @app.route("/desafios/<int:id_desafio>/quiz", methods=["GET", "POST"])
    @perfil_requerido(ALUNO)
    def fazer_quiz(id_desafio):
        uid = session["id_usuario"]
        try:
            if request.method == "POST":
                # só os campos q<id_questao> = id_alternativa; nada de nota vinda do formulário
                respostas = {k[1:]: v for k, v in request.form.items() if k.startswith("q") and k[1:].isdigit()}
                r = corrigir_e_registrar(uid, id_desafio, respostas)
                flash(f"Quiz enviado: {r['acertos']} de {r['total']} certas. "
                      f"Sua nota é {r['nota']:g} de {r['pontuacao_maxima']}.", "sucesso")
                return redirect(url_for("listar_desafios"))
            desafio, questoes = preparar_quiz(uid, id_desafio)
        except QuizErro as erro:
            flash(erro.mensagem, "erro")
            return redirect(url_for("listar_desafios"))
        return render_template("quiz.html", d=desafio, questoes=questoes)

    # ---------- professor/administrador: cadastrar as perguntas de um desafio
    def _desafio_gerenciavel(id_desafio):
        d = db.consultar_um("SELECT d.id_desafio, d.titulo, d.pontuacao_maxima, c.id_conteudo, c.titulo AS conteudo, "
                            "c.id_professor FROM desafio d JOIN conteudo c ON c.id_conteudo=d.id_conteudo "
                            "WHERE d.id_desafio=%s", (id_desafio,))
        if not d:
            flash("Desafio não encontrado.", "erro")
            return None
        if session["tipo"] == PROFESSOR and d["id_professor"] != session["id_usuario"]:
            flash("Você só pode alterar os desafios dos seus conteúdos.", "erro")
            return None
        return d

    def _ler_questao():
        enunciado = request.form.get("enunciado", "").strip()
        textos = [request.form.get(f"alt{i}", "").strip() for i in range(1, MAX_ALTERNATIVAS + 1)]
        certa = request.form.get("correta", "")
        if not enunciado or len(enunciado) > 500:
            return None, "Informe o enunciado (até 500 caracteres)."
        if sum(1 for t in textos if t) < MIN_ALTERNATIVAS or any(len(t) > 200 for t in textos):
            return None, f"Informe ao menos {MIN_ALTERNATIVAS} alternativas (até 200 caracteres cada)."
        if not certa.isdigit() or not 1 <= int(certa) <= MAX_ALTERNATIVAS or not textos[int(certa) - 1]:
            return None, "Marque qual alternativa preenchida é a correta."
        return (enunciado, [(t, i + 1 == int(certa)) for i, t in enumerate(textos) if t]), None

    @app.route("/desafios/<int:id_desafio>/questoes", methods=["GET", "POST"])
    @perfil_requerido(ADMIN, PROFESSOR)
    def questoes_do_desafio(id_desafio):
        d = _desafio_gerenciavel(id_desafio)
        if not d:
            return redirect(url_for("listar_conteudos"))
        if request.method == "POST":
            dados, erro_campo = _ler_questao()
            if erro_campo:
                flash(erro_campo, "erro")
            else:
                enunciado, alternativas = dados
                try:
                    with db.transacao() as cnx:
                        cur = cnx.cursor()
                        cur.execute("SELECT COALESCE(MAX(ordem),0)+1 FROM questao WHERE id_desafio=%s", (id_desafio,))
                        ordem = cur.fetchone()[0]
                        cur.execute("INSERT INTO questao (id_desafio, ordem, enunciado) VALUES (%s,%s,%s)",
                                    (id_desafio, ordem, enunciado))
                        id_questao = cur.lastrowid
                        for texto, correta in alternativas:
                            cur.execute("INSERT INTO alternativa (id_questao, texto, correta) VALUES (%s,%s,%s)",
                                        (id_questao, texto, correta))
                        cur.close()
                    flash("Pergunta adicionada.", "sucesso")
                except Error as erro:
                    flash(db.mensagem_erro(erro, padrao="Não foi possível salvar a pergunta."), "erro")
            return redirect(url_for("questoes_do_desafio", id_desafio=id_desafio))
        questoes = carregar_quiz(id_desafio, com_gabarito=True)
        respondidos = db.consultar_um("SELECT COUNT(*) n FROM pontuacao WHERE id_desafio=%s", (id_desafio,))["n"]
        return render_template("questoes_desafio.html", d=d, questoes=questoes, respondidos=respondidos,
                               max_alt=MAX_ALTERNATIVAS)

    @app.route("/questoes/<int:id_questao>/excluir", methods=["POST"])
    @perfil_requerido(ADMIN, PROFESSOR)
    def excluir_questao(id_questao):
        q = db.consultar_um("SELECT id_desafio FROM questao WHERE id_questao=%s", (id_questao,))
        if not q:
            flash("Pergunta não encontrada.", "erro")
            return redirect(url_for("listar_conteudos"))
        if _desafio_gerenciavel(q["id_desafio"]):
            try:
                db.executar("DELETE FROM questao WHERE id_questao=%s", (id_questao,))
                flash("Pergunta excluída. As notas já registradas não mudam.", "sucesso")
            except Error as erro:
                flash(db.mensagem_erro(erro), "erro")
        return redirect(url_for("questoes_do_desafio", id_desafio=q["id_desafio"]))
