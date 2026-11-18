# VirtuaLingua — Banco de Dados, Semana 3
Segurança, regras de negócio, transações e concorrência (MySQL 8 / Workbench)

## 1. O que foi entregue

| Tarefa | Arquivo |
|---|---|
| Triggers: turma lotada, professor habilitado, pontuação acima do máximo | `08_triggers_regras_negocio.sql` (já existia no projeto) |
| Trigger: status da matrícula (transições + pagamento pago ativa a matrícula) | `09_triggers_status_matricula.sql` |
| Triggers de auditoria (exclusão de conta, alteração de pagamento) | `10_triggers_auditoria.sql` |
| `sp_matricular_aluno`, `sp_matricular_lote`, `sp_registrar_pontuacao`, `fn_media_aluno` | `11_procedures_funcoes.sql` |
| Roles e GRANTs por perfil | `12_roles_grants.sql` |
| Transações ACID: COMMIT, ROLLBACK, SAVEPOINT em lote | `13_transacoes_acid_savepoint.sql` |
| Demo dos níveis de isolamento (2 sessões) | `14_demo_niveis_isolamento.sql` |
| Demo de lock (última vaga) e deadlock (2 sessões) | `15_demo_lock_deadlock.sql` |
| Backup + prova de restore | `16_verificar_backup_restore.sql` e pasta `scripts/` |
| Testes automatizados (pytest) | `backend/tests/test_banco_semana3.py` |

### Um problema real que os testes encontraram no arquivo 08
O trigger `trg_matricula_validar_bi` do 08 permitia **vender a última vaga duas vezes** quando dois alunos se matriculavam ao mesmo tempo (no modo padrão REPEATABLE READ, o `COUNT(*)` lia uma foto antiga da tabela, tirada antes de esperar o lock da turma). Reproduzido: turma de 1 vaga ficou com 2 matrículas. A correção (`COUNT(*) … FOR SHARE`) está na **seção 0 do arquivo 09**, que recria os dois triggers de vaga. O grupo pode aplicar a mesma troca direto no 08 e apagar a seção 0, se preferir. O teste `test_ultima_vaga_nao_e_vendida_duas_vezes` garante que não volta a acontecer.

## 2. Pré-requisitos
- MySQL 8.0.20 ou superior e MySQL Workbench.
- Banco `virtualingua` já criado com os scripts 01 a 05 e 08 (conforme o README principal).
- Para criar usuários e roles (arquivo 12) use a conexão **root**.

## 3. Ordem de execução
No Workbench: **File > Open SQL Script…** (Ctrl+Shift+O), escolha o arquivo e clique no **raio** (Execute). Rode nesta ordem:

`09` → `10` → `11` → `12`

Os arquivos 09, 10, 11 e 12 podem ser executados de novo sem problema (recriam os objetos). Os arquivos 13 a 16 são **demonstrações**: seguem passo a passo, descritos abaixo.

Conferência rápida depois do 12 (deve retornar 12 triggers e 5 rotinas):
```sql
SELECT COUNT(*) AS triggers FROM information_schema.triggers WHERE trigger_schema = 'virtualingua';
SELECT routine_name, routine_type FROM information_schema.routines WHERE routine_schema = 'virtualingua';
```

## 4. Regras implementadas

**Triggers (08, 09, 10)**
- Matrícula só para usuário ativo do tipo aluno; turma sem vaga é recusada (`Turma sem vagas disponíveis`).
- Turma só aceita professor ativo e habilitado no idioma dela.
- Pontuação não pode ser negativa nem passar do máximo do desafio.
- **Status da matrícula:** `pendente → ativa | cancelada`; `ativa → concluida | cancelada`; `cancelada → pendente` (reaproveita a linha, pois há `UNIQUE aluno+turma`); `concluida` é final. Qualquer outra troca dá erro `Transição de status da matrícula não permitida`.
- **Pagamento `pago`** ativa a matrícula `pendente` (na mesma transação).
- **Auditoria** em `log_auditoria`: `EXCLUSAO_CONTA` / `EXCLUSAO_FISICA` (usuário) e `ALTERACAO` / `EXCLUSAO` (pagamento, com valores antes → depois). O log guarda só ID e tipo, nunca nome nem e-mail. Uma exclusão via `sp_excluir_conta` gera duas linhas (`ANONIMIZACAO` da procedure + `EXCLUSAO_CONTA` do trigger): é proposital, o trigger cobre também UPDATE direto.

