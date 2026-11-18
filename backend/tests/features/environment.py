import sys
from pathlib import Path
sys.path.insert(0, str(Path(__file__).resolve().parents[2]))
from test_support import configurar_ambiente, recriar_banco
configurar_ambiente()
from app import app


def before_all(context):
    recriar_banco()
    context.app = app


def before_scenario(context, scenario):
    context.client = context.app.test_client()
