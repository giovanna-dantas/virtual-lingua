-- Indices para listar TURMAS e CONTEUDOS por IDIOMA e NIVEL.
-- Executar DEPOIS do 01_schema.sql (e depois do 03_seed.sql).
-- Executar UMA vez: rodar de novo da erro 1061 (indice ja existe).
-- Para desfazer, use o bloco ROLLBACK no final do arquivo.

USE virtualingua;

-- Consulta atendida (RF02 - listar turmas por idioma e nivel):
--   SELECT id_turma, nome, vagas FROM turma
--    WHERE id_idioma = ? AND id_nivel = ? ORDER BY nome;
-- Tambem atende a consulta so por idioma (prefixo mais a esquerda).
-- A coluna 'nome' no fim evita a ordenacao extra (filesort); consultas
-- que pedem so id_turma e nome (ou COUNT) sao respondidas so pelo indice.
CREATE INDEX idx_turma_idioma_nivel
    ON turma (id_idioma, id_nivel, nome);

-- Consulta atendida (RF04 - listar conteudos por idioma e nivel):
--   SELECT id_conteudo, titulo FROM conteudo
--    WHERE id_idioma = ? AND id_nivel = ? ORDER BY titulo;
-- O UNIQUE uk_conteudo (titulo, id_idioma, id_nivel) NAO serve aqui,
-- porque 'titulo' vem primeiro: o MySQL so usa um indice a partir da
-- coluna mais a esquerda.
CREATE INDEX idx_conteudo_idioma_nivel
    ON conteudo (id_idioma, id_nivel, titulo);

-- Obs.: ao criar os indices acima, o MySQL pode remover sozinho o indice
-- automatico fk_turma_idioma / fk_conteudo_idioma (id_idioma): o novo
-- indice composto ja cumpre esse papel (id_idioma e a primeira coluna).
-- A FK continua valendo normalmente. Os indices em id_nivel e id_professor
-- continuam, pois servem a outras consultas e as FKs precisam deles.

-- Conferir: SHOW INDEX FROM turma;   SHOW INDEX FROM conteudo;

-- ROLLBACK (desfazer) - descomente e execute se precisar.
-- Nao basta um DROP INDEX: a FK de id_idioma passou a usar o indice
-- composto (erro 1553). Por isso recriamos o indice simples e removemos o
-- composto na MESMA instrucao:
-- ALTER TABLE turma    ADD INDEX fk_turma_idioma (id_idioma),
--                      DROP INDEX idx_turma_idioma_nivel;
-- ALTER TABLE conteudo ADD INDEX fk_conteudo_idioma (id_idioma),
--                      DROP INDEX idx_conteudo_idioma_nivel;


-- Comprovacao (rodar separadamente, em outra aba) - o campo "key" deve
-- mostrar o indice criado:
-- EXPLAIN SELECT id_turma, nome, vagas FROM turma
--  WHERE id_idioma = 1 AND id_nivel = 1 ORDER BY nome;
-- EXPLAIN SELECT id_conteudo, titulo FROM conteudo
--  WHERE id_idioma = 1 AND id_nivel = 1 ORDER BY titulo;
-- ---------------------------------------------------------------------