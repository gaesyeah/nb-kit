# One Dark Pro Mix para NetBeans

Instalador em bash que leva as cores do tema **One Dark Pro Mix**, do VS Code, para o **Apache NetBeans** no Linux. Ele cria um perfil de cores próprio, seleciona o visual FlatLaf Dark e instala um pequeno módulo que colore o que o NetBeans sozinho não consegue colorir.

Tudo é feito por um menu no terminal, com perguntas `[S/n]` só quando há algo a decidir.

## O que ele faz

- Cria o perfil **"One Dark Pro Mix"** como cópia do FlatLaf Dark da sua versão do NetBeans, com as cores do tema. O perfil FlatLaf Dark original não é alterado.
- Usa as cores do Mix sempre que existe um equivalente. Onde o Mix não define uma cor, usa o padrão do VS Code.
- Mantém o itálico e o negrito do NetBeans, exceto nas palavras-chave, que ficam sem negrito como no Mix.
- Seleciona o visual FlatLaf Dark, o perfil do tema e a cor de seleção do terminal integrado.
- Instala e seleciona a fonte **JetBrains Mono** se ela ainda não estiver instalada.
- Instala um módulo de coloração que pinta o que o editor do NetBeans não distingue sozinho:
  - **JavaScript:** chamadas de função, objetos, constantes e funções e classes da biblioteca padrão.
  - **CSS, SCSS e LESS:** unidades, funções, tags, ids, seletores de atributo e `@keyframes`.
  - **EL (JSF/Facelets):** variáveis locais e objetos implícitos.
  - **HTML, XML, JSP:** DOCTYPE e instruções de processamento.
  - **Colchetes coloridos por nível,** como no VS Code, em Java, JavaScript, JSON, CSS e EL.

## Requisitos

- Linux com bash 4 ou mais novo.
- Apache NetBeans, testado na versão 31. Funciona com instalação normal, Flatpak ou Snap.
- NetBeans rodando com Java 17 ou mais novo, que o módulo de coloração exige.
- `python3`.
- `curl` ou `wget`, só se a JetBrains Mono precisar ser baixada.

## Instalação

Baixe o `netbeans-onedark.sh` e rode:

```bash
bash netbeans-onedark.sh
```

O script mostra o status e só as opções que fazem sentido:

- **Não instalado:** pergunta `Instalar agora? [S/n]`.
- **Instalado:** abre um menu com Reinstalar (ou Atualizar, se houver versão nova), Conferir, Desinstalar e Sair. Use ↑↓ para navegar, Enter para escolher e Esc para sair.
- **Mais de um NetBeans no computador:** pergunta em qual deles instalar.

Se o NetBeans estiver aberto, o script oferece fechar. Ele fecha pelo mesmo caminho do File > Exit, então o NetBeans pergunta sobre arquivos não salvos e processos rodando como sempre. No fim, oferece abrir o NetBeans e confere sozinho se tudo carregou.

> Na primeira instalação, ou ao atualizar de uma versão anterior à v24, o script ainda não consegue fechar o NetBeans sozinho. Feche você e ele continua automaticamente.

## Comandos

Para usar em scripts ou sem o menu:

| Comando | O que faz |
|---|---|
| `bash netbeans-onedark.sh` | Abre o menu |
| `bash netbeans-onedark.sh install [userdir]` | Instala ou atualiza direto |
| `bash netbeans-onedark.sh uninstall [userdir]` | Remove o tema e volta o que você usava antes |
| `bash netbeans-onedark.sh check [userdir]` | Com o NetBeans já aberto, confere se tudo carregou |
| `bash netbeans-onedark.sh --help` | Mostra a ajuda |

O `userdir` é opcional. O padrão é o NetBeans mais novo em `~/.netbeans/`. O caminho certo aparece em Help > About, na linha User directory.

## Suas configurações

- **Personalizações:** se você mudou valores que o tema também define, como chaves da interface ou a fonte, o script pergunta se quer manter os seus.
- **Backup:** antes da primeira instalação, ele guarda um backup do estado original no userdir (`onedark-backup-*.tar.gz`).
- **Falha ou Ctrl+C no meio:** se a instalação falhar ou for interrompida, tudo volta como estava.
- **Desinstalar:**
  - Volta o visual e o perfil de cores anteriores.
  - Remove a JetBrains Mono só se foi o script que instalou.
  - Pergunta se quer apagar os backups.

## Problemas

- **"não achei a instalação do NetBeans":** informe a pasta do NetBeans, a que tem `platform/` e `ide/`:
  ```bash
  NB_HOME=/caminho/do/netbeans bash netbeans-onedark.sh
  ```
- **Módulo de coloração não carregou:** confira se o NetBeans roda com Java 17 ou mais novo. O `check` mostra qual Java ele está usando.
- **Algo diferente do esperado:** rode o `check` com o NetBeans aberto e veja quais itens aparecem como `PROBLEMA`.

## Créditos

- Cores: [One Dark Pro](https://github.com/Binaryify/OneDark-Pro), variante Mix, por Binaryify.
- Fonte: [JetBrains Mono](https://github.com/JetBrains/JetBrainsMono), licença SIL Open Font License 1.1.