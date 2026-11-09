import pytest
from mysql.connector import IntegrityError
import db


def test_seed_tem_idiomas():
    assert db.consultar_um("SELECT id_idioma FROM idioma WHERE codigo='EN'")
    assert db.consultar_um("SELECT id_idioma FROM idioma WHERE codigo='ES'")


def test_email_duplicado_e_rejeitado():
    usuario = db.consultar_um("SELECT nome, email, senha_hash, tipo FROM usuario WHERE email=%s",
                              ("admin@virtualingua.com.br",))
    assert usuario is not None
    with pytest.raises(IntegrityError) as erro:
        db.executar("INSERT INTO usuario(nome,email,senha_hash,tipo) VALUES (%s,%s,%s,%s)",
                    (usuario["nome"], usuario["email"], usuario["senha_hash"], usuario["tipo"]))
    assert erro.value.errno == 1062


def test_rollback_de_insert_sem_commit():
    with db.conexao() as cnx:
        cursor = cnx.cursor()
        try:
            cursor.execute("INSERT INTO idioma(nome,codigo) VALUES (%s,%s)", ("Temporário", "TP"))
        finally:
            cursor.close()
    assert db.consultar_um("SELECT id_idioma FROM idioma WHERE codigo='TP'") is None


def test_procedure_excluir_conta_rejeita_usuario_inexistente():
    # Procedure possui handler de erro e ROLLBACK; chamada com ID inexistente.
    with pytest.raises(Exception) as erro:
        db.executar("CALL sp_excluir_conta(%s)", (999999999,))
    assert getattr(erro.value, "errno", None) == 1644