**Procedures e função (11)**
```sql
-- matrícula + pagamento em uma transação (trava a turma com FOR UPDATE)
CALL sp_matricular_aluno(16, 5, 300.00, '2026-12-10', @id_mat, @id_pag);
SELECT @id_mat, @id_pag;

-- vários alunos; cada um com SAVEPOINT; devolve OK/ERRO por aluno
CALL sp_matricular_lote(5, '[17, 18, 12, 1, 999]', 300.00, '2026-12-10');

-- pontuação: INSERIDA | ATUALIZADA | MANTIDA (fica a maior)
CALL sp_registrar_pontuacao(7, 2, 15, @resultado);
SELECT @resultado;

-- média percentual de aproveitamento (0 a 100)
SELECT fn_media_aluno(5);
```
Cuidado: `START TRANSACTION` dentro de uma procedure faz COMMIT de qualquer transação que sua sessão tivesse aberta.

**Decisões que o grupo/professor deve confirmar** (assumi estas):
1. Se o aluno já tem pontuação no desafio, **fica a maior** (RF06 ainda estava em aberto).
2. A pontuação exige matrícula `ativa` ou `concluida` em turma do **mesmo idioma** do desafio.
3. A média é **percentual**: média de `pontos / pontuacao_maxima × 100`.
4. Máquina de estados da matrícula acima (concluída é estado final).

Atenção back-end: o `PUT /matriculas/{id}` e o `PUT /pagamentos/{id}` agora podem receber erro 1644 com a mensagem do trigger (a API já devolve essa mensagem com HTTP 409).

## 5. Roles e GRANTs (arquivo 12) — tarefa de Segurança

| Role | Pode | Não pode |
|---|---|---|
| `role_vl_admin` | tudo em `virtualingua` | mexer em outros bancos |
| `role_vl_professor` | ler catálogo/turmas/matrículas/pontuação; editar conteúdo e desafio; ler `usuario` só nas colunas id, nome, tipo; executar `sp_registrar_pontuacao` | ver e-mail e `senha_hash`; ver pagamentos; apagar |
| `role_vl_aluno` | ler catálogo e ranking; executar `sp_matricular_aluno`, `sp_registrar_pontuacao`, `sp_excluir_conta`, `fn_media_aluno` | ler `usuario`, `pagamento`, `matricula`, `pontuacao`; alterar qualquer tabela direto |
| `role_vl_relatorio` | só `SELECT` nas 4 views | tudo o mais |
| `role_vl_backup` | `SELECT`, `SHOW VIEW`, `TRIGGER`, `LOCK TABLES`, `EVENT`, `PROCESS`, `SHOW_ROUTINE` | alterar dados |

Usuários de demonstração: `vl_admin`, `vl_professor`, `vl_aluno`, `vl_relatorio`, `vl_backup` (senhas no arquivo 12, **só para estudo**).

**Limitação a citar no relatório:** o MySQL não tem segurança por linha. No banco, um `vl_aluno` pode chamar `sp_registrar_pontuacao` para o id de outro aluno; quem garante "só os meus dados" é a API (sessão). O aluno não recebe `SELECT` nas tabelas sensíveis justamente por isso.

### Como testar os perfis no Workbench
1. Na tela inicial, clique no **+** ao lado de *MySQL Connections*.
2. Nome: `VL aluno`; Username: `vl_aluno`; clique em *Store in Vault* e digite `Demo@Aluno123`; *Test Connection* → OK.
3. Abra a conexão `VL aluno` e rode:
```sql
USE virtualingua;
SELECT CURRENT_ROLE();                         -- `role_vl_aluno`@`%`
SELECT COUNT(*) FROM turma;                    -- funciona
SELECT email FROM usuario;                     -- ERRO 1142 (negado)  [print]
SELECT * FROM pagamento;                       -- ERRO 1142 (negado)  [print]
DELETE FROM turma;                             -- ERRO 1142 (negado)  [print]
SELECT fn_media_aluno(5);                      -- funciona
```
4. Repita com `vl_professor` (`Demo@Prof123`):
```sql
SELECT id_usuario, nome, tipo FROM usuario;    -- funciona
SELECT email FROM usuario;                     -- ERRO 1143 (coluna negada)  [print]
SELECT * FROM pagamento;                       -- ERRO 1142                  [print]
```
5. Com `vl_relatorio` (`Demo@Rel123`): `SELECT * FROM vw_pagamentos_pendentes;` funciona; `SELECT * FROM turma;` dá erro 1142.

