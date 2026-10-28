-- Dados de teste: 1 administrador, 3 professores, 15 alunos, turmas EN e ES.
-- Senha de TODOS os usuarios de teste: Senha@123  (hash PBKDF2 do Werkzeug)
-- Execute depois do 01_schema.sql. Reexecutavel: limpa as tabelas antes.

USE virtualingua;
SET NAMES utf8mb4;

SET FOREIGN_KEY_CHECKS = 0;
TRUNCATE TABLE log_auditoria;
TRUNCATE TABLE pontuacao;
TRUNCATE TABLE desafio;
TRUNCATE TABLE conteudo;
TRUNCATE TABLE pagamento;
TRUNCATE TABLE matricula;
TRUNCATE TABLE turma;
TRUNCATE TABLE professor_idioma;
TRUNCATE TABLE usuario;
TRUNCATE TABLE nivel;
TRUNCATE TABLE idioma;
SET FOREIGN_KEY_CHECKS = 1;

START TRANSACTION;


-- Idiomas e niveis (CEFR)
INSERT INTO idioma (nome, codigo) VALUES ('Inglês', 'EN'), ('Espanhol', 'ES');

INSERT INTO nivel (codigo, descricao) VALUES
 ('A1', 'Iniciante'),
 ('A2', 'Básico'),
 ('B1', 'Intermediário'),
 ('B2', 'Intermediário superior'),
 ('C1', 'Avançado'),
 ('C2', 'Proficiente');


-- Usuarios (hash da senha Senha@123)
SET @hash = 'pbkdf2:sha256:1000000$c7G98yUIv8M5gY8D$9610bbaacf2dfb47a9a630c4993d9aea776e0beb6a9422824be3670687292d33';

INSERT INTO usuario (nome, email, senha_hash, tipo) VALUES
 ('Administrador VirtuaLingua', 'admin@virtualingua.com.br',          @hash, 'administrador'),
 ('Carlos Mendes',   'carlos.mendes@virtualingua.com.br',   @hash, 'professor'),
 ('Marina Duarte',   'marina.duarte@virtualingua.com.br',   @hash, 'professor'),
 ('Beatriz Lacerda', 'beatriz.lacerda@virtualingua.com.br', @hash, 'professor');

INSERT INTO usuario (nome, email, senha_hash, tipo) VALUES

 ('Ana Beatriz Costa', 'ana.costa@exemplo.com', @hash, 'aluno'),
 ('Bruno Henrique Alves', 'bruno.alves@exemplo.com', @hash, 'aluno'),
 ('Camila Ferreira', 'camila.ferreira@exemplo.com', @hash, 'aluno'),
 ('Daniel Oliveira', 'daniel.oliveira@exemplo.com', @hash, 'aluno'),
 ('Eduarda Nascimento', 'eduarda.nascimento@exemplo.com', @hash, 'aluno'),
 ('Felipe Rocha', 'felipe.rocha@exemplo.com', @hash, 'aluno'),
 ('Gabriela Martins', 'gabriela.martins@exemplo.com', @hash, 'aluno'),
 ('Heitor Souza', 'heitor.souza@exemplo.com', @hash, 'aluno'),
 ('Isabela Ribeiro', 'isabela.ribeiro@exemplo.com', @hash, 'aluno'),
 ('João Pedro Lima', 'joao.lima@exemplo.com', @hash, 'aluno'),
 ('Karen Barbosa', 'karen.barbosa@exemplo.com', @hash, 'aluno'),
 ('Leonardo Pereira', 'leonardo.pereira@exemplo.com', @hash, 'aluno'),
 ('Mariana Gomes', 'mariana.gomes@exemplo.com', @hash, 'aluno'),
 ('Nicolas Araújo', 'nicolas.araujo@exemplo.com', @hash, 'aluno'),
 ('Olívia Teixeira', 'olivia.teixeira@exemplo.com', @hash, 'aluno');


