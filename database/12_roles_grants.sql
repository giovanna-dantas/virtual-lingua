-- =====================================================================
-- VirtuaLingua | Semana 3 | 12_roles_grants.sql
-- Perfis (ROLES) e permissões (GRANT) no MySQL 8.
--
--   role_vl_admin       tudo no banco virtualingua
--   role_vl_professor   conteúdos/desafios, pontuação, seus idiomas
--   role_vl_aluno       consulta o catálogo e usa as procedures
--   role_vl_relatorio   somente leitura, só nas VIEWS
--   role_vl_backup      o mínimo para o mysqldump / Data Export
--
-- Pré-requisito: 01 a 11 já executados (os GRANT EXECUTE exigem que as
-- procedures já existam). Execute com um usuário administrador (root).
--
-- ATENÇÃO: as senhas abaixo são SÓ para a demonstração do trabalho.
-- Troque-as antes de usar fora do ambiente de estudo.
--
-- LIMITAÇÃO: o MySQL não tem segurança por linha. Um "aluno" no banco
-- consegue executar sp_registrar_pontuacao para QUALQUER id de aluno;
-- quem garante "só os meus dados" é a API (sessão) e as views.
-- Por isso o aluno NÃO recebe SELECT em usuario, matricula, pagamento
-- nem pontuacao.
-- =====================================================================
USE virtualingua;

-- ---------------------------------------------------------------------
-- 0) Limpeza (permite rodar o script de novo)
-- ---------------------------------------------------------------------
DROP USER IF EXISTS 'vl_admin'@'localhost';
DROP USER IF EXISTS 'vl_professor'@'localhost';
DROP USER IF EXISTS 'vl_aluno'@'localhost';
DROP USER IF EXISTS 'vl_relatorio'@'localhost';
DROP USER IF EXISTS 'vl_backup'@'localhost';
DROP ROLE IF EXISTS 'role_vl_admin', 'role_vl_professor', 'role_vl_aluno',
                    'role_vl_relatorio', 'role_vl_backup';

-- ---------------------------------------------------------------------
-- 1) Roles
-- ---------------------------------------------------------------------
CREATE ROLE 'role_vl_admin', 'role_vl_professor', 'role_vl_aluno',
            'role_vl_relatorio', 'role_vl_backup';

-- ---------------------------------------------------------------------
-- 2) Administrador: tudo, somente neste banco
-- ---------------------------------------------------------------------
GRANT ALL PRIVILEGES ON virtualingua.* TO 'role_vl_admin';

-- ---------------------------------------------------------------------
-- 3) Professor
--    * lê catálogo e turmas; pontuação dos desafios
--    * lê de usuario SÓ id, nome e tipo (sem e-mail nem senha_hash)
--    * cria/edita conteúdo e desafio
--    * define os idiomas que leciona
--    * registra pontuação pela procedure
-- ---------------------------------------------------------------------
GRANT SELECT ON virtualingua.idioma    TO 'role_vl_professor';
GRANT SELECT ON virtualingua.nivel     TO 'role_vl_professor';
GRANT SELECT ON virtualingua.turma     TO 'role_vl_professor';
GRANT SELECT ON virtualingua.matricula TO 'role_vl_professor';
GRANT SELECT ON virtualingua.pontuacao TO 'role_vl_professor';
GRANT SELECT, INSERT, UPDATE ON virtualingua.conteudo TO 'role_vl_professor';
GRANT SELECT, INSERT, UPDATE ON virtualingua.desafio  TO 'role_vl_professor';
GRANT SELECT, INSERT, DELETE ON virtualingua.professor_idioma TO 'role_vl_professor';
GRANT SELECT (id_usuario, nome, tipo) ON virtualingua.usuario TO 'role_vl_professor';
GRANT SELECT ON virtualingua.vw_turmas_por_idioma  TO 'role_vl_professor';
GRANT SELECT ON virtualingua.vw_alunos_por_idioma  TO 'role_vl_professor';
GRANT SELECT ON virtualingua.vw_ranking_por_idioma TO 'role_vl_professor';
GRANT EXECUTE ON PROCEDURE virtualingua.sp_registrar_pontuacao TO 'role_vl_professor';
GRANT EXECUTE ON FUNCTION  virtualingua.fn_media_aluno         TO 'role_vl_professor';

