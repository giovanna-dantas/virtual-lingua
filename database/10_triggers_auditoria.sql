-- =====================================================================
-- VirtuaLingua | Semana 3 | 10_triggers_auditoria.sql
-- Triggers de AUDITORIA gravando em log_auditoria:
--   * exclusão de conta (anonimização ou DELETE físico de usuario)
--   * alteração / exclusão de pagamento
--
-- Privacidade (LGPD): o log guarda ID e tipo, NUNCA nome, e-mail ou
-- senha do usuário.
--
-- Observação: sp_excluir_conta (05) já grava a linha 'ANONIMIZACAO'
-- (evento de negócio). O trigger grava 'EXCLUSAO_CONTA', que garante
-- o registro mesmo se alguém anonimizar com UPDATE direto, fora da
-- procedure. Por isso uma exclusão via procedure gera 2 linhas.
--
-- Pré-requisito: 01 a 09 já executados.
-- =====================================================================
USE virtualingua;

DROP TRIGGER IF EXISTS trg_usuario_audit_au;
DROP TRIGGER IF EXISTS trg_usuario_audit_ad;
DROP TRIGGER IF EXISTS trg_pagamento_audit_au;
DROP TRIGGER IF EXISTS trg_pagamento_audit_ad;

DELIMITER $$

-- Conta anonimizada (anonimizado_em passou de NULL para preenchido)
CREATE TRIGGER trg_usuario_audit_au
AFTER UPDATE ON usuario
FOR EACH ROW
BEGIN
  IF OLD.anonimizado_em IS NULL AND NEW.anonimizado_em IS NOT NULL THEN
    INSERT INTO log_auditoria (tabela, operacao, id_registro, detalhe)
    VALUES ('usuario', 'EXCLUSAO_CONTA', OLD.id_usuario,
            CONCAT('conta anonimizada; tipo=', OLD.tipo));
  END IF;
END$$

-- Remoção física de usuário (a API do administrador permite DELETE)
CREATE TRIGGER trg_usuario_audit_ad
AFTER DELETE ON usuario
FOR EACH ROW
BEGIN
  INSERT INTO log_auditoria (tabela, operacao, id_registro, detalhe)
  VALUES ('usuario', 'EXCLUSAO_FISICA', OLD.id_usuario,
          CONCAT('usuario removido; tipo=', OLD.tipo));
END$$

-- Alteração de pagamento: registra valores ANTES -> DEPOIS
-- (<=> compara com segurança campos que podem ser NULL)
CREATE TRIGGER trg_pagamento_audit_au
AFTER UPDATE ON pagamento
FOR EACH ROW
BEGIN
  IF NOT (OLD.valor           <=> NEW.valor
      AND OLD.status          <=> NEW.status
      AND OLD.data_vencimento <=> NEW.data_vencimento
      AND OLD.data_pagamento  <=> NEW.data_pagamento
      AND OLD.id_matricula    <=> NEW.id_matricula) THEN
    INSERT INTO log_auditoria (tabela, operacao, id_registro, detalhe)
    VALUES ('pagamento', 'ALTERACAO', OLD.id_pagamento,
            CONCAT('status: ', OLD.status, ' -> ', NEW.status,
                   '; valor: ', OLD.valor, ' -> ', NEW.valor,
                   '; vencimento: ', OLD.data_vencimento, ' -> ', NEW.data_vencimento,
                   '; pagamento: ', IFNULL(OLD.data_pagamento,'NULL'), ' -> ', IFNULL(NEW.data_pagamento,'NULL'),
                   '; matricula: ', OLD.id_matricula, ' -> ', NEW.id_matricula));
  END IF;
END$$

CREATE TRIGGER trg_pagamento_audit_ad
AFTER DELETE ON pagamento
FOR EACH ROW
BEGIN
  INSERT INTO log_auditoria (tabela, operacao, id_registro, detalhe)
  VALUES ('pagamento', 'EXCLUSAO', OLD.id_pagamento,
          CONCAT('pagamento removido; matricula=', OLD.id_matricula,
                 '; valor=', OLD.valor, '; status=', OLD.status));
END$$

DELIMITER ;
