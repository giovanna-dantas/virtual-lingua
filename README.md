# VirtuaLingua

**Plataforma web de gerenciamento de ensino e aprendizagem de idiomas.**

O VirtuaLingua é um projeto acadêmico desenvolvido com Python, Flask e MySQL, com o objetivo de integrar o gerenciamento de usuários, idiomas, turmas, matrículas, conteúdos, desafios, pontuações e pagamentos em uma única aplicação.

## Tecnologias utilizadas

- **Python e Flask:** desenvolvimento do backend e da aplicação web.
- **MySQL 8:** gerenciamento do banco de dados.
- **HTML, CSS e JavaScript:** desenvolvimento da interface.
- **Git e GitHub:** controle de versão.

## Funcionalidades

- Gerenciamento de usuários e perfis de acesso.
- Cadastro de idiomas, níveis e turmas.
- Controle de matrículas e pagamentos.
- Gerenciamento de conteúdos e desafios.
- Registro e acompanhamento de pontuações.
- API REST para operações do sistema.
- Controle de acesso e auditoria de operações.

## Estrutura do projeto

```text
virtual-lingua/
├── backend/       # Aplicação Flask, API e interface
├── database/      # Scripts SQL e estrutura do banco
├── evidencias/    # Registros de testes e resultados
├── scripts/       # Backup e restauração do banco
├── README.md
└── VirtuaLingua_Documentacao.pdf
```

## Banco de dados

O banco de dados `virtualingua` foi desenvolvido em MySQL 8 e contempla:

- 11 tabelas;
- 4 views;
- 12 triggers;
- 5 procedures e functions.

Também são utilizados recursos como chaves primárias e estrangeiras, índices, transações, controle de permissões e auditoria.

Os scripts de criação, configuração e demonstração estão disponíveis na pasta `database/`.

## Como executar

### 1. Pré-requisitos

- Python 3.10 ou superior.
- MySQL Server 8.
- Git.

### 2. Clonar o repositório

```bash
git clone https://github.com/giovanna-dantas/virtual-lingua.git
cd virtual-lingua
```

### 3. Configurar o banco de dados

No MySQL Workbench, execute os scripts da pasta `database/`, seguindo a ordem indicada no README e nos arquivos de apoio da pasta.

**Atenção:** o script `01_schema.sql` recria as tabelas e pode apagar dados existentes.

### 4. Instalar as dependências

Acesse a pasta do backend:

```bash
cd backend
```

Crie e ative o ambiente virtual:

**Windows:**
```bash
python -m venv venv
venv\Scripts\activate
```

**Linux/macOS:**
```bash
python3 -m venv venv
source venv/bin/activate
```

Instale as dependências:

```bash
python -m pip install -r requirements.txt
```

### 5. Configurar o ambiente

Copie o arquivo `.env.example` para `.env` e configure as credenciais de acesso ao MySQL, além da chave secreta da aplicação.

### 6. Iniciar a aplicação

```bash
python app.py
```

Acesse pelo navegador

## Documentação e testes

- **Documentação do projeto:** `VirtuaLingua_Documentacao.pdf`
- **Documentação da API:** `backend/API.md`
- **Evidências de testes:** pasta `evidencias/`
- **Scripts de backup e restauração:** pasta `scripts/`

## Autoria

Projeto acadêmico desenvolvido como parte das atividades de graduação, aplicando conceitos de desenvolvimento web, programação e banco de dados.

**Repositório:** [GitHub — VirtuaLingua](https://github.com/giovanna-dantas/virtual-lingua)
