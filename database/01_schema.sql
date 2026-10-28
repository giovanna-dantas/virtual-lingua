-- Modelo fisico em 3FN. Execute antes do 03_seed.sql e do 05_rf10_excluir_conta.sql.
-- Requer MySQL 8.0.16 ou superior (antes disso o MySQL ignora as clausulas CHECK).

CREATE DATABASE IF NOT EXISTS virtualingua
    CHARACTER SET utf8mb4
    COLLATE utf8mb4_unicode_ci;

USE virtualingua;

SET NAMES utf8mb4;
SET FOREIGN_KEY_CHECKS = 0;

DROP TABLE IF EXISTS log_auditoria;
DROP TABLE IF EXISTS pontuacao;
DROP TABLE IF EXISTS desafio;
DROP TABLE IF EXISTS conteudo;
DROP TABLE IF EXISTS pagamento;
DROP TABLE IF EXISTS matricula;
DROP TABLE IF EXISTS turma;
DROP TABLE IF EXISTS professor_idioma;
DROP TABLE IF EXISTS usuario;
DROP TABLE IF EXISTS nivel;
DROP TABLE IF EXISTS idioma;

SET FOREIGN_KEY_CHECKS = 1;


-- Tabelas de dominio (RF11)
CREATE TABLE idioma (
    id_idioma  INT          NOT NULL AUTO_INCREMENT,
    nome       VARCHAR(30)  NOT NULL,
    codigo     CHAR(2)      NOT NULL,
    PRIMARY KEY (id_idioma),
    UNIQUE KEY uk_idioma_nome (nome),
    UNIQUE KEY uk_idioma_codigo (codigo),
    -- BINARY forca a comparacao sensivel a maiusculas (a colacao padrao nao e)
    CONSTRAINT ck_idioma_codigo CHECK (BINARY codigo = BINARY UPPER(codigo))
) ENGINE = InnoDB;

CREATE TABLE nivel (
    id_nivel   INT          NOT NULL AUTO_INCREMENT,
    codigo     VARCHAR(2)   NOT NULL,
    descricao  VARCHAR(60)  NOT NULL,
    PRIMARY KEY (id_nivel),
    UNIQUE KEY uk_nivel_codigo (codigo),
    CONSTRAINT ck_nivel_codigo CHECK (codigo IN ('A1','A2','B1','B2','C1','C2'))
) ENGINE = InnoDB;


-- Usuarios (RF01, RF08, RF09, RF10)
-- RF10 / LGPD: a conta NAO e apagada fisicamente; os dados pessoais sao
-- anonimizados pela procedure sp_excluir_conta (ver 05_rf10_excluir_conta.sql).

CREATE TABLE usuario (
    id_usuario     INT          NOT NULL AUTO_INCREMENT,
    nome           VARCHAR(100) NOT NULL,
    email          VARCHAR(120) NOT NULL,
    senha_hash     VARCHAR(255) NOT NULL,
    tipo           VARCHAR(15)  NOT NULL,
    ativo          BOOLEAN      NOT NULL DEFAULT TRUE,
    criado_em      DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,
    anonimizado_em DATETIME     NULL,
    PRIMARY KEY (id_usuario),
    UNIQUE KEY uk_usuario_email (email),
    CONSTRAINT ck_usuario_email CHECK (email LIKE '%_@_%'),
    CONSTRAINT ck_usuario_tipo  CHECK (tipo IN ('aluno','professor','administrador')),
    CONSTRAINT ck_usuario_anon  CHECK (anonimizado_em IS NULL OR ativo = FALSE)
) ENGINE = InnoDB;

-- N:N - idiomas em que cada professor esta habilitado
CREATE TABLE professor_idioma (
    id_professor INT NOT NULL,
    id_idioma    INT NOT NULL,
    PRIMARY KEY (id_professor, id_idioma),
    CONSTRAINT fk_pi_professor FOREIGN KEY (id_professor)
        REFERENCES usuario (id_usuario) ON DELETE CASCADE,
    CONSTRAINT fk_pi_idioma FOREIGN KEY (id_idioma)
        REFERENCES idioma (id_idioma) ON DELETE RESTRICT
) ENGINE = InnoDB;


-- Turmas, matriculas e pagamentos (RF02, RF03, RF07)
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
    CONSTRAINT fk_turma_idioma FOREIGN KEY (id_idioma)
        REFERENCES idioma (id_idioma) ON DELETE RESTRICT,
    CONSTRAINT fk_turma_nivel FOREIGN KEY (id_nivel)
        REFERENCES nivel (id_nivel) ON DELETE RESTRICT,
    CONSTRAINT fk_turma_professor FOREIGN KEY (id_professor)
        REFERENCES usuario (id_usuario) ON DELETE SET NULL,
    CONSTRAINT ck_turma_carga CHECK (carga_horaria > 0),
    CONSTRAINT ck_turma_vagas CHECK (vagas > 0)
) ENGINE = InnoDB;

