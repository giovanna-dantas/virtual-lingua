-- MySQL dump 10.13  Distrib 8.0.46, for Win64 (x86_64)
--
-- Host: localhost    Database: virtualingua
-- ------------------------------------------------------
-- Server version	8.0.46

/*!40101 SET @OLD_CHARACTER_SET_CLIENT=@@CHARACTER_SET_CLIENT */;
/*!40101 SET @OLD_CHARACTER_SET_RESULTS=@@CHARACTER_SET_RESULTS */;
/*!40101 SET @OLD_COLLATION_CONNECTION=@@COLLATION_CONNECTION */;
/*!50503 SET NAMES utf8mb4 */;
/*!40103 SET @OLD_TIME_ZONE=@@TIME_ZONE */;
/*!40103 SET TIME_ZONE='+00:00' */;
/*!40014 SET @OLD_UNIQUE_CHECKS=@@UNIQUE_CHECKS, UNIQUE_CHECKS=0 */;
/*!40014 SET @OLD_FOREIGN_KEY_CHECKS=@@FOREIGN_KEY_CHECKS, FOREIGN_KEY_CHECKS=0 */;
/*!40101 SET @OLD_SQL_MODE=@@SQL_MODE, SQL_MODE='NO_AUTO_VALUE_ON_ZERO' */;
/*!40111 SET @OLD_SQL_NOTES=@@SQL_NOTES, SQL_NOTES=0 */;

--
-- Table structure for table `conteudo`
--

DROP TABLE IF EXISTS `conteudo`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `conteudo` (
  `id_conteudo` int NOT NULL AUTO_INCREMENT,
  `titulo` varchar(120) COLLATE utf8mb4_unicode_ci NOT NULL,
  `descricao` text COLLATE utf8mb4_unicode_ci,
  `id_idioma` int NOT NULL,
  `id_nivel` int NOT NULL,
  `id_professor` int DEFAULT NULL,
  PRIMARY KEY (`id_conteudo`),
  UNIQUE KEY `uk_conteudo` (`titulo`,`id_idioma`,`id_nivel`),
  KEY `fk_conteudo_nivel` (`id_nivel`),
  KEY `fk_conteudo_professor` (`id_professor`),
  KEY `idx_conteudo_idioma_nivel` (`id_idioma`,`id_nivel`,`titulo`),
  CONSTRAINT `fk_conteudo_idioma` FOREIGN KEY (`id_idioma`) REFERENCES `idioma` (`id_idioma`) ON DELETE RESTRICT,
  CONSTRAINT `fk_conteudo_nivel` FOREIGN KEY (`id_nivel`) REFERENCES `nivel` (`id_nivel`) ON DELETE RESTRICT,
  CONSTRAINT `fk_conteudo_professor` FOREIGN KEY (`id_professor`) REFERENCES `usuario` (`id_usuario`) ON DELETE SET NULL
) ENGINE=InnoDB AUTO_INCREMENT=8 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `conteudo`
--

LOCK TABLES `conteudo` WRITE;
/*!40000 ALTER TABLE `conteudo` DISABLE KEYS */;
INSERT INTO `conteudo` VALUES (1,'Greetings and Introductions','Cumprimentos, apresentações e verbo to be.',1,1,2),(2,'Travel and Daily Routines','Passado simples, rotina e viagens.',1,3,4),(3,'Business English','Reuniões, e-mails e apresentações profissionais.',1,4,2),(4,'Saludos y Presentaciones','Saudações, apresentações e verbos ser e estar.',2,1,3),(5,'La Vida Cotidiana','Rotina, gostos e pretérito perfeito.',2,2,4),(6,'Viajes y Cultura','Pretérito indefinido, viagens e cultura hispânica.',2,3,3);
/*!40000 ALTER TABLE `conteudo` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `desafio`
--

DROP TABLE IF EXISTS `desafio`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `desafio` (
  `id_desafio` int NOT NULL AUTO_INCREMENT,
  `id_conteudo` int NOT NULL,
  `titulo` varchar(120) COLLATE utf8mb4_unicode_ci NOT NULL,
  `descricao` text COLLATE utf8mb4_unicode_ci,
  `pontuacao_maxima` int NOT NULL,
  PRIMARY KEY (`id_desafio`),
  UNIQUE KEY `uk_desafio` (`id_conteudo`,`titulo`),
  CONSTRAINT `fk_desafio_conteudo` FOREIGN KEY (`id_conteudo`) REFERENCES `conteudo` (`id_conteudo`) ON DELETE CASCADE,
  CONSTRAINT `ck_desafio_max` CHECK ((`pontuacao_maxima` > 0))
) ENGINE=InnoDB AUTO_INCREMENT=16 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `desafio`
--

LOCK TABLES `desafio` WRITE;
/*!40000 ALTER TABLE `desafio` DISABLE KEYS */;
INSERT INTO `desafio` VALUES (1,1,'Quiz de cumprimentos','Dez questões de múltipla escolha.',10),(2,1,'Apresente-se em áudio','Grave um áudio de 1 minuto.',20),(3,2,'Diário de viagem','Escreva um texto de 150 palavras.',30),(4,2,'Quiz de passado simples','Quinze questões de gramática.',15),(5,3,'Simulação de reunião','Roleplay de reunião em duplas.',40),(6,3,'E-mail profissional','Redija um e-mail formal.',20),(7,4,'Quiz de saludos','Dez questões de múltipla escolha.',10),(8,4,'Preséntate en audio','Grave um áudio de 1 minuto.',20),(9,5,'Mi rutina diaria','Escreva um texto sobre sua rotina.',25),(10,5,'Quiz de gustos','Doze questões de vocabulário.',12),(11,6,'Reseña de un viaje','Resenha de 200 palavras.',30),(12,6,'Quiz de pretérito','Quinze questões de gramática.',15);
/*!40000 ALTER TABLE `desafio` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `idioma`
--

DROP TABLE IF EXISTS `idioma`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `idioma` (
  `id_idioma` int NOT NULL AUTO_INCREMENT,
  `nome` varchar(30) COLLATE utf8mb4_unicode_ci NOT NULL,
  `codigo` char(2) COLLATE utf8mb4_unicode_ci NOT NULL,
  PRIMARY KEY (`id_idioma`),
  UNIQUE KEY `uk_idioma_nome` (`nome`),
  UNIQUE KEY `uk_idioma_codigo` (`codigo`),
  CONSTRAINT `ck_idioma_codigo` CHECK ((cast(`codigo` as char charset binary) = cast(upper(`codigo`) as char charset binary)))
) ENGINE=InnoDB AUTO_INCREMENT=3 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `idioma`
--

LOCK TABLES `idioma` WRITE;
/*!40000 ALTER TABLE `idioma` DISABLE KEYS */;
INSERT INTO `idioma` VALUES (1,'Inglês','EN'),(2,'Espanhol','ES');
/*!40000 ALTER TABLE `idioma` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `log_auditoria`
--

DROP TABLE IF EXISTS `log_auditoria`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `log_auditoria` (
  `id_log` bigint NOT NULL AUTO_INCREMENT,
  `tabela` varchar(40) COLLATE utf8mb4_unicode_ci NOT NULL,
  `operacao` varchar(20) COLLATE utf8mb4_unicode_ci NOT NULL,
  `id_registro` int DEFAULT NULL,
  `detalhe` text COLLATE utf8mb4_unicode_ci,
  `usuario_bd` varchar(100) COLLATE utf8mb4_unicode_ci NOT NULL DEFAULT (current_user()),
  `criado_em` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id_log`)
) ENGINE=InnoDB AUTO_INCREMENT=6 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `log_auditoria`
--

LOCK TABLES `log_auditoria` WRITE;
/*!40000 ALTER TABLE `log_auditoria` DISABLE KEYS */;
INSERT INTO `log_auditoria` VALUES (1,'pagamento','EXCLUSAO',32,'pagamento removido; matricula=32; valor=300.00; status=pendente','root@localhost','2026-11-20 18:21:39'),(4,'pagamento','EXCLUSAO',33,'pagamento removido; matricula=33; valor=300.00; status=pendente','root@localhost','2026-11-20 18:21:40'),(5,'pagamento','EXCLUSAO',34,'pagamento removido; matricula=34; valor=300.00; status=pendente','root@localhost','2026-11-20 18:21:40');
/*!40000 ALTER TABLE `log_auditoria` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `matricula`
--

DROP TABLE IF EXISTS `matricula`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `matricula` (
  `id_matricula` int NOT NULL AUTO_INCREMENT,
  `id_aluno` int NOT NULL,
  `id_turma` int NOT NULL,
  `data_matricula` date NOT NULL DEFAULT (curdate()),
  `status` varchar(10) COLLATE utf8mb4_unicode_ci NOT NULL DEFAULT 'pendente',
  PRIMARY KEY (`id_matricula`),
  UNIQUE KEY `uk_matricula_aluno_turma` (`id_aluno`,`id_turma`),
  KEY `fk_matricula_turma` (`id_turma`),
  CONSTRAINT `fk_matricula_aluno` FOREIGN KEY (`id_aluno`) REFERENCES `usuario` (`id_usuario`) ON DELETE RESTRICT,
  CONSTRAINT `fk_matricula_turma` FOREIGN KEY (`id_turma`) REFERENCES `turma` (`id_turma`) ON DELETE RESTRICT,
  CONSTRAINT `ck_matricula_status` CHECK ((`status` in (_utf8mb4'pendente',_utf8mb4'ativa',_utf8mb4'cancelada',_utf8mb4'concluida')))
) ENGINE=InnoDB AUTO_INCREMENT=37 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `matricula`
--

LOCK TABLES `matricula` WRITE;
/*!40000 ALTER TABLE `matricula` DISABLE KEYS */;
INSERT INTO `matricula` VALUES (1,5,2,'2026-08-10','ativa'),(2,5,4,'2026-08-12','ativa'),(3,6,1,'2026-08-10','ativa'),(4,6,5,'2026-09-01','ativa'),(5,7,1,'2026-08-11','ativa'),(6,8,3,'2026-08-11','ativa'),(7,9,2,'2026-08-15','ativa'),(8,10,4,'2026-08-15','ativa'),(9,11,4,'2026-08-18','ativa'),(10,12,5,'2026-08-18','ativa'),(11,13,6,'2026-08-20','ativa'),(12,14,1,'2026-08-20','ativa'),(13,15,3,'2026-08-22','ativa'),(14,16,6,'2026-08-22','ativa'),(15,17,7,'2026-09-02','ativa'),(16,18,7,'2026-09-02','ativa'),(17,19,2,'2026-10-10','pendente'),(18,10,1,'2026-08-25','pendente'),(19,14,5,'2026-07-01','cancelada');
/*!40000 ALTER TABLE `matricula` ENABLE KEYS */;
UNLOCK TABLES;
/*!50003 SET @saved_cs_client      = @@character_set_client */ ;
/*!50003 SET @saved_cs_results     = @@character_set_results */ ;
/*!50003 SET @saved_col_connection = @@collation_connection */ ;
/*!50003 SET character_set_client  = utf8mb4 */ ;
/*!50003 SET character_set_results = utf8mb4 */ ;
/*!50003 SET collation_connection  = utf8mb4_0900_ai_ci */ ;
/*!50003 SET @saved_sql_mode       = @@sql_mode */ ;
/*!50003 SET sql_mode              = 'ONLY_FULL_GROUP_BY,STRICT_TRANS_TABLES,NO_ZERO_IN_DATE,NO_ZERO_DATE,ERROR_FOR_DIVISION_BY_ZERO,NO_ENGINE_SUBSTITUTION' */ ;
DELIMITER ;;
/*!50003 CREATE*/ /*!50017 DEFINER=`root`@`localhost`*/ /*!50003 TRIGGER `trg_matricula_validar_bi` BEFORE INSERT ON `matricula` FOR EACH ROW BEGIN
  DECLARE v_tipo VARCHAR(15);
  DECLARE v_ativo BOOLEAN;
  DECLARE v_vagas INT;
  DECLARE v_ocupadas INT;
  SELECT tipo,ativo INTO v_tipo,v_ativo FROM usuario WHERE id_usuario=NEW.id_aluno;
  IF v_tipo<>'aluno' OR v_ativo=0 THEN SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Matrícula exige usuário ativo do tipo aluno'; END IF;
  SELECT vagas INTO v_vagas FROM turma WHERE id_turma=NEW.id_turma FOR UPDATE;
  SELECT COUNT(*) INTO v_ocupadas FROM matricula WHERE id_turma=NEW.id_turma AND status IN ('pendente','ativa') FOR SHARE;
  IF v_ocupadas>=v_vagas AND NEW.status IN ('pendente','ativa') THEN SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Turma sem vagas disponíveis'; END IF;
END */;;
DELIMITER ;
/*!50003 SET sql_mode              = @saved_sql_mode */ ;
/*!50003 SET character_set_client  = @saved_cs_client */ ;
/*!50003 SET character_set_results = @saved_cs_results */ ;
/*!50003 SET collation_connection  = @saved_col_connection */ ;
/*!50003 SET @saved_cs_client      = @@character_set_client */ ;
/*!50003 SET @saved_cs_results     = @@character_set_results */ ;
/*!50003 SET @saved_col_connection = @@collation_connection */ ;
/*!50003 SET character_set_client  = utf8mb4 */ ;
/*!50003 SET character_set_results = utf8mb4 */ ;
/*!50003 SET collation_connection  = utf8mb4_0900_ai_ci */ ;
/*!50003 SET @saved_sql_mode       = @@sql_mode */ ;
/*!50003 SET sql_mode              = 'ONLY_FULL_GROUP_BY,STRICT_TRANS_TABLES,NO_ZERO_IN_DATE,NO_ZERO_DATE,ERROR_FOR_DIVISION_BY_ZERO,NO_ENGINE_SUBSTITUTION' */ ;
DELIMITER ;;
/*!50003 CREATE*/ /*!50017 DEFINER=`root`@`localhost`*/ /*!50003 TRIGGER `trg_matricula_validar_bu` BEFORE UPDATE ON `matricula` FOR EACH ROW BEGIN
  DECLARE v_tipo VARCHAR(15);
  DECLARE v_ativo BOOLEAN;
  DECLARE v_vagas INT;
  DECLARE v_ocupadas INT;
  SELECT tipo,ativo INTO v_tipo,v_ativo FROM usuario WHERE id_usuario=NEW.id_aluno;
  IF v_tipo<>'aluno' OR v_ativo=0 THEN SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Matrícula exige usuário ativo do tipo aluno'; END IF;
  IF NEW.status IN ('pendente','ativa') AND OLD.status NOT IN ('pendente','ativa') THEN
    SELECT vagas INTO v_vagas FROM turma WHERE id_turma=NEW.id_turma FOR UPDATE;
    SELECT COUNT(*) INTO v_ocupadas FROM matricula WHERE id_turma=NEW.id_turma AND status IN ('pendente','ativa') AND id_matricula<>OLD.id_matricula FOR SHARE;
    IF v_ocupadas>=v_vagas THEN SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Turma sem vagas disponíveis'; END IF;
  END IF;
END */;;
DELIMITER ;
/*!50003 SET sql_mode              = @saved_sql_mode */ ;
/*!50003 SET character_set_client  = @saved_cs_client */ ;
/*!50003 SET character_set_results = @saved_cs_results */ ;
/*!50003 SET collation_connection  = @saved_col_connection */ ;
/*!50003 SET @saved_cs_client      = @@character_set_client */ ;
/*!50003 SET @saved_cs_results     = @@character_set_results */ ;
/*!50003 SET @saved_col_connection = @@collation_connection */ ;
/*!50003 SET character_set_client  = utf8mb4 */ ;
/*!50003 SET character_set_results = utf8mb4 */ ;
/*!50003 SET collation_connection  = utf8mb4_0900_ai_ci */ ;
/*!50003 SET @saved_sql_mode       = @@sql_mode */ ;
/*!50003 SET sql_mode              = 'ONLY_FULL_GROUP_BY,STRICT_TRANS_TABLES,NO_ZERO_IN_DATE,NO_ZERO_DATE,ERROR_FOR_DIVISION_BY_ZERO,NO_ENGINE_SUBSTITUTION' */ ;
DELIMITER ;;
/*!50003 CREATE*/ /*!50017 DEFINER=`root`@`localhost`*/ /*!50003 TRIGGER `trg_matricula_status_bu` BEFORE UPDATE ON `matricula` FOR EACH ROW BEGIN
  IF NEW.status <> OLD.status THEN
    IF NOT (
         (OLD.status = 'pendente'  AND NEW.status IN ('ativa','cancelada'))
      OR (OLD.status = 'ativa'     AND NEW.status IN ('concluida','cancelada'))
      OR (OLD.status = 'cancelada' AND NEW.status = 'pendente')
    ) THEN
      SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Transição de status da matrícula não permitida';
    END IF;
  END IF;
END */;;
DELIMITER ;
/*!50003 SET sql_mode              = @saved_sql_mode */ ;
/*!50003 SET character_set_client  = @saved_cs_client */ ;
/*!50003 SET character_set_results = @saved_cs_results */ ;
/*!50003 SET collation_connection  = @saved_col_connection */ ;

