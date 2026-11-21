-- Quiz com correção no servidor: o aluno responde, o sistema calcula a nota.
--
-- Cria:
--   questao      pergunta de um desafio (1 desafio -> N questões)
--   alternativa  opções de uma questão; "correta" é o gabarito
--
-- Regras:
--   * o gabarito (alternativa.correta) NUNCA sai do servidor para o aluno;
--   * nota = pontuacao_maxima * acertos / total de questões, e é gravada
--     por sp_registrar_pontuacao (as regras de matrícula ativa e de
--     pontuação máxima continuam no banco);
--   * desafio SEM questões não é quiz: a nota é lançada pelo professor;
--   * os desafios do seed ganham 3 perguntas padrão iguais (ver abaixo).
--
-- Pré-requisito: 01 a 11 já executados. Pode ser aplicado sobre um banco
-- existente SEM rodar o 01 de novo (não toca nas tabelas antigas).
-- Reexecutável: recria apenas as duas tabelas novas (perde as questões).

USE virtualingua;
SET NAMES utf8mb4;

DROP TABLE IF EXISTS alternativa;
DROP TABLE IF EXISTS questao;

CREATE TABLE questao (
    id_questao INT          NOT NULL AUTO_INCREMENT,
    id_desafio INT          NOT NULL,
    ordem      INT          NOT NULL DEFAULT 1,
    enunciado  VARCHAR(500) NOT NULL,
    PRIMARY KEY (id_questao),
    KEY idx_questao_desafio (id_desafio, ordem),
    CONSTRAINT fk_questao_desafio FOREIGN KEY (id_desafio)
        REFERENCES desafio (id_desafio) ON DELETE CASCADE,
    CONSTRAINT ck_questao_ordem CHECK (ordem > 0)
) ENGINE = InnoDB;

CREATE TABLE alternativa (
    id_alternativa INT          NOT NULL AUTO_INCREMENT,
    id_questao     INT          NOT NULL,
    texto          VARCHAR(200) NOT NULL,
    correta        BOOLEAN      NOT NULL DEFAULT FALSE,
    PRIMARY KEY (id_alternativa),
    KEY idx_alternativa_questao (id_questao),
    CONSTRAINT fk_alternativa_questao FOREIGN KEY (id_questao)
        REFERENCES questao (id_questao) ON DELETE CASCADE
) ENGINE = InnoDB;

-- ---------------------------------------------------------------------
-- Atividades padrão (dados de exemplo)
-- TODOS os desafios existentes recebem as MESMAS 3 perguntas, com 3
-- alternativas cada (só uma correta). São conteúdo de demonstração: o
-- professor pode apagar e cadastrar as suas em Conteúdos > Desafios > Perguntas.
-- Com 3 perguntas, cada acerto vale pontuacao_maxima / 3.
-- ---------------------------------------------------------------------
INSERT INTO questao (id_desafio, ordem, enunciado)
SELECT d.id_desafio, m.ordem, m.enunciado
  FROM desafio d
 CROSS JOIN (SELECT 1 AS ordem, 'Quantos dias tem uma semana?' AS enunciado
             UNION ALL SELECT 2, 'Qual destes é um mês do ano?'
             UNION ALL SELECT 3, 'Qual cor resulta da mistura de azul com amarelo?') m;

INSERT INTO alternativa (id_questao, texto, correta)
SELECT q.id_questao, a.texto, a.correta
  FROM questao q
  JOIN (SELECT 1 AS ordem, '7' AS texto, 1 AS correta
        UNION ALL SELECT 1, '5', 0
        UNION ALL SELECT 1, '10', 0
        UNION ALL SELECT 2, 'Março', 1
        UNION ALL SELECT 2, 'Terça-feira', 0
        UNION ALL SELECT 2, 'Verão', 0
        UNION ALL SELECT 3, 'Verde', 1
        UNION ALL SELECT 3, 'Roxo', 0
        UNION ALL SELECT 3, 'Laranja', 0) a ON a.ordem = q.ordem;

-- Conferência: cada desafio deve ter 3 questões e 3 alternativas corretas.
SELECT d.id_desafio, d.titulo, COUNT(DISTINCT q.id_questao) AS questoes,
       SUM(a.correta) AS alternativas_corretas
  FROM desafio d
  JOIN questao q ON q.id_desafio = d.id_desafio
  JOIN alternativa a ON a.id_questao = q.id_questao
 GROUP BY d.id_desafio, d.titulo
 ORDER BY d.id_desafio;