-- Habilitacoes: Carlos = EN | Marina = ES | Beatriz = EN e ES (bilingue)
INSERT INTO professor_idioma (id_professor, id_idioma)
SELECT u.id_usuario, i.id_idioma
FROM (
    SELECT 'carlos.mendes@virtualingua.com.br' AS email, 'EN' AS cod_idioma
    UNION ALL SELECT 'marina.duarte@virtualingua.com.br', 'ES'
    UNION ALL SELECT 'beatriz.lacerda@virtualingua.com.br', 'EN'
    UNION ALL SELECT 'beatriz.lacerda@virtualingua.com.br', 'ES'
) AS v
JOIN usuario u ON u.email  = v.email
JOIN idioma  i ON i.codigo = v.cod_idioma;


-- Turmas (a ultima tem 2 vagas e sera lotada: serve para testar o trigger)
INSERT INTO turma (nome, id_idioma, id_nivel, id_professor, carga_horaria, vagas)
SELECT v.nome_turma, i.id_idioma, n.id_nivel, u.id_usuario, v.carga, v.qtd_vagas
FROM (
    SELECT 'Inglês A1 Manhã' AS nome_turma, 'EN' AS cod_idioma, 'A1' AS cod_nivel, 'carlos.mendes@virtualingua.com.br' AS email_prof, 60 AS carga, 15 AS qtd_vagas
    UNION ALL SELECT 'Inglês B1 Noite', 'EN', 'B1', 'beatriz.lacerda@virtualingua.com.br', 80, 12
    UNION ALL SELECT 'Inglês B2 Noite', 'EN', 'B2', 'carlos.mendes@virtualingua.com.br', 80, 10
    UNION ALL SELECT 'Espanhol A1 Manhã', 'ES', 'A1', 'marina.duarte@virtualingua.com.br', 60, 15
    UNION ALL SELECT 'Espanhol A2 Tarde', 'ES', 'A2', 'beatriz.lacerda@virtualingua.com.br', 60, 12
    UNION ALL SELECT 'Espanhol B1 Noite', 'ES', 'B1', 'marina.duarte@virtualingua.com.br', 80, 10
    UNION ALL SELECT 'Espanhol A1 Intensivo', 'ES', 'A1', 'marina.duarte@virtualingua.com.br', 40, 2
) AS v
JOIN idioma  i ON i.codigo = v.cod_idioma
JOIN nivel   n ON n.codigo = v.cod_nivel
JOIN usuario u ON u.email  = v.email_prof;


-- Matriculas (a Ana e o Bruno estudam nos dois idiomas)
INSERT INTO matricula (id_aluno, id_turma, data_matricula, status)
SELECT u.id_usuario, t.id_turma, CAST(v.dt AS DATE), v.st
FROM (
    SELECT 'ana.costa@exemplo.com' AS email, 'Inglês B1 Noite' AS nome_turma, '2026-08-10' AS dt, 'ativa' AS st
    UNION ALL SELECT 'ana.costa@exemplo.com', 'Espanhol A1 Manhã', '2026-08-12', 'ativa'
    UNION ALL SELECT 'bruno.alves@exemplo.com', 'Inglês A1 Manhã', '2026-08-10', 'ativa'
    UNION ALL SELECT 'bruno.alves@exemplo.com', 'Espanhol A2 Tarde', '2026-09-01', 'ativa'
    UNION ALL SELECT 'camila.ferreira@exemplo.com', 'Inglês A1 Manhã', '2026-08-11', 'ativa'
    UNION ALL SELECT 'daniel.oliveira@exemplo.com', 'Inglês B2 Noite', '2026-08-11', 'ativa'
    UNION ALL SELECT 'eduarda.nascimento@exemplo.com', 'Inglês B1 Noite', '2026-08-15', 'ativa'
    UNION ALL SELECT 'felipe.rocha@exemplo.com', 'Espanhol A1 Manhã', '2026-08-15', 'ativa'
    UNION ALL SELECT 'gabriela.martins@exemplo.com', 'Espanhol A1 Manhã', '2026-08-18', 'ativa'
    UNION ALL SELECT 'heitor.souza@exemplo.com', 'Espanhol A2 Tarde', '2026-08-18', 'ativa'
    UNION ALL SELECT 'isabela.ribeiro@exemplo.com', 'Espanhol B1 Noite', '2026-08-20', 'ativa'
    UNION ALL SELECT 'joao.lima@exemplo.com', 'Inglês A1 Manhã', '2026-08-20', 'ativa'
    UNION ALL SELECT 'karen.barbosa@exemplo.com', 'Inglês B2 Noite', '2026-08-22', 'ativa'
    UNION ALL SELECT 'leonardo.pereira@exemplo.com', 'Espanhol B1 Noite', '2026-08-22', 'ativa'
    UNION ALL SELECT 'mariana.gomes@exemplo.com', 'Espanhol A1 Intensivo', '2026-09-02', 'ativa'
    UNION ALL SELECT 'nicolas.araujo@exemplo.com', 'Espanhol A1 Intensivo', '2026-09-02', 'ativa'
    UNION ALL SELECT 'olivia.teixeira@exemplo.com', 'Inglês B1 Noite', '2026-10-10', 'pendente'
    UNION ALL SELECT 'felipe.rocha@exemplo.com', 'Inglês A1 Manhã', '2026-08-25', 'pendente'
    UNION ALL SELECT 'joao.lima@exemplo.com', 'Espanhol A2 Tarde', '2026-07-01', 'cancelada'
) AS v
JOIN usuario u ON u.email = v.email
JOIN turma   t ON t.nome  = v.nome_turma;

