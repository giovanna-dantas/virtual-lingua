"""API REST combinada para desenvolvimento paralelo do frontend.
Todas as rotas usam JSON, SQL parametrizado e sessão Flask.
"""
import re
from decimal import Decimal, InvalidOperation
from functools import wraps
from flask import Blueprint, jsonify, request, session
from mysql.connector import Error
from werkzeug.security import generate_password_hash, check_password_hash
import db

api = Blueprint('api', __name__, url_prefix='/api')

def resposta(dados=None, status=200, mensagem=None):
    corpo = {"ok": status < 400}
    if mensagem: corpo['mensagem'] = mensagem
    if dados is not None: corpo['dados'] = dados
    return jsonify(corpo), status

def autenticado(*papeis):
    def deco(fn):
        @wraps(fn)
        def wrapper(*a, **kw):
            if not session.get('id_usuario'): return resposta(status=401, mensagem='Autenticação necessária.')
            if papeis and session.get('tipo') not in papeis: return resposta(status=403, mensagem='Acesso não permitido para este perfil.')
            return fn(*a, **kw)
        return wrapper
    return deco

def corpo(): return request.get_json(silent=True) or {}
def obrigatorio(d, campos): return [c for c in campos if d.get(c) is None or str(d.get(c)).strip() == '']
def int_positivo(v):
    try: return int(v) > 0
    except (TypeError, ValueError): return False

def tratar_erro(e):
    return resposta(status=409 if getattr(e, 'errno', 0) in (1062,1451,1452,3819,1644) else 503,
                    mensagem=db.mensagem_erro(e))

@api.get('/rotas')
def rotas():
    """Contrato de endpoints para o frontend."""
    itens = [
      ('GET','/api/csrf','Público: obter token CSRF'),
      ('POST','/api/login','Público: email, senha'),('POST','/api/logout','Autenticado'),
      ('GET/POST','/api/usuarios','Admin: listar/criar aluno ou professor'),('GET/PUT/DELETE','/api/usuarios/<id>','Admin: consultar/editar/excluir usuário'),
      ('GET/PUT','/api/perfil','Consultar/editar próprio perfil'),('DELETE','/api/conta','Excluir/anonimizar própria conta com confirmar=true'),
      ('GET/POST','/api/turmas','Admin/professor: listar/criar'),('GET/PUT/DELETE','/api/turmas/<id>','Admin: consultar/editar/excluir'),
      ('GET/POST','/api/matriculas','Admin/aluno: listar/criar matrícula'),('GET/PUT/DELETE','/api/matriculas/<id>','Admin: consultar/editar/cancelar'),
      ('GET/POST','/api/conteudos','Admin/professor: listar/criar'),('GET/PUT/DELETE','/api/conteudos/<id>','Admin/professor: consultar/editar/excluir'),
      ('GET/POST','/api/desafios','Admin/professor: listar/criar'),('GET/PUT/DELETE','/api/desafios/<id>','Admin/professor: consultar/editar/excluir'),
      ('GET/POST','/api/pontuacoes','Aluno consulta/registra própria; professor/admin gerencia'),('GET/PUT/DELETE','/api/pontuacoes/<id>','Admin/professor gerencia'),
      ('GET/POST','/api/pagamentos','Admin: listar/criar'),('GET/PUT/DELETE','/api/pagamentos/<id>','Admin: consultar/editar/excluir')]
    return resposta([{'metodos':m,'rota':p,'permissao':d} for m,p,d in itens])

@api.post('/login')
def login():
    d=corpo(); email=str(d.get('email','')).strip().lower(); senha=str(d.get('senha',''))
    u=db.consultar_um('SELECT id_usuario,nome,email,senha_hash,tipo,ativo FROM usuario WHERE email=%s',(email,))
    if not u or not u['ativo'] or not check_password_hash(u['senha_hash'],senha): return resposta(status=401,mensagem='E-mail ou senha inválidos.')
    session.clear(); session.update(id_usuario=u['id_usuario'],nome=u['nome'],email=u['email'],tipo=u['tipo'])
    return resposta({k:u[k] for k in ('id_usuario','nome','email','tipo')},mensagem='Login realizado.')

