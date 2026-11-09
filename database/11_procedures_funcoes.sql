-- =====================================================================
-- VirtuaLingua | Semana 3 | 11_procedures_funcoes.sql
--   sp_matricular_aluno     matrícula + pagamento em UMA transação
--   sp_matricular_lote      várias matrículas com SAVEPOINT por aluno
--   sp_registrar_pontuacao  valida e grava a pontuação do desafio
--   fn_media_aluno          média percentual de aproveitamento
--
-- Pré-requisito: 01 a 10 já executados.
-- Atenção: START TRANSACTION dentro de uma procedure FAZ COMMIT de
-- qualquer transação que a sessão já tivesse aberta. Chame as
-- procedures com autocommit ligado ou sem transação pendente.
-- =====================================================================
USE virtualingua;

DROP PROCEDURE IF EXISTS sp_matricular_aluno;
DROP PROCEDURE IF EXISTS sp_matricular_lote;
DROP PROCEDURE IF EXISTS sp_registrar_pontuacao;
DROP FUNCTION  IF EXISTS fn_media_aluno;

DELIMITER $$

-- ---------------------------------------------------------------------
-- sp_matricular_aluno(aluno, turma, valor, vencimento, OUT matrícula, OUT pagamento)
--
-- 1) trava a linha da turma (SELECT ... FOR UPDATE): duas matrículas
--    simultâneas na MESMA turma entram em fila, então a última vaga
--    nunca é vendida duas vezes;
-- 2) valida aluno, duplicidade, vaga, valor e vencimento;
-- 3) insere matrícula 'pendente' + pagamento 'pendente';
-- 4) qualquer erro => ROLLBACK de tudo (nem matrícula nem pagamento).
-- Se o aluno tinha matrícula CANCELADA nessa turma, a linha é
-- reaproveitada (UNIQUE aluno+turma) e volta para 'pendente'.
-- ---------------------------------------------------------------------
CREATE PROCEDURE sp_matricular_aluno(
    IN  p_id_aluno        INT,
    IN  p_id_turma        INT,
    IN  p_valor           DECIMAL(10,2),
    IN  p_data_vencimento DATE,
    OUT p_id_matricula    INT,
    OUT p_id_pagamento    INT
)
BEGIN
    DECLARE v_vagas     INT          DEFAULT NULL;
    DECLARE v_ocupadas  INT          DEFAULT 0;
    DECLARE v_tipo      VARCHAR(15)  DEFAULT NULL;
    DECLARE v_ativo     BOOLEAN      DEFAULT NULL;
    DECLARE v_mat_id    INT          DEFAULT NULL;
    DECLARE v_mat_st    VARCHAR(10)  DEFAULT NULL;

    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        RESIGNAL;
    END;

    SET p_id_matricula = NULL;
    SET p_id_pagamento = NULL;

    START TRANSACTION;

    SELECT vagas INTO v_vagas
      FROM turma WHERE id_turma = p_id_turma FOR UPDATE;
    IF v_vagas IS NULL THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Turma inexistente';
    END IF;

    SELECT tipo, ativo INTO v_tipo, v_ativo
      FROM usuario WHERE id_usuario = p_id_aluno FOR UPDATE;
    IF v_tipo IS NULL OR v_tipo <> 'aluno' OR v_ativo = 0 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Matrícula exige usuário ativo do tipo aluno';
    END IF;

    IF p_valor IS NULL OR p_valor <= 0 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Valor do pagamento deve ser positivo';
    END IF;
    IF p_data_vencimento IS NULL THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Data de vencimento é obrigatória';
    END IF;

    SELECT id_matricula, status INTO v_mat_id, v_mat_st
      FROM matricula
     WHERE id_aluno = p_id_aluno AND id_turma = p_id_turma
       FOR UPDATE;
    IF v_mat_id IS NOT NULL AND v_mat_st <> 'cancelada' THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Aluno já matriculado nesta turma';
    END IF;

    SELECT COUNT(*) INTO v_ocupadas
      FROM matricula
     WHERE id_turma = p_id_turma AND status IN ('pendente','ativa');
    IF v_ocupadas >= v_vagas THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Turma sem vagas disponíveis';
    END IF;

    IF v_mat_id IS NULL THEN
        INSERT INTO matricula (id_aluno, id_turma, status)
        VALUES (p_id_aluno, p_id_turma, 'pendente');
        SET v_mat_id = LAST_INSERT_ID();
    ELSE
        UPDATE matricula SET status = 'pendente', data_matricula = CURDATE()
         WHERE id_matricula = v_mat_id;
    END IF;

    INSERT INTO pagamento (id_matricula, valor, data_vencimento, status)
    VALUES (v_mat_id, p_valor, p_data_vencimento, 'pendente');

    SET p_id_matricula = v_mat_id;
    SET p_id_pagamento = LAST_INSERT_ID();

    COMMIT;