## 6. Demonstração de transações (arquivo 13)
Abra o arquivo, **selecione um bloco por vez** (do comentário `BLOCO n` até o próximo) e pressione **Ctrl+Shift+Enter**. Não use o raio no arquivo inteiro: os blocos 5 e 6 têm erro de propósito.

| Bloco | Mostra | Resultado esperado |
|---|---|---|
| 1 | COMMIT via `sp_matricular_aluno` | matrícula e pagamento criados juntos |
| 2 | ROLLBACK | status do pagamento/matrícula/log voltam ao valor de antes |
| 3 | SAVEPOINT manual | `ROLLBACK TO SAVEPOINT` desfaz só o passo B |
| 4 | SAVEPOINT em lote | 17 e 18 `OK`; 12, 1 e 999 `ERRO`; só 17 e 18 gravados |
| 5 | Consistência (CHECK) | erro 3819 |
| 6 | Atomicidade com erro | erro 1644 `Turma sem vagas disponíveis`; nada gravado |

Mapa ACID para o relatório: **A**tomicidade = blocos 2 e 6; **C**onsistência = bloco 5 e triggers; **I**solamento = arquivos 14 e 15; **D**urabilidade = bloco 1 (depois do COMMIT o dado permanece, inclusive após restore do backup).

## 7. Demo dos níveis de isolamento (arquivo 14) — duas sessões
1. No Workbench, abra a conexão `root` e crie **duas abas** (Ctrl+T). Renomeie para **A** e **B** (botão direito na aba → *Rename Tab*).
2. Em **cada aba**, rode o bloco `PREPARO`.
3. Siga os passos na ordem (A1, B1, A2…), rodando cada um **na aba indicada** com Ctrl+Shift+Enter. Cada passo tem o comentário `=> esperado`.

| Experimento | Nível | O que acontece |
|---|---|---|
| 1 | READ UNCOMMITTED | A lê 999.00 que B ainda não confirmou (leitura suja) |
| 2 | READ COMMITTED | A lê 360.00 e depois 400.00 na mesma transação |
| 3 | REPEATABLE READ (padrão) | A continua vendo 360.00 e 3 matrículas; `FOR UPDATE` enxerga as 4 |
| 4 | SERIALIZABLE | o UPDATE da aba B **fica esperando** a aba A dar COMMIT |

No experimento 4, enquanto a aba B gira, rode o passo A2 e tire print: `innodb_trx` mostra uma transação `LOCK WAIT`. Se esperar mais de 20 s, a aba B dá erro 1205 (normal). No fim, volte as duas abas ao padrão (`SET SESSION TRANSACTION ISOLATION LEVEL REPEATABLE READ`).

## 8. Demo de lock e deadlock (arquivo 15) — duas sessões
Mesma preparação (abas A e B). Rode o bloco `SETUP` uma vez: cria a turma **Demo Última Vaga** com 1 vaga.
- **Parte 1A:** A reserva a vaga com `FOR UPDATE`; B espera; em A2 rode `sys.innodb_lock_waits` (print); A dá COMMIT; B vê a vaga ocupada.
- **Parte 1B:** B tenta um `INSERT` direto, sem `SELECT` antes: o trigger trava a turma sozinho e B recebe `Turma sem vagas disponíveis` (print do erro 1644).
- **Parte 2 (deadlock):** A trava a turma 4 e pede a 5; B trava a 5 e pede a 4. A aba B recebe **ERROR 1213 Deadlock found** (print). Depois rode `SHOW ENGINE INNODB STATUS;` e tire print do trecho `LATEST DETECTED DEADLOCK` (no Workbench, abra a coluna *Status* → *View Field Value*).
- **Parte 3 (solução):** travar sempre em ordem crescente de id: não há deadlock, B só espera.
- Rode a `LIMPEZA FINAL` no fim.

## 9. Backup e restore (arquivo 16 e pasta `scripts/`)

### 9.1 Backup com mysqldump
Windows (CMD, com a pasta `scripts` aberta): dê duplo clique em `backup.bat`, ou rode `backup.bat`. Ajuste a linha `MYSQLBIN` se o seu MySQL estiver em outra pasta. A senha do `vl_backup` (`Demo@Bkp123`) é pedida na hora; o arquivo vai para `backups\virtualingua_AAAAMMDD_HHMMSS.sql`.
Linux/Mac/Git Bash: `./backup.sh`.