@api.post('/logout')
@autenticado()
def logout(): session.clear(); return resposta(mensagem='Sessão encerrada.')

@api.get('/usuarios')
@autenticado('administrador')
def usuarios_listar():
    return resposta(db.consultar("SELECT id_usuario,nome,email,tipo,ativo,criado_em FROM usuario WHERE tipo IN ('aluno','professor') ORDER BY nome"))

@api.post('/usuarios')
@autenticado('administrador')
def usuarios_criar():
    d=corpo(); faltam=obrigatorio(d,['nome','email','senha','tipo'])
    if faltam: return resposta(status=400,mensagem='Campos obrigatórios: '+', '.join(faltam))
    if d['tipo'] not in ('aluno','professor') or len(d['senha'])<8 or not re.fullmatch(r'[^@\s]+@[^@\s]+\.[^@\s]+',d['email']): return resposta(status=400,mensagem='Tipo, e-mail ou senha inválidos (mínimo 8 caracteres).')
    try:
        ops=[('INSERT INTO usuario(nome,email,senha_hash,tipo) VALUES(%s,%s,%s,%s)',(d['nome'].strip(),d['email'].strip().lower(),generate_password_hash(d['senha']),d['tipo']))]
        with db.transacao() as cnx:
            cur=cnx.cursor(); cur.execute(*ops[0]); uid=cur.lastrowid
            if d['tipo']=='professor':
                for iid in d.get('idiomas_habilitados',[]): cur.execute('INSERT INTO professor_idioma(id_professor,id_idioma) VALUES(%s,%s)',(uid,iid))
            cur.close()
        return resposta({'id_usuario':uid},201,'Usuário criado.')
    except Error as e: return tratar_erro(e)

@api.get('/usuarios/<int:uid>')
@autenticado('administrador')
def usuario_obter(uid):
    u=db.consultar_um("SELECT id_usuario,nome,email,tipo,ativo FROM usuario WHERE id_usuario=%s AND tipo IN ('aluno','professor')",(uid,))
    return resposta(u) if u else resposta(status=404,mensagem='Usuário não encontrado.')

@api.route('/usuarios/<int:uid>',methods=['PUT','DELETE'])
@autenticado('administrador')
def usuario_editar_excluir(uid):
    if request.method=='DELETE':
        try: db.chamar_procedure('sp_excluir_conta',(uid,)); return resposta(mensagem='Conta anonimizada.')
        except Error as e: return tratar_erro(e)
    d=corpo(); sets=[]; vals=[]
    for campo in ('nome','email'):
        if campo in d: sets.append(campo+'=%s'); vals.append(str(d[campo]).strip())
    if 'senha' in d and len(d['senha'])>=8: sets.append('senha_hash=%s'); vals.append(generate_password_hash(d['senha']))
    if not sets: return resposta(status=400,mensagem='Informe nome, email ou senha para alterar.')
    vals.append(uid)
    try: db.executar('UPDATE usuario SET '+','.join(sets)+' WHERE id_usuario=%s AND tipo IN (\'aluno\',\'professor\')',tuple(vals)); return resposta(mensagem='Usuário atualizado.')
    except Error as e: return tratar_erro(e)

@api.route('/perfil',methods=['GET','PUT'])
@autenticado()
def perfil():
    uid=session['id_usuario']
    if request.method=='GET': return resposta(db.consultar_um('SELECT id_usuario,nome,email,tipo FROM usuario WHERE id_usuario=%s',(uid,)))
    d=corpo(); sets=[]; vals=[]
    for c in ('nome','email'):
        if c in d: sets.append(c+'=%s'); vals.append(str(d[c]).strip())
    if d.get('senha'):
        if len(d['senha'])<8: return resposta(status=400,mensagem='A senha deve ter pelo menos 8 caracteres.')
        sets.append('senha_hash=%s'); vals.append(generate_password_hash(d['senha']))
    if not sets: return resposta(status=400,mensagem='Nenhum campo para atualizar.')
    vals.append(uid)
    try: db.executar('UPDATE usuario SET '+','.join(sets)+' WHERE id_usuario=%s',tuple(vals)); return resposta(mensagem='Perfil atualizado.')
    except Error as e: return tratar_erro(e)

