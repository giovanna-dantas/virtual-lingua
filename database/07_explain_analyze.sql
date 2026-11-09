-- Por que um banco separado? O seed tem so 7 turmas; com tabela tao
-- pequena o MySQL ignora indices e a diferenca nao aparece. Aqui criamos
-- o banco "virtualingua_perf" com 100 mil turmas e 100 mil conteudos
-- ficticios. O banco real (virtualingua) NAO e tocado e este script nao
-- precisa que o 01/02/03 tenham sido executados.

-- EXPLAIN ANALYZE EXECUTA a consulta de verdade e mostra o plano com os
-- tempos medidos e as linhas lidas

-- PASSO 1 - banco de teste, com as tabelas no estado "ANTES":
DROP DATABASE IF EXISTS virtualingua_perf;
CREATE DATABASE virtualingua_perf CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
USE virtualingua_perf;

CREATE TABLE turma (
    id_turma      INT         NOT NULL AUTO_INCREMENT,
    nome          VARCHAR(80) NOT NULL,
    id_idioma     INT         NOT NULL,
    id_nivel      INT         NOT NULL,
    id_professor  INT         NULL,
    carga_horaria INT         NOT NULL,
    vagas         INT         NOT NULL,
    PRIMARY KEY (id_turma),
    UNIQUE KEY uk_turma_nome (nome),
    KEY fk_turma_idioma    (id_idioma),
    KEY fk_turma_nivel     (id_nivel),
    KEY fk_turma_professor (id_professor)
) ENGINE = InnoDB;

CREATE TABLE conteudo (
    id_conteudo  INT          NOT NULL AUTO_INCREMENT,
    titulo       VARCHAR(120) NOT NULL,
    descricao    TEXT         NULL,
    id_idioma    INT          NOT NULL,
    id_nivel     INT          NOT NULL,
    id_professor INT          NULL,
    PRIMARY KEY (id_conteudo),
    UNIQUE KEY uk_conteudo (titulo, id_idioma, id_nivel),
    KEY fk_conteudo_idioma    (id_idioma),
    KEY fk_conteudo_nivel     (id_nivel),
    KEY fk_conteudo_professor (id_professor)
) ENGINE = InnoDB;

-- PASSO 2 - carga de 100 mil linhas em cada tabela.
-- 2 idiomas x 6 niveis = 12 combinacoes, ~8.333 linhas cada.
-- Os nomes sao hashes (MD5) para ficarem fora de ordem, como dados reais.
SET SESSION cte_max_recursion_depth = 200000;

INSERT INTO turma (nome, id_idioma, id_nivel, carga_horaria, vagas)
WITH RECURSIVE n (i) AS (SELECT 1 UNION ALL SELECT i + 1 FROM n WHERE i < 100000)
SELECT CONCAT('Turma ', MD5(i)), 1 + (i DIV 6) % 2, 1 + i % 6, 40, 20 FROM n;

INSERT INTO conteudo (titulo, id_idioma, id_nivel)
WITH RECURSIVE n (i) AS (SELECT 1 UNION ALL SELECT i + 1 FROM n WHERE i < 100000)
SELECT CONCAT('Conteudo ', MD5(i)), 1 + (i DIV 6) % 2, 1 + i % 6 FROM n;

ANALYZE TABLE turma, conteudo;          -- atualiza as estatisticas do otimizador

SELECT (SELECT COUNT(*) FROM turma)    AS turmas,
       (SELECT COUNT(*) FROM conteudo) AS conteudos,
       (SELECT COUNT(*) FROM turma WHERE id_idioma = 2 AND id_nivel = 3) AS turmas_idioma2_nivel3;

-- PASSO 3 - ANTES dos indices 
-- 3a) listar as turmas de um idioma e nivel (RF02)
EXPLAIN ANALYZE
SELECT id_turma, nome, vagas FROM turma
 WHERE id_idioma = 2 AND id_nivel = 3 ORDER BY nome;

-- 3b) listar os conteudos de um idioma e nivel (RF04)
EXPLAIN ANALYZE
SELECT id_conteudo, titulo FROM conteudo
 WHERE id_idioma = 2 AND id_nivel = 3 ORDER BY titulo;

-- 3c) contar as turmas de um idioma e nivel
EXPLAIN ANALYZE
SELECT COUNT(*) FROM turma WHERE id_idioma = 2 AND id_nivel = 3;

-- PASSO 4 - criar os indices (mesmas definicoes do 02_indexes.sql).
CREATE INDEX idx_turma_idioma_nivel    ON turma    (id_idioma, id_nivel, nome);
CREATE INDEX idx_conteudo_idioma_nivel ON conteudo (id_idioma, id_nivel, titulo);

-- No banco real, o MySQL remove sozinho o indice simples de id_idioma
-- quando o composto e criado (a FK passa a usar o composto). Como aqui
-- nao ha FK, removemos na mao para o teste ficar igual ao banco real.

DROP INDEX fk_turma_idioma    ON turma;
DROP INDEX fk_conteudo_idioma ON conteudo;
ANALYZE TABLE turma, conteudo;


-- PASSO 5 - DEPOIS dos indices 
-- 5a)
EXPLAIN ANALYZE
SELECT id_turma, nome, vagas FROM turma
 WHERE id_idioma = 2 AND id_nivel = 3 ORDER BY nome;

-- 5b)
EXPLAIN ANALYZE
SELECT id_conteudo, titulo FROM conteudo
 WHERE id_idioma = 2 AND id_nivel = 3 ORDER BY titulo;

-- 5c)
EXPLAIN ANALYZE
SELECT COUNT(*) FROM turma WHERE id_idioma = 2 AND id_nivel = 3;

-- PASSO 6 - limpeza (apaga so o banco de teste).
-- DROP DATABASE virtualingua_perf;
