# Banco de Dados — Semana 2

Views, consultas avançadas e comparação de desempenho dos índices (EXPLAIN ANALYZE).
Tudo em **MySQL 8** para ser executado no **MySQL Workbench**.

## O que tem aqui

| Arquivo | Tarefa da Semana 2 | O que faz |
|---|---|---|
| `01_schema.sql` | Semana 1 | Cria o banco `virtualingua` e as 11 tabelas |
| `02_indexes.sql` | Índices | Índices de turma e conteúdo por idioma e nível |
| `03_seed.sql` | Semana 1 | Dados de teste (1 admin, 3 professores, 15 alunos, 7 turmas...) |
| **`04_views.sql`** | **Views** | `vw_turmas_por_idioma`, `vw_alunos_por_idioma`, `vw_pagamentos_pendentes`, `vw_ranking_por_idioma` |
| `05_rf10_excluir_conta.sql` | RF10 | Procedure `sp_excluir_conta` (anonimização, LGPD) |
| **`06_consultas_avancadas.sql`** | **Consultas avançadas** | 18 consultas: JOINs, LEFT JOIN, GROUP BY/HAVING, subconsultas, `RANK() OVER` |
| **`07_explain_analyze.sql`** | **EXPLAIN ANALYZE** | Mede as consultas antes e depois dos índices, num banco separado |

Os arquivos em **negrito** são os novos desta semana.

## Pré-requisitos

- MySQL Server **8.0.18 ou superior** (o `EXPLAIN ANALYZE` não existe antes disso) e MySQL Workbench.
- Para conferir a versão, abra uma aba de consulta e execute `SELECT VERSION();`.

## Ordem de execução

| # | Arquivo | Pode rodar de novo? |
|---|---|---|
| 1 | `01_schema.sql` | Sim, mas **apaga as 11 tabelas e todos os dados** e recria vazias. Depois rode de novo 02, 03 (e a 05, se quiser) |
| 2 | `02_indexes.sql` | **Não** (dá erro 1061, "índice já existe"), a menos que o `01_schema.sql` tenha recriado as tabelas antes. Para refazer, use o bloco ROLLBACK no fim do arquivo |
| 3 | `03_seed.sql` | Sim (limpa as tabelas e recarrega os dados) |
| 4 | `04_views.sql` | Sim (usa `CREATE OR REPLACE VIEW`) |
| 5 | `05_rf10_excluir_conta.sql` | Sim |
| 6 | `06_consultas_avancadas.sql` | Sim (só lê dados) |
| 7 | `07_explain_analyze.sql` | Sim, e **não depende dos outros**: cria o próprio banco de teste |

> Se você já tinha os scripts 01 a 03 e 05 rodados da Semana 1, basta rodar **04, 06 e 07**.

## Como executar um script no Workbench

1. Abra o MySQL Workbench e clique na conexão (por exemplo, *Local instance MySQL80*).
2. Menu **File → Open SQL Script…** e escolha o arquivo `.sql`.
3. Clique no ícone de **raio** (Execute) para rodar o script inteiro.
4. Para rodar só um trecho: selecione o trecho e use **Ctrl+Shift+Enter**. Para rodar a instrução onde o cursor está, use **Ctrl+Enter**.
5. Cada `SELECT` abre uma aba de resultado (*Result 1*, *Result 2*...) embaixo da tela.

## Teste passo a passo, com o resultado esperado

### 1. Recriar o banco (se quiser partir do zero)

Execute, nesta ordem (o `01` apaga os dados que existirem): `01_schema.sql`, `02_indexes.sql`, `03_seed.sql`, `05_rf10_excluir_conta.sql`.

Conferência:

```sql
USE virtualingua;
SELECT COUNT(*) AS tabelas FROM information_schema.tables
 WHERE table_schema = 'virtualingua' AND table_type = 'BASE TABLE';   -- esperado: 11
SHOW INDEX FROM turma;      -- deve aparecer idx_turma_idioma_nivel
SHOW INDEX FROM conteudo;   -- deve aparecer idx_conteudo_idioma_nivel
```

Quantidade de linhas esperada após o seed:

| Tabela | Linhas | Tabela | Linhas |
|---|---|---|---|
| idioma | 2 | matricula | 19 |
| nivel | 6 | pagamento | 19 |
| usuario | 19 | conteudo | 6 |
| professor_idioma | 4 | desafio | 12 |
| turma | 7 | pontuacao | 14 |

### 2. Views — `04_views.sql`

Execute o arquivo inteiro. No final ele roda um `SELECT` em cada view (4 abas de resultado).

