-- Executar DEPOIS do 01_schema.sql e do 03_seed.sql 
-- Pode ser executado varias vezes: usa CREATE OR REPLACE VIEW.

-- Regra de vaga (a mesma do trigger de matricula): a matricula ocupa
-- vaga quando o status e 'pendente' ou 'ativa'.

USE virtualingua;

-- 1) vw_turmas_por_idioma  (RF02)
-- Uma linha por turma, com idioma, nivel, professor e situacao das vagas.
-- Uso:  SELECT * FROM vw_turmas_por_idioma WHERE idioma = 'Espanhol';

CREATE OR REPLACE VIEW vw_turmas_por_idioma AS
SELECT t.id_turma,
       t.nome                                   AS turma,
       i.id_idioma,
       i.nome                                   AS idioma,
       n.codigo                                 AS nivel,
       n.descricao                              AS nivel_descricao,
       p.nome                                   AS professor,
       t.carga_horaria,
       t.vagas,
       COALESCE(m.ocupadas, 0)                  AS vagas_ocupadas,
       t.vagas - COALESCE(m.ocupadas, 0)        AS vagas_disponiveis,
       CASE WHEN t.vagas - COALESCE(m.ocupadas, 0) <= 0
            THEN 'lotada' ELSE 'com vagas' END  AS situacao
FROM turma t
JOIN idioma i       ON i.id_idioma  = t.id_idioma
JOIN nivel n        ON n.id_nivel   = t.id_nivel
LEFT JOIN usuario p ON p.id_usuario = t.id_professor      -- turma pode estar sem professor
LEFT JOIN (SELECT id_turma, COUNT(*) AS ocupadas
             FROM matricula
            WHERE status IN ('pendente', 'ativa')
            GROUP BY id_turma) m ON m.id_turma = t.id_turma;

-- 2) vw_alunos_por_idioma  (RF03)
-- Uma linha por (aluno, idioma) para alunos com matricula pendente ou
-- ativa. Um aluno que estuda os dois idiomas aparece duas vezes.
-- Uso:  SELECT * FROM vw_alunos_por_idioma WHERE idioma = 'Inglês';

CREATE OR REPLACE VIEW vw_alunos_por_idioma AS
SELECT i.id_idioma,
       i.nome                                              AS idioma,
       u.id_usuario                                        AS id_aluno,
       u.nome                                              AS aluno,
       u.email,
       COUNT(*)                                            AS turmas_matriculadas,
       SUM(CASE WHEN m.status = 'ativa' THEN 1 ELSE 0 END) AS turmas_ativas,
       MIN(m.data_matricula)                               AS primeira_matricula
FROM matricula m
JOIN usuario u ON u.id_usuario = m.id_aluno
JOIN turma t   ON t.id_turma   = m.id_turma
JOIN idioma i  ON i.id_idioma  = t.id_idioma
WHERE m.status IN ('pendente', 'ativa')
  AND u.tipo = 'aluno'
  AND u.ativo = TRUE                                       -- ignora contas anonimizadas (RF10)
GROUP BY i.id_idioma, i.nome, u.id_usuario, u.nome, u.email;

-- 3) vw_pagamentos_pendentes  (RF07)
-- Pagamentos ainda nao quitados (pendente ou atrasado), com o aluno, a
-- turma e os dias de atraso calculados pela data de hoje.
-- 'situacao' = 'vencido' quando o status e 'atrasado' OU a data de
-- vencimento ja passou (mesmo que ninguem tenha atualizado o status).
-- Uso:  SELECT * FROM vw_pagamentos_pendentes ORDER BY dias_em_atraso DESC;

CREATE OR REPLACE VIEW vw_pagamentos_pendentes AS
SELECT pg.id_pagamento,
       m.id_matricula,
       u.id_usuario                              AS id_aluno,
       u.nome                                    AS aluno,
       u.email,
       t.nome                                    AS turma,
       i.nome                                    AS idioma,
       pg.valor,
       pg.data_vencimento,
       pg.status,
       CASE WHEN pg.data_vencimento < CURRENT_DATE
            THEN DATEDIFF(CURRENT_DATE, pg.data_vencimento)
            ELSE 0 END                           AS dias_em_atraso,
       CASE WHEN pg.status = 'atrasado' OR pg.data_vencimento < CURRENT_DATE
            THEN 'vencido' ELSE 'a vencer' END   AS situacao
FROM pagamento pg
JOIN matricula m ON m.id_matricula = pg.id_matricula
JOIN usuario u   ON u.id_usuario   = m.id_aluno
JOIN turma t     ON t.id_turma     = m.id_turma
JOIN idioma i    ON i.id_idioma    = t.id_idioma
WHERE pg.status IN ('pendente', 'atrasado');

-- 4) vw_ranking_por_idioma  (RF06)
-- Soma dos pontos de cada aluno nos desafios de cada idioma e a posicao
-- dele dentro do idioma. RANK() deixa empates na mesma posicao
-- Uso:  SELECT * FROM vw_ranking_por_idioma WHERE posicao <= 3;

CREATE OR REPLACE VIEW vw_ranking_por_idioma AS
SELECT i.id_idioma,
       i.nome                         AS idioma,
       u.id_usuario                   AS id_aluno,
       u.nome                         AS aluno,
       SUM(p.pontos)                  AS total_pontos,
       COUNT(*)                       AS desafios_realizados,
       RANK() OVER (PARTITION BY i.id_idioma
                    ORDER BY SUM(p.pontos) DESC) AS posicao
FROM pontuacao p
JOIN desafio d  ON d.id_desafio  = p.id_desafio
JOIN conteudo c ON c.id_conteudo = d.id_conteudo
JOIN idioma i   ON i.id_idioma   = c.id_idioma
JOIN usuario u  ON u.id_usuario  = p.id_aluno
WHERE u.ativo = TRUE
GROUP BY i.id_idioma, i.nome, u.id_usuario, u.nome;


-- Conferir 

SELECT * FROM vw_turmas_por_idioma      ORDER BY idioma, nivel, turma;
SELECT * FROM vw_alunos_por_idioma      ORDER BY idioma, aluno;
SELECT * FROM vw_pagamentos_pendentes   ORDER BY dias_em_atraso DESC;
SELECT * FROM vw_ranking_por_idioma     ORDER BY idioma, posicao, aluno;

-- Para desfazer:
-- DROP VIEW IF EXISTS vw_turmas_por_idioma, vw_alunos_por_idioma,
--                     vw_pagamentos_pendentes, vw_ranking_por_idioma;