CREATE TABLE matricula (
    id_matricula   INT         NOT NULL AUTO_INCREMENT,
    id_aluno       INT         NOT NULL,
    id_turma       INT         NOT NULL,
    data_matricula DATE        NOT NULL DEFAULT (CURRENT_DATE),
    status         VARCHAR(10) NOT NULL DEFAULT 'pendente',
    PRIMARY KEY (id_matricula),
    UNIQUE KEY uk_matricula_aluno_turma (id_aluno, id_turma),
    CONSTRAINT fk_matricula_aluno FOREIGN KEY (id_aluno)
        REFERENCES usuario (id_usuario) ON DELETE RESTRICT,
    CONSTRAINT fk_matricula_turma FOREIGN KEY (id_turma)
        REFERENCES turma (id_turma) ON DELETE RESTRICT,
    CONSTRAINT ck_matricula_status CHECK (status IN ('pendente','ativa','cancelada','concluida'))
) ENGINE = InnoDB;

CREATE TABLE pagamento (
    id_pagamento    INT           NOT NULL AUTO_INCREMENT,
    id_matricula    INT           NOT NULL,
    valor           DECIMAL(10,2) NOT NULL,
    data_vencimento DATE          NOT NULL,
    data_pagamento  DATE          NULL,
    status          VARCHAR(10)   NOT NULL DEFAULT 'pendente',
    PRIMARY KEY (id_pagamento),
    CONSTRAINT fk_pagamento_matricula FOREIGN KEY (id_matricula)
        REFERENCES matricula (id_matricula) ON DELETE RESTRICT,
    CONSTRAINT ck_pagamento_valor  CHECK (valor > 0),
    CONSTRAINT ck_pagamento_status CHECK (status IN ('pendente','pago','atrasado','cancelado')),
    -- status 'pago' exige data de pagamento, e so ele a permite
    CONSTRAINT ck_pagamento_data   CHECK ((status = 'pago') = (data_pagamento IS NOT NULL))
) ENGINE = InnoDB;


-- Conteudos, desafios e pontuacoes (RF04, RF05, RF06)
CREATE TABLE conteudo (
    id_conteudo  INT          NOT NULL AUTO_INCREMENT,
    titulo       VARCHAR(120) NOT NULL,
    descricao    TEXT         NULL,
    id_idioma    INT          NOT NULL,
    id_nivel     INT          NOT NULL,
    id_professor INT          NULL,
    PRIMARY KEY (id_conteudo),
    UNIQUE KEY uk_conteudo (titulo, id_idioma, id_nivel),
    CONSTRAINT fk_conteudo_idioma FOREIGN KEY (id_idioma)
        REFERENCES idioma (id_idioma) ON DELETE RESTRICT,
    CONSTRAINT fk_conteudo_nivel FOREIGN KEY (id_nivel)
        REFERENCES nivel (id_nivel) ON DELETE RESTRICT,
    CONSTRAINT fk_conteudo_professor FOREIGN KEY (id_professor)
        REFERENCES usuario (id_usuario) ON DELETE SET NULL
) ENGINE = InnoDB;

CREATE TABLE desafio (
    id_desafio       INT          NOT NULL AUTO_INCREMENT,
    id_conteudo      INT          NOT NULL,
    titulo           VARCHAR(120) NOT NULL,
    descricao        TEXT         NULL,
    pontuacao_maxima INT          NOT NULL,
    PRIMARY KEY (id_desafio),
    UNIQUE KEY uk_desafio (id_conteudo, titulo),
    CONSTRAINT fk_desafio_conteudo FOREIGN KEY (id_conteudo)
        REFERENCES conteudo (id_conteudo) ON DELETE CASCADE,
    CONSTRAINT ck_desafio_max CHECK (pontuacao_maxima > 0)
) ENGINE = InnoDB;

CREATE TABLE pontuacao (
    id_pontuacao  INT          NOT NULL AUTO_INCREMENT,
    id_aluno      INT          NOT NULL,
    id_desafio    INT          NOT NULL,
    pontos        DECIMAL(5,2) NOT NULL,
    data_registro DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (id_pontuacao),
    UNIQUE KEY uk_pontuacao (id_aluno, id_desafio),
    CONSTRAINT fk_pontuacao_aluno FOREIGN KEY (id_aluno)
        REFERENCES usuario (id_usuario) ON DELETE RESTRICT,
    CONSTRAINT fk_pontuacao_desafio FOREIGN KEY (id_desafio)
        REFERENCES desafio (id_desafio) ON DELETE CASCADE,
    CONSTRAINT ck_pontuacao_pontos CHECK (pontos >= 0)
) ENGINE = InnoDB;


-- Auditoria (alimentada por triggers na Semana 4; usada ja no RF10)
CREATE TABLE log_auditoria (
    id_log      BIGINT      NOT NULL AUTO_INCREMENT,
    tabela      VARCHAR(40) NOT NULL,
    operacao    VARCHAR(20) NOT NULL,
    id_registro INT         NULL,
    detalhe     TEXT        NULL,
    usuario_bd  VARCHAR(100) NOT NULL DEFAULT (CURRENT_USER()),
    criado_em   DATETIME    NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (id_log)
) ENGINE = InnoDB;

-- Regras que NAO cabem em CHECK/FK simples (viram triggers - Semana 4):
--  * turma.id_professor deve ser usuario.tipo = 'professor' habilitado no idioma
--  * matricula: turma sem vaga; aluno deve ser tipo 'aluno'
--  * pontuacao.pontos <= desafio.pontuacao_maxima
-- (o MySQL nao permite subconsulta dentro de CHECK, por isso triggers.)