| View | Linhas esperadas | O que conferir |
|---|---|---|
| `vw_turmas_por_idioma` | 7 | "Espanhol A1 Intensivo" aparece como **lotada** (2 de 2 vagas); as demais, "com vagas" |
| `vw_alunos_por_idioma` | 18 | 9 de Espanhol e 9 de Inglês; Ana e Bruno aparecem nos **dois** idiomas |
| `vw_pagamentos_pendentes` | 2 | Felipe Rocha (status `atrasado`) e Olívia Teixeira (status `pendente`, mas já vencido) |
| `vw_ranking_por_idioma` | 13 | Em Inglês, Ana e Bruno **empatam em 2º lugar** (27 pontos) e o seguinte é o 4º: é o comportamento do `RANK()` |

A coluna `dias_em_atraso` depende da data de hoje, então o número no seu computador será diferente do de outros dias.

Usos comuns:

```sql
SELECT * FROM vw_turmas_por_idioma    WHERE idioma = 'Espanhol';
SELECT * FROM vw_ranking_por_idioma   WHERE posicao <= 3;
SELECT * FROM vw_pagamentos_pendentes ORDER BY dias_em_atraso DESC;
```

**Regra das vagas:** uma matrícula ocupa vaga quando o status é `pendente` ou `ativa` (a mesma regra do trigger de matrícula).

### 3. Consultas avançadas — `06_consultas_avancadas.sql`

Execute **uma consulta por vez** (selecione e use Ctrl+Shift+Enter), para tirar print de cada resultado. As 18 consultas e o que cada uma mostra:

| Consulta | Técnica | Linhas esperadas |
|---|---|---|
| A1 | INNER JOIN de 4 tabelas (turma, idioma, nível, professor) | 7 |
| A2 | INNER JOIN de 5 tabelas (matrículas ativas) | 16 |
| B1 | LEFT JOIN + `IS NULL`: alunos sem matrícula ativa (filtro no `ON`) | 1 |
| B2 | LEFT JOIN + `COUNT`: matrículas por turma | 7 |
| B3 | LEFT JOIN + `IS NULL`: alunos sem pontuação | 3 |
| C1 | GROUP BY: ocupação de cada turma em % | 7 |
| C2 | GROUP BY + HAVING: turmas lotadas | 1 |
| C3 | GROUP BY + HAVING: alunos com mais de uma turma | 3 |
| C4 | GROUP BY ... WITH ROLLUP: receita por idioma + total geral | 3 |
| C5 | HAVING: professor habilitado em 2 idiomas (Beatriz) | 1 |
| D1 | Subconsulta escalar: alunos acima da média de pontos | 5 |
| D2 | `EXISTS`: alunos com pagamento vencido | 2 |
| D3 | `NOT IN` com subconsulta aninhada: sem desafio de Espanhol | 9 |
| D4 | Subconsulta correlacionada: melhor nota de cada desafio | 11 |
| D5 | Subconsulta na lista de colunas: vagas livres | 7 |
| E1 | `RANK`, `DENSE_RANK` e `ROW_NUMBER` lado a lado | 13 |
| E2 | Top 3 por idioma (CTE + `RANK`) | 6 |
| E3 | Soma acumulada de pontos (`SUM() OVER`) | 14 |

Se o seu seed foi alterado, as contagens podem mudar. O importante é a consulta rodar sem erro.

### 4. EXPLAIN ANALYZE antes e depois dos índices — `07_explain_analyze.sql`

Este script cria o banco separado **`virtualingua_perf`** com 100 mil turmas e 100 mil conteúdos fictícios. Isso é necessário porque, com apenas 7 turmas, o MySQL ignora os índices e a diferença não aparece. O banco real (`virtualingua`) **não é alterado**.

Execute **por passos** (selecione o trecho e use Ctrl+Shift+Enter):

| Passo | O que faz | Tira print? |
|---|---|---|
| 1 | Cria o banco `virtualingua_perf` e as tabelas (só com os índices automáticos) | Não |
| 2 | Carrega 100 mil linhas em cada tabela (leva alguns segundos) | Sim, o `SELECT` de contagem no fim |
| 3 | `EXPLAIN ANALYZE` das 3 consultas **ANTES** dos índices (3a, 3b, 3c) | **Sim** |
| 4 | Cria os índices | Não |
| 5 | As **mesmas** 3 consultas **DEPOIS** (5a, 5b, 5c) | **Sim** |
| 6 | Limpeza (`DROP DATABASE virtualingua_perf`, vem comentado) | Não |