@api.delete('/conta')
@autenticado()
def conta_excluir():
    if corpo().get('confirmar') is not True: return resposta(status=400,mensagem='Envie confirmar=true para confirmar a exclusão.')
    uid=session['id_usuario']
    try: db.chamar_procedure('sp_excluir_conta',(uid,)); session.clear(); return resposta(mensagem='Conta excluída/anonimizada conforme procedimento do banco.')
    except Error as e: return tratar_erro(e)

# CRUDs simples com whitelist de tabelas/campos; os valores são sempre parametrizados.
CRUDS={
 'turmas': {'table':'turma','pk':'id_turma','fields':['nome','id_idioma','id_nivel','id_professor','carga_horaria','vagas'],'roles':['administrador'],'required':['nome','id_idioma','id_nivel','carga_horaria','vagas']},
 'conteudos': {'table':'conteudo','pk':'id_conteudo','fields':['titulo','descricao','id_idioma','id_nivel','id_professor'],'roles':['administrador','professor'],'required':['titulo','id_idioma','id_nivel']},
 'desafios': {'table':'desafio','pk':'id_desafio','fields':['id_conteudo','titulo','descricao','pontuacao_maxima'],'roles':['administrador','professor'],'required':['id_conteudo','titulo','pontuacao_maxima']},
}
def registrar_crud(nome,cfg):
    tabela,pk,campos=cfg['table'],cfg['pk'],cfg['fields']; roles=cfg['roles']
    def listar():
        if nome=='conteudos' and session.get('tipo')=='professor': return resposta(db.consultar('SELECT * FROM conteudo WHERE id_professor=%s ORDER BY id_conteudo DESC',(session['id_usuario'],)))
        if nome=='desafios' and session.get('tipo')=='professor': return resposta(db.consultar('SELECT d.* FROM desafio d JOIN conteudo c ON c.id_conteudo=d.id_conteudo WHERE c.id_professor=%s ORDER BY d.id_desafio DESC',(session['id_usuario'],)))
        return resposta(db.consultar('SELECT * FROM '+tabela+' ORDER BY '+pk+' DESC'))
    listar.__name__=nome+'_listar'; api.add_url_rule('/'+nome,endpoint=nome+'_listar',view_func=autenticado(*roles)(listar),methods=['GET'])
    def criar():
        d=corpo(); faltam=obrigatorio(d,cfg['required'])
        if faltam: return resposta(status=400,mensagem='Campos obrigatórios: '+', '.join(faltam))
        if nome=='conteudos' and session.get('tipo')=='professor': d['id_professor']=session['id_usuario']
        if nome=='desafios' and session.get('tipo')=='professor':
            dono=db.consultar_um('SELECT id_professor FROM conteudo WHERE id_conteudo=%s',(d['id_conteudo'],))
            if not dono or dono['id_professor']!=session['id_usuario']: return resposta(status=403,mensagem='Você só pode criar desafios para seus próprios conteúdos.')
        if nome=='turmas' and d.get('id_professor'):
            habilitado=db.consultar_um("SELECT 1 ok FROM usuario u JOIN professor_idioma pi ON pi.id_professor=u.id_usuario WHERE u.id_usuario=%s AND u.tipo='professor' AND u.ativo=1 AND pi.id_idioma=%s",(d['id_professor'],d['id_idioma']))
            if not habilitado: return resposta(status=400,mensagem='O professor não está habilitado no idioma selecionado.')
        if nome=='turmas' and (not int_positivo(d.get('vagas')) or not int_positivo(d.get('carga_horaria'))): return resposta(status=400,mensagem='Vagas e carga horária devem ser positivas.')
        if nome=='desafios' and not int_positivo(d.get('pontuacao_maxima')): return resposta(status=400,mensagem='Pontuação máxima deve ser positiva.')
        if nome=='pagamentos':
            try:
                if Decimal(str(d['valor']))<=0: raise InvalidOperation()
            except InvalidOperation: return resposta(status=400,mensagem='Valor do pagamento deve ser positivo.')
        cols=[c for c in campos if c in d]; vals=[d[c] for c in cols]
        try:
            _,newid=db.executar('INSERT INTO '+tabela+' ('+','.join(cols)+') VALUES ('+','.join(['%s']*len(cols))+')',tuple(vals))
            return resposta({pk:newid},201,'Registro criado.')
        except Error as e: return tratar_erro(e)
    criar.__name__=nome+'_criar'; api.add_url_rule('/'+nome,endpoint=nome+'_criar',view_func=autenticado(*roles)(criar),methods=['POST'])
    def obter(rid):
        if nome=='conteudos' and session.get('tipo')=='professor': row=db.consultar_um('SELECT * FROM conteudo WHERE id_conteudo=%s AND id_professor=%s',(rid,session['id_usuario']))
        elif nome=='desafios' and session.get('tipo')=='professor': row=db.consultar_um('SELECT d.* FROM desafio d JOIN conteudo c ON c.id_conteudo=d.id_conteudo WHERE d.id_desafio=%s AND c.id_professor=%s',(rid,session['id_usuario']))
        else: row=db.consultar_um('SELECT * FROM '+tabela+' WHERE '+pk+'=%s',(rid,))
        return resposta(row) if row else resposta(status=404,mensagem='Registro não encontrado.')
    obter.__name__=nome+'_obter'; api.add_url_rule('/'+nome+'/<int:rid>',endpoint=nome+'_obter',view_func=autenticado(*roles)(obter),methods=['GET'])
    def alterar(rid):
        if nome=='conteudos' and session.get('tipo')=='professor': dono=db.consultar_um('SELECT id_conteudo FROM conteudo WHERE id_conteudo=%s AND id_professor=%s',(rid,session['id_usuario']))
        elif nome=='desafios' and session.get('tipo')=='professor': dono=db.consultar_um('SELECT d.id_desafio FROM desafio d JOIN conteudo c ON c.id_conteudo=d.id_conteudo WHERE d.id_desafio=%s AND c.id_professor=%s',(rid,session['id_usuario']))
        else: dono=True
        if not dono: return resposta(status=403,mensagem='Você não tem permissão para alterar este registro.')
        if request.method=='DELETE':
            try:
                n,_=db.executar('DELETE FROM '+tabela+' WHERE '+pk+'=%s',(rid,)); return resposta(mensagem='Registro excluído.' if n else 'Registro não encontrado.')
            except Error as e: return tratar_erro(e)
        d=corpo()
        if nome=='conteudos' and session.get('tipo')=='professor': d.pop('id_professor',None)
        cols=[c for c in campos if c in d]
        if not cols: return resposta(status=400,mensagem='Nenhum campo válido informado.')
        if nome=='turmas':
            atual=db.consultar_um('SELECT id_idioma,id_professor FROM turma WHERE id_turma=%s',(rid,))
            if atual:
                idioma=d.get('id_idioma',atual['id_idioma']); prof=d.get('id_professor',atual['id_professor'])
                if prof and not db.consultar_um("SELECT 1 ok FROM usuario u JOIN professor_idioma pi ON pi.id_professor=u.id_usuario WHERE u.id_usuario=%s AND u.tipo='professor' AND u.ativo=1 AND pi.id_idioma=%s",(prof,idioma)):
                    return resposta(status=400,mensagem='Professor não habilitado para o idioma da turma.')
        try:
            n,_=db.executar('UPDATE '+tabela+' SET '+','.join(c+'=%s' for c in cols)+' WHERE '+pk+'=%s',tuple([d[c] for c in cols]+[rid]))
            return resposta(mensagem='Registro atualizado.' if n else 'Nenhuma alteração ou registro inexistente.')
        except Error as e: return tratar_erro(e)
    alterar.__name__=nome+'_alterar'; api.add_url_rule('/'+nome+'/<int:rid>',endpoint=nome+'_alterar',view_func=autenticado(*roles)(alterar),methods=['PUT','DELETE'])