Comando equivalente:
```
mysqldump -uvl_backup -p --single-transaction --routines --triggers --events --set-gtid-purged=OFF --default-character-set=utf8mb4 --result-file=backup.sql virtualingua
```
**Cuidado no PowerShell:** não use `> arquivo.sql`. No Windows PowerShell 5 isso grava em UTF-16 e o backup não restaura. Use `--result-file` (como acima) ou o CMD.

### 9.2 Backup pelo Workbench (Data Export)
1. Menu **Server > Data Export**.
2. Marque o schema **virtualingua** (todas as tabelas).
3. Em *Objects to Export* marque **Dump Stored Procedures and Functions**, **Dump Events** e **Dump Triggers**.
4. Escolha **Export to Self-Contained File** e o caminho do `.sql`.
5. **Desmarque** *Include Create Schema* (assim o arquivo pode ser restaurado em outro schema sem sobrescrever o original).
6. Clique em **Start Export** (print da tela *Export Completed*).

### 9.3 Teste de restore (num banco separado, sem tocar no original)
Pelo terminal: `restaurar_teste.bat backups\SEU_ARQUIVO.sql` (ou `./restaurar_teste.sh`). Ele cria `virtualingua_restore` e restaura nele.

Pelo Workbench: **Server > Data Import** → *Import from Self-Contained File* → escolha o `.sql` → em *Default Target Schema* clique **New…**, digite `virtualingua_restore` → **Start Import**.

### 9.4 Prova
Abra e execute `16_verificar_backup_restore.sql` (raio). Print das 3 saídas: contagem de objetos iguais (11 tabelas, 4 views, 12 triggers, 5 rotinas), linhas por tabela `IGUAIS` e checksums idênticos. Se você fez novos testes antes, os números de `log_auditoria` e outras tabelas podem diferir do seed; o que importa é original = restaurado.

Para limpar depois: `DROP DATABASE virtualingua_restore;`

## 10. Testes automatizados
O arquivo `backend/test_support.py` foi atualizado para carregar 08 a 11 no banco descartável `virtualingua_test`. Dentro de `backend` (com o venv ativo):
```
python -m pytest -q
```
Resultado esperado: **33 passed** (os testes anteriores do grupo + 12 novos em `test_banco_semana3.py`: procedures, lote com savepoint, máquina de estados, auditoria sem dado pessoal e a corrida da última vaga com duas conexões).

## 11. Checklist de prints para o relatório
1. `12_roles_grants`: resultado dos `SHOW GRANTS` (aluno e professor).
2. `vl_aluno`: erros 1142 em `usuario`, `pagamento` e `DELETE`.
3. `vl_professor`: erro 1143 ao ler `email`.
4. Trigger de status: erro `Transição de status da matrícula não permitida`.
5. `log_auditoria` após alterar um pagamento e após `sp_excluir_conta`.
6. `13` bloco 2 (ROLLBACK) e bloco 3 (SAVEPOINT): antes e depois.
7. `13` bloco 4: resultado do lote com OK e ERRO.
8. `13` bloco 6: erro 1644 e contagem inalterada.
9. `14` experimentos 1, 2 e 3 (duas abas lado a lado) e a tela `LOCK WAIT` do 4.
10. `15` parte 1A (`innodb_lock_waits`), parte 1B (erro 1644), parte 2 (erro 1213 + `LATEST DETECTED DEADLOCK`).
11. Backup: tela *Export Completed* ou terminal do `mysqldump`.
12. Restore + `16_verificar_backup_restore.sql` com os resultados iguais.
13. `pytest`: `33 passed`.

## 12. Problemas comuns
| Mensagem | Causa e solução |
|---|---|
| `ERROR 1305 PROCEDURE … does not exist` ao rodar o 12 | rode o 11 antes |
| `ERROR 1146` ou `Unknown database` | rode antes 01 a 05 e 08 |
| `ERROR 1419 You do not have the SUPER privilege…` ao criar rotina/trigger | rode como root, ou `SET GLOBAL log_bin_trust_function_creators = 1;` |
| Usuário `vl_aluno` conecta mas "não pode nada" | faltou `SET DEFAULT ROLE` (o 12 já faz); confirme com `SELECT CURRENT_ROLE();` |
| `ERROR 1442 … can't update table … in stored function/trigger` | um trigger tentou alterar a tabela que o disparou; não use essa construção |
| Aba B girando por muito tempo | é o lock esperado; dê COMMIT/ROLLBACK na aba A (limite de 20 s → erro 1205) |
| `Deadlock found` na aplicação | é normal em concorrência; repita a transação (retry) |
| Demo travou e esqueci transações abertas | rode `ROLLBACK;` nas duas abas |