**Como ler o resultado.** O `EXPLAIN ANALYZE` devolve um texto em uma única célula. Para ver inteiro, clique com o botão direito na célula e escolha *Open Value in Viewer* (ou copie o conteúdo). Veja estes pontos:

- `actual time=A..B`: **B** é o tempo total, em milissegundos.
- `rows=`: quantas linhas foram realmente lidas.
- `Sort`: ordenação feita na memória (só aparece no ANTES).
- `Filter`: o MySQL leu linhas e descartou parte delas (só no ANTES).
- `Covering index`: a resposta saiu só do índice, sem ler a tabela (aparece em 5b e 5c).

**Exemplo de resultado** (uma execução de teste; os seus tempos variam conforme o computador, mas o **formato do plano** deve ser o mesmo):

| Consulta | ANTES | DEPOIS | Plano depois |
|---|---|---|---|
| Listar turmas de um idioma e nível, ordenado | ~55 ms | ~19 ms | `Index lookup on turma using idx_turma_idioma_nivel`, sem `Sort` |
| Listar conteúdos de um idioma e nível, ordenado | ~50 ms | ~2 ms | `Covering index lookup on conteudo using idx_conteudo_idioma_nivel` |
| Contar turmas de um idioma e nível | ~22 ms | ~3 ms | `Covering index lookup on turma using idx_turma_idioma_nivel` |

O ganho em "listar turmas" é menor porque a consulta também pede a coluna `vagas`, que não está no índice, então o MySQL ainda precisa ler a tabela. Essa é uma boa observação para o relatório.

**Se o passo 2 der "Error Code: 2013. Lost connection"** ou *timeout*: aumente o tempo em **Edit → Preferences → SQL Editor → DBMS connection read timeout** (por exemplo, para 600 segundos), reconecte e rode de novo.

### 5. Teste extra: as views reagem à exclusão de conta (RF10)

```sql
USE virtualingua;
SELECT vagas_ocupadas FROM vw_turmas_por_idioma WHERE turma = 'Espanhol A1 Manhã';  -- 3
SELECT COUNT(*) FROM vw_alunos_por_idioma WHERE id_aluno = 10;                      -- 2 (Felipe)

CALL sp_excluir_conta(10);      -- anonimiza o Felipe e cancela as matrículas abertas

SELECT vagas_ocupadas FROM vw_turmas_por_idioma WHERE turma = 'Espanhol A1 Manhã';  -- 2 (a vaga foi liberada)
SELECT COUNT(*) FROM vw_alunos_por_idioma WHERE id_aluno = 10;                      -- 0
```

Para **restaurar os dados**, execute o `03_seed.sql` de novo.

## Prints para o relatório

Guarde os prints (e anote o nome do arquivo e a consulta de cada um):

- [ ] `SHOW INDEX FROM turma;` e `SHOW INDEX FROM conteudo;` (mostrando os índices novos)
- [ ] As 4 abas de resultado das views (`04_views.sql`)
- [ ] Cada uma das 18 consultas do `06_consultas_avancadas.sql`
- [ ] `EXPLAIN ANALYZE` ANTES (3a, 3b, 3c) e DEPOIS (5a, 5b, 5c), lado a lado
- [ ] A tabela de comparação de tempos, com os **seus** números

## Problemas comuns

| Mensagem | Causa e solução |
|---|---|
| `Error 1049: Unknown database 'virtualingua'` | O `01_schema.sql` ainda não foi executado |
| `Error 1146: Table ... doesn't exist` | Idem: rode o `01_schema.sql` antes |
| `Error 1061: Duplicate key name 'idx_turma_idioma_nivel'` | O `02_indexes.sql` já foi executado. Para refazer, use o bloco ROLLBACK no fim dele |
| Views retornam 0 linhas | O `03_seed.sql` não foi executado |
| `You have an error in your SQL syntax ... EXPLAIN ANALYZE` | MySQL abaixo de 8.0.18. Confira com `SELECT VERSION();` |
| `Lost connection` no passo 2 do `07` | Aumente o *DBMS connection read timeout* (veja acima) |

## Como foi testado

Todos os scripts foram executados em um MySQL 8.0.46 recém-criado, na ordem 01 → 02 → 03 → 04 → 05 → 06 → 07, sem nenhum erro. As views e consultas foram conferidas contra o seed, e a exclusão de conta (RF10) foi testada junto com as views. A execução foi feita por linha de comando; os atalhos e menus do Workbench citados acima são os padrões do programa.