for _nome,_cfg in CRUDS.items(): registrar_crud(_nome,_cfg)

@api.get('/matriculas')
@autenticado('administrador','aluno')
def matriculas_listar():
    if session['tipo']=='aluno':
        rows=db.consultar('SELECT m.*,t.nome turma,i.nome idioma,n.codigo nivel FROM matricula m JOIN turma t ON t.id_turma=m.id_turma JOIN idioma i ON i.id_idioma=t.id_idioma JOIN nivel n ON n.id_nivel=t.id_nivel WHERE m.id_aluno=%s',(session['id_usuario'],))
    else: rows=db.consultar('SELECT * FROM matricula ORDER BY id_matricula DESC')
    return resposta(rows)

@api.post('/matriculas')
@autenticado('administrador','aluno')
def matricula_criar():
    d=corpo(); aluno=session['id_usuario'] if session['tipo']=='aluno' else d.get('id_aluno'); turma=d.get('id_turma')
    if not aluno or not turma: return resposta(status=400,mensagem='Informe aluno (admin) e turma.')
    if d.get('id_idioma') is not None:
        idioma_turma=db.consultar_um('SELECT id_idioma FROM turma WHERE id_turma=%s',(turma,))
        if not idioma_turma or int(d['id_idioma'])!=idioma_turma['id_idioma']: return resposta(status=400,mensagem='O idioma informado não corresponde ao idioma da turma selecionada.')
    try:
        with db.transacao() as cnx:
            cur=cnx.cursor(dictionary=True)
            cur.execute("SELECT u.tipo,u.ativo,t.vagas,(SELECT COUNT(*) FROM matricula m WHERE m.id_turma=t.id_turma AND m.status IN ('pendente','ativa')) ocupadas FROM usuario u JOIN turma t ON t.id_turma=%s WHERE u.id_usuario=%s FOR UPDATE",(turma,aluno)); row=cur.fetchone()
            if not row or row['tipo']!='aluno' or not row['ativo']: return resposta(status=400,mensagem='Aluno ou turma inválidos.')
            if row['ocupadas']>=row['vagas']: return resposta(status=409,mensagem='Turma sem vagas disponíveis.')
            cur.execute("INSERT INTO matricula(id_aluno,id_turma,status) VALUES(%s,%s,'pendente')",(aluno,turma)); mid=cur.lastrowid; cur.close()
        return resposta({'id_matricula':mid},201,'Matrícula criada.')
    except Error as e: return tratar_erro(e)

