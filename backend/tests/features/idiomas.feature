# language: pt
Funcionalidade: Cadastro de idiomas
  Como administrador
  Quero cadastrar idiomas
  Para manter o catalogo do sistema

  Cenário: Cadastrar idioma válido
    Dado que o administrador entrou no sistema
    Quando cadastra o idioma "Francês" com código "FR"
    Então o idioma "Francês" deve existir no banco

  Cenário: Impedir código duplicado
    Dado que o administrador entrou no sistema
    Quando cadastra o idioma "Outro" com código "EN"
    Então o cadastro deve ser recusado por duplicidade
    E o idioma "Outro" não deve existir no banco