END$$

-- ---------------------------------------------------------------------
-- sp_matricular_lote(turma, JSON de alunos, valor, vencimento)
-- Ex.: CALL sp_matricular_lote(4, '[7, 8, 5, 1, 999]', 300, '2026-12-10');
--
-- UMA transação para o lote inteiro e um SAVEPOINT por aluno:
-- se um aluno falha (já matriculado, não é aluno, turma lotada...),
-- ROLLBACK TO SAVEPOINT desfaz só ele e o lote continua.
-- No fim, COMMIT e uma tabela de resultado por aluno.
-- ---------------------------------------------------------------------
CREATE PROCEDURE sp_matricular_lote(
    IN p_id_turma        INT,
    IN p_ids_alunos      JSON,
    IN p_valor           DECIMAL(10,2),
    IN p_data_vencimento DATE
)
BEGIN
    DECLARE v_i      INT DEFAULT 0;
    DECLARE v_n      INT DEFAULT 0;
    DECLARE v_aluno  INT;
    DECLARE v_mat    INT;
    DECLARE v_msg    TEXT;

    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        RESIGNAL;
    END;

    IF p_ids_alunos IS NULL OR JSON_TYPE(p_ids_alunos) <> 'ARRAY' THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Informe os alunos como array JSON, ex.: [7,8,9]';
    END IF;

    DROP TEMPORARY TABLE IF EXISTS tmp_lote_resultado;
    CREATE TEMPORARY TABLE tmp_lote_resultado (
        id_aluno  INT,
        resultado VARCHAR(10),
        mensagem  VARCHAR(255)
    ) ENGINE = MEMORY;   -- MEMORY não participa do rollback: o log do lote sobrevive

    SET v_n = JSON_LENGTH(p_ids_alunos);

    START TRANSACTION;
    -- trava a turma uma vez para o lote todo
    SELECT id_turma INTO v_mat FROM turma WHERE id_turma = p_id_turma FOR UPDATE;
    IF v_mat IS NULL THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Turma inexistente';
    END IF;

    WHILE v_i < v_n DO
        SET v_aluno = JSON_EXTRACT(p_ids_alunos, CONCAT('$[', v_i, ']'));
        SET v_mat = NULL;

        BEGIN
            -- erro neste aluno: desfaz SÓ o aluno e segue o lote
            DECLARE EXIT HANDLER FOR SQLEXCEPTION
            BEGIN
                GET DIAGNOSTICS CONDITION 1 v_msg = MESSAGE_TEXT;
                ROLLBACK TO SAVEPOINT sp_item;
                INSERT INTO tmp_lote_resultado VALUES (v_aluno, 'ERRO', v_msg);
            END;

            SAVEPOINT sp_item;

            INSERT INTO matricula (id_aluno, id_turma, status)
            VALUES (v_aluno, p_id_turma, 'pendente');
            SET v_mat = LAST_INSERT_ID();

            INSERT INTO pagamento (id_matricula, valor, data_vencimento, status)
            VALUES (v_mat, p_valor, p_data_vencimento, 'pendente');

            RELEASE SAVEPOINT sp_item;
            INSERT INTO tmp_lote_resultado VALUES (v_aluno, 'OK', CONCAT('matrícula ', v_mat));
        END;

        SET v_i = v_i + 1;
    END WHILE;

    COMMIT;
    SELECT * FROM tmp_lote_resultado;
END$$