@api.get('/matriculas/<int:mid>')
@autenticado('administrador','aluno')
def matricula_obter(mid):
    row=db.consultar_um('SELECT * FROM matricula WHERE id_matricula=%s',(mid,))
    if row and session['tipo']=='aluno' and row['id_aluno']!=session['id_usuario']: return resposta(status=403,mensagem='Matrícula de outro aluno.')
    return resposta(row) if row else resposta(status=404,mensagem='Matrícula não encontrada.')

@api.route('/matriculas/<int:mid>',methods=['PUT','DELETE'])
@autenticado('administrador')
def matricula_alterar(mid):
    if request.method=='DELETE':
        try:
            n,_=db.executar("UPDATE matricula SET status='cancelada' WHERE id_matricula=%s",(mid,))
            return resposta(mensagem='Matrícula cancelada.' if n else 'Matrícula não encontrada.')
        except Error as e: return tratar_erro(e)
    d=corpo(); atual=db.consultar_um('SELECT id_aluno,id_turma,status FROM matricula WHERE id_matricula=%s',(mid,))
    if not atual: return resposta(status=404,mensagem='Matrícula não encontrada.')
    aluno=d.get('id_aluno',atual['id_aluno']); turma=d.get('id_turma',atual['id_turma']); status=d.get('status',atual['status'])
    if status not in ('pendente','ativa','cancelada','concluida'): return resposta(status=400,mensagem='Status inválido.')
    if d.get('id_idioma') is not None:
        idioma_turma=db.consultar_um('SELECT id_idioma FROM turma WHERE id_turma=%s',(turma,))
        if not idioma_turma or int(d['id_idioma'])!=idioma_turma['id_idioma']: return resposta(status=400,mensagem='O idioma informado não corresponde ao idioma da turma selecionada.')
    try:
        with db.transacao() as cnx:
            cur=cnx.cursor(dictionary=True)
            cur.execute("SELECT u.tipo,u.ativo,t.vagas,t.id_idioma,(SELECT COUNT(*) FROM matricula m WHERE m.id_turma=t.id_turma AND m.status IN ('pendente','ativa') AND m.id_matricula<>%s) ocupadas FROM usuario u JOIN turma t ON t.id_turma=%s WHERE u.id_usuario=%s FOR UPDATE",(mid,turma,aluno)); valid=cur.fetchone()
            if not valid or valid['tipo']!='aluno' or not valid['ativo']: return resposta(status=400,mensagem='Aluno ou turma inválidos.')
            if status in ('pendente','ativa') and valid['ocupadas']>=valid['vagas']: return resposta(status=409,mensagem='Turma sem vagas disponíveis.')
            cur.execute('UPDATE matricula SET id_aluno=%s,id_turma=%s,status=%s WHERE id_matricula=%s',(aluno,turma,status,mid)); cur.close()
        return resposta(mensagem='Matrícula atualizada.')
    except Error as e: return tratar_erro(e)