-- Pagamentos: um por matricula (valor = R$ 4,50 por hora-aula)
-- ativa -> pago | pendente -> pendente | cancelada -> cancelado
INSERT INTO pagamento (id_matricula, valor, data_vencimento, data_pagamento, status)
SELECT m.id_matricula,
       t.carga_horaria * 4.50,
       DATE_ADD(m.data_matricula, INTERVAL 7 DAY),
       CASE WHEN m.status = 'ativa' THEN DATE_ADD(m.data_matricula, INTERVAL 3 DAY) END,
       CASE m.status WHEN 'ativa'    THEN 'pago'
                     WHEN 'pendente' THEN 'pendente'
                     ELSE 'cancelado' END
FROM matricula m
JOIN turma t ON t.id_turma = m.id_turma;

-- Pagamento atrasado (vencimento ja passou e nao foi pago): caso de teste
UPDATE pagamento
   SET status = 'atrasado'
 WHERE id_matricula = (SELECT m.id_matricula
                         FROM matricula m
                         JOIN usuario u ON u.id_usuario = m.id_aluno
                         JOIN turma t   ON t.id_turma   = m.id_turma
                        WHERE u.email = 'felipe.rocha@exemplo.com'
                          AND t.nome  = 'Inglês A1 Manhã');

-- Conteudos (um por turma-tipo) e desafios (dois por conteudo)
INSERT INTO conteudo (titulo, descricao, id_idioma, id_nivel, id_professor)
SELECT v.titulo, v.descricao, i.id_idioma, n.id_nivel, u.id_usuario
FROM (
    SELECT 'Greetings and Introductions' AS titulo, 'Cumprimentos, apresentações e verbo to be.' AS descricao, 'EN' AS cod_idioma, 'A1' AS cod_nivel, 'carlos.mendes@virtualingua.com.br' AS email_prof
    UNION ALL SELECT 'Travel and Daily Routines', 'Passado simples, rotina e viagens.', 'EN', 'B1', 'beatriz.lacerda@virtualingua.com.br'
    UNION ALL SELECT 'Business English', 'Reuniões, e-mails e apresentações profissionais.', 'EN', 'B2', 'carlos.mendes@virtualingua.com.br'
    UNION ALL SELECT 'Saludos y Presentaciones', 'Saudações, apresentações e verbos ser e estar.', 'ES', 'A1', 'marina.duarte@virtualingua.com.br'
    UNION ALL SELECT 'La Vida Cotidiana', 'Rotina, gostos e pretérito perfeito.', 'ES', 'A2', 'beatriz.lacerda@virtualingua.com.br'
    UNION ALL SELECT 'Viajes y Cultura', 'Pretérito indefinido, viagens e cultura hispânica.', 'ES', 'B1', 'marina.duarte@virtualingua.com.br'
) AS v
JOIN idioma  i ON i.codigo = v.cod_idioma
JOIN nivel   n ON n.codigo = v.cod_nivel
JOIN usuario u ON u.email  = v.email_prof;

