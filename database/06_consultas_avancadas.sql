-- Executar DEPOIS do 01_schema.sql e do 03_seed.sql.
-- So faz SELECT: pode rodar quantas vezes quiser. Cada consulta abre uma
-- aba de resultado no Workbench (para tirar print, execute uma de cada
-- vez: selecione o trecho e use Ctrl+Shift+Enter).

USE virtualingua;

-- A) JOINs

-- A1. INNER JOIN de 4 tabelas: turmas com idioma, nivel e professor.
SELECT t.nome AS turma, i.nome AS idioma, n.codigo AS nivel, u.nome AS professor
FROM turma t
JOIN idioma i  ON i.id_idioma  = t.id_idioma
JOIN nivel n   ON n.id_nivel   = t.id_nivel
JOIN usuario u ON u.id_usuario = t.id_professor
ORDER BY i.nome, n.codigo;

-- A2. INNER JOIN de 5 tabelas: matriculas ativas (quem estuda o que).
SELECT a.nome AS aluno, t.nome AS turma, i.nome AS idioma, m.data_matricula
FROM matricula m
JOIN usuario a ON a.id_usuario = m.id_aluno
JOIN turma t   ON t.id_turma   = m.id_turma
JOIN idioma i  ON i.id_idioma  = t.id_idioma
JOIN nivel n   ON n.id_nivel   = t.id_nivel
WHERE m.status = 'ativa'
ORDER BY a.nome, t.nome;

-- B) LEFT JOIN (mantem as linhas da esquerda mesmo sem correspondencia)

-- B1. Alunos SEM matricula ativa (LEFT JOIN + IS NULL).
--     Atencao: o filtro m.status = 'ativa' fica no ON, nao no WHERE.
--     No WHERE ele descartaria as linhas sem correspondencia (NULL) e o
--     LEFT JOIN viraria um INNER JOIN.
SELECT u.id_usuario, u.nome, u.email
FROM usuario u
LEFT JOIN matricula m ON m.id_aluno = u.id_usuario AND m.status = 'ativa'
WHERE u.tipo = 'aluno' AND m.id_matricula IS NULL;

-- B2. Todas as turmas com a quantidade de matriculas, inclusive as que
--     tem zero (COUNT(m.id) ignora NULL; COUNT(*) contaria 1 linha vazia).
SELECT t.nome AS turma, COUNT(m.id_matricula) AS matriculas
FROM turma t
LEFT JOIN matricula m ON m.id_turma = t.id_turma
GROUP BY t.id_turma, t.nome
ORDER BY matriculas DESC, t.nome;

-- B3. Alunos que ainda nao tem nenhuma pontuacao registrada.
SELECT u.nome, u.email
FROM usuario u
LEFT JOIN pontuacao p ON p.id_aluno = u.id_usuario
WHERE u.tipo = 'aluno' AND p.id_pontuacao IS NULL
ORDER BY u.nome;

-- C) GROUP BY e HAVING (HAVING filtra DEPOIS de agrupar; WHERE, antes)

-- C1. Ocupacao de cada turma em % (matriculas pendentes e ativas).
SELECT t.nome AS turma, t.vagas,
       COUNT(m.id_matricula) AS ocupadas,
       ROUND(100 * COUNT(m.id_matricula) / t.vagas, 1) AS ocupacao_pct
FROM turma t
LEFT JOIN matricula m ON m.id_turma = t.id_turma
                     AND m.status IN ('pendente', 'ativa')
GROUP BY t.id_turma, t.nome, t.vagas
ORDER BY ocupacao_pct DESC;

-- C2. HAVING: turmas lotadas (ocupadas >= vagas).
SELECT t.nome AS turma, t.vagas, COUNT(m.id_matricula) AS ocupadas
FROM turma t
JOIN matricula m ON m.id_turma = t.id_turma
                AND m.status IN ('pendente', 'ativa')
GROUP BY t.id_turma, t.nome, t.vagas
HAVING COUNT(m.id_matricula) >= t.vagas;

-- C3. HAVING: alunos matriculados em mais de uma turma (ativa/pendente).
SELECT a.nome AS aluno, COUNT(*) AS turmas
FROM matricula m
JOIN usuario a ON a.id_usuario = m.id_aluno
WHERE m.status IN ('pendente', 'ativa')
GROUP BY a.id_usuario, a.nome
HAVING COUNT(*) > 1
ORDER BY turmas DESC, a.nome;

-- C4. Receita (pagamentos pagos) por idioma, com total geral (WITH ROLLUP).
SELECT COALESCE(i.nome, 'TOTAL GERAL') AS idioma,
       COUNT(*)      AS pagamentos,
       SUM(pg.valor) AS receita
FROM pagamento pg
JOIN matricula m ON m.id_matricula = pg.id_matricula
JOIN turma t     ON t.id_turma     = m.id_turma
JOIN idioma i    ON i.id_idioma    = t.id_idioma
WHERE pg.status = 'pago'
GROUP BY i.nome WITH ROLLUP;

-- C5. HAVING: professores habilitados em mais de um idioma.
SELECT u.nome AS professor, COUNT(*) AS idiomas,
       GROUP_CONCAT(i.nome ORDER BY i.nome SEPARATOR ' + ') AS lista
