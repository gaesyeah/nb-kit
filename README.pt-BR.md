<p align="center">
  <a href="README.md"><img alt="English" src="https://img.shields.io/badge/English-30363D?style=for-the-badge"></a>
  <a href="README.pt-BR.md"><img alt="Português (Brasil)" src="https://img.shields.io/badge/Portugu%C3%AAs%20(Brasil)-2F81F7?style=for-the-badge"></a>
</p>

# nbkit

Kit de módulos para o **Apache NetBeans** no Linux, instalado por um CLI no terminal. Hoje tem dois módulos:

- **Tema One Dark Pro Mix:** as cores do tema do VS Code, com o visual FlatLaf Dark e a fonte JetBrains Mono.
- **Verificações de JSF:** avisos no editor de xhtml para erros que o NetBeans não mostra, como um bean com nome digitado errado (`#{clienteVn.nome}` em vez de `#{clienteVm.nome}`).

Cada módulo instala e desinstala separado.

## Instalação

Baixe a pasta `nbkit` inteira e rode:

```bash
bash nbkit/nbkit.sh
```

O CLI mostra o status de cada módulo e só as opções que fazem sentido. Use ↑↓ para navegar, Enter para escolher e Esc para voltar.

- **Instalar ou atualizar:** escolha "Todos" ou um módulo.
- **Reinstalar** e **Desinstalar:** também por módulo.
- **Conferir se carregou no NetBeans:** confere cada módulo instalado.
- **Backups:** só aparece quando existe algum. Enter restaura, Del apaga, Esc volta, e restaurar e apagar pedem confirmação.

Se o NetBeans estiver aberto, o nbkit oferece fechar pelo mesmo caminho do File > Exit, então o NetBeans pergunta sobre arquivos não salvos e processos rodando como sempre. No fim, oferece abrir o NetBeans e confere sozinho se tudo carregou. Se algo falhar no meio, ou se você apertar Ctrl+C, tudo volta como estava.

### Sem o menu

| Comando | O que faz |
|---|---|
| `bash nbkit.sh install [módulo...] [userdir]` | Instala ou atualiza (sem módulo: todos) |
| `bash nbkit.sh uninstall [módulo...] [userdir]` | Remove (sem módulo: todos os instalados) |
| `bash nbkit.sh check [userdir]` | Com o NetBeans aberto, confere se tudo carregou |
| `bash nbkit.sh --help` | Ajuda e lista de módulos |
| `--lang pt-BR` ou `--lang en` | Junto com qualquer comando, troca o idioma |

Os ids dos módulos são `one-dark-pro-mix` e `jsf`. O userdir padrão é o NetBeans mais novo em `~/.netbeans/`; se houver mais de um, o menu pergunta qual usar.

## Idiomas

O terminal fala português ou inglês, conforme o idioma do sistema (`LANG`): português quando ele começa com `pt`, inglês nos outros casos. Para escolher, use `--lang pt-BR` ou `--lang en`, ou a variável `NBKIT_LANG`.

Dentro do NetBeans, as dicas do JSF e a tela de Options seguem o idioma em que o NetBeans roda, que vem do sistema ou do `--locale` no `netbeans.conf`.

Para adicionar um idioma:
- **Terminal:** copie `lang/en.lang` para `lang/<idioma>.lang` (ex.: `es.lang`) e traduza os valores. O `pt-BR.lang` é a referência: uma chave que faltar sai em português.
- **NetBeans:** crie `Bundle_<idioma>.properties` ao lado do `Bundle.properties` de cada módulo em `src/` e gere o jar de novo.

## Requisitos

- Linux com bash 4 ou mais novo, e `python3`.
- Apache NetBeans, testado na versão 31. Funciona com instalação normal, Flatpak ou Snap.
- NetBeans rodando com Java 17 ou mais novo.
- `curl` ou `wget`, só se a JetBrains Mono precisar ser baixada.