--
-- Table structure for table `nivel`
--

DROP TABLE IF EXISTS `nivel`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `nivel` (
  `id_nivel` int NOT NULL AUTO_INCREMENT,
  `codigo` varchar(2) COLLATE utf8mb4_unicode_ci NOT NULL,
  `descricao` varchar(60) COLLATE utf8mb4_unicode_ci NOT NULL,
  PRIMARY KEY (`id_nivel`),
  UNIQUE KEY `uk_nivel_codigo` (`codigo`),
  CONSTRAINT `ck_nivel_codigo` CHECK ((`codigo` in (_utf8mb4'A1',_utf8mb4'A2',_utf8mb4'B1',_utf8mb4'B2',_utf8mb4'C1',_utf8mb4'C2')))
) ENGINE=InnoDB AUTO_INCREMENT=7 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `nivel`
--

LOCK TABLES `nivel` WRITE;
/*!40000 ALTER TABLE `nivel` DISABLE KEYS */;
INSERT INTO `nivel` VALUES (1,'A1','Iniciante'),(2,'A2','Básico'),(3,'B1','Intermediário'),(4,'B2','Intermediário superior'),(5,'C1','Avançado'),(6,'C2','Proficiente');
/*!40000 ALTER TABLE `nivel` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `pagamento`
--

DROP TABLE IF EXISTS `pagamento`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `pagamento` (
  `id_pagamento` int NOT NULL AUTO_INCREMENT,
  `id_matricula` int NOT NULL,
  `valor` decimal(10,2) NOT NULL,
  `data_vencimento` date NOT NULL,
  `data_pagamento` date DEFAULT NULL,
  `status` varchar(10) COLLATE utf8mb4_unicode_ci NOT NULL DEFAULT 'pendente',
  PRIMARY KEY (`id_pagamento`),
  KEY `fk_pagamento_matricula` (`id_matricula`),
  CONSTRAINT `fk_pagamento_matricula` FOREIGN KEY (`id_matricula`) REFERENCES `matricula` (`id_matricula`) ON DELETE RESTRICT,
  CONSTRAINT `ck_pagamento_data` CHECK (((`status` = _utf8mb4'pago') = (`data_pagamento` is not null))),
  CONSTRAINT `ck_pagamento_status` CHECK ((`status` in (_utf8mb4'pendente',_utf8mb4'pago',_utf8mb4'atrasado',_utf8mb4'cancelado'))),
  CONSTRAINT `ck_pagamento_valor` CHECK ((`valor` > 0))
) ENGINE=InnoDB AUTO_INCREMENT=35 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `pagamento`
--

LOCK TABLES `pagamento` WRITE;
/*!40000 ALTER TABLE `pagamento` DISABLE KEYS */;
INSERT INTO `pagamento` VALUES (1,3,270.00,'2026-08-17','2026-08-13','pago'),(2,5,270.00,'2026-08-18','2026-08-14','pago'),(3,12,270.00,'2026-08-27','2026-08-23','pago'),(4,18,270.00,'2026-09-01',NULL,'atrasado'),(5,1,360.00,'2026-08-17','2026-08-13','pago'),(6,7,360.00,'2026-08-22','2026-08-18','pago'),(7,17,360.00,'2026-10-17',NULL,'pendente'),(8,6,360.00,'2026-08-18','2026-08-14','pago'),(9,13,360.00,'2026-08-29','2026-08-25','pago'),(10,2,270.00,'2026-08-19','2026-08-15','pago'),(11,8,270.00,'2026-08-22','2026-08-18','pago'),(12,9,270.00,'2026-08-25','2026-08-21','pago'),(13,4,270.00,'2026-09-08','2026-09-04','pago'),(14,10,270.00,'2026-08-25','2026-08-21','pago'),(15,19,270.00,'2026-07-08',NULL,'cancelado'),(16,11,360.00,'2026-08-27','2026-08-23','pago'),(17,14,360.00,'2026-08-29','2026-08-25','pago'),(18,15,180.00,'2026-09-09','2026-09-05','pago'),(19,16,180.00,'2026-09-09','2026-09-05','pago');
/*!40000 ALTER TABLE `pagamento` ENABLE KEYS */;
UNLOCK TABLES;
/*!50003 SET @saved_cs_client      = @@character_set_client */ ;
/*!50003 SET @saved_cs_results     = @@character_set_results */ ;
/*!50003 SET @saved_col_connection = @@collation_connection */ ;
/*!50003 SET character_set_client  = utf8mb4 */ ;
/*!50003 SET character_set_results = utf8mb4 */ ;
/*!50003 SET collation_connection  = utf8mb4_0900_ai_ci */ ;
/*!50003 SET @saved_sql_mode       = @@sql_mode */ ;
/*!50003 SET sql_mode              = 'ONLY_FULL_GROUP_BY,STRICT_TRANS_TABLES,NO_ZERO_IN_DATE,NO_ZERO_DATE,ERROR_FOR_DIVISION_BY_ZERO,NO_ENGINE_SUBSTITUTION' */ ;
DELIMITER ;;
/*!50003 CREATE*/ /*!50017 DEFINER=`root`@`localhost`*/ /*!50003 TRIGGER `trg_pagamento_ativa_matricula_au` AFTER UPDATE ON `pagamento` FOR EACH ROW BEGIN
  IF NEW.status = 'pago' AND OLD.status <> 'pago' THEN
    UPDATE matricula
       SET status = 'ativa'
     WHERE id_matricula = NEW.id_matricula
       AND status = 'pendente';
  END IF;
END */;;
DELIMITER ;
/*!50003 SET sql_mode              = @saved_sql_mode */ ;
/*!50003 SET character_set_client  = @saved_cs_client */ ;
/*!50003 SET character_set_results = @saved_cs_results */ ;
/*!50003 SET collation_connection  = @saved_col_connection */ ;
/*!50003 SET @saved_cs_client      = @@character_set_client */ ;
/*!50003 SET @saved_cs_results     = @@character_set_results */ ;
/*!50003 SET @saved_col_connection = @@collation_connection */ ;
/*!50003 SET character_set_client  = utf8mb4 */ ;
/*!50003 SET character_set_results = utf8mb4 */ ;
/*!50003 SET collation_connection  = utf8mb4_0900_ai_ci */ ;
/*!50003 SET @saved_sql_mode       = @@sql_mode */ ;
/*!50003 SET sql_mode              = 'ONLY_FULL_GROUP_BY,STRICT_TRANS_TABLES,NO_ZERO_IN_DATE,NO_ZERO_DATE,ERROR_FOR_DIVISION_BY_ZERO,NO_ENGINE_SUBSTITUTION' */ ;
DELIMITER ;;
/*!50003 CREATE*/ /*!50017 DEFINER=`root`@`localhost`*/ /*!50003 TRIGGER `trg_pagamento_audit_au` AFTER UPDATE ON `pagamento` FOR EACH ROW BEGIN
  IF NOT (OLD.valor           <=> NEW.valor
      AND OLD.status          <=> NEW.status
      AND OLD.data_vencimento <=> NEW.data_vencimento
      AND OLD.data_pagamento  <=> NEW.data_pagamento
      AND OLD.id_matricula    <=> NEW.id_matricula) THEN
    INSERT INTO log_auditoria (tabela, operacao, id_registro, detalhe)
    VALUES ('pagamento', 'ALTERACAO', OLD.id_pagamento,
            CONCAT('status: ', OLD.status, ' -> ', NEW.status,
                   '; valor: ', OLD.valor, ' -> ', NEW.valor,
                   '; vencimento: ', OLD.data_vencimento, ' -> ', NEW.data_vencimento,
                   '; pagamento: ', IFNULL(OLD.data_pagamento,'NULL'), ' -> ', IFNULL(NEW.data_pagamento,'NULL'),
                   '; matricula: ', OLD.id_matricula, ' -> ', NEW.id_matricula));
  END IF;
END */;;
DELIMITER ;
/*!50003 SET sql_mode              = @saved_sql_mode */ ;
/*!50003 SET character_set_client  = @saved_cs_client */ ;
/*!50003 SET character_set_results = @saved_cs_results */ ;
/*!50003 SET collation_connection  = @saved_col_connection */ ;
/*!50003 SET @saved_cs_client      = @@character_set_client */ ;
/*!50003 SET @saved_cs_results     = @@character_set_results */ ;
/*!50003 SET @saved_col_connection = @@collation_connection */ ;
/*!50003 SET character_set_client  = utf8mb4 */ ;
/*!50003 SET character_set_results = utf8mb4 */ ;
/*!50003 SET collation_connection  = utf8mb4_0900_ai_ci */ ;
/*!50003 SET @saved_sql_mode       = @@sql_mode */ ;
/*!50003 SET sql_mode              = 'ONLY_FULL_GROUP_BY,STRICT_TRANS_TABLES,NO_ZERO_IN_DATE,NO_ZERO_DATE,ERROR_FOR_DIVISION_BY_ZERO,NO_ENGINE_SUBSTITUTION' */ ;
DELIMITER ;;
/*!50003 CREATE*/ /*!50017 DEFINER=`root`@`localhost`*/ /*!50003 TRIGGER `trg_pagamento_audit_ad` AFTER DELETE ON `pagamento` FOR EACH ROW BEGIN
  INSERT INTO log_auditoria (tabela, operacao, id_registro, detalhe)
  VALUES ('pagamento', 'EXCLUSAO', OLD.id_pagamento,
          CONCAT('pagamento removido; matricula=', OLD.id_matricula,
                 '; valor=', OLD.valor, '; status=', OLD.status));
END */;;
DELIMITER ;
/*!50003 SET sql_mode              = @saved_sql_mode */ ;
/*!50003 SET character_set_client  = @saved_cs_client */ ;
/*!50003 SET character_set_results = @saved_cs_results */ ;
/*!50003 SET collation_connection  = @saved_col_connection */ ;

