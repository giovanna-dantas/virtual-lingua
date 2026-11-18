-- DEMONSTRAÇÃO de LOCK (a última vaga da turma) e de DEADLOCK.
-- Usa DUAS sessões (abas A e B do Workbench) - veja as instruções do
-- arquivo 14_demo_niveis_isolamento.sql.
--
-- Parte 1: duas pessoas disputam a ÚLTIMA vaga. Quem chega primeiro
--          trava a linha da turma; o outro espera e depois recebe
--          "Turma sem vagas disponíveis". Ninguém fica sem pagar
--          nem duas pessoas ficam com a mesma vaga.
-- Parte 2: DEADLOCK - cada sessão segura um lock e pede o do outro.
--          O InnoDB derruba uma delas (erro 1213) e a outra segue.
-- Parte 3: como evitar o deadlock (ordem fixa dos locks).
--
-- Pré-requisito: 01 a 11 executados.

USE virtualingua;
INSERT INTO turma (nome, id_idioma, id_nivel, id_professor, carga_horaria, vagas)
VALUES ('Demo Última Vaga', 1, 1, NULL, 20, 1);
SELECT id_turma, nome, vagas FROM turma WHERE nome = 'Demo Última Vaga';

USE virtualingua;
SET SESSION innodb_lock_wait_timeout = 20;
SET @t := (SELECT id_turma FROM turma WHERE nome = 'Demo Última Vaga');
SELECT @t AS id_turma_demo;

-- PARTE 1A - ÚLTIMA VAGA com SELECT ... FOR UPDATE
-- (é o mesmo padrão usado por sp_matricular_aluno)
-- A1 (aba A)  -- Camila (aluno 7) reserva a vaga, mas ainda NÃO confirma
START TRANSACTION;
SELECT vagas FROM turma WHERE id_turma = @t FOR UPDATE;                         -- => 1
SELECT COUNT(*) AS ocupadas FROM matricula
 WHERE id_turma = @t AND status IN ('pendente','ativa');                        -- => 0
INSERT INTO matricula (id_aluno, id_turma, status) VALUES (7, @t, 'pendente');

-- B1 (aba B)  -- Daniel (aluno 8) tenta a mesma vaga. FICA ESPERANDO (girando)
START TRANSACTION;
SELECT vagas FROM turma WHERE id_turma = @t FOR UPDATE;

-- A2 (aba A)  -- ENQUANTO a aba B espera, tire print de quem espera quem:
SELECT waiting_pid, waiting_query, blocking_pid, wait_age_secs
  FROM sys.innodb_lock_waits;                                                   -- => 1 linha
SELECT trx_id, trx_state, trx_rows_locked, LEFT(trx_query, 50) AS consulta
  FROM information_schema.innodb_trx;

-- A3 (aba A)  -- confirma a matrícula; a aba B é liberada
COMMIT;

-- B2 (aba B)  -- agora B enxerga a vaga ocupada
SELECT COUNT(*) AS ocupadas FROM matricula
 WHERE id_turma = @t AND status IN ('pendente','ativa');                        -- => 1  (>= vagas)
ROLLBACK;   -- B desiste: "Turma sem vagas disponíveis"

-- LIMPEZA (aba A)
DELETE FROM matricula WHERE id_turma = @t;

-- PARTE 1B - O BANCO PROTEGE MESMO SE O APP ESQUECER O FOR UPDATE
-- O trigger trg_matricula_validar_bi (08) trava a turma sozinho.
-- A1 (aba A)
START TRANSACTION;
INSERT INTO matricula (id_aluno, id_turma, status) VALUES (7, @t, 'pendente');

-- B1 (aba B)  -- insert direto, SEM select antes: espera pelo trigger
START TRANSACTION;
INSERT INTO matricula (id_aluno, id_turma, status) VALUES (8, @t, 'pendente');

-- A2 (aba A)
COMMIT;

-- B2 (aba B)  -- B recebe o erro 1644 "Turma sem vagas disponíveis" (tire print)
ROLLBACK;

-- LIMPEZA (aba A)
DELETE FROM matricula WHERE id_turma = @t;


-- PARTE 2 - DEADLOCK: duas trocas de turma em ordem oposta
--   Aba A: vai da turma 4 para a 5.   Aba B: vai da turma 5 para a 4.
-- A1 (aba A)
START TRANSACTION;
SELECT id_turma FROM turma WHERE id_turma = 4 FOR UPDATE;

-- B1 (aba B)
START TRANSACTION;
SELECT id_turma FROM turma WHERE id_turma = 5 FOR UPDATE;

-- A2 (aba A)  -- pede a turma 5, que a aba B segura: ESPERA
SELECT id_turma FROM turma WHERE id_turma = 5 FOR UPDATE;

-- B2 (aba B)  -- pede a turma 4, que a aba A segura: CICLO => DEADLOCK
SELECT id_turma FROM turma WHERE id_turma = 4 FOR UPDATE;
-- => ERROR 1213 (40001): Deadlock found when trying to get lock;
--    try restarting transaction.   (tire print do erro)
--    A transação da aba B foi DESFEITA pelo InnoDB. A aba A, que estava
--    esperando, já recebeu a turma 5 (volte na aba A e veja).

-- A3 (aba A)
COMMIT;

-- Diagnóstico (qualquer aba, com usuário root) - tire print do bloco
-- "LATEST DETECTED DEADLOCK":
SHOW ENGINE INNODB STATUS;
-- No Workbench, clique no ícone de "olho"/campo Status e copie o trecho.
-- Atalho: SELECT * FROM performance_schema.data_locks;  (só mostra locks ativos)

-- B3 (aba B)  -- limpa a sessão
ROLLBACK;

-- PARTE 3 - SOLUÇÃO: sempre travar na MESMA ORDEM (menor id primeiro)
-- A1 (aba A)
START TRANSACTION;
SELECT id_turma FROM turma WHERE id_turma IN (4, 5) ORDER BY id_turma FOR UPDATE;

-- B1 (aba B)  -- espera a aba A (sem deadlock)
START TRANSACTION;
SELECT id_turma FROM turma WHERE id_turma IN (4, 5) ORDER BY id_turma FOR UPDATE;

-- A2 (aba A)
COMMIT;

-- B2 (aba B)  -- B é liberada e termina normalmente
COMMIT;

-- Regras práticas:
--   * travar sempre na mesma ordem;
--   * transações curtas (nada de esperar o usuário dentro da transação);
--   * o app deve tentar de novo quando receber 1213 (deadlock) ou
--     1205 (tempo de espera esgotado).

-- LIMPEZA FINAL (qualquer aba)
DELETE FROM matricula WHERE id_turma = (SELECT id_turma FROM turma WHERE nome = 'Demo Última Vaga');
DELETE FROM turma WHERE nome = 'Demo Última Vaga';