## Tema One Dark Pro Mix

- Cria o perfil **"One Dark Pro Mix"** como cópia do FlatLaf Dark da sua versão do NetBeans, com as cores do tema. O perfil FlatLaf Dark original não é alterado.
- Usa as cores do Mix sempre que existe um equivalente. Onde o Mix não define uma cor, usa o padrão do VS Code.
- Mantém o itálico e o negrito do NetBeans, exceto nas palavras-chave, que ficam sem negrito como no Mix.
- Seleciona o visual FlatLaf Dark, o perfil e a cor de seleção do terminal, e instala a JetBrains Mono se faltar.
- Avisos em amarelo e erros em vermelho, os dois com um fundo suave.
- Um módulo de coloração pinta o que o editor não distingue sozinho:
  - **JavaScript:** chamadas, objetos e constantes.
  - **CSS:** unidades, funções e seletores.
  - **EL:** variáveis.
  - **HTML/XML:** DOCTYPE.
  - **Colchetes coloridos por nível.**
- **Suas personalizações:** se você mudou valores que o tema também define, o nbkit pergunta se quer manter os seus.
- **Backup:** antes da primeira instalação, ele guarda um backup do estado original, que volta ao desinstalar.

## Criar um tema

Tudo o que o One Dark Pro Mix tem além das cores fica no motor de temas, em `modules/themes/_engine.sh`. Um tema novo só descreve as cores. O motor já cuida de:

- criar o perfil de cores como cópia do perfil base da sua versão do NetBeans, sem mexer no original;
- fazer backup, restaurar, desinstalar e voltar ao visual e ao perfil de antes;
- preservar as personalizações de quem usa;
- instalar a fonte se ela faltar, e removê-la depois só se foi o nbkit que instalou;
- instalar o módulo de coloração (`nbkit-colors.jar`): chamadas, objetos, constantes, unidades, funções, colchetes por nível, DOCTYPE...;
- aplicar a cor de seleção do terminal;
- desfazer tudo com Ctrl+C;
- conferir com o NetBeans aberto (`check`).

Crie `modules/themes/<id>.sh`. O nbkit carrega o arquivo sozinho e o tema aparece no menu.

```bash
source "$(dirname "${BASH_SOURCE[0]}")/_engine.sh"
theme_register my-theme mt "My Theme" "Descrição curta" 1

mt_config() {
  THEME_PROFILE="My Theme"                  # nome do perfil em Tools > Options > Fonts & Colors
  THEME_TERMINAL_SELECTION=-12499634        # opcional: cor de seleção do terminal (ARGB como inteiro)
  THEME_FONT_NAME="JetBrains Mono"          # opcional: fonte do editor
  THEME_FONT_DIR="JetBrainsMono"            # pasta em ~/.local/share/fonts
  THEME_FONT_URLS=("https://.../Regular.ttf" "https://.../Bold.ttf")
  THEME_FONT_LICENSE="https://.../OFL.txt"
}

# interface (FlatLaf): conteúdo do arquivo de propriedades do visual
mt_ui() {
  cat <<'EOF'
nb.preferred.color.profile=My Theme
@background=#1e1e1e
@foreground=#d4d4d4
EOF
}

# editor
mt_colors() {
  colors_tokens <<'EOF'
    <fontcolor name="default" foreColor="ffd4d4d4" bgColor="ff1e1e1e"/>
    <fontcolor name="comment" foreColor="ff6a9955"/>
EOF
  colors_highlights <<'EOF'
    <fontcolor name="selection" bgColor="ff264f78"/>
EOF
  colors_annotations <<'EOF'
EOF
  colors_language text/x-java <<'EOF'
    <fontcolor name="method-declaration" foreColor="ffdcdcaa"/>
EOF
  colors_extras text/javascript <<'EOF'
    <fontcolor name="nbkit-call" foreColor="ffdcdcaa"/>
EOF
}
```

