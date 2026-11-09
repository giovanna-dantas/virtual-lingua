# Tutorial: subir no GitHub e testar tudo (VirtuaLingua integrado)

Este pacote é o projeto **completo**: o integrado das suas amigas (back-end, evidências, scripts 01 a 08) **mais** a Semana 3 de Banco de Dados (scripts 09 a 16, `scripts/`, testes novos). Nada foi removido. Os comandos são para o **Git Bash** (Windows) ou terminal Linux/Mac.

> O arquivo `backend/.env` **não** está no pacote de propósito (tem senhas). Você cria o seu na Parte B.

---

## PARTE A — Subir no GitHub

### A1. Conferir o repositório local
```bash
cd caminho/para/virtual-lingua
git status
git branch -a
```
A árvore tem que estar limpa. Se não estiver, faça commit ou `git stash`.

### A2. Atualizar e criar a branch
Parta da branch que já tem o projeto integrado (provavelmente `dev`; troque se for outra):
```bash
git fetch origin
git checkout dev
git pull origin dev
git checkout -b feature/banco-semana3
```

### A3. Copiar o pacote para dentro do repositório
1. Extraia o zip (surge a pasta `VirtuaLingua_integrado`).
2. Abra a pasta extraída, selecione **todo o conteúdo** (não a pasta em si) e copie para a raiz do repositório `virtual-lingua`.
3. Se o Windows perguntar sobre arquivos existentes, escolha **Substituir** (os iguais continuam iguais; só mudam `README.md` e `backend/test_support.py`).
4. A pasta `.git` do repositório fica intacta, não a apague.

**Antes do commit, olhe o que mudou de verdade:**
```bash
git status
git diff README.md backend/test_support.py
```
Esperado:
- **Novos:** `database/09` a `16`, `database/README_semana3.md`, `scripts/`, `backend/tests/test_banco_semana3.py`, `backend/.env.example`, `TUTORIAL_GITHUB_E_TESTES.md`.
- **Modificados:** só `README.md` e `backend/test_support.py`, com linhas **acrescentadas**. Se o `git diff` mostrar linhas de colegas sendo **removidas**, alguém mexeu nesses arquivos depois do zip: pare, rode `git checkout -- README.md backend/test_support.py`, e aplique as mudanças à mão.
- **O `.env` NÃO pode aparecer.** Se aparecer, não faça `git add`.

### A4. Commit
```bash
git add .
git status
git commit -m "feat(banco): semana 3 - triggers de status e auditoria, procedures, roles, demos de concorrência e backup"
```
(O `git status` entre os dois é para conferir de novo que o `.env` não está na lista.)

### A5. Enviar
```bash
git push -u origin feature/banco-semana3
```
Se pedir login: usuário do GitHub e um **Personal Access Token** no lugar da senha (GitHub → Settings → Developer settings → Personal access tokens).

### A6. Pull Request
1. No GitHub, abra o repositório e clique em **Compare & pull request**.
2. **Base:** a mesma branch de onde você partiu (`dev` no exemplo). **Compare:** `feature/banco-semana3`.
3. Título: `Banco de Dados — Semana 3`. Na descrição, resuma: triggers (09, 10), procedures e função (11), roles (12), demos (13 a 15), backup (16), testes.
4. Peça revisão a uma amiga e faça o merge depois.

**Ordem dos PRs:** se o PR da `feature/banco-semana2` ainda não foi mesclado, mescle-o primeiro. Senão o da Semana 3 vai arrastar os arquivos da Semana 2 junto.

### A7. Depois do merge
```bash
git checkout dev
git pull origin dev
git branch -d feature/banco-semana3
```
Cole o link do PR no campo **Link do PR** das tarefas no Notion.

---

## PARTE B — Como testar

### B1. Pré-requisitos
MySQL 8.0.20+ (com o serviço ligado), MySQL Workbench, Python 3.10+ e Git.

### B2. Montar o banco (Workbench, conexão root)
Abra cada arquivo com **File > Open SQL Script** (Ctrl+Shift+O) e clique no **raio**, **nesta ordem**:

`01_schema` → `02_indexes` → `03_seed` → `04_views` → `05_rf10_excluir_conta` → `08_triggers_regras_negocio` → `09` → `10` → `11` → `12`

(Os arquivos 06, 07 e 13 a 16 não entram aqui: são consultas e demonstrações.)

Conferência (rode no Workbench, `USE virtualingua;`):
```sql
SELECT COUNT(*) FROM usuario;                                                      -- 19
SELECT COUNT(*) FROM information_schema.triggers WHERE trigger_schema='virtualingua'; -- 12
SELECT COUNT(*) FROM information_schema.routines WHERE routine_schema='virtualingua'; -- 5
```