@api.get('/pontuacoes')
@autenticado('aluno','professor','administrador')
def pontuacoes_listar():
    if session['tipo']=='aluno': rows=db.consultar('SELECT * FROM pontuacao WHERE id_aluno=%s',(session['id_usuario'],))
    else: rows=db.consultar('SELECT * FROM pontuacao ORDER BY data_registro DESC')
    return resposta(rows)

@api.post('/pontuacoes')
@autenticado('aluno','professor','administrador')
def pontuacao_criar():
    d=corpo(); aluno=session['id_usuario'] if session['tipo']=='aluno' else d.get('id_aluno')
    if not aluno or not d.get('id_desafio') or d.get('pontos') is None: return resposta(status=400,mensagem='Informe aluno, desafio e pontos.')
    if session['tipo']=='aluno' and aluno!=session['id_usuario']: return resposta(status=403,mensagem='Não pode registrar pontuação para outro aluno.')
    try:
        with db.transacao() as cnx:
            cur=cnx.cursor(dictionary=True); cur.execute('SELECT pontuacao_maxima FROM desafio WHERE id_desafio=%s',(d['id_desafio'],)); des=cur.fetchone()
            pontos=Decimal(str(d['pontos']))
            if not des or pontos<0 or pontos>des['pontuacao_maxima']: return resposta(status=400,mensagem='Desafio inexistente ou pontuação fora do intervalo permitido.')
            cur.execute('INSERT INTO pontuacao(id_aluno,id_desafio,pontos) VALUES(%s,%s,%s) ON DUPLICATE KEY UPDATE pontos=VALUES(pontos),data_registro=CURRENT_TIMESTAMP',(aluno,d['id_desafio'],pontos)); pid=cur.lastrowid; cur.close()
        return resposta({'id_pontuacao':pid},201,'Pontuação registrada.')
    except (Error,InvalidOperation,ValueError) as e: return tratar_erro(e) if isinstance(e,Error) else resposta(status=400,mensagem='Pontuação inválida.')

@api.route('/pontuacoes/<int:pid>',methods=['GET','PUT','DELETE'])
@autenticado('professor','administrador')
def pontuacao_item(pid):
    row=db.consultar_um('SELECT * FROM pontuacao WHERE id_pontuacao=%s',(pid,))
    if not row: return resposta(status=404,mensagem='Pontuação não encontrada.')
    if request.method=='GET': return resposta(row)
    if request.method=='DELETE': db.executar('DELETE FROM pontuacao WHERE id_pontuacao=%s',(pid,)); return resposta(mensagem='Pontuação excluída.')
    d=corpo()
    try:
        p=Decimal(str(d.get('pontos'))); limite=db.consultar_um('SELECT pontuacao_maxima FROM desafio WHERE id_desafio=%s',(row['id_desafio'],))
        if p<0 or p>limite['pontuacao_maxima']: return resposta(status=400,mensagem='Pontuação fora do intervalo.')
        db.executar('UPDATE pontuacao SET pontos=%s WHERE id_pontuacao=%s',(p,pid)); return resposta(mensagem='Pontuação atualizada.')
    except (InvalidOperation,TypeError): return resposta(status=400,mensagem='Pontuação inválida.')
    except Error as e: return tratar_erro(e)