O que cada parte faz:

- **`theme_register <id> <prefixo> "<nome>" "<descrição>" <versão>`:** registra o tema no menu e liga as funções do nbkit ao motor. Aumente a versão quando mudar as cores, para o menu oferecer a atualização. Para a descrição sair no idioma do terminal, crie uma chave nos arquivos de `lang/` e passe `"$(t <chave>)"`, como o One Dark Pro Mix faz.
- **`<prefixo>_config`:** só `THEME_PROFILE` é obrigatório. Os padrões são:
  - base `FlatLafDark` (`THEME_BASE`, com `THEME_BASE_NAME` e `THEME_BASE_PROFILE` para as mensagens e para a desinstalação);
  - visual `com.formdev.flatlaf.FlatDarkLaf` (`THEME_LAF`), com o arquivo `FlatDarkLaf.properties` (`THEME_LAF_FILE`).

  Sem `THEME_FONT_NAME`, a fonte não é alterada. Sem `THEME_TERMINAL_SELECTION`, o terminal não é alterado.
- **`<prefixo>_ui`:** chaves do FlatLaf (`@background`, `Component.focusColor`...). A linha `nb.preferred.color.profile=<perfil>` faz o NetBeans manter o perfil do tema ao trocar de visual. O motor põe a marca do tema na primeira linha e mescla as chaves que a pessoa já tinha.
- **`<prefixo>_colors`:** linhas `<fontcolor .../>` do NetBeans, com cores em `ffRRGGBB`.
  - `colors_tokens` vale para todas as linguagens (`default`, `comment`, `keyword`, `string`, `error`, `warning`...).
  - `colors_highlights` cobre seleção, linha atual, busca, números de linha...
  - `colors_annotations` são os sublinhados que os módulos usam.
  - `colors_language <mime>` são os tokens de uma linguagem.
  - `colors_extras <mime>` são as categorias do módulo de coloração.

  Uma cor que o tema não define fica como no perfil base. Para descobrir o nome de um token, mude a cor dele em Tools > Options > Fonts & Colors e veja o arquivo gravado em `~/.netbeans/<versão>/config/Editors/<mime>/FontsColors/`.

Categorias do módulo de coloração, por linguagem (em `colors_extras`):

| Linguagem | Categorias |
|---|---|
| `text/javascript` | `nbkit-call`, `nbkit-object`, `nbkit-type`, `nbkit-constant`, `nbkit-library`, `nbkit-readonly`, `nbkit-library-function`, colchetes |
| `text/css` | `nbkit-unit`, `nbkit-function`, `nbkit-tag`, `nbkit-id`, `nbkit-attribute`, `nbkit-string`, `nbkit-plain`, `nbkit-url-parameter`, colchetes |
| `text/x-el` | `nbkit-call`, `nbkit-object`, `nbkit-library`, colchetes |
| `text/html` | `nbkit-plain`, `nbkit-doctype`, `nbkit-attribute`, `nbkit-string` |
| `text/xml`, `text/xml-external-parsed-entity` | `nbkit-plain`, `nbkit-attribute`, `nbkit-string`, `nbkit-keyword`, `nbkit-documentroot`, `nbkit-doctype` |
| `text/x-java`, `text/x-json` | colchetes |

Os colchetes são `nbkit-bracket1`, `nbkit-bracket2` e `nbkit-bracket3`, um por nível, e `nbkit-bracket-unexpected` para o colchete sem par.

O `modules/themes/one-dark-pro-mix.sh` é um exemplo completo.

## Verificações de JSF

O NetBeans checa tags, atributos e a sintaxe do EL, mas não pega erros que só aparecem rodando, ou que nem aparecem. Este módulo marca esses erros no editor:
- **Vermelho:** quebra com certeza.
- **Amarelo:** provável erro, ou depende de algo fora do arquivo.

