-- =====================================================================
-- VirtuaLingua | Semana 3 | 09_triggers_status_matricula.sql
-- Regras de STATUS da matrícula (complementa o 08_triggers_regras_negocio.sql).
--
-- O 08 já cobre: turma lotada, professor habilitado no idioma e
-- pontuação acima do máximo. Aqui entram as regras que faltavam:
--   0) Correção de corrida na última vaga (triggers de vaga do 08).
--   1) Máquina de estados da matrícula (transições permitidas).
--   2) Pagamento 'pago'  ->  matrícula 'pendente' vira 'ativa'.
--
-- Pré-requisito: 01 a 08 já executados.
-- Pode ser executado várias vezes (DROP TRIGGER IF EXISTS).
-- =====================================================================
USE virtualingua;

DROP TRIGGER IF EXISTS trg_matricula_status_bu;
DROP TRIGGER IF EXISTS trg_pagamento_ativa_matricula_au;
DROP TRIGGER IF EXISTS trg_matricula_validar_bi;
DROP TRIGGER IF EXISTS trg_matricula_validar_bu;

DELIMITER $$

-- ---------------------------------------------------------------------
-- 0) CORREÇÃO DE CONCORRÊNCIA nos triggers de vaga do 08
--    Problema encontrado nos testes: o trigger do 08 começa com um
--    SELECT comum (em usuario). No REPEATABLE READ (padrão) isso cria o
--    "snapshot" ANTES de esperar o lock da turma; depois do lock, o
--    COUNT(*) comum lê o snapshot antigo e NÃO enxerga a matrícula que
--    o outro aluno acabou de confirmar => a última vaga era vendida
--    2 vezes. Solução: o COUNT passa a ser leitura ATUAL (FOR SHARE).
--    O resto da lógica é idêntico ao 08. (Se o grupo preferir, aplique
--    a mesma troca direto no 08 e apague esta seção 0.)
-- ---------------------------------------------------------------------
CREATE TRIGGER trg_matricula_validar_bi BEFORE INSERT ON matricula FOR EACH ROW
BEGIN
  DECLARE v_tipo VARCHAR(15);
  DECLARE v_ativo BOOLEAN;
  DECLARE v_vagas INT;
  DECLARE v_ocupadas INT;
  SELECT tipo,ativo INTO v_tipo,v_ativo FROM usuario WHERE id_usuario=NEW.id_aluno;
  IF v_tipo<>'aluno' OR v_ativo=0 THEN SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Matrícula exige usuário ativo do tipo aluno'; END IF;
  SELECT vagas INTO v_vagas FROM turma WHERE id_turma=NEW.id_turma FOR UPDATE;
  SELECT COUNT(*) INTO v_ocupadas FROM matricula WHERE id_turma=NEW.id_turma AND status IN ('pendente','ativa') FOR SHARE;
  IF v_ocupadas>=v_vagas AND NEW.status IN ('pendente','ativa') THEN SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Turma sem vagas disponíveis'; END IF;
END$$

CREATE TRIGGER trg_matricula_validar_bu BEFORE UPDATE ON matricula FOR EACH ROW
BEGIN
  DECLARE v_tipo VARCHAR(15);
  DECLARE v_ativo BOOLEAN;
  DECLARE v_vagas INT;
  DECLARE v_ocupadas INT;
  SELECT tipo,ativo INTO v_tipo,v_ativo FROM usuario WHERE id_usuario=NEW.id_aluno;
  IF v_tipo<>'aluno' OR v_ativo=0 THEN SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Matrícula exige usuário ativo do tipo aluno'; END IF;
  IF NEW.status IN ('pendente','ativa') AND OLD.status NOT IN ('pendente','ativa') THEN
    SELECT vagas INTO v_vagas FROM turma WHERE id_turma=NEW.id_turma FOR UPDATE;
    SELECT COUNT(*) INTO v_ocupadas FROM matricula WHERE id_turma=NEW.id_turma AND status IN ('pendente','ativa') AND id_matricula<>OLD.id_matricula FOR SHARE;
    IF v_ocupadas>=v_vagas THEN SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Turma sem vagas disponíveis'; END IF;
  END IF;
END$$

-- ---------------------------------------------------------------------
-- 1) Transições permitidas de status da matrícula
--      pendente  -> ativa | cancelada
--      ativa     -> concluida | cancelada
--      cancelada -> pendente   (nova tentativa: reaproveita a linha por
--                               causa do UNIQUE aluno+turma; a vaga é
--                               revalidada pelo trigger do 08)
--      concluida -> (nenhuma, estado final)
-- ---------------------------------------------------------------------
CREATE TRIGGER trg_matricula_status_bu
BEFORE UPDATE ON matricula
FOR EACH ROW
FOLLOWS trg_matricula_validar_bu
BEGIN
  IF NEW.status <> OLD.status THEN
    IF NOT (
         (OLD.status = 'pendente'  AND NEW.status IN ('ativa','cancelada'))
      OR (OLD.status = 'ativa'     AND NEW.status IN ('concluida','cancelada'))
      OR (OLD.status = 'cancelada' AND NEW.status = 'pendente')
    ) THEN
      SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Transição de status da matrícula não permitida';
    END IF;
  END IF;
END$$

-- ---------------------------------------------------------------------
-- 2) Pagamento confirmado ativa a matrícula
--    Só mexe em matrícula 'pendente' (nunca reativa cancelada/concluída).
--    Roda na MESMA transação do UPDATE do pagamento: se algo falhar,
--    os dois voltam juntos (atomicidade).
-- ---------------------------------------------------------------------
CREATE TRIGGER trg_pagamento_ativa_matricula_au
AFTER UPDATE ON pagamento
FOR EACH ROW
BEGIN
  IF NEW.status = 'pago' AND OLD.status <> 'pago' THEN
    UPDATE matricula
       SET status = 'ativa'
     WHERE id_matricula = NEW.id_matricula
       AND status = 'pendente';
  END IF;
END$$

DELIMITER ;
