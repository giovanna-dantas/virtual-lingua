-- =====================================================================
-- VirtuaLingua | Semana 3 | 14_demo_niveis_isolamento.sql
-- DEMONSTRAÇÃO dos níveis de isolamento com DUAS SESSÕES.
--
-- COMO USAR NO WORKBENCH
--   1. Abra DUAS abas de consulta (SQL tabs) na MESMA conexão:
--      menu File > New Query Tab (Ctrl+T). Chame uma de "A" e outra de
--      "B" (botão direito na aba > Rename).  Cada aba é uma sessão.
--   2. Em CADA aba rode primeiro o bloco "PREPARO".
--   3. Siga a ordem dos passos: A1, B1, A2, B2... Cada passo diz em que
--      aba rodar. Selecione o passo e Ctrl+Shift+Enter.
--   4. Compare o resultado com o comentário "=> esperado".
--
-- Dados usados: pagamento 7 (valor 360.00) e matrículas da turma 5.
-- No fim de cada experimento há uma LIMPEZA para o banco voltar ao normal.
--
-- Resumo (MySQL/InnoDB):
--   nível              | leitura suja | não-repetível | fantasma
--   READ UNCOMMITTED   |    SIM       |     SIM       |   SIM
--   READ COMMITTED     |    não       |     SIM       |   SIM
--   REPEATABLE READ *  |    não       |     não       |   não (leitura comum)
--   SERIALIZABLE       |    não       |     não       |   não (com bloqueios)
--   (* padrão do InnoDB)
-- =====================================================================

-- =====================================================================
-- PREPARO  (rode nas abas A e B)
-- =====================================================================
USE virtualingua;
SET SESSION innodb_lock_wait_timeout = 20;   -- não deixa a demo travar por 50 s
SELECT @@transaction_isolation AS nivel_atual;   -- => REPEATABLE-READ
SELECT valor FROM pagamento WHERE id_pagamento = 7;   -- => 360.00


-- #####################################################################
-- EXPERIMENTO 1 - READ UNCOMMITTED: LEITURA SUJA (dirty read)
-- #####################################################################
-- A1 (aba A)
SET SESSION TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;
START TRANSACTION;
SELECT valor FROM pagamento WHERE id_pagamento = 7;          -- => 360.00

-- B1 (aba B)  -- altera e NÃO confirma
START TRANSACTION;
UPDATE pagamento SET valor = 999.00 WHERE id_pagamento = 7;

-- A2 (aba A)
SELECT valor FROM pagamento WHERE id_pagamento = 7;          -- => 999.00  (leu dado NÃO confirmado!)

-- B2 (aba B)  -- desiste
ROLLBACK;

-- A3 (aba A)
SELECT valor FROM pagamento WHERE id_pagamento = 7;          -- => 360.00  (o 999 nunca existiu de verdade)
COMMIT;
SET SESSION TRANSACTION ISOLATION LEVEL REPEATABLE READ;


-- #####################################################################
-- EXPERIMENTO 2 - READ COMMITTED: LEITURA NÃO-REPETÍVEL
-- #####################################################################
-- A1 (aba A)
SET SESSION TRANSACTION ISOLATION LEVEL READ COMMITTED;
START TRANSACTION;
SELECT valor FROM pagamento WHERE id_pagamento = 7;          -- => 360.00

-- B1 (aba B)  -- altera e CONFIRMA (autocommit ligado)
UPDATE pagamento SET valor = 400.00 WHERE id_pagamento = 7;

-- A2 (aba A)  -- mesma consulta, mesma transação, resultado diferente
SELECT valor FROM pagamento WHERE id_pagamento = 7;          -- => 400.00  (não-repetível)
COMMIT;
SET SESSION TRANSACTION ISOLATION LEVEL REPEATABLE READ;

-- LIMPEZA (aba B)
UPDATE pagamento SET valor = 360.00 WHERE id_pagamento = 7;


-- #####################################################################
-- EXPERIMENTO 3 - REPEATABLE READ (padrão): foto fixa da transação
-- #####################################################################
-- A1 (aba A)
SET SESSION TRANSACTION ISOLATION LEVEL REPEATABLE READ;
START TRANSACTION;
SELECT valor FROM pagamento WHERE id_pagamento = 7;          -- => 360.00  (a foto é tirada aqui)
SELECT COUNT(*) AS matriculas_turma5 FROM matricula WHERE id_turma = 5;   -- => 3

-- B1 (aba B)  -- muda um valor E cria uma linha nova, tudo confirmado
UPDATE pagamento SET valor = 400.00 WHERE id_pagamento = 7;
INSERT INTO matricula (id_aluno, id_turma, status) VALUES (16, 5, 'pendente');

-- A2 (aba A)  -- A continua vendo a foto antiga
SELECT valor FROM pagamento WHERE id_pagamento = 7;          -- => 360.00  (repetível)
SELECT COUNT(*) AS matriculas_turma5 FROM matricula WHERE id_turma = 5;   -- => 3  (sem fantasma)

-- A3 (aba A)  -- leitura com bloqueio ("leitura atual") enxerga o que foi confirmado
SELECT COUNT(*) AS matriculas_turma5_atual
  FROM matricula WHERE id_turma = 5 FOR UPDATE;              -- => 4
COMMIT;

-- A4 (aba A)  -- transação nova = foto nova
SELECT valor FROM pagamento WHERE id_pagamento = 7;          -- => 400.00

-- LIMPEZA (aba B)
UPDATE pagamento SET valor = 360.00 WHERE id_pagamento = 7;
DELETE FROM matricula WHERE id_turma = 5 AND id_aluno = 16;


-- #####################################################################
-- EXPERIMENTO 4 - SERIALIZABLE: leitura vira bloqueio compartilhado
-- #####################################################################
-- A1 (aba A)
SET SESSION TRANSACTION ISOLATION LEVEL SERIALIZABLE;
START TRANSACTION;
SELECT valor FROM pagamento WHERE id_pagamento = 7;          -- => 360.00  (trava a linha para leitura)

-- B1 (aba B)  -- FICA GIRANDO, esperando a aba A (até 20 s e dá erro 1205)
START TRANSACTION;
UPDATE pagamento SET valor = 400.00 WHERE id_pagamento = 7;

-- A2 (aba A)  -- ENQUANTO a aba B espera, tire print disto:
SELECT trx_id, trx_state, trx_started, LEFT(trx_query, 60) AS consulta
  FROM information_schema.innodb_trx;                         -- => 2 transações, uma LOCK WAIT

-- A3 (aba A)  -- libera; a aba B conclui o UPDATE na hora
COMMIT;

-- B2 (aba B)  -- desfaz para não alterar o dado
ROLLBACK;

-- VOLTE AO PADRÃO (rode nas abas A e B)
SET SESSION TRANSACTION ISOLATION LEVEL REPEATABLE READ;

-- Contraste: em REPEATABLE READ o passo B1 NÃO esperaria, porque o
-- SELECT comum da aba A não trava nada. Serializable troca
-- concorrência por segurança.