### B3. Testes automatizados (pytest + behave)
Abra o **CMD** (ou PowerShell) na pasta `backend`:
```
cd caminho\para\virtual-lingua\backend
python -m venv venv
venv\Scripts\activate
python -m pip install -r requirements.txt -r requirements-dev.txt
copy .env.example .env
notepad .env
```
No Bloco de Notas, preencha `DB_PASSWORD` (senha do seu MySQL) e troque `FLASK_SECRET_KEY` por um texto longo qualquer. Salve e feche. Depois:
```
python -m pytest -q
python -m behave tests/features
```
Esperado:
- pytest: **33 passed** (os testes do grupo + 12 novos da Semana 3).
- behave: **1 feature passed, 2 scenarios passed, 7 steps passed**.

Os testes usam um banco **descartável** `virtualingua_test`. Seu banco `virtualingua` não é tocado. Exige o `mysql.exe` no PATH; se aparecer "Cliente mysql nao encontrado", adicione `C:\Program Files\MySQL\MySQL Server 8.0\bin` às variáveis de ambiente (Path) e abra um CMD novo.

Para as **evidências** da pasta `evidencias/`, rode também com saída para arquivo, se o professor pedir versão nova:
```
python -m pytest -v --junitxml=..\evidencias\pytest.xml
```

### B4. Rodar a aplicação
Com o venv ativo, na pasta `backend`:
```
python app.py
```
Abra `http://127.0.0.1:5000/`. Logins do seed (senha de todos: `Senha@123`):

| Perfil | E-mail |
|---|---|
| Administrador | `admin@virtualingua.com.br` |
| Professor | `carlos.mendes@virtualingua.com.br` |
| Aluno | `ana.costa@exemplo.com` |

A API (contrato em `backend/API.md`) fica em `http://127.0.0.1:5000/api`.

### B5. Testar as regras novas na mão (Workbench)
```sql
USE virtualingua;
-- matrícula + pagamento numa transação
CALL sp_matricular_aluno(16, 5, 300.00, '2026-12-10', @m, @p);  SELECT @m, @p;
-- pagar ativa a matrícula (trigger) e gera auditoria
UPDATE pagamento SET status='pago', data_pagamento=CURDATE() WHERE id_pagamento=@p;
SELECT status FROM matricula WHERE id_matricula=@m;             -- ativa
SELECT * FROM log_auditoria ORDER BY id_log DESC LIMIT 3;
-- transição proibida (erro 1644)
UPDATE matricula SET status='pendente' WHERE id_matricula=@m;
-- lote com SAVEPOINT
CALL sp_matricular_lote(5, '[17, 18, 12, 1, 999]', 300, '2026-12-10');
-- pontuação e média
CALL sp_registrar_pontuacao(7, 2, 15, @r);  SELECT @r, fn_media_aluno(7);
```
Para voltar o banco ao estado original depois dos testes manuais, rode de novo `01` a `12` na ordem (o 01 recria tudo).

### B6. Demonstrações para o relatório
Siga o `database/README_semana3.md`: seção 5 (perfis), 6 (transações), 7 (isolamento, duas abas), 8 (lock e deadlock, duas abas), 9 (backup e restore) e 11 (**checklist de prints**).

### B7. Backup rápido (Windows)
Na pasta `scripts`, duplo clique em `backup.bat` (ajuste `MYSQLBIN` no começo do arquivo se o seu MySQL não estiver em `C:\Program Files\MySQL\MySQL Server 8.0\bin`). Senha do `vl_backup`: `Demo@Bkp123`. Depois `restaurar_teste.bat backups\ARQUIVO.sql` e rode o `16_verificar_backup_restore.sql`.

---

## Problemas comuns

| Sintoma | Solução |
|---|---|
| `git status` mostra `backend/.env` | **não** faça `git add`; confirme que o `.gitignore` tem a linha `.env` |
| `Cliente mysql nao encontrado` nos testes | coloque a pasta `bin` do MySQL no Path e abra um CMD novo |
| `Access denied` nos testes | senha errada no `.env` (`DB_PASSWORD`) |
| `ERROR 1305 PROCEDURE ... does not exist` | rodou o 12 antes do 11 |
| `.env.example` não é reconhecido no CMD | é um arquivo para copiar, não um comando: use `copy .env.example .env` |
| Push recusado (`non-fast-forward`) | `git pull --rebase origin feature/banco-semana3` e tente de novo |
| PR traz arquivos que não são seus | a base do PR está errada, ou o PR da Semana 2 ainda não foi mesclado |
