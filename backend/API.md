# Contrato da API VirtuaLingua

Base URL: `http://127.0.0.1:5000/api`

## Convenções
- Requisições e respostas usam JSON (`Content-Type: application/json`).
- Resposta padrão: `{"ok": true, "dados": ..., "mensagem": "..."}`. Erros incluem `ok:false` e `mensagem`.
- A autenticação usa sessão Flask por cookie. O frontend deve manter o cookie entre chamadas.
- Proteção CSRF: primeiro faça `GET /api/csrf`; envie o valor `dados.csrf_token` no cabeçalho `X-CSRF-Token` em toda requisição POST/PUT/DELETE.
- `GET /api/rotas` publica a lista resumida dos endpoints.
- Perfis: `administrador`, `professor`, `aluno`. Rotas restritas respondem HTTP 401 sem login e 403 sem permissão.

## Autenticação e conta
| Método | Rota | Acesso |
|---|---|---|
| GET | `/csrf` | Público |
| POST | `/login` | Público; `{ "email": "...", "senha": "..." }` |
| POST | `/logout` | Autenticado |
| GET/PUT | `/perfil` | Próprio usuário; PUT aceita `nome`, `email`, `senha` |
| DELETE | `/conta` | Próprio usuário; corpo `{ "confirmar": true }` |

## Recursos CRUD
| Recurso | Rotas | Acesso |
|---|---|---|
| Usuários | GET/POST `/usuarios`; GET/PUT/DELETE `/usuarios/{id}` | Administrador |
| Turmas | GET/POST `/turmas`; GET/PUT/DELETE `/turmas/{id}` | Administrador |
| Matrículas | GET/POST `/matriculas`; GET `/matriculas/{id}`; PUT/DELETE `/matriculas/{id}` | Aluno (próprias consultas e criação) ou administrador |
| Conteúdos/trilhas | GET/POST `/conteudos`; GET/PUT/DELETE `/conteudos/{id}` | Administrador/professor |
| Desafios | GET/POST `/desafios`; GET/PUT/DELETE `/desafios/{id}` | Administrador/professor |
| Pontuações | GET/POST `/pontuacoes`; GET/PUT/DELETE `/pontuacoes/{id}` | Aluno registra/consulta própria; professor/administrador gerencia |
| Pagamentos | GET/POST `/pagamentos`; GET/PUT/DELETE `/pagamentos/{id}` | Aluno consulta os próprios; administrador gerencia |

## Campos principais
- Usuário: `nome`, `email`, `senha`, `tipo` (`aluno` ou `professor`); professor pode informar `idiomas_habilitados` como lista de IDs.
- Turma: `nome`, `id_idioma`, `id_nivel`, `id_professor` (opcional), `carga_horaria`, `vagas`.
- Matrícula: `id_turma`; administrador também informa `id_aluno`. Aluno usa o próprio ID da sessão.
- Conteúdo: `titulo`, `descricao`, `id_idioma`, `id_nivel`, `id_professor`.
- Desafio: `id_conteudo`, `titulo`, `descricao`, `pontuacao_maxima`.
- Pontuação: `id_desafio`, `pontos`; administrador/professor também informa `id_aluno`. Aluno usa o próprio ID da sessão.
- Pagamento: `id_matricula`, `valor`, `data_vencimento`, `status` (`pendente`, `pago`, `atrasado`, `cancelado`), `data_pagamento` (obrigatória apenas quando status `pago`). Datas no formato `AAAA-MM-DD`.

## Fluxo mínimo do frontend
1. `GET /api/csrf` e guardar o token e cookie de sessão.
2. `POST /api/login` com e-mail e senha.
3. Enviar `X-CSRF-Token` em POST/PUT/DELETE.
4. Consultar `GET /api/rotas` para obter o catálogo publicado.
5. Ao sair, chamar `POST /api/logout`.

## Regras de negócio
- Matrícula exige usuário ativo do tipo aluno, não permite duplicidade (chave única) e valida vagas disponíveis.
- Turma com professor exige habilitação do professor no idioma da turma.
- Pontuação não pode ser negativa nem exceder a pontuação máxima do desafio.
- Pagamento sempre referencia uma matrícula; valor deve ser positivo e status/data de pagamento devem ser coerentes.
- Exclusão de conta chama `sp_excluir_conta`, que anonimiza dados pessoais e preserva histórico conforme o script SQL do projeto.
