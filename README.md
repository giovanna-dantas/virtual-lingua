# VirtuaLingua

Escola online de inglês e espanhol — projeto da disciplina de Banco de Dados.
**Stack:** MySQL 8 (Workbench) + Python/Flask (`mysql-connector-python`, SQL puro).

## Estrutura

```
virtualingua/
├── database/
│   ├── 01_schema.sql            # cria o banco "virtualingua" e as 11 tabelas
│   ├── 03_seed.sql              # dados de teste (1 admin, 3 professores, 15 alunos, turmas...)
│   └── 05_rf10_excluir_conta.sql# procedure sp_excluir_conta (RF10 / LGPD)
└── backend/
    ├── app.py                   # rotas Flask (login, idiomas, níveis)
    ├── db.py                    # pool de conexões, consultas e tradução de erros do MySQL
    ├── templates/               # páginas HTML
    ├── tests/                   # testes automatizados (pytest)
    ├── requirements.txt         # dependências
    └── .env.example             # modelo de configuração (copie para .env)
```

## Como rodar

1. **Banco** — no MySQL Workbench, abra e execute (raio) nesta ordem:
   `database/01_schema.sql` → `database/03_seed.sql` → `database/05_rf10_excluir_conta.sql`.
2. **Back-end** (terminal na pasta `backend`):
   ```
   python -m venv venv
   venv\Scripts\activate            # Windows  (Linux/Mac: source venv/bin/activate)
   pip install -r requirements.txt
   copy .env.example .env           # Windows  (Linux/Mac: cp .env.example .env)
   ```
   Abra o `.env` e preencha `DB_PASSWORD` (a senha do seu MySQL) e `FLASK_SECRET_KEY`.
3. `python app.py` e acesse http://127.0.0.1:5000

## Usuários de teste (vêm do `03_seed.sql`)

Senha de todos: `Senha@123`

| Perfil | E-mail |
|---|---|
| Administrador | admin@virtualingua.com.br |
| Professor | carlos.mendes@virtualingua.com.br |
| Aluno | ana.costa@exemplo.com |

Somente o administrador cadastra, edita e exclui idiomas e níveis.

## Testes automatizados

Na pasta `backend`, com o venv ativo:
```
pip install -r requirements-dev.txt
pytest
```
> Os testes gravam no banco do seu `.env` (criam e apagam um idioma "Francês"). Use o banco de desenvolvimento.

## Fluxo de trabalho no Git

- Nunca commite o `.env` (já está no `.gitignore`) nem a pasta `venv`.
- Trabalhe em branch (`git checkout -b feature/nome-da-tarefa`), faça push e abra um Pull Request para a `main`.