FROM professor_idioma pi
JOIN usuario u ON u.id_usuario = pi.id_professor
JOIN idioma i  ON i.id_idioma  = pi.id_idioma
GROUP BY u.id_usuario, u.nome
HAVING COUNT(*) > 1;

-- D) Subconsultas

-- D1. Subconsulta escalar: alunos com pontuacao total acima da media.
SELECT a.nome AS aluno, SUM(p.pontos) AS total
FROM pontuacao p
JOIN usuario a ON a.id_usuario = p.id_aluno
GROUP BY a.id_usuario, a.nome
HAVING SUM(p.pontos) > (SELECT AVG(total_aluno)
                          FROM (SELECT SUM(pontos) AS total_aluno
                                  FROM pontuacao
                                 GROUP BY id_aluno) AS soma)
ORDER BY total DESC;

-- D2. EXISTS: alunos que possuem algum pagamento vencido/atrasado.
SELECT a.nome, a.email
FROM usuario a
WHERE a.tipo = 'aluno'
  AND EXISTS (SELECT 1
                FROM matricula m
                JOIN pagamento pg ON pg.id_matricula = m.id_matricula
               WHERE m.id_aluno = a.id_usuario
                 AND pg.status IN ('pendente', 'atrasado')
                 AND pg.data_vencimento < CURRENT_DATE);

-- D3. NOT IN com subconsulta aninhada: alunos que ainda nao fizeram nenhum desafio de Espanhol.
SELECT u.nome
FROM usuario u
WHERE u.tipo = 'aluno'
  AND u.id_usuario NOT IN (SELECT p.id_aluno
                             FROM pontuacao p
                             JOIN desafio d  ON d.id_desafio  = p.id_desafio
                             JOIN conteudo c ON c.id_conteudo = d.id_conteudo
                            WHERE c.id_idioma = (SELECT id_idioma FROM idioma WHERE codigo = 'ES'))
ORDER BY u.nome;

-- D4. Subconsulta correlacionada: melhor pontuacao de cada desafio
SELECT d.titulo AS desafio, a.nome AS aluno, p.pontos
FROM pontuacao p
JOIN desafio d ON d.id_desafio = p.id_desafio
JOIN usuario a ON a.id_usuario = p.id_aluno
WHERE p.pontos = (SELECT MAX(p2.pontos)
                    FROM pontuacao p2
                   WHERE p2.id_desafio = p.id_desafio)
ORDER BY d.titulo;

-- D5. Subconsulta na lista de colunas: vagas livres de cada turma.
SELECT t.nome AS turma,
       t.vagas - (SELECT COUNT(*)
                    FROM matricula m
                   WHERE m.id_turma = t.id_turma
                     AND m.status IN ('pendente', 'ativa')) AS vagas_livres
FROM turma t
ORDER BY vagas_livres;

-- E) Funcoes de janela: RANK() OVER

-- E1. Ranking de alunos dentro de cada idioma (PARTITION BY idioma).
--     RANK mantem empates e pula posicoes (1, 2, 2, 4); DENSE_RANK nao
--     pula (1, 2, 2, 3); ROW_NUMBER numera sem empate.
SELECT i.nome AS idioma, a.nome AS aluno, SUM(p.pontos) AS total,
       RANK()       OVER (PARTITION BY i.id_idioma ORDER BY SUM(p.pontos) DESC) AS rank_pos,
       DENSE_RANK() OVER (PARTITION BY i.id_idioma ORDER BY SUM(p.pontos) DESC) AS dense_pos,
       ROW_NUMBER() OVER (PARTITION BY i.id_idioma ORDER BY SUM(p.pontos) DESC) AS linha
FROM pontuacao p
JOIN desafio d  ON d.id_desafio  = p.id_desafio
JOIN conteudo c ON c.id_conteudo = d.id_conteudo
JOIN idioma i   ON i.id_idioma   = c.id_idioma
JOIN usuario a  ON a.id_usuario  = p.id_aluno
GROUP BY i.id_idioma, i.nome, a.id_usuario, a.nome
ORDER BY i.nome, rank_pos, a.nome;

-- E2. Top 3 de cada idioma: o RANK() vai para uma CTE (WITH) porque nao
--     da para filtrar funcao de janela direto no WHERE.
WITH ranking AS (
    SELECT i.nome AS idioma, a.nome AS aluno, SUM(p.pontos) AS total,
           RANK() OVER (PARTITION BY i.id_idioma ORDER BY SUM(p.pontos) DESC) AS posicao
    FROM pontuacao p
    JOIN desafio d  ON d.id_desafio  = p.id_desafio
    JOIN conteudo c ON c.id_conteudo = d.id_conteudo
    JOIN idioma i   ON i.id_idioma   = c.id_idioma
    JOIN usuario a  ON a.id_usuario  = p.id_aluno
    GROUP BY i.id_idioma, i.nome, a.id_usuario, a.nome
)
SELECT * FROM ranking WHERE posicao <= 3 ORDER BY idioma, posicao, aluno;

-- E3. Pontos acumulados de cada aluno ao longo do tempo (soma corrida).
SELECT a.nome AS aluno, p.data_registro, p.pontos,
       SUM(p.pontos) OVER (PARTITION BY p.id_aluno ORDER BY p.data_registro, p.id_pontuacao) AS acumulado
FROM pontuacao p
JOIN usuario a ON a.id_usuario = p.id_aluno
ORDER BY a.nome, p.data_registro;
