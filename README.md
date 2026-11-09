# VirtuaLingua — projeto integrado

## Estrutura
- `backend/`: aplicação Flask, API REST, conexão MySQL, templates, CSS e testes.
- `database/`: schema, índices, dados iniciais, views, procedure, consultas e triggers.

## Configuração
1. Instale MySQL 8.0.16+ e crie/prepare o banco `virtualingua`.
2. No MySQL Workbench, execute na ordem: `database/01_schema.sql`, `02_indexes.sql`, `03_seed.sql`, `04_views.sql`, `05_rf10_excluir_conta.sql`, `08_triggers_regras_negocio.sql` e, da Semana 3, `09` a `12` (triggers de status/auditoria, procedures e roles). Os scripts 06 e 07 são consultas de apoio/análise e 13 a 16 são demonstrações (veja `database/README_semana3.md`).
3. Entre em `backend/`, crie ambiente virtual e instale dependências:
   - Windows CMD: `python -m venv venv` ; `venv\\Scripts\\activate` ; `python -m pip install -r requirements.txt`.
   - Linux/macOS: `python3 -m venv venv` ; `source venv/bin/activate` ; `python -m pip install -r requirements.txt`.
4. Copie `.env.example` para `.env` e configure `DB_HOST`, `DB_PORT`, `DB_USER`, `DB_PASSWORD`, `DB_NAME` e uma `FLASK_SECRET_KEY` longa e aleatória.
5. Execute `python app.py` e acesse `http://127.0.0.1:5000/`.

**Atenção:** `01_schema.sql` recria as tabelas e apaga dados existentes. Não o execute sobre uma base com dados que deseja preservar. Para banco já criado, aplique somente scripts ainda não executados, conferindo previamente seus objetos.

## API
O contrato completo, os métodos, permissões, campos e fluxo de autenticação estão em `backend/API.md`. O endpoint `GET /api/rotas` também publica o catálogo em JSON.

## Segurança e operação
- Senhas são armazenadas com hash Werkzeug; não são guardadas em texto puro.
- SQL usa parâmetros `%s`; nomes de tabelas/colunas são definidos por whitelist no código.
- Sessões usam cookie HttpOnly/SameSite e rotas de escrita exigem token CSRF (`GET /api/csrf`, header `X-CSRF-Token`).
- `db.py` usa pool MySQL e disponibiliza `transacao()`/`executar_transacao()` para atomicidade.
- A exclusão de conta chama `sp_excluir_conta`, que anonimiza os dados pessoais e preserva histórico acadêmico/financeiro (não é DELETE físico).
- `FLASK_DEBUG=1` deve ser usado somente em desenvolvimento local.

## Banco de dados — Semana 3
Triggers de status e auditoria, procedures transacionais, roles/GRANTs, demos de transação/isolamento/deadlock e backup/restore: veja `database/README_semana3.md`. Testes: `python -m pytest -q` em `backend/` (33 passed).