Cada regra liga e desliga em **Tools > Options > Editor > JSF**. As mensagens saem em português ou inglês, conforme o idioma do NetBeans.

- **EL:**
  - nome que não existe;
  - variável fora do lugar;
  - propriedade ou método inexistente no bean;
  - `value` de campo que não pode ser gravado;
  - método onde se espera propriedade;
  - constante de enum inexistente;
  - `cc.attrs` não declarado;
  - `${}` em componente JSF.
- **Declarado e não usado:** `ui:param`, `c:set`, `var`, `varStatus`, `cc:attribute`, parâmetro de lambda.
- **IDs:**
  - `update`/`process`/`for` para id inexistente;
  - palavra de busca errada (`@from`);
  - id inválido ou repetido;
  - update de componente com `rendered`;
  - `PF('x')` sem `widgetVar`.
- **Formulários:**
  - botão ou campo fora de `h:form`;
  - form dentro de form;
  - `p:dialog` com `appendTo` body;
  - `p:fileUpload` sem multipart;
  - validação sem componente de mensagem.
- **Ciclo de vida:**
  - `c:if`/`c:forEach` com a variável de um `ui:repeat`/`p:dataTable`;
  - `f:viewParam` fora de `f:metadata`;
  - evento de `p:ajax` que o componente não tem.
- **Templates e arquivos:**
  - `ui:define` sem `ui:insert`;
  - conteúdo fora de `ui:define`;
  - include, template, recurso ou página de navegação inexistente.
- **Outros:**
  - EL dentro de comentário (o Facelets executa);
  - `&nbsp;` e outras entidades HTML;
  - `escape="false"`.

Os beans (Spring `@Component` e derivados, `@Bean`, CDI `@Named`, `@ManagedBean`) e os tipos vêm das classes compiladas do projeto e dos jars do classpath, então funciona em qualquer projeto sem configurar nada. Classes ainda não compiladas entram pelo nome, lido do código-fonte.

## Estrutura

```
nbkit/
├── nbkit.sh                     CLI
├── lang/
│   ├── pt-BR.lang               textos do terminal em português (referência)
│   └── en.lang                  textos do terminal em inglês
├── modules/
│   ├── README.md                como criar um módulo
│   ├── themes/
│   │   ├── _engine.sh           motor de temas (veja "Criar um tema")
│   │   └── one-dark-pro-mix.sh  só as cores do tema
│   └── jsf.sh
└── src/                         código Java dos módulos do NetBeans
    ├── nbkit-core/              fechar o NetBeans pelo terminal
    ├── nbkit-colors/            coloração por padrão de texto (usado pelos temas)
    └── nbkit-jsf/               verificações de JSF, com o teste em test/
```

Para adicionar um módulo, basta colocar um `.sh` em `modules/` seguindo o [contrato](modules/README.pt-BR.md).

## Problemas

- **"não achei a instalação do NetBeans":** rode com `NB_HOME=/caminho/do/netbeans bash nbkit.sh`.
- **Módulo não carregou:** confira se o NetBeans roda com Java 17 ou mais novo. O `check` mostra qual Java ele está usando.

## Licença

[MIT](LICENSE).

### Terceiros

- **Cores:** [One Dark Pro](https://github.com/Binaryify/OneDark-Pro), variante Mix. Copyright (c) 2013-2022 Binaryify, licença MIT.
- **Fonte:** [JetBrains Mono](https://github.com/JetBrains/JetBrainsMono), baixada do repositório oficial durante a instalação. Copyright 2020 The JetBrains Mono Project Authors, licença SIL Open Font License 1.1.
- **Apache NetBeans** e **FlatLaf** são licenciados sob Apache 2.0. Os módulos usam as APIs públicas do NetBeans.

Projeto independente, sem vínculo com a Apache Software Foundation, com a JetBrains nem com os autores do One Dark Pro. "Apache NetBeans" é marca registrada da Apache Software Foundation.
