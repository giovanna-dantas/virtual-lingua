-- Permissões das tabelas do quiz. Rode DEPOIS do 12 e do 17.
--
-- O aluno só enxerga as colunas que NÃO revelam o gabarito: o GRANT em
-- alternativa é por coluna e deixa de fora "correta". Mesmo que o aluno
-- tivesse acesso direto ao banco, não leria a resposta certa.

USE virtualingua;

GRANT SELECT, INSERT, UPDATE, DELETE ON virtualingua.questao     TO 'role_vl_professor';
GRANT SELECT, INSERT, UPDATE, DELETE ON virtualingua.alternativa TO 'role_vl_professor';

GRANT SELECT ON virtualingua.questao TO 'role_vl_aluno';
GRANT SELECT (id_alternativa, id_questao, texto) ON virtualingua.alternativa TO 'role_vl_aluno';

-- Conferência: a coluna "correta" não pode aparecer para o aluno.
SHOW GRANTS FOR 'vl_aluno'@'localhost' USING 'role_vl_aluno';