INSERT INTO desafio (id_conteudo, titulo, descricao, pontuacao_maxima)
SELECT c.id_conteudo, v.titulo, v.descricao, v.maximo
FROM (
    SELECT 'Greetings and Introductions' AS titulo_conteudo, 'Quiz de cumprimentos' AS titulo, 'Dez questões de múltipla escolha.' AS descricao, 10 AS maximo
    UNION ALL SELECT 'Greetings and Introductions', 'Apresente-se em áudio', 'Grave um áudio de 1 minuto.', 20
    UNION ALL SELECT 'Travel and Daily Routines', 'Diário de viagem', 'Escreva um texto de 150 palavras.', 30
    UNION ALL SELECT 'Travel and Daily Routines', 'Quiz de passado simples', 'Quinze questões de gramática.', 15
    UNION ALL SELECT 'Business English', 'Simulação de reunião', 'Roleplay de reunião em duplas.', 40
    UNION ALL SELECT 'Business English', 'E-mail profissional', 'Redija um e-mail formal.', 20
    UNION ALL SELECT 'Saludos y Presentaciones', 'Quiz de saludos', 'Dez questões de múltipla escolha.', 10
    UNION ALL SELECT 'Saludos y Presentaciones', 'Preséntate en audio', 'Grave um áudio de 1 minuto.', 20
    UNION ALL SELECT 'La Vida Cotidiana', 'Mi rutina diaria', 'Escreva um texto sobre sua rotina.', 25
    UNION ALL SELECT 'La Vida Cotidiana', 'Quiz de gustos', 'Doze questões de vocabulário.', 12
    UNION ALL SELECT 'Viajes y Cultura', 'Reseña de un viaje', 'Resenha de 200 palavras.', 30
    UNION ALL SELECT 'Viajes y Cultura', 'Quiz de pretérito', 'Quinze questões de gramática.', 15
) AS v
JOIN conteudo c ON c.titulo = v.titulo_conteudo;

-- Pontuacoes (sempre <= pontuacao_maxima do desafio)
INSERT INTO pontuacao (id_aluno, id_desafio, pontos, data_registro)
SELECT u.id_usuario, d.id_desafio, v.pontos, CAST(v.dt AS DATETIME)
FROM (
    SELECT 'bruno.alves@exemplo.com' AS email, 'Quiz de cumprimentos' AS titulo_desafio, 9.0 AS pontos, '2026-08-20 10:00:00' AS dt
    UNION ALL SELECT 'camila.ferreira@exemplo.com', 'Quiz de cumprimentos', 7.5, '2026-08-21 10:00:00'
    UNION ALL SELECT 'joao.lima@exemplo.com', 'Quiz de cumprimentos', 8.0, '2026-08-30 10:00:00'
    UNION ALL SELECT 'bruno.alves@exemplo.com', 'Apresente-se em áudio', 18.0, '2026-08-28 14:00:00'
    UNION ALL SELECT 'ana.costa@exemplo.com', 'Diário de viagem', 27.0, '2026-09-05 19:00:00'
    UNION ALL SELECT 'eduarda.nascimento@exemplo.com', 'Quiz de passado simples', 12.0, '2026-09-06 19:00:00'
    UNION ALL SELECT 'daniel.oliveira@exemplo.com', 'Simulação de reunião', 35.0, '2026-09-10 20:00:00'
    UNION ALL SELECT 'karen.barbosa@exemplo.com', 'E-mail profissional', 16.5, '2026-09-12 20:00:00'
    UNION ALL SELECT 'ana.costa@exemplo.com', 'Quiz de saludos', 10.0, '2026-08-25 09:00:00'
    UNION ALL SELECT 'felipe.rocha@exemplo.com', 'Quiz de saludos', 6.5, '2026-08-26 09:00:00'
    UNION ALL SELECT 'gabriela.martins@exemplo.com', 'Preséntate en audio', 17.0, '2026-08-29 09:00:00'
    UNION ALL SELECT 'heitor.souza@exemplo.com', 'Mi rutina diaria', 22.0, '2026-09-08 15:00:00'
    UNION ALL SELECT 'isabela.ribeiro@exemplo.com', 'Reseña de un viaje', 28.0, '2026-09-15 19:00:00'
    UNION ALL SELECT 'leonardo.pereira@exemplo.com', 'Quiz de pretérito', 11.0, '2026-09-16 19:00:00'
) AS v
JOIN usuario u ON u.email  = v.email
JOIN desafio d ON d.titulo = v.titulo_desafio;

COMMIT;