@api.get('/pagamentos')
@autenticado('administrador','aluno')
def pagamentos_aluno():
    if session['tipo']=='aluno': rows=db.consultar('SELECT p.* FROM pagamento p JOIN matricula m ON m.id_matricula=p.id_matricula WHERE m.id_aluno=%s',(session['id_usuario'],))
    else: rows=db.consultar('SELECT * FROM pagamento ORDER BY data_vencimento DESC')
    return resposta(rows)

@api.get('/csrf')
def csrf():
    import secrets
    if 'csrf_token' not in session: session['csrf_token']=secrets.token_hex(16)
    return resposta({'csrf_token':session['csrf_token']})

@api.post('/pagamentos')
@autenticado('administrador')
def pagamento_criar():
    d=corpo(); faltam=obrigatorio(d,['id_matricula','valor','data_vencimento'])
    if faltam: return resposta(status=400,mensagem='Campos obrigatórios: '+', '.join(faltam))
    try:
        valor=Decimal(str(d['valor']))
        if valor<=0: raise InvalidOperation()
    except InvalidOperation: return resposta(status=400,mensagem='Valor deve ser positivo.')
    status=d.get('status','pendente'); data_pagamento=d.get('data_pagamento')
    if status not in ('pendente','pago','atrasado','cancelado') or (status=='pago') != bool(data_pagamento):
        return resposta(status=400,mensagem='Status/data de pagamento inválidos.')
    try:
        _,pid=db.executar('INSERT INTO pagamento(id_matricula,valor,data_vencimento,data_pagamento,status) VALUES(%s,%s,%s,%s,%s)',(d['id_matricula'],valor,d['data_vencimento'],data_pagamento,status))
        return resposta({'id_pagamento':pid},201,'Pagamento criado.')
    except Error as e: return tratar_erro(e)

@api.get('/pagamentos/<int:pid>')
@autenticado('administrador','aluno')
def pagamento_obter(pid):
    row=db.consultar_um('SELECT p.* FROM pagamento p JOIN matricula m ON m.id_matricula=p.id_matricula WHERE p.id_pagamento=%s',(pid,))
    if row and session['tipo']=='aluno':
        vinc=db.consultar_um('SELECT id_aluno FROM matricula WHERE id_matricula=%s',(row['id_matricula'],))
        if vinc['id_aluno']!=session['id_usuario']: return resposta(status=403,mensagem='Pagamento de outro aluno.')
    return resposta(row) if row else resposta(status=404,mensagem='Pagamento não encontrado.')

@api.route('/pagamentos/<int:pid>',methods=['PUT','DELETE'])
@autenticado('administrador')
def pagamento_alterar(pid):
    if request.method=='DELETE':
        try: db.executar('DELETE FROM pagamento WHERE id_pagamento=%s',(pid,)); return resposta(mensagem='Pagamento excluído.')
        except Error as e: return tratar_erro(e)
    d=corpo(); campos=[c for c in ('id_matricula','valor','data_vencimento','data_pagamento','status') if c in d]
    if not campos: return resposta(status=400,mensagem='Nenhum campo válido informado.')
    if d.get('status')=='pago' and not d.get('data_pagamento'): return resposta(status=400,mensagem='Informe a data de pagamento para status pago.')
    if d.get('status') and d['status']!='pago' and d.get('data_pagamento') is not None: return resposta(status=400,mensagem='Somente pagamento pago pode ter data de pagamento.')
    try: db.executar('UPDATE pagamento SET '+','.join(c+'=%s' for c in campos)+' WHERE id_pagamento=%s',tuple([d[c] for c in campos]+[pid])); return resposta(mensagem='Pagamento atualizado.')
    except Error as e: return tratar_erro(e)
