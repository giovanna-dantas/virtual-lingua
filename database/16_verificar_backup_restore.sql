-- Prova de que o BACKUP é restaurável: compara o banco original
-- (virtualingua) com a cópia restaurada (virtualingua_restore).
--
-- Passos completos (mysqldump e Workbench) no README_semana3.md.
-- Rode este script DEPOIS de restaurar o backup em virtualingua_restore.

-- 1) Quantidade de objetos (tabelas, views, triggers, rotinas)
SELECT 'tabelas' AS objeto,
       (SELECT COUNT(*) FROM information_schema.tables   WHERE table_schema='virtualingua'         AND table_type='BASE TABLE') AS original,
       (SELECT COUNT(*) FROM information_schema.tables   WHERE table_schema='virtualingua_restore' AND table_type='BASE TABLE') AS restaurado
UNION ALL
SELECT 'views',
       (SELECT COUNT(*) FROM information_schema.views    WHERE table_schema='virtualingua'),
       (SELECT COUNT(*) FROM information_schema.views    WHERE table_schema='virtualingua_restore')
UNION ALL
SELECT 'triggers',
       (SELECT COUNT(*) FROM information_schema.triggers WHERE trigger_schema='virtualingua'),
       (SELECT COUNT(*) FROM information_schema.triggers WHERE trigger_schema='virtualingua_restore')
UNION ALL
SELECT 'procedures/funções',
       (SELECT COUNT(*) FROM information_schema.routines WHERE routine_schema='virtualingua'),
       (SELECT COUNT(*) FROM information_schema.routines WHERE routine_schema='virtualingua_restore');

-- 2) Linhas por tabela
SELECT t.table_name AS tabela,
       t.n_original, t.n_restaurado,
       IF(t.n_original = t.n_restaurado, 'IGUAIS', 'DIFERENTES') AS situacao
FROM (
  SELECT 'idioma' AS table_name, (SELECT COUNT(*) FROM virtualingua.idioma) AS n_original, (SELECT COUNT(*) FROM virtualingua_restore.idioma) AS n_restaurado
  UNION ALL SELECT 'nivel',            (SELECT COUNT(*) FROM virtualingua.nivel),            (SELECT COUNT(*) FROM virtualingua_restore.nivel)
  UNION ALL SELECT 'usuario',          (SELECT COUNT(*) FROM virtualingua.usuario),          (SELECT COUNT(*) FROM virtualingua_restore.usuario)
  UNION ALL SELECT 'professor_idioma', (SELECT COUNT(*) FROM virtualingua.professor_idioma), (SELECT COUNT(*) FROM virtualingua_restore.professor_idioma)
  UNION ALL SELECT 'turma',            (SELECT COUNT(*) FROM virtualingua.turma),            (SELECT COUNT(*) FROM virtualingua_restore.turma)
  UNION ALL SELECT 'matricula',        (SELECT COUNT(*) FROM virtualingua.matricula),        (SELECT COUNT(*) FROM virtualingua_restore.matricula)
  UNION ALL SELECT 'pagamento',        (SELECT COUNT(*) FROM virtualingua.pagamento),        (SELECT COUNT(*) FROM virtualingua_restore.pagamento)
  UNION ALL SELECT 'conteudo',         (SELECT COUNT(*) FROM virtualingua.conteudo),         (SELECT COUNT(*) FROM virtualingua_restore.conteudo)
  UNION ALL SELECT 'desafio',          (SELECT COUNT(*) FROM virtualingua.desafio),          (SELECT COUNT(*) FROM virtualingua_restore.desafio)
  UNION ALL SELECT 'pontuacao',        (SELECT COUNT(*) FROM virtualingua.pontuacao),        (SELECT COUNT(*) FROM virtualingua_restore.pontuacao)
  UNION ALL SELECT 'log_auditoria',    (SELECT COUNT(*) FROM virtualingua.log_auditoria),    (SELECT COUNT(*) FROM virtualingua_restore.log_auditoria)
) t;

-- 3) Checksum do CONTEÚDO de cada tabela (o valor tem que ser igual nas duas linhas)
CHECKSUM TABLE virtualingua.usuario,   virtualingua_restore.usuario;
CHECKSUM TABLE virtualingua.matricula, virtualingua_restore.matricula;
CHECKSUM TABLE virtualingua.pagamento, virtualingua_restore.pagamento;
CHECKSUM TABLE virtualingua.pontuacao, virtualingua_restore.pontuacao;
