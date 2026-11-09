-- =====================================================================
-- VirtuaLingua | Semana 3 | 13_transacoes_acid_savepoint.sql
-- DEMONSTRAÇÃO de transações (ACID): COMMIT, ROLLBACK, SAVEPOINT em lote.
--
-- COMO USAR NO WORKBENCH
--   Rode UM BLOCO por vez: selecione o bloco inteiro (do título "BLOCO"
--   até o próximo) e aperte Ctrl+Shift+Enter. Tire um print por bloco.
--   NÃO use o raio com o arquivo inteiro: o bloco 6 tem um erro de
--   propósito e o Workbench para o script nele.
--
-- Pré-requisito: 01 a 11 executados. O script deixa o banco como estava
-- (as linhas criadas são apagadas no fim dos blocos 1 e 3).
-- =====================================================================
USE virtualingua;

-- =====================================================================
-- BLOCO 0 - Estado inicial (rode e anote os números)
-- =====================================================================
SELECT id_turma, nome, vagas FROM turma WHERE id_turma = 5;
SELECT COUNT(*) AS matriculas_turma5 FROM matricula WHERE id_turma = 5;
SELECT COUNT(*) AS total_pagamentos  FROM pagamento;
SELECT COUNT(*) AS total_log         FROM log_auditoria;

-- =====================================================================
-- BLOCO 1 - COMMIT: matrícula + pagamento viram permanentes JUNTOS
--           (sp_matricular_aluno faz START TRANSACTION ... COMMIT)
-- =====================================================================
CALL sp_matricular_aluno(16, 5, 300.00, '2026-12-10', @id_mat, @id_pag);
SELECT @id_mat AS id_matricula, @id_pag AS id_pagamento;
SELECT * FROM matricula WHERE id_matricula = @id_mat;
SELECT * FROM pagamento WHERE id_pagamento = @id_pag;

-- limpeza do bloco 1 (pagamento primeiro, por causa da chave estrangeira)
DELETE FROM pagamento WHERE id_pagamento = @id_pag;
DELETE FROM matricula WHERE id_matricula = @id_mat;

-- =====================================================================
-- BLOCO 2 - ROLLBACK: nada do que aconteceu na transação sobrevive
--   Pagamento 7 pago => o trigger 09 ativa a matrícula 17 e o trigger
--   10 grava auditoria. O ROLLBACK desfaz os TRÊS (atomicidade).
-- =====================================================================
SELECT status FROM pagamento WHERE id_pagamento = 7;            -- pendente
SELECT status FROM matricula WHERE id_matricula = 17;           -- pendente
SELECT COUNT(*) AS log_antes FROM log_auditoria;

START TRANSACTION;
UPDATE pagamento SET status = 'pago', data_pagamento = CURDATE() WHERE id_pagamento = 7;
SELECT status FROM matricula WHERE id_matricula = 17;           -- ativa (trigger)
SELECT COUNT(*) AS log_dentro_da_transacao FROM log_auditoria;  -- +1
ROLLBACK;

SELECT status FROM pagamento WHERE id_pagamento = 7;            -- pendente de novo
SELECT status FROM matricula WHERE id_matricula = 17;           -- pendente de novo
SELECT COUNT(*) AS log_depois FROM log_auditoria;               -- igual ao log_antes

-- =====================================================================
-- BLOCO 3 - SAVEPOINT manual: desfazer só uma PARTE da transação
-- =====================================================================
START TRANSACTION;

UPDATE pagamento SET status = 'cancelado' WHERE id_pagamento = 4;   -- passo A
SAVEPOINT apos_cancelar_pagamento;
UPDATE matricula SET status = 'cancelada' WHERE id_matricula = 18;  -- passo B

SELECT 'antes do rollback to savepoint' AS momento,
       (SELECT status FROM pagamento WHERE id_pagamento = 4) AS pagamento_4,
       (SELECT status FROM matricula WHERE id_matricula = 18) AS matricula_18;

ROLLBACK TO SAVEPOINT apos_cancelar_pagamento;                      -- desfaz só o passo B

SELECT 'depois do rollback to savepoint' AS momento,
       (SELECT status FROM pagamento WHERE id_pagamento = 4) AS pagamento_4,   -- cancelado (A mantido)
       (SELECT status FROM matricula WHERE id_matricula = 18) AS matricula_18; -- pendente  (B desfeito)

ROLLBACK;   -- aqui desistimos de tudo para o banco ficar como estava

SELECT status FROM pagamento WHERE id_pagamento = 4;               -- atrasado de novo

-- =====================================================================
-- BLOCO 4 - SAVEPOINT em LOTE: matricular vários alunos de uma vez.
--   Alunos: 17 e 18 (ok), 12 (já matriculado), 1 (é administrador),
--   999 (não existe). Cada um tem seu SAVEPOINT: os que falham são
--   desfeitos sozinhos e os que deram certo entram no COMMIT final.
-- =====================================================================
CALL sp_matricular_lote(5, '[17, 18, 12, 1, 999]', 300.00, '2026-12-10');

-- conferência: só 17 e 18 foram matriculados (12 já existia)
SELECT m.id_matricula, m.id_aluno, m.status, p.id_pagamento, p.valor
  FROM matricula m LEFT JOIN pagamento p ON p.id_matricula = m.id_matricula
 WHERE m.id_turma = 5 ORDER BY m.id_matricula;

-- limpeza do bloco 4
DELETE p FROM pagamento p JOIN matricula m ON m.id_matricula = p.id_matricula
 WHERE m.id_turma = 5 AND m.id_aluno IN (17, 18);
DELETE FROM matricula WHERE id_turma = 5 AND id_aluno IN (17, 18);

-- =====================================================================
-- BLOCO 5 - CONSISTÊNCIA: o banco recusa estado inválido (CHECK)
--   Rode ESTA linha sozinha. Erro esperado: 3819 (ck_pagamento_data).
-- =====================================================================
UPDATE pagamento SET status = 'pago' WHERE id_pagamento = 7;   -- 'pago' sem data_pagamento

-- =====================================================================
-- BLOCO 6 - ATOMICIDADE com erro: turma lotada
--   Rode ESTA linha sozinha. Erro esperado: 1644 'Turma sem vagas
--   disponíveis'. Em seguida confira que NADA foi gravado.
-- =====================================================================
CALL sp_matricular_aluno(11, 7, 300.00, '2026-12-10', @m, @p);

SELECT COUNT(*) AS matriculas_turma7 FROM matricula WHERE id_turma = 7;   -- continua 2
SELECT COUNT(*) AS total_pagamentos  FROM pagamento;                      -- igual ao bloco 0