--
-- Table structure for table `pontuacao`
--

DROP TABLE IF EXISTS `pontuacao`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `pontuacao` (
  `id_pontuacao` int NOT NULL AUTO_INCREMENT,
  `id_aluno` int NOT NULL,
  `id_desafio` int NOT NULL,
  `pontos` decimal(5,2) NOT NULL,
  `data_registro` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id_pontuacao`),
  UNIQUE KEY `uk_pontuacao` (`id_aluno`,`id_desafio`),
  KEY `fk_pontuacao_desafio` (`id_desafio`),
  CONSTRAINT `fk_pontuacao_aluno` FOREIGN KEY (`id_aluno`) REFERENCES `usuario` (`id_usuario`) ON DELETE RESTRICT,
  CONSTRAINT `fk_pontuacao_desafio` FOREIGN KEY (`id_desafio`) REFERENCES `desafio` (`id_desafio`) ON DELETE CASCADE,
  CONSTRAINT `ck_pontuacao_pontos` CHECK ((`pontos` >= 0))
) ENGINE=InnoDB AUTO_INCREMENT=16 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `pontuacao`
--

LOCK TABLES `pontuacao` WRITE;
/*!40000 ALTER TABLE `pontuacao` DISABLE KEYS */;
INSERT INTO `pontuacao` VALUES (1,6,1,9.00,'2026-08-20 10:00:00'),(2,7,1,7.50,'2026-08-21 10:00:00'),(3,14,1,8.00,'2026-08-30 10:00:00'),(4,6,2,18.00,'2026-08-28 14:00:00'),(5,5,3,27.00,'2026-09-05 19:00:00'),(6,9,4,12.00,'2026-09-06 19:00:00'),(7,8,5,35.00,'2026-09-10 20:00:00'),(8,15,6,16.50,'2026-09-12 20:00:00'),(9,5,7,10.00,'2026-08-25 09:00:00'),(10,10,7,6.50,'2026-08-26 09:00:00'),(11,11,8,17.00,'2026-08-29 09:00:00'),(12,12,9,22.00,'2026-09-08 15:00:00'),(13,13,11,28.00,'2026-09-15 19:00:00'),(14,16,12,11.00,'2026-09-16 19:00:00');
/*!40000 ALTER TABLE `pontuacao` ENABLE KEYS */;
UNLOCK TABLES;
/*!50003 SET @saved_cs_client      = @@character_set_client */ ;
/*!50003 SET @saved_cs_results     = @@character_set_results */ ;
/*!50003 SET @saved_col_connection = @@collation_connection */ ;
/*!50003 SET character_set_client  = utf8mb4 */ ;
/*!50003 SET character_set_results = utf8mb4 */ ;
/*!50003 SET collation_connection  = utf8mb4_0900_ai_ci */ ;
/*!50003 SET @saved_sql_mode       = @@sql_mode */ ;
/*!50003 SET sql_mode              = 'ONLY_FULL_GROUP_BY,STRICT_TRANS_TABLES,NO_ZERO_IN_DATE,NO_ZERO_DATE,ERROR_FOR_DIVISION_BY_ZERO,NO_ENGINE_SUBSTITUTION' */ ;
DELIMITER ;;
/*!50003 CREATE*/ /*!50017 DEFINER=`root`@`localhost`*/ /*!50003 TRIGGER `trg_pontuacao_maxima_bi` BEFORE INSERT ON `pontuacao` FOR EACH ROW BEGIN
  DECLARE v_max INT;
  SELECT pontuacao_maxima INTO v_max FROM desafio WHERE id_desafio=NEW.id_desafio;
  IF NEW.pontos<0 OR NEW.pontos>v_max THEN SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Pontuação fora do limite do desafio'; END IF;
END */;;
DELIMITER ;
/*!50003 SET sql_mode              = @saved_sql_mode */ ;
/*!50003 SET character_set_client  = @saved_cs_client */ ;
/*!50003 SET character_set_results = @saved_cs_results */ ;
/*!50003 SET collation_connection  = @saved_col_connection */ ;
/*!50003 SET @saved_cs_client      = @@character_set_client */ ;
/*!50003 SET @saved_cs_results     = @@character_set_results */ ;
/*!50003 SET @saved_col_connection = @@collation_connection */ ;
/*!50003 SET character_set_client  = utf8mb4 */ ;
/*!50003 SET character_set_results = utf8mb4 */ ;
/*!50003 SET collation_connection  = utf8mb4_0900_ai_ci */ ;
/*!50003 SET @saved_sql_mode       = @@sql_mode */ ;
/*!50003 SET sql_mode              = 'ONLY_FULL_GROUP_BY,STRICT_TRANS_TABLES,NO_ZERO_IN_DATE,NO_ZERO_DATE,ERROR_FOR_DIVISION_BY_ZERO,NO_ENGINE_SUBSTITUTION' */ ;
DELIMITER ;;
/*!50003 CREATE*/ /*!50017 DEFINER=`root`@`localhost`*/ /*!50003 TRIGGER `trg_pontuacao_maxima_bu` BEFORE UPDATE ON `pontuacao` FOR EACH ROW BEGIN
  DECLARE v_max INT;
  SELECT pontuacao_maxima INTO v_max FROM desafio WHERE id_desafio=NEW.id_desafio;
  IF NEW.pontos<0 OR NEW.pontos>v_max THEN SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Pontuação fora do limite do desafio'; END IF;
END */;;
DELIMITER ;
/*!50003 SET sql_mode              = @saved_sql_mode */ ;
/*!50003 SET character_set_client  = @saved_cs_client */ ;
/*!50003 SET character_set_results = @saved_cs_results */ ;
/*!50003 SET collation_connection  = @saved_col_connection */ ;

--
-- Table structure for table `professor_idioma`
--

DROP TABLE IF EXISTS `professor_idioma`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `professor_idioma` (
  `id_professor` int NOT NULL,
  `id_idioma` int NOT NULL,
  PRIMARY KEY (`id_professor`,`id_idioma`),
  KEY `fk_pi_idioma` (`id_idioma`),
  CONSTRAINT `fk_pi_idioma` FOREIGN KEY (`id_idioma`) REFERENCES `idioma` (`id_idioma`) ON DELETE RESTRICT,
  CONSTRAINT `fk_pi_professor` FOREIGN KEY (`id_professor`) REFERENCES `usuario` (`id_usuario`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `professor_idioma`
--

LOCK TABLES `professor_idioma` WRITE;
/*!40000 ALTER TABLE `professor_idioma` DISABLE KEYS */;
INSERT INTO `professor_idioma` VALUES (2,1),(4,1),(3,2),(4,2);
/*!40000 ALTER TABLE `professor_idioma` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `turma`
--

DROP TABLE IF EXISTS `turma`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `turma` (
  `id_turma` int NOT NULL AUTO_INCREMENT,
  `nome` varchar(80) COLLATE utf8mb4_unicode_ci NOT NULL,
  `id_idioma` int NOT NULL,
  `id_nivel` int NOT NULL,
  `id_professor` int DEFAULT NULL,
  `carga_horaria` int NOT NULL,
  `vagas` int NOT NULL,
  PRIMARY KEY (`id_turma`),
  UNIQUE KEY `uk_turma_nome` (`nome`),
  KEY `fk_turma_nivel` (`id_nivel`),
  KEY `fk_turma_professor` (`id_professor`),
  KEY `idx_turma_idioma_nivel` (`id_idioma`,`id_nivel`,`nome`),
  CONSTRAINT `fk_turma_idioma` FOREIGN KEY (`id_idioma`) REFERENCES `idioma` (`id_idioma`) ON DELETE RESTRICT,
  CONSTRAINT `fk_turma_nivel` FOREIGN KEY (`id_nivel`) REFERENCES `nivel` (`id_nivel`) ON DELETE RESTRICT,
  CONSTRAINT `fk_turma_professor` FOREIGN KEY (`id_professor`) REFERENCES `usuario` (`id_usuario`) ON DELETE SET NULL,
  CONSTRAINT `ck_turma_carga` CHECK ((`carga_horaria` > 0)),
  CONSTRAINT `ck_turma_vagas` CHECK ((`vagas` > 0))
) ENGINE=InnoDB AUTO_INCREMENT=8 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `turma`
--

LOCK TABLES `turma` WRITE;
/*!40000 ALTER TABLE `turma` DISABLE KEYS */;
INSERT INTO `turma` VALUES (1,'Inglês A1 Manhã',1,1,2,60,15),(2,'Inglês B1 Noite',1,3,4,80,12),(3,'Inglês B2 Noite',1,4,2,80,10),(4,'Espanhol A1 Manhã',2,1,3,60,15),(5,'Espanhol A2 Tarde',2,2,4,60,12),(6,'Espanhol B1 Noite',2,3,3,80,10),(7,'Espanhol A1 Intensivo',2,1,3,40,2);
/*!40000 ALTER TABLE `turma` ENABLE KEYS */;
UNLOCK TABLES;
/*!50003 SET @saved_cs_client      = @@character_set_client */ ;
/*!50003 SET @saved_cs_results     = @@character_set_results */ ;
/*!50003 SET @saved_col_connection = @@collation_connection */ ;
/*!50003 SET character_set_client  = utf8mb4 */ ;
/*!50003 SET character_set_results = utf8mb4 */ ;
/*!50003 SET collation_connection  = utf8mb4_0900_ai_ci */ ;
/*!50003 SET @saved_sql_mode       = @@sql_mode */ ;
/*!50003 SET sql_mode              = 'ONLY_FULL_GROUP_BY,STRICT_TRANS_TABLES,NO_ZERO_IN_DATE,NO_ZERO_DATE,ERROR_FOR_DIVISION_BY_ZERO,NO_ENGINE_SUBSTITUTION' */ ;
DELIMITER ;;
/*!50003 CREATE*/ /*!50017 DEFINER=`root`@`localhost`*/ /*!50003 TRIGGER `trg_turma_professor_bi` BEFORE INSERT ON `turma` FOR EACH ROW BEGIN
  IF NEW.id_professor IS NOT NULL AND NOT EXISTS (
    SELECT 1 FROM usuario u JOIN professor_idioma pi ON pi.id_professor=u.id_usuario
    WHERE u.id_usuario=NEW.id_professor AND u.tipo='professor' AND u.ativo=1 AND pi.id_idioma=NEW.id_idioma
  ) THEN SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Professor não habilitado para o idioma da turma'; END IF;
END */;;
DELIMITER ;
/*!50003 SET sql_mode              = @saved_sql_mode */ ;
/*!50003 SET character_set_client  = @saved_cs_client */ ;
/*!50003 SET character_set_results = @saved_cs_results */ ;
/*!50003 SET collation_connection  = @saved_col_connection */ ;
/*!50003 SET @saved_cs_client      = @@character_set_client */ ;
/*!50003 SET @saved_cs_results     = @@character_set_results */ ;
/*!50003 SET @saved_col_connection = @@collation_connection */ ;
/*!50003 SET character_set_client  = utf8mb4 */ ;
/*!50003 SET character_set_results = utf8mb4 */ ;
/*!50003 SET collation_connection  = utf8mb4_0900_ai_ci */ ;
/*!50003 SET @saved_sql_mode       = @@sql_mode */ ;
/*!50003 SET sql_mode              = 'ONLY_FULL_GROUP_BY,STRICT_TRANS_TABLES,NO_ZERO_IN_DATE,NO_ZERO_DATE,ERROR_FOR_DIVISION_BY_ZERO,NO_ENGINE_SUBSTITUTION' */ ;
DELIMITER ;;
/*!50003 CREATE*/ /*!50017 DEFINER=`root`@`localhost`*/ /*!50003 TRIGGER `trg_turma_professor_bu` BEFORE UPDATE ON `turma` FOR EACH ROW BEGIN
  IF NEW.id_professor IS NOT NULL AND NOT EXISTS (
    SELECT 1 FROM usuario u JOIN professor_idioma pi ON pi.id_professor=u.id_usuario
    WHERE u.id_usuario=NEW.id_professor AND u.tipo='professor' AND u.ativo=1 AND pi.id_idioma=NEW.id_idioma
  ) THEN SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Professor não habilitado para o idioma da turma'; END IF;
END */;;
DELIMITER ;
/*!50003 SET sql_mode              = @saved_sql_mode */ ;
/*!50003 SET character_set_client  = @saved_cs_client */ ;
/*!50003 SET character_set_results = @saved_cs_results */ ;
/*!50003 SET collation_connection  = @saved_col_connection */ ;

--
-- Table structure for table `usuario`
--

DROP TABLE IF EXISTS `usuario`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `usuario` (
  `id_usuario` int NOT NULL AUTO_INCREMENT,
  `nome` varchar(100) COLLATE utf8mb4_unicode_ci NOT NULL,
  `email` varchar(120) COLLATE utf8mb4_unicode_ci NOT NULL,
  `senha_hash` varchar(255) COLLATE utf8mb4_unicode_ci NOT NULL,
  `tipo` varchar(15) COLLATE utf8mb4_unicode_ci NOT NULL,
  `ativo` tinyint(1) NOT NULL DEFAULT '1',
  `criado_em` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `anonimizado_em` datetime DEFAULT NULL,
  PRIMARY KEY (`id_usuario`),
  UNIQUE KEY `uk_usuario_email` (`email`),
  CONSTRAINT `ck_usuario_anon` CHECK (((`anonimizado_em` is null) or (`ativo` = false))),
  CONSTRAINT `ck_usuario_email` CHECK ((`email` like _utf8mb4'%_@_%')),
  CONSTRAINT `ck_usuario_tipo` CHECK ((`tipo` in (_utf8mb4'aluno',_utf8mb4'professor',_utf8mb4'administrador')))
) ENGINE=InnoDB AUTO_INCREMENT=20 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `usuario`
--

LOCK TABLES `usuario` WRITE;
/*!40000 ALTER TABLE `usuario` DISABLE KEYS */;
INSERT INTO `usuario` VALUES (1,'Administrador VirtuaLingua','admin@virtualingua.com.br','pbkdf2:sha256:1000000$c7G98yUIv8M5gY8D$9610bbaacf2dfb47a9a630c4993d9aea776e0beb6a9422824be3670687292d33','administrador',1,'2026-11-20 18:17:10',NULL),(2,'Carlos Mendes','carlos.mendes@virtualingua.com.br','pbkdf2:sha256:1000000$c7G98yUIv8M5gY8D$9610bbaacf2dfb47a9a630c4993d9aea776e0beb6a9422824be3670687292d33','professor',1,'2026-11-20 18:17:10',NULL),(3,'Marina Duarte','marina.duarte@virtualingua.com.br','pbkdf2:sha256:1000000$c7G98yUIv8M5gY8D$9610bbaacf2dfb47a9a630c4993d9aea776e0beb6a9422824be3670687292d33','professor',1,'2026-11-20 18:17:10',NULL),(4,'Beatriz Lacerda','beatriz.lacerda@virtualingua.com.br','pbkdf2:sha256:1000000$c7G98yUIv8M5gY8D$9610bbaacf2dfb47a9a630c4993d9aea776e0beb6a9422824be3670687292d33','professor',1,'2026-11-20 18:17:10',NULL),(5,'Ana Beatriz Costa','ana.costa@exemplo.com','pbkdf2:sha256:1000000$c7G98yUIv8M5gY8D$9610bbaacf2dfb47a9a630c4993d9aea776e0beb6a9422824be3670687292d33','aluno',1,'2026-11-20 18:17:10',NULL),(6,'Bruno Henrique Alves','bruno.alves@exemplo.com','pbkdf2:sha256:1000000$c7G98yUIv8M5gY8D$9610bbaacf2dfb47a9a630c4993d9aea776e0beb6a9422824be3670687292d33','aluno',1,'2026-11-20 18:17:10',NULL),(7,'Camila Ferreira','camila.ferreira@exemplo.com','pbkdf2:sha256:1000000$c7G98yUIv8M5gY8D$9610bbaacf2dfb47a9a630c4993d9aea776e0beb6a9422824be3670687292d33','aluno',1,'2026-11-20 18:17:10',NULL),(8,'Daniel Oliveira','daniel.oliveira@exemplo.com','pbkdf2:sha256:1000000$c7G98yUIv8M5gY8D$9610bbaacf2dfb47a9a630c4993d9aea776e0beb6a9422824be3670687292d33','aluno',1,'2026-11-20 18:17:10',NULL),(9,'Eduarda Nascimento','eduarda.nascimento@exemplo.com','pbkdf2:sha256:1000000$c7G98yUIv8M5gY8D$9610bbaacf2dfb47a9a630c4993d9aea776e0beb6a9422824be3670687292d33','aluno',1,'2026-11-20 18:17:10',NULL),(10,'Felipe Rocha','felipe.rocha@exemplo.com','pbkdf2:sha256:1000000$c7G98yUIv8M5gY8D$9610bbaacf2dfb47a9a630c4993d9aea776e0beb6a9422824be3670687292d33','aluno',1,'2026-11-20 18:17:10',NULL),(11,'Gabriela Martins','gabriela.martins@exemplo.com','pbkdf2:sha256:1000000$c7G98yUIv8M5gY8D$9610bbaacf2dfb47a9a630c4993d9aea776e0beb6a9422824be3670687292d33','aluno',1,'2026-11-20 18:17:10',NULL),(12,'Heitor Souza','heitor.souza@exemplo.com','pbkdf2:sha256:1000000$c7G98yUIv8M5gY8D$9610bbaacf2dfb47a9a630c4993d9aea776e0beb6a9422824be3670687292d33','aluno',1,'2026-11-20 18:17:10',NULL),(13,'Isabela Ribeiro','isabela.ribeiro@exemplo.com','pbkdf2:sha256:1000000$c7G98yUIv8M5gY8D$9610bbaacf2dfb47a9a630c4993d9aea776e0beb6a9422824be3670687292d33','aluno',1,'2026-11-20 18:17:10',NULL),(14,'João Pedro Lima','joao.lima@exemplo.com','pbkdf2:sha256:1000000$c7G98yUIv8M5gY8D$9610bbaacf2dfb47a9a630c4993d9aea776e0beb6a9422824be3670687292d33','aluno',1,'2026-11-20 18:17:10',NULL),(15,'Karen Barbosa','karen.barbosa@exemplo.com','pbkdf2:sha256:1000000$c7G98yUIv8M5gY8D$9610bbaacf2dfb47a9a630c4993d9aea776e0beb6a9422824be3670687292d33','aluno',1,'2026-11-20 18:17:10',NULL),(16,'Leonardo Pereira','leonardo.pereira@exemplo.com','pbkdf2:sha256:1000000$c7G98yUIv8M5gY8D$9610bbaacf2dfb47a9a630c4993d9aea776e0beb6a9422824be3670687292d33','aluno',1,'2026-11-20 18:17:10',NULL),(17,'Mariana Gomes','mariana.gomes@exemplo.com','pbkdf2:sha256:1000000$c7G98yUIv8M5gY8D$9610bbaacf2dfb47a9a630c4993d9aea776e0beb6a9422824be3670687292d33','aluno',1,'2026-11-20 18:17:10',NULL),(18,'Nicolas Araújo','nicolas.araujo@exemplo.com','pbkdf2:sha256:1000000$c7G98yUIv8M5gY8D$9610bbaacf2dfb47a9a630c4993d9aea776e0beb6a9422824be3670687292d33','aluno',1,'2026-11-20 18:17:10',NULL),(19,'Olívia Teixeira','olivia.teixeira@exemplo.com','pbkdf2:sha256:1000000$c7G98yUIv8M5gY8D$9610bbaacf2dfb47a9a630c4993d9aea776e0beb6a9422824be3670687292d33','aluno',1,'2026-11-20 18:17:10',NULL);
/*!40000 ALTER TABLE `usuario` ENABLE KEYS */;
UNLOCK TABLES;
/*!50003 SET @saved_cs_client      = @@character_set_client */ ;
/*!50003 SET @saved_cs_results     = @@character_set_results */ ;
/*!50003 SET @saved_col_connection = @@collation_connection */ ;
/*!50003 SET character_set_client  = utf8mb4 */ ;
/*!50003 SET character_set_results = utf8mb4 */ ;
/*!50003 SET collation_connection  = utf8mb4_0900_ai_ci */ ;
/*!50003 SET @saved_sql_mode       = @@sql_mode */ ;
/*!50003 SET sql_mode              = 'ONLY_FULL_GROUP_BY,STRICT_TRANS_TABLES,NO_ZERO_IN_DATE,NO_ZERO_DATE,ERROR_FOR_DIVISION_BY_ZERO,NO_ENGINE_SUBSTITUTION' */ ;
DELIMITER ;;
/*!50003 CREATE*/ /*!50017 DEFINER=`root`@`localhost`*/ /*!50003 TRIGGER `trg_usuario_audit_au` AFTER UPDATE ON `usuario` FOR EACH ROW BEGIN
  IF OLD.anonimizado_em IS NULL AND NEW.anonimizado_em IS NOT NULL THEN
    INSERT INTO log_auditoria (tabela, operacao, id_registro, detalhe)
    VALUES ('usuario', 'EXCLUSAO_CONTA', OLD.id_usuario,
            CONCAT('conta anonimizada; tipo=', OLD.tipo));
  END IF;
END */;;
DELIMITER ;
/*!50003 SET sql_mode              = @saved_sql_mode */ ;
/*!50003 SET character_set_client  = @saved_cs_client */ ;
/*!50003 SET character_set_results = @saved_cs_results */ ;
/*!50003 SET collation_connection  = @saved_col_connection */ ;
/*!50003 SET @saved_cs_client      = @@character_set_client */ ;
/*!50003 SET @saved_cs_results     = @@character_set_results */ ;
/*!50003 SET @saved_col_connection = @@collation_connection */ ;
/*!50003 SET character_set_client  = utf8mb4 */ ;
/*!50003 SET character_set_results = utf8mb4 */ ;
/*!50003 SET collation_connection  = utf8mb4_0900_ai_ci */ ;
/*!50003 SET @saved_sql_mode       = @@sql_mode */ ;
/*!50003 SET sql_mode              = 'ONLY_FULL_GROUP_BY,STRICT_TRANS_TABLES,NO_ZERO_IN_DATE,NO_ZERO_DATE,ERROR_FOR_DIVISION_BY_ZERO,NO_ENGINE_SUBSTITUTION' */ ;
DELIMITER ;;
/*!50003 CREATE*/ /*!50017 DEFINER=`root`@`localhost`*/ /*!50003 TRIGGER `trg_usuario_audit_ad` AFTER DELETE ON `usuario` FOR EACH ROW BEGIN
  INSERT INTO log_auditoria (tabela, operacao, id_registro, detalhe)
  VALUES ('usuario', 'EXCLUSAO_FISICA', OLD.id_usuario,
          CONCAT('usuario removido; tipo=', OLD.tipo));
END */;;
DELIMITER ;
/*!50003 SET sql_mode              = @saved_sql_mode */ ;
/*!50003 SET character_set_client  = @saved_cs_client */ ;
/*!50003 SET character_set_results = @saved_cs_results */ ;
/*!50003 SET collation_connection  = @saved_col_connection */ ;

--
-- Temporary view structure for view `vw_alunos_por_idioma`
--

DROP TABLE IF EXISTS `vw_alunos_por_idioma`;
/*!50001 DROP VIEW IF EXISTS `vw_alunos_por_idioma`*/;
SET @saved_cs_client     = @@character_set_client;
/*!50503 SET character_set_client = utf8mb4 */;
/*!50001 CREATE VIEW `vw_alunos_por_idioma` AS SELECT 
 1 AS `id_idioma`,
 1 AS `idioma`,
 1 AS `id_aluno`,
 1 AS `aluno`,
 1 AS `email`,
 1 AS `turmas_matriculadas`,
 1 AS `turmas_ativas`,
 1 AS `primeira_matricula`*/;
SET character_set_client = @saved_cs_client;

--
-- Temporary view structure for view `vw_pagamentos_pendentes`
--

DROP TABLE IF EXISTS `vw_pagamentos_pendentes`;
/*!50001 DROP VIEW IF EXISTS `vw_pagamentos_pendentes`*/;
SET @saved_cs_client     = @@character_set_client;
/*!50503 SET character_set_client = utf8mb4 */;
/*!50001 CREATE VIEW `vw_pagamentos_pendentes` AS SELECT 
 1 AS `id_pagamento`,
 1 AS `id_matricula`,
 1 AS `id_aluno`,
 1 AS `aluno`,
 1 AS `email`,
 1 AS `turma`,
 1 AS `idioma`,
 1 AS `valor`,
 1 AS `data_vencimento`,
 1 AS `status`,
 1 AS `dias_em_atraso`,
 1 AS `situacao`*/;
SET character_set_client = @saved_cs_client;

--
-- Temporary view structure for view `vw_ranking_por_idioma`
--

DROP TABLE IF EXISTS `vw_ranking_por_idioma`;
/*!50001 DROP VIEW IF EXISTS `vw_ranking_por_idioma`*/;
SET @saved_cs_client     = @@character_set_client;
/*!50503 SET character_set_client = utf8mb4 */;
/*!50001 CREATE VIEW `vw_ranking_por_idioma` AS SELECT 
 1 AS `id_idioma`,
 1 AS `idioma`,
 1 AS `id_aluno`,
 1 AS `aluno`,
 1 AS `total_pontos`,
 1 AS `desafios_realizados`,
 1 AS `posicao`*/;
SET character_set_client = @saved_cs_client;

--
-- Temporary view structure for view `vw_turmas_por_idioma`
--

DROP TABLE IF EXISTS `vw_turmas_por_idioma`;
/*!50001 DROP VIEW IF EXISTS `vw_turmas_por_idioma`*/;
SET @saved_cs_client     = @@character_set_client;
/*!50503 SET character_set_client = utf8mb4 */;
/*!50001 CREATE VIEW `vw_turmas_por_idioma` AS SELECT 
 1 AS `id_turma`,
 1 AS `turma`,
 1 AS `id_idioma`,
 1 AS `idioma`,
 1 AS `nivel`,
 1 AS `nivel_descricao`,
 1 AS `professor`,
 1 AS `carga_horaria`,
 1 AS `vagas`,
 1 AS `vagas_ocupadas`,
 1 AS `vagas_disponiveis`,
 1 AS `situacao`*/;
SET character_set_client = @saved_cs_client;

--
-- Dumping events for database 'virtualingua'
--

--
-- Dumping routines for database 'virtualingua'
--
/*!50003 DROP FUNCTION IF EXISTS `fn_media_aluno` */;
/*!50003 SET @saved_cs_client      = @@character_set_client */ ;
/*!50003 SET @saved_cs_results     = @@character_set_results */ ;
/*!50003 SET @saved_col_connection = @@collation_connection */ ;
/*!50003 SET character_set_client  = utf8mb4 */ ;
/*!50003 SET character_set_results = utf8mb4 */ ;
/*!50003 SET collation_connection  = utf8mb4_0900_ai_ci */ ;
/*!50003 SET @saved_sql_mode       = @@sql_mode */ ;
/*!50003 SET sql_mode              = 'ONLY_FULL_GROUP_BY,STRICT_TRANS_TABLES,NO_ZERO_IN_DATE,NO_ZERO_DATE,ERROR_FOR_DIVISION_BY_ZERO,NO_ENGINE_SUBSTITUTION' */ ;
DELIMITER ;;
CREATE DEFINER=`root`@`localhost` FUNCTION `fn_media_aluno`(p_id_aluno INT) RETURNS decimal(5,2)
    READS SQL DATA
BEGIN
    DECLARE v_media DECIMAL(5,2);
    SELECT ROUND(AVG(p.pontos / d.pontuacao_maxima * 100), 2) INTO v_media
      FROM pontuacao p JOIN desafio d ON d.id_desafio = p.id_desafio
     WHERE p.id_aluno = p_id_aluno;
    RETURN v_media;
END ;;
DELIMITER ;
/*!50003 SET sql_mode              = @saved_sql_mode */ ;
/*!50003 SET character_set_client  = @saved_cs_client */ ;
/*!50003 SET character_set_results = @saved_cs_results */ ;
/*!50003 SET collation_connection  = @saved_col_connection */ ;
/*!50003 DROP PROCEDURE IF EXISTS `sp_excluir_conta` */;
/*!50003 SET @saved_cs_client      = @@character_set_client */ ;
/*!50003 SET @saved_cs_results     = @@character_set_results */ ;
/*!50003 SET @saved_col_connection = @@collation_connection */ ;
/*!50003 SET character_set_client  = utf8mb4 */ ;
/*!50003 SET character_set_results = utf8mb4 */ ;
/*!50003 SET collation_connection  = utf8mb4_0900_ai_ci */ ;
/*!50003 SET @saved_sql_mode       = @@sql_mode */ ;
/*!50003 SET sql_mode              = 'ONLY_FULL_GROUP_BY,STRICT_TRANS_TABLES,NO_ZERO_IN_DATE,NO_ZERO_DATE,ERROR_FOR_DIVISION_BY_ZERO,NO_ENGINE_SUBSTITUTION' */ ;
DELIMITER ;;
CREATE DEFINER=`root`@`localhost` PROCEDURE `sp_excluir_conta`(IN p_id_usuario INT)
BEGIN
    DECLARE v_tipo VARCHAR(15) DEFAULT NULL;

    -- Qualquer erro desfaz tudo e e repassado a quem chamou
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        RESIGNAL;
    END;

    -- START TRANSACTION confirma (COMMIT) qualquer transacao que
    -- ja estivesse aberta na conexao. Chame a procedure fora de uma transacao.
    START TRANSACTION;

    -- Trava a linha do usuario e recusa se nao existir ou ja foi anonimizado
    SELECT tipo INTO v_tipo
      FROM usuario
     WHERE id_usuario = p_id_usuario
       AND anonimizado_em IS NULL
       FOR UPDATE;

    IF v_tipo IS NULL THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Usuario inexistente ou ja anonimizado';
    END IF;

    -- Matriculas ainda em aberto sao canceladas (e os pagamentos pendentes delas)
    UPDATE pagamento p
      JOIN matricula m ON m.id_matricula = p.id_matricula
       SET p.status = 'cancelado'
     WHERE m.id_aluno = p_id_usuario
       AND m.status IN ('pendente','ativa')
       AND p.status IN ('pendente','atrasado');

    UPDATE matricula
       SET status = 'cancelada'
     WHERE id_aluno = p_id_usuario
       AND status IN ('pendente','ativa');

    -- Professor: libera turmas e conteudos (ficam sem responsavel) e habilitacoes
    UPDATE turma    SET id_professor = NULL WHERE id_professor = p_id_usuario;
    UPDATE conteudo SET id_professor = NULL WHERE id_professor = p_id_usuario;
    DELETE FROM professor_idioma WHERE id_professor = p_id_usuario;

    -- Anonimizacao dos dados pessoais
    UPDATE usuario
       SET nome           = 'Usuario removido',
           email          = CONCAT('removido+', id_usuario, '@anonimo.invalid'),
           senha_hash     = '!',
           ativo          = FALSE,
           anonimizado_em = NOW()
     WHERE id_usuario = p_id_usuario;

    INSERT INTO log_auditoria (tabela, operacao, id_registro, detalhe)
    VALUES ('usuario', 'ANONIMIZACAO', p_id_usuario,
            CONCAT('RF10 - exclusao de conta (', v_tipo, ')'));

    COMMIT;
END ;;
DELIMITER ;
/*!50003 SET sql_mode              = @saved_sql_mode */ ;
/*!50003 SET character_set_client  = @saved_cs_client */ ;
/*!50003 SET character_set_results = @saved_cs_results */ ;
/*!50003 SET collation_connection  = @saved_col_connection */ ;
/*!50003 DROP PROCEDURE IF EXISTS `sp_matricular_aluno` */;
/*!50003 SET @saved_cs_client      = @@character_set_client */ ;
/*!50003 SET @saved_cs_results     = @@character_set_results */ ;
/*!50003 SET @saved_col_connection = @@collation_connection */ ;
/*!50003 SET character_set_client  = utf8mb4 */ ;
/*!50003 SET character_set_results = utf8mb4 */ ;
/*!50003 SET collation_connection  = utf8mb4_0900_ai_ci */ ;
/*!50003 SET @saved_sql_mode       = @@sql_mode */ ;
/*!50003 SET sql_mode              = 'ONLY_FULL_GROUP_BY,STRICT_TRANS_TABLES,NO_ZERO_IN_DATE,NO_ZERO_DATE,ERROR_FOR_DIVISION_BY_ZERO,NO_ENGINE_SUBSTITUTION' */ ;
DELIMITER ;;
CREATE DEFINER=`root`@`localhost` PROCEDURE `sp_matricular_aluno`(
    IN  p_id_aluno        INT,
    IN  p_id_turma        INT,
    IN  p_valor           DECIMAL(10,2),
    IN  p_data_vencimento DATE,
    OUT p_id_matricula    INT,
    OUT p_id_pagamento    INT
)
BEGIN
    DECLARE v_vagas     INT          DEFAULT NULL;
    DECLARE v_ocupadas  INT          DEFAULT 0;
    DECLARE v_tipo      VARCHAR(15)  DEFAULT NULL;
    DECLARE v_ativo     BOOLEAN      DEFAULT NULL;
    DECLARE v_mat_id    INT          DEFAULT NULL;
    DECLARE v_mat_st    VARCHAR(10)  DEFAULT NULL;

    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        RESIGNAL;
    END;

    SET p_id_matricula = NULL;
    SET p_id_pagamento = NULL;

    START TRANSACTION;

    SELECT vagas INTO v_vagas
      FROM turma WHERE id_turma = p_id_turma FOR UPDATE;
    IF v_vagas IS NULL THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Turma inexistente';
    END IF;

    SELECT tipo, ativo INTO v_tipo, v_ativo
      FROM usuario WHERE id_usuario = p_id_aluno FOR UPDATE;
    IF v_tipo IS NULL OR v_tipo <> 'aluno' OR v_ativo = 0 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Matrícula exige usuário ativo do tipo aluno';
    END IF;

    IF p_valor IS NULL OR p_valor <= 0 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Valor do pagamento deve ser positivo';
    END IF;
    IF p_data_vencimento IS NULL THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Data de vencimento é obrigatória';
    END IF;

    SELECT id_matricula, status INTO v_mat_id, v_mat_st
      FROM matricula
     WHERE id_aluno = p_id_aluno AND id_turma = p_id_turma
       FOR UPDATE;
    IF v_mat_id IS NOT NULL AND v_mat_st <> 'cancelada' THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Aluno já matriculado nesta turma';
    END IF;

    SELECT COUNT(*) INTO v_ocupadas
      FROM matricula
     WHERE id_turma = p_id_turma AND status IN ('pendente','ativa');
    IF v_ocupadas >= v_vagas THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Turma sem vagas disponíveis';
    END IF;

    IF v_mat_id IS NULL THEN
        INSERT INTO matricula (id_aluno, id_turma, status)
        VALUES (p_id_aluno, p_id_turma, 'pendente');
        SET v_mat_id = LAST_INSERT_ID();
    ELSE
        UPDATE matricula SET status = 'pendente', data_matricula = CURDATE()
         WHERE id_matricula = v_mat_id;
    END IF;

    INSERT INTO pagamento (id_matricula, valor, data_vencimento, status)
    VALUES (v_mat_id, p_valor, p_data_vencimento, 'pendente');

    SET p_id_matricula = v_mat_id;
    SET p_id_pagamento = LAST_INSERT_ID();

    COMMIT;
END ;;
DELIMITER ;
/*!50003 SET sql_mode              = @saved_sql_mode */ ;
/*!50003 SET character_set_client  = @saved_cs_client */ ;
/*!50003 SET character_set_results = @saved_cs_results */ ;
/*!50003 SET collation_connection  = @saved_col_connection */ ;
/*!50003 DROP PROCEDURE IF EXISTS `sp_matricular_lote` */;
/*!50003 SET @saved_cs_client      = @@character_set_client */ ;
/*!50003 SET @saved_cs_results     = @@character_set_results */ ;
/*!50003 SET @saved_col_connection = @@collation_connection */ ;
/*!50003 SET character_set_client  = utf8mb4 */ ;
/*!50003 SET character_set_results = utf8mb4 */ ;
/*!50003 SET collation_connection  = utf8mb4_0900_ai_ci */ ;
/*!50003 SET @saved_sql_mode       = @@sql_mode */ ;
/*!50003 SET sql_mode              = 'ONLY_FULL_GROUP_BY,STRICT_TRANS_TABLES,NO_ZERO_IN_DATE,NO_ZERO_DATE,ERROR_FOR_DIVISION_BY_ZERO,NO_ENGINE_SUBSTITUTION' */ ;
DELIMITER ;;
CREATE DEFINER=`root`@`localhost` PROCEDURE `sp_matricular_lote`(
    IN p_id_turma        INT,
    IN p_ids_alunos      JSON,
    IN p_valor           DECIMAL(10,2),
    IN p_data_vencimento DATE
)
BEGIN
    DECLARE v_i      INT DEFAULT 0;
    DECLARE v_n      INT DEFAULT 0;
    DECLARE v_aluno  INT;
    DECLARE v_mat    INT;
    DECLARE v_msg    TEXT;

    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        RESIGNAL;
    END;

    IF p_ids_alunos IS NULL OR JSON_TYPE(p_ids_alunos) <> 'ARRAY' THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Informe os alunos como array JSON, ex.: [7,8,9]';
    END IF;

    DROP TEMPORARY TABLE IF EXISTS tmp_lote_resultado;
    CREATE TEMPORARY TABLE tmp_lote_resultado (
        id_aluno  INT,
        resultado VARCHAR(10),
        mensagem  VARCHAR(255)
    ) ENGINE = MEMORY;   -- MEMORY não participa do rollback: o log do lote sobrevive

    SET v_n = JSON_LENGTH(p_ids_alunos);

    START TRANSACTION;
    -- trava a turma uma vez para o lote todo
    SELECT id_turma INTO v_mat FROM turma WHERE id_turma = p_id_turma FOR UPDATE;
    IF v_mat IS NULL THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Turma inexistente';
    END IF;

    WHILE v_i < v_n DO
        SET v_aluno = JSON_EXTRACT(p_ids_alunos, CONCAT('$[', v_i, ']'));
        SET v_mat = NULL;

        BEGIN
            -- erro neste aluno: desfaz SÓ o aluno e segue o lote
            DECLARE EXIT HANDLER FOR SQLEXCEPTION
            BEGIN
                GET DIAGNOSTICS CONDITION 1 v_msg = MESSAGE_TEXT;
                ROLLBACK TO SAVEPOINT sp_item;
                INSERT INTO tmp_lote_resultado VALUES (v_aluno, 'ERRO', v_msg);
            END;

            SAVEPOINT sp_item;

            INSERT INTO matricula (id_aluno, id_turma, status)
            VALUES (v_aluno, p_id_turma, 'pendente');
            SET v_mat = LAST_INSERT_ID();

            INSERT INTO pagamento (id_matricula, valor, data_vencimento, status)
            VALUES (v_mat, p_valor, p_data_vencimento, 'pendente');

            RELEASE SAVEPOINT sp_item;
            INSERT INTO tmp_lote_resultado VALUES (v_aluno, 'OK', CONCAT('matrícula ', v_mat));
        END;

        SET v_i = v_i + 1;
    END WHILE;

    COMMIT;
    SELECT * FROM tmp_lote_resultado;
END ;;
DELIMITER ;
/*!50003 SET sql_mode              = @saved_sql_mode */ ;
/*!50003 SET character_set_client  = @saved_cs_client */ ;
/*!50003 SET character_set_results = @saved_cs_results */ ;
/*!50003 SET collation_connection  = @saved_col_connection */ ;
/*!50003 DROP PROCEDURE IF EXISTS `sp_registrar_pontuacao` */;
/*!50003 SET @saved_cs_client      = @@character_set_client */ ;
/*!50003 SET @saved_cs_results     = @@character_set_results */ ;
/*!50003 SET @saved_col_connection = @@collation_connection */ ;
/*!50003 SET character_set_client  = utf8mb4 */ ;
/*!50003 SET character_set_results = utf8mb4 */ ;
/*!50003 SET collation_connection  = utf8mb4_0900_ai_ci */ ;
/*!50003 SET @saved_sql_mode       = @@sql_mode */ ;
/*!50003 SET sql_mode              = 'ONLY_FULL_GROUP_BY,STRICT_TRANS_TABLES,NO_ZERO_IN_DATE,NO_ZERO_DATE,ERROR_FOR_DIVISION_BY_ZERO,NO_ENGINE_SUBSTITUTION' */ ;
DELIMITER ;;
CREATE DEFINER=`root`@`localhost` PROCEDURE `sp_registrar_pontuacao`(
    IN  p_id_aluno   INT,
    IN  p_id_desafio INT,
    IN  p_pontos     DECIMAL(5,2),
    OUT p_resultado  VARCHAR(10)
)
BEGIN
    DECLARE v_max      INT          DEFAULT NULL;
    DECLARE v_idioma   INT          DEFAULT NULL;
    DECLARE v_tipo     VARCHAR(15)  DEFAULT NULL;
    DECLARE v_ativo    BOOLEAN      DEFAULT NULL;
    DECLARE v_matric   INT          DEFAULT 0;
    DECLARE v_pont_id  INT          DEFAULT NULL;
    DECLARE v_atual    DECIMAL(5,2) DEFAULT NULL;

    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        RESIGNAL;
    END;

    SET p_resultado = NULL;

    START TRANSACTION;

    SELECT tipo, ativo INTO v_tipo, v_ativo
      FROM usuario WHERE id_usuario = p_id_aluno;
    IF v_tipo IS NULL OR v_tipo <> 'aluno' OR v_ativo = 0 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Pontuação exige usuário ativo do tipo aluno';
    END IF;

    SELECT d.pontuacao_maxima, c.id_idioma INTO v_max, v_idioma
      FROM desafio d JOIN conteudo c ON c.id_conteudo = d.id_conteudo
     WHERE d.id_desafio = p_id_desafio;
    IF v_max IS NULL THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Desafio inexistente';
    END IF;

    IF p_pontos IS NULL OR p_pontos < 0 OR p_pontos > v_max THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Pontuação fora do limite do desafio';
    END IF;

    SELECT COUNT(*) INTO v_matric
      FROM matricula m JOIN turma t ON t.id_turma = m.id_turma
     WHERE m.id_aluno = p_id_aluno
       AND t.id_idioma = v_idioma
       AND m.status IN ('ativa','concluida');
    IF v_matric = 0 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Aluno sem matrícula ativa no idioma do desafio';
    END IF;

    -- trava a pontuação existente (se houver) para evitar corrida
    SELECT id_pontuacao, pontos INTO v_pont_id, v_atual
      FROM pontuacao
     WHERE id_aluno = p_id_aluno AND id_desafio = p_id_desafio
       FOR UPDATE;

    IF v_pont_id IS NULL THEN
        INSERT INTO pontuacao (id_aluno, id_desafio, pontos)
        VALUES (p_id_aluno, p_id_desafio, p_pontos);
        SET p_resultado = 'INSERIDA';
    ELSEIF p_pontos > v_atual THEN
        UPDATE pontuacao SET pontos = p_pontos, data_registro = NOW()
         WHERE id_pontuacao = v_pont_id;
        SET p_resultado = 'ATUALIZADA';
    ELSE
        SET p_resultado = 'MANTIDA';
    END IF;

    COMMIT;
END ;;
DELIMITER ;
/*!50003 SET sql_mode              = @saved_sql_mode */ ;
/*!50003 SET character_set_client  = @saved_cs_client */ ;
/*!50003 SET character_set_results = @saved_cs_results */ ;
/*!50003 SET collation_connection  = @saved_col_connection */ ;

--
-- Final view structure for view `vw_alunos_por_idioma`
--

/*!50001 DROP VIEW IF EXISTS `vw_alunos_por_idioma`*/;
/*!50001 SET @saved_cs_client          = @@character_set_client */;
/*!50001 SET @saved_cs_results         = @@character_set_results */;
/*!50001 SET @saved_col_connection     = @@collation_connection */;
/*!50001 SET character_set_client      = utf8mb4 */;
/*!50001 SET character_set_results     = utf8mb4 */;
/*!50001 SET collation_connection      = utf8mb4_0900_ai_ci */;
/*!50001 CREATE ALGORITHM=UNDEFINED */
/*!50013 DEFINER=`root`@`localhost` SQL SECURITY DEFINER */
/*!50001 VIEW `vw_alunos_por_idioma` AS select `i`.`id_idioma` AS `id_idioma`,`i`.`nome` AS `idioma`,`u`.`id_usuario` AS `id_aluno`,`u`.`nome` AS `aluno`,`u`.`email` AS `email`,count(0) AS `turmas_matriculadas`,sum((case when (`m`.`status` = 'ativa') then 1 else 0 end)) AS `turmas_ativas`,min(`m`.`data_matricula`) AS `primeira_matricula` from (((`matricula` `m` join `usuario` `u` on((`u`.`id_usuario` = `m`.`id_aluno`))) join `turma` `t` on((`t`.`id_turma` = `m`.`id_turma`))) join `idioma` `i` on((`i`.`id_idioma` = `t`.`id_idioma`))) where ((`m`.`status` in ('pendente','ativa')) and (`u`.`tipo` = 'aluno') and (`u`.`ativo` = true)) group by `i`.`id_idioma`,`i`.`nome`,`u`.`id_usuario`,`u`.`nome`,`u`.`email` */;
/*!50001 SET character_set_client      = @saved_cs_client */;
/*!50001 SET character_set_results     = @saved_cs_results */;
/*!50001 SET collation_connection      = @saved_col_connection */;

--
-- Final view structure for view `vw_pagamentos_pendentes`
--

/*!50001 DROP VIEW IF EXISTS `vw_pagamentos_pendentes`*/;
/*!50001 SET @saved_cs_client          = @@character_set_client */;
/*!50001 SET @saved_cs_results         = @@character_set_results */;
/*!50001 SET @saved_col_connection     = @@collation_connection */;
/*!50001 SET character_set_client      = utf8mb4 */;
/*!50001 SET character_set_results     = utf8mb4 */;
/*!50001 SET collation_connection      = utf8mb4_0900_ai_ci */;
/*!50001 CREATE ALGORITHM=UNDEFINED */
/*!50013 DEFINER=`root`@`localhost` SQL SECURITY DEFINER */
/*!50001 VIEW `vw_pagamentos_pendentes` AS select `pg`.`id_pagamento` AS `id_pagamento`,`m`.`id_matricula` AS `id_matricula`,`u`.`id_usuario` AS `id_aluno`,`u`.`nome` AS `aluno`,`u`.`email` AS `email`,`t`.`nome` AS `turma`,`i`.`nome` AS `idioma`,`pg`.`valor` AS `valor`,`pg`.`data_vencimento` AS `data_vencimento`,`pg`.`status` AS `status`,(case when (`pg`.`data_vencimento` < curdate()) then (to_days(curdate()) - to_days(`pg`.`data_vencimento`)) else 0 end) AS `dias_em_atraso`,(case when ((`pg`.`status` = 'atrasado') or (`pg`.`data_vencimento` < curdate())) then 'vencido' else 'a vencer' end) AS `situacao` from ((((`pagamento` `pg` join `matricula` `m` on((`m`.`id_matricula` = `pg`.`id_matricula`))) join `usuario` `u` on((`u`.`id_usuario` = `m`.`id_aluno`))) join `turma` `t` on((`t`.`id_turma` = `m`.`id_turma`))) join `idioma` `i` on((`i`.`id_idioma` = `t`.`id_idioma`))) where (`pg`.`status` in ('pendente','atrasado')) */;
/*!50001 SET character_set_client      = @saved_cs_client */;
/*!50001 SET character_set_results     = @saved_cs_results */;
/*!50001 SET collation_connection      = @saved_col_connection */;

--
-- Final view structure for view `vw_ranking_por_idioma`
--

/*!50001 DROP VIEW IF EXISTS `vw_ranking_por_idioma`*/;
/*!50001 SET @saved_cs_client          = @@character_set_client */;
/*!50001 SET @saved_cs_results         = @@character_set_results */;
/*!50001 SET @saved_col_connection     = @@collation_connection */;
/*!50001 SET character_set_client      = utf8mb4 */;
/*!50001 SET character_set_results     = utf8mb4 */;
/*!50001 SET collation_connection      = utf8mb4_0900_ai_ci */;
/*!50001 CREATE ALGORITHM=UNDEFINED */
/*!50013 DEFINER=`root`@`localhost` SQL SECURITY DEFINER */
/*!50001 VIEW `vw_ranking_por_idioma` AS select `i`.`id_idioma` AS `id_idioma`,`i`.`nome` AS `idioma`,`u`.`id_usuario` AS `id_aluno`,`u`.`nome` AS `aluno`,sum(`p`.`pontos`) AS `total_pontos`,count(0) AS `desafios_realizados`,rank() OVER (PARTITION BY `i`.`id_idioma` ORDER BY sum(`p`.`pontos`) desc )  AS `posicao` from ((((`pontuacao` `p` join `desafio` `d` on((`d`.`id_desafio` = `p`.`id_desafio`))) join `conteudo` `c` on((`c`.`id_conteudo` = `d`.`id_conteudo`))) join `idioma` `i` on((`i`.`id_idioma` = `c`.`id_idioma`))) join `usuario` `u` on((`u`.`id_usuario` = `p`.`id_aluno`))) where (`u`.`ativo` = true) group by `i`.`id_idioma`,`i`.`nome`,`u`.`id_usuario`,`u`.`nome` */;
/*!50001 SET character_set_client      = @saved_cs_client */;
/*!50001 SET character_set_results     = @saved_cs_results */;
/*!50001 SET collation_connection      = @saved_col_connection */;

--
-- Final view structure for view `vw_turmas_por_idioma`
--

/*!50001 DROP VIEW IF EXISTS `vw_turmas_por_idioma`*/;
/*!50001 SET @saved_cs_client          = @@character_set_client */;
/*!50001 SET @saved_cs_results         = @@character_set_results */;
/*!50001 SET @saved_col_connection     = @@collation_connection */;
/*!50001 SET character_set_client      = utf8mb4 */;
/*!50001 SET character_set_results     = utf8mb4 */;
/*!50001 SET collation_connection      = utf8mb4_0900_ai_ci */;
/*!50001 CREATE ALGORITHM=UNDEFINED */
/*!50013 DEFINER=`root`@`localhost` SQL SECURITY DEFINER */
/*!50001 VIEW `vw_turmas_por_idioma` AS select `t`.`id_turma` AS `id_turma`,`t`.`nome` AS `turma`,`i`.`id_idioma` AS `id_idioma`,`i`.`nome` AS `idioma`,`n`.`codigo` AS `nivel`,`n`.`descricao` AS `nivel_descricao`,`p`.`nome` AS `professor`,`t`.`carga_horaria` AS `carga_horaria`,`t`.`vagas` AS `vagas`,coalesce(`m`.`ocupadas`,0) AS `vagas_ocupadas`,(`t`.`vagas` - coalesce(`m`.`ocupadas`,0)) AS `vagas_disponiveis`,(case when ((`t`.`vagas` - coalesce(`m`.`ocupadas`,0)) <= 0) then 'lotada' else 'com vagas' end) AS `situacao` from ((((`turma` `t` join `idioma` `i` on((`i`.`id_idioma` = `t`.`id_idioma`))) join `nivel` `n` on((`n`.`id_nivel` = `t`.`id_nivel`))) left join `usuario` `p` on((`p`.`id_usuario` = `t`.`id_professor`))) left join (select `matricula`.`id_turma` AS `id_turma`,count(0) AS `ocupadas` from `matricula` where (`matricula`.`status` in ('pendente','ativa')) group by `matricula`.`id_turma`) `m` on((`m`.`id_turma` = `t`.`id_turma`))) */;
/*!50001 SET character_set_client      = @saved_cs_client */;
/*!50001 SET character_set_results     = @saved_cs_results */;
/*!50001 SET collation_connection      = @saved_col_connection */;
/*!40103 SET TIME_ZONE=@OLD_TIME_ZONE */;

/*!40101 SET SQL_MODE=@OLD_SQL_MODE */;
/*!40014 SET FOREIGN_KEY_CHECKS=@OLD_FOREIGN_KEY_CHECKS */;
/*!40014 SET UNIQUE_CHECKS=@OLD_UNIQUE_CHECKS */;
/*!40101 SET CHARACTER_SET_CLIENT=@OLD_CHARACTER_SET_CLIENT */;
/*!40101 SET CHARACTER_SET_RESULTS=@OLD_CHARACTER_SET_RESULTS */;
/*!40101 SET COLLATION_CONNECTION=@OLD_COLLATION_CONNECTION */;
/*!40111 SET SQL_NOTES=@OLD_SQL_NOTES */;

-- Dump completed on 2026-11-20 18:37:48