-- ---------------------------------------------------------------------
-- sp_registrar_pontuacao(aluno, desafio, pontos, OUT resultado)
-- Regras:
--   * aluno ativo; desafio existente;
--   * 0 <= pontos <= pontuacao_maxima do desafio;
--   * aluno com matrícula 'ativa' ou 'concluida' em turma do MESMO
--     idioma do conteúdo do desafio;
--   * UNIQUE aluno+desafio: se já existe pontuação, fica a MAIOR
--     (resultado: INSERIDA | ATUALIZADA | MANTIDA).
-- ---------------------------------------------------------------------
CREATE PROCEDURE sp_registrar_pontuacao(
    IN  p_id_aluno   INT,
    IN  p_id_desafio INT,
    IN  p_pontos     DECIMAL(5,2),
    OUT p_resultado  VARCHAR(10)
)
BEGIN
    DECLARE v_max      INT          DEFAULT NULL;
    DECLARE v_idioma   INT          DEFAULT NULL;
    DECLARE v_tipo     VARCHAR(15)  DEFAULT NULL;
    DECLARE v_ativo    BOOLEAN      DEFAULT NULL;
    DECLARE v_matric   INT          DEFAULT 0;
    DECLARE v_pont_id  INT          DEFAULT NULL;
    DECLARE v_atual    DECIMAL(5,2) DEFAULT NULL;

    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        RESIGNAL;
    END;

    SET p_resultado = NULL;

    START TRANSACTION;

    SELECT tipo, ativo INTO v_tipo, v_ativo
      FROM usuario WHERE id_usuario = p_id_aluno;
    IF v_tipo IS NULL OR v_tipo <> 'aluno' OR v_ativo = 0 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Pontuação exige usuário ativo do tipo aluno';
    END IF;

    SELECT d.pontuacao_maxima, c.id_idioma INTO v_max, v_idioma
      FROM desafio d JOIN conteudo c ON c.id_conteudo = d.id_conteudo
     WHERE d.id_desafio = p_id_desafio;
    IF v_max IS NULL THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Desafio inexistente';
    END IF;

    IF p_pontos IS NULL OR p_pontos < 0 OR p_pontos > v_max THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Pontuação fora do limite do desafio';
    END IF;

    SELECT COUNT(*) INTO v_matric
      FROM matricula m JOIN turma t ON t.id_turma = m.id_turma
     WHERE m.id_aluno = p_id_aluno
       AND t.id_idioma = v_idioma
       AND m.status IN ('ativa','concluida');
    IF v_matric = 0 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Aluno sem matrícula ativa no idioma do desafio';
    END IF;

    -- trava a pontuação existente (se houver) para evitar corrida
    SELECT id_pontuacao, pontos INTO v_pont_id, v_atual
      FROM pontuacao
     WHERE id_aluno = p_id_aluno AND id_desafio = p_id_desafio
       FOR UPDATE;

    IF v_pont_id IS NULL THEN
        INSERT INTO pontuacao (id_aluno, id_desafio, pontos)
        VALUES (p_id_aluno, p_id_desafio, p_pontos);
        SET p_resultado = 'INSERIDA';
    ELSEIF p_pontos > v_atual THEN
        UPDATE pontuacao SET pontos = p_pontos, data_registro = NOW()
         WHERE id_pontuacao = v_pont_id;
        SET p_resultado = 'ATUALIZADA';
    ELSE
        SET p_resultado = 'MANTIDA';
    END IF;

    COMMIT;
END$$

-- ---------------------------------------------------------------------
-- fn_media_aluno(aluno) -> média percentual de aproveitamento (0 a 100)
-- = média de (pontos / pontuacao_maxima * 100) nos desafios feitos.
-- Normaliza por desafio, para que um 8/10 e um 16/20 valham o mesmo.
-- Devolve NULL se o aluno ainda não fez nenhum desafio.
-- ---------------------------------------------------------------------
CREATE FUNCTION fn_media_aluno(p_id_aluno INT)
RETURNS DECIMAL(5,2)
READS SQL DATA
BEGIN
    DECLARE v_media DECIMAL(5,2);
    SELECT ROUND(AVG(p.pontos / d.pontuacao_maxima * 100), 2) INTO v_media
      FROM pontuacao p JOIN desafio d ON d.id_desafio = p.id_desafio
     WHERE p.id_aluno = p_id_aluno;
    RETURN v_media;
END$$

DELIMITER ;
