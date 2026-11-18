-- RF10 - Excluir conta com conformidade LGPD (RNF02)   (MySQL 8 / Workbench)
-- Estrategia: ANONIMIZACAO. Os dados pessoais deixam de existir; o historico
-- academico e financeiro e mantido sem identificar a pessoa.
-- Uso:  CALL sp_excluir_conta(10);

USE virtualingua;

DROP PROCEDURE IF EXISTS sp_excluir_conta;

DELIMITER $$

CREATE PROCEDURE sp_excluir_conta(IN p_id_usuario INT)
BEGIN
    DECLARE v_tipo VARCHAR(15) DEFAULT NULL;

    -- Qualquer erro desfaz tudo e e repassado a quem chamou
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        RESIGNAL;
    END;

    -- START TRANSACTION confirma (COMMIT) qualquer transacao que
    -- ja estivesse aberta na conexao. Chame a procedure fora de uma transacao.
    START TRANSACTION;

    -- Trava a linha do usuario e recusa se nao existir ou ja foi anonimizado
    SELECT tipo INTO v_tipo
      FROM usuario
     WHERE id_usuario = p_id_usuario
       AND anonimizado_em IS NULL
       FOR UPDATE;

    IF v_tipo IS NULL THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Usuario inexistente ou ja anonimizado';
    END IF;

    -- Matriculas ainda em aberto sao canceladas (e os pagamentos pendentes delas)
    UPDATE pagamento p
      JOIN matricula m ON m.id_matricula = p.id_matricula
       SET p.status = 'cancelado'
     WHERE m.id_aluno = p_id_usuario
       AND m.status IN ('pendente','ativa')
       AND p.status IN ('pendente','atrasado');

    UPDATE matricula
       SET status = 'cancelada'
     WHERE id_aluno = p_id_usuario
       AND status IN ('pendente','ativa');

    -- Professor: libera turmas e conteudos (ficam sem responsavel) e habilitacoes
    UPDATE turma    SET id_professor = NULL WHERE id_professor = p_id_usuario;
    UPDATE conteudo SET id_professor = NULL WHERE id_professor = p_id_usuario;
    DELETE FROM professor_idioma WHERE id_professor = p_id_usuario;

    -- Anonimizacao dos dados pessoais
    UPDATE usuario
       SET nome           = 'Usuario removido',
           email          = CONCAT('removido+', id_usuario, '@anonimo.invalid'),
           senha_hash     = '!',
           ativo          = FALSE,
           anonimizado_em = NOW()
     WHERE id_usuario = p_id_usuario;

    INSERT INTO log_auditoria (tabela, operacao, id_registro, detalhe)
    VALUES ('usuario', 'ANONIMIZACAO', p_id_usuario,
            CONCAT('RF10 - exclusao de conta (', v_tipo, ')'));

    COMMIT;
END$$

DELIMITER ;