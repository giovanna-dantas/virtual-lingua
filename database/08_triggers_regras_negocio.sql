-- Regras de integridade complementares para o MySQL 8.
-- Execute depois de 01_schema.sql e antes de utilizar a API.
USE virtualingua;

DROP TRIGGER IF EXISTS trg_turma_professor_bi;
DROP TRIGGER IF EXISTS trg_turma_professor_bu;
DROP TRIGGER IF EXISTS trg_matricula_validar_bi;
DROP TRIGGER IF EXISTS trg_matricula_validar_bu;
DROP TRIGGER IF EXISTS trg_pontuacao_maxima_bi;
DROP TRIGGER IF EXISTS trg_pontuacao_maxima_bu;

DELIMITER $$
CREATE TRIGGER trg_turma_professor_bi BEFORE INSERT ON turma FOR EACH ROW
BEGIN
  IF NEW.id_professor IS NOT NULL AND NOT EXISTS (
    SELECT 1 FROM usuario u JOIN professor_idioma pi ON pi.id_professor=u.id_usuario
    WHERE u.id_usuario=NEW.id_professor AND u.tipo='professor' AND u.ativo=1 AND pi.id_idioma=NEW.id_idioma
  ) THEN SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Professor não habilitado para o idioma da turma'; END IF;
END$$
CREATE TRIGGER trg_turma_professor_bu BEFORE UPDATE ON turma FOR EACH ROW
BEGIN
  IF NEW.id_professor IS NOT NULL AND NOT EXISTS (
    SELECT 1 FROM usuario u JOIN professor_idioma pi ON pi.id_professor=u.id_usuario
    WHERE u.id_usuario=NEW.id_professor AND u.tipo='professor' AND u.ativo=1 AND pi.id_idioma=NEW.id_idioma
  ) THEN SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Professor não habilitado para o idioma da turma'; END IF;
END$$
CREATE TRIGGER trg_matricula_validar_bi BEFORE INSERT ON matricula FOR EACH ROW
BEGIN
  DECLARE v_tipo VARCHAR(15);
  DECLARE v_ativo BOOLEAN;
  DECLARE v_vagas INT;
  DECLARE v_ocupadas INT;
  SELECT tipo,ativo INTO v_tipo,v_ativo FROM usuario WHERE id_usuario=NEW.id_aluno;
  IF v_tipo<>'aluno' OR v_ativo=0 THEN SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Matrícula exige usuário ativo do tipo aluno'; END IF;
  SELECT vagas INTO v_vagas FROM turma WHERE id_turma=NEW.id_turma FOR UPDATE;
  SELECT COUNT(*) INTO v_ocupadas FROM matricula WHERE id_turma=NEW.id_turma AND status IN ('pendente','ativa');
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
    SELECT COUNT(*) INTO v_ocupadas FROM matricula WHERE id_turma=NEW.id_turma AND status IN ('pendente','ativa') AND id_matricula<>OLD.id_matricula;
    IF v_ocupadas>=v_vagas THEN SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Turma sem vagas disponíveis'; END IF;
  END IF;
END$$
CREATE TRIGGER trg_pontuacao_maxima_bi BEFORE INSERT ON pontuacao FOR EACH ROW
BEGIN
  DECLARE v_max INT;
  SELECT pontuacao_maxima INTO v_max FROM desafio WHERE id_desafio=NEW.id_desafio;
  IF NEW.pontos<0 OR NEW.pontos>v_max THEN SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Pontuação fora do limite do desafio'; END IF;
END$$
CREATE TRIGGER trg_pontuacao_maxima_bu BEFORE UPDATE ON pontuacao FOR EACH ROW
BEGIN
  DECLARE v_max INT;
  SELECT pontuacao_maxima INTO v_max FROM desafio WHERE id_desafio=NEW.id_desafio;
  IF NEW.pontos<0 OR NEW.pontos>v_max THEN SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Pontuação fora do limite do desafio'; END IF;
END$$
DELIMITER ;
