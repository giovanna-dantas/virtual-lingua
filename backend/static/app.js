/* VirtuaLingua - melhorias de usabilidade (sem dependencias). Tudo degrada bem sem JS. */
(function () {
  'use strict';
  var q = function (s, r) { return (r || document).querySelector(s); };
  var qa = function (s, r) { return Array.prototype.slice.call((r || document).querySelectorAll(s)); };

  /* 1. Menu no celular */
  var btn = q('.menu-btn'), menu = q('#menu');
  if (btn && menu) {
    btn.addEventListener('click', function () {
      var aberto = menu.classList.toggle('aberto');
      btn.setAttribute('aria-expanded', aberto ? 'true' : 'false');
    });
    document.addEventListener('keydown', function (e) {
      if (e.key === 'Escape' && menu.classList.contains('aberto')) { menu.classList.remove('aberto'); btn.setAttribute('aria-expanded', 'false'); btn.focus(); }
    });
  }

  /* 2. Link da pagina atual destacado no menu */
  if (menu) {
    var atual = location.pathname.replace(/\/$/, '') || '/', melhor = null, tam = -1;
    qa('a', menu).forEach(function (a) {
      var p = a.pathname.replace(/\/$/, '') || '/';
      if (a.classList.contains('botao') || a.classList.contains('usuario') && p !== atual) return;
      if ((p === atual || (p !== '/' && atual.indexOf(p + '/') === 0)) && p.length > tam) { melhor = a; tam = p.length; }
    });
    if (melhor) melhor.setAttribute('aria-current', 'page');
  }

  /* 3. Avisos: botao de fechar; sucesso some sozinho */
  qa('.mensagem').forEach(function (m) {
    var fechar = q('.fechar', m);
    var remover = function () { m.classList.add('saindo'); setTimeout(function () { m.remove(); }, 250); };
    if (fechar) fechar.addEventListener('click', remover);
    if (m.classList.contains('sucesso')) setTimeout(remover, 9000);
  });

  /* 4. Confirmacao em janela propria (data-confirm) */
  var dlg = null;
  function criarDialogo() {
    dlg = document.createElement('dialog');
    dlg.className = 'confirmacao';
    dlg.setAttribute('aria-labelledby', 'conf-titulo');
    dlg.innerHTML = '<form method="dialog"><h3 id="conf-titulo">Confirmar ação</h3><p class="conf-texto"></p>' +
      '<div class="acoes"><button value="ok" class="conf-ok" type="submit">Confirmar</button>' +
      '<button value="nao" class="secundario" type="submit">Voltar</button></div></form>';
    document.body.appendChild(dlg);
  }
  function confirmar(texto, aoConfirmar) {
    if (typeof HTMLDialogElement !== 'function') { if (window.confirm(texto)) aoConfirmar(); return; }
    if (!dlg) criarDialogo();
    q('.conf-texto', dlg).textContent = texto;
    dlg.onclose = function () { if (dlg.returnValue === 'ok') aoConfirmar(); dlg.returnValue = ''; };
    dlg.showModal();
    q('.secundario', dlg).focus();
  }
  document.addEventListener('submit', function (e) {
    var f = e.target, texto = f.getAttribute && f.getAttribute('data-confirm');
    if (texto && !f.dataset.confirmado) {
      e.preventDefault();
      var quem = e.submitter;
      confirmar(texto, function () { f.dataset.confirmado = '1'; if (f.requestSubmit) f.requestSubmit(quem || undefined); else f.submit(); });
      return;
    }
    /* 5. Evita envio duplo: desativa o botao enquanto a pagina responde */
    if (!e.defaultPrevented) {
      var b = e.submitter || q('button[type=submit]', f);
      if (b && !b.dataset.original) {
        b.dataset.original = b.textContent;
        setTimeout(function () { b.disabled = true; b.textContent = 'Aguarde…'; }, 0);
      }
    }
  });
  window.addEventListener('pageshow', function () {
    qa('button[data-original]').forEach(function (b) { b.disabled = false; b.textContent = b.dataset.original; delete b.dataset.original; });
    qa('form[data-confirmado]').forEach(function (f) { delete f.dataset.confirmado; });
  });

  /* 6. Mostrar/ocultar senha */
  qa('input[type=password]').forEach(function (inp) {
    var rotulo = inp.closest('label') || inp;
    var t = document.createElement('button');
    t.type = 'button'; t.className = 'link-btn'; t.textContent = 'Mostrar senha';
    t.setAttribute('aria-pressed', 'false');
    t.addEventListener('click', function () {
      var mostrar = inp.type === 'password';
      inp.type = mostrar ? 'text' : 'password';
      t.textContent = mostrar ? 'Ocultar senha' : 'Mostrar senha';
      t.setAttribute('aria-pressed', mostrar ? 'true' : 'false');
    });
    rotulo.parentNode.insertBefore(t, rotulo.nextSibling);
  });

  /* 7. Tabelas: rolagem horizontal no celular + busca rapida (table[data-busca]) */
  qa('table').forEach(function (t) {
    var wrap = document.createElement('div');
    wrap.className = 'tabela-wrap'; wrap.tabIndex = 0; wrap.setAttribute('role', 'region');
    wrap.setAttribute('aria-label', 'Tabela (role para ver mais colunas)');
    t.parentNode.insertBefore(wrap, t); wrap.appendChild(t);
    if (t.hasAttribute('data-busca') && qa('tbody tr', t).length > 5) {
      var barra = document.createElement('div'); barra.className = 'busca-rapida';
      barra.innerHTML = '<label>Filtrar esta lista<input type="search" placeholder="Digite para filtrar…" autocomplete="off"></label><span class="ajuda" aria-live="polite"></span>';
      wrap.parentNode.insertBefore(barra, wrap);
      var campo = q('input', barra), info = q('.ajuda', barra), linhas = qa('tbody tr', t);
      campo.addEventListener('input', function () {
        var termo = campo.value.trim().toLowerCase(), vis = 0;
        linhas.forEach(function (l) { var ok = !termo || l.textContent.toLowerCase().indexOf(termo) !== -1; l.hidden = !ok; if (ok) vis++; });
        info.textContent = termo ? vis + ' de ' + linhas.length + ' linha(s)' : '';
      });
    }
  });
})();