-- ---------------------------------------------------------------------
-- 4) Aluno
--    * lê catálogo (idiomas, níveis, turmas, conteúdos, desafios)
--    * lê o ranking e o quadro de turmas
--    * escreve SÓ pelas procedures (matricular, pontuar, excluir conta)
-- ---------------------------------------------------------------------
GRANT SELECT ON virtualingua.idioma   TO 'role_vl_aluno';
GRANT SELECT ON virtualingua.nivel    TO 'role_vl_aluno';
GRANT SELECT ON virtualingua.turma    TO 'role_vl_aluno';
GRANT SELECT ON virtualingua.conteudo TO 'role_vl_aluno';
GRANT SELECT ON virtualingua.desafio  TO 'role_vl_aluno';
GRANT SELECT ON virtualingua.vw_turmas_por_idioma  TO 'role_vl_aluno';
GRANT SELECT ON virtualingua.vw_ranking_por_idioma TO 'role_vl_aluno';
GRANT EXECUTE ON PROCEDURE virtualingua.sp_matricular_aluno    TO 'role_vl_aluno';
GRANT EXECUTE ON PROCEDURE virtualingua.sp_registrar_pontuacao TO 'role_vl_aluno';
GRANT EXECUTE ON PROCEDURE virtualingua.sp_excluir_conta       TO 'role_vl_aluno';
GRANT EXECUTE ON FUNCTION  virtualingua.fn_media_aluno         TO 'role_vl_aluno';

-- ---------------------------------------------------------------------
-- 5) Relatório (somente leitura nas views)
-- ---------------------------------------------------------------------
GRANT SELECT ON virtualingua.vw_turmas_por_idioma   TO 'role_vl_relatorio';
GRANT SELECT ON virtualingua.vw_alunos_por_idioma   TO 'role_vl_relatorio';
GRANT SELECT ON virtualingua.vw_pagamentos_pendentes TO 'role_vl_relatorio';
GRANT SELECT ON virtualingua.vw_ranking_por_idioma  TO 'role_vl_relatorio';

-- ---------------------------------------------------------------------
-- 6) Backup (mysqldump --single-transaction --routines --triggers)
--    PROCESS evita o erro de tablespaces; SHOW_ROUTINE permite exportar
--    procedures e funções (MySQL >= 8.0.20).
-- ---------------------------------------------------------------------
GRANT SELECT, SHOW VIEW, TRIGGER, LOCK TABLES, EVENT ON virtualingua.* TO 'role_vl_backup';
GRANT PROCESS, SHOW_ROUTINE ON *.* TO 'role_vl_backup';

-- ---------------------------------------------------------------------
-- 7) Usuários de demonstração + role PADRÃO
--    Sem SET DEFAULT ROLE o usuário conecta e NÃO tem permissão nenhuma
--    (a role existe mas não está ativa na sessão).
-- ---------------------------------------------------------------------
CREATE USER 'vl_admin'@'localhost'     IDENTIFIED BY 'Demo@Admin123';
CREATE USER 'vl_professor'@'localhost' IDENTIFIED BY 'Demo@Prof123';
CREATE USER 'vl_aluno'@'localhost'     IDENTIFIED BY 'Demo@Aluno123';
CREATE USER 'vl_relatorio'@'localhost' IDENTIFIED BY 'Demo@Rel123';
CREATE USER 'vl_backup'@'localhost'    IDENTIFIED BY 'Demo@Bkp123';

GRANT 'role_vl_admin'     TO 'vl_admin'@'localhost';
GRANT 'role_vl_professor' TO 'vl_professor'@'localhost';
GRANT 'role_vl_aluno'     TO 'vl_aluno'@'localhost';
GRANT 'role_vl_relatorio' TO 'vl_relatorio'@'localhost';
GRANT 'role_vl_backup'    TO 'vl_backup'@'localhost';

SET DEFAULT ROLE 'role_vl_admin'     TO 'vl_admin'@'localhost';
SET DEFAULT ROLE 'role_vl_professor' TO 'vl_professor'@'localhost';
SET DEFAULT ROLE 'role_vl_aluno'     TO 'vl_aluno'@'localhost';
SET DEFAULT ROLE 'role_vl_relatorio' TO 'vl_relatorio'@'localhost';
SET DEFAULT ROLE 'role_vl_backup'    TO 'vl_backup'@'localhost';

-- ---------------------------------------------------------------------
-- 8) Conferência (tire print destes resultados)
-- ---------------------------------------------------------------------
SHOW GRANTS FOR 'vl_aluno'@'localhost'     USING 'role_vl_aluno';
SHOW GRANTS FOR 'vl_professor'@'localhost' USING 'role_vl_professor';
SHOW GRANTS FOR 'vl_relatorio'@'localhost' USING 'role_vl_relatorio';
SHOW GRANTS FOR 'vl_backup'@'localhost'    USING 'role_vl_backup';
