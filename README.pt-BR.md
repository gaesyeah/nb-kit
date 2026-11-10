<p align="center">
  <a href="https://github.com/gaesyeah/nb-kit#readme"><img alt="English" src="https://img.shields.io/badge/English-30363D?style=for-the-badge"></a>
  <a href="README.pt-BR.md"><img alt="Português (Brasil)" src="https://img.shields.io/badge/Portugu%C3%AAs%20(Brasil)-2F81F7?style=for-the-badge"></a>
</p>

# nbkit

<p align="center">
  <a href="https://github.com/gaesyeah/nb-kit/releases/latest/download/nbkit.zip"><img alt="Baixar nbkit.zip" src="https://img.shields.io/badge/Baixar-nbkit.zip-2F81F7?style=for-the-badge&logo=github&logoColor=white"></a>
  <a href="https://github.com/gaesyeah/nb-kit/releases/latest"><img alt="Release" src="https://img.shields.io/github/v/release/gaesyeah/nb-kit?style=for-the-badge&color=30363D"></a>
  <a href="https://github.com/gaesyeah/nb-kit/actions/workflows/tests.yml"><img alt="Tests" src="https://img.shields.io/github/actions/workflow/status/gaesyeah/nb-kit/tests.yml?branch=main&style=for-the-badge&label=tests"></a>
  <a href="LICENSE"><img alt="License" src="https://img.shields.io/github/license/gaesyeah/nb-kit?style=for-the-badge&color=30363D"></a>
</p>

Kit de módulos para o **Apache NetBeans** no Linux, instalado por um CLI no terminal ou por uma interface gráfica. Hoje tem dois módulos:

- **Verificações de JSF:** avisos no editor de xhtml para erros que o NetBeans não mostra, como um bean com nome digitado errado (`#{clienteVn.nome}` em vez de `#{clienteVm.nome}`).
- **Tema One Dark Pro Mix:** as cores do tema do VS Code, com o visual FlatLaf Dark e a fonte JetBrains Mono.

Cada módulo instala e desinstala separado.

## Instalação

Baixe o [`nbkit.zip`](https://github.com/gaesyeah/nb-kit/releases/latest/download/nbkit.zip) da última versão, descompacte e rode:

```bash
bash nbkit/nbkit.sh
```

O CLI mostra o status de cada módulo e só as opções que fazem sentido. Use ↑↓ para navegar, Enter para escolher e Esc para voltar.

- **Instalar ou atualizar:** escolha "Todos" ou um módulo.
- **Reinstalar** e **Desinstalar:** também por módulo.
- **Conferir se carregou no NetBeans:** confere cada módulo instalado.
- **Rodar os testes** e **Compilar os módulos:** só aparecem num clone do repositório (veja "Testes" e "Compilar os jars").
- **Backups:** só aparece quando existe algum. Enter restaura, Del apaga, Esc volta, e restaurar e apagar pedem confirmação.

Se o NetBeans estiver aberto, o nbkit oferece fechar pelo mesmo caminho do File > Exit, então o NetBeans pergunta sobre arquivos não salvos e processos rodando como sempre. No fim, oferece abrir o NetBeans e confere sozinho se tudo carregou (se você disser não, ele diz como conferir depois). Se algo falhar no meio, ou se você apertar Ctrl+C, tudo volta como estava.

### Interface gráfica

```bash
bash nbkit/nbkit.sh gui
```

Uma janela com as mesmas opções: os módulos com o status e os botões (ferramentas primeiro, depois temas), instalar ou atualizar, reinstalar e desinstalar todos de uma vez, o userdir, Backups (restaurar ou apagar cada um), Verificar e, num clone, Rodar os testes e Compilar os módulos. Embaixo, um terminal roda o próprio CLI, então você vê o mesmo progresso, as mesmas cores e mensagens, com uma barra de progresso em cima. Para copiar dele: selecione e aperte Ctrl+Shift+C, ou use o botão direito; sem seleção, copia tudo.

Toda pergunta do CLI também aparece como diálogo. Dá para responder nele ou digitando no terminal: o diálogo fecha sozinho. A senha do sudo, quando precisa, é digitada no terminal; a interface nunca vê a senha. Fechar a janela no meio de uma ação aperta Ctrl+C por você, então tudo volta como estava.

Precisa do GTK 4 e do VTE para GTK 4 (pelo PyGObject). Se faltarem, o nbkit oferece instalar (`python3-gi`, `gir1.2-gtk-4.0` e `gir1.2-vte-3.91` no Debian, Ubuntu e Pop!_OS; os nomes certos no Fedora, Arch e openSUSE). Funciona em qualquer ambiente gráfico (GNOME, KDE, XFCE, Cinnamon, COSMIC) e segue o tema GTK do sistema e a preferência de modo escuro, inclusive no terminal.

### Sem o menu

| Comando | O que faz |
|---|---|
| `bash nbkit.sh install [módulo...] [userdir]` | Instala ou atualiza (sem módulo: todos) |
| `bash nbkit.sh uninstall [módulo...] [userdir]` | Remove (sem módulo: todos os instalados) |
| `bash nbkit.sh check [userdir]` | Com o NetBeans aberto, confere se tudo carregou |
| `bash nbkit.sh gui [userdir]` | Abre a interface gráfica |
| `bash nbkit.sh status [--json] [userdir]` | O que está instalado; `--json` para programas (a interface usa) |
| `bash nbkit.sh restore <backup>` | Volta para um backup (os arquivos aparecem no `status --json`) |
| `bash nbkit.sh delete-backup <backup>` | Apaga um backup |
| `bash nbkit.sh test` | Roda os testes (no repositório, veja "Testes") |
| `bash nbkit.sh build` | Compila os jars a partir do `src/` (veja "Compilar os jars") |
| `bash nbkit.sh --help` | Ajuda e lista de módulos |
| `--lang pt-BR` ou `--lang en` | Junto com qualquer comando, troca o idioma |

Os ids dos módulos são `jsf` e `one-dark-pro-mix`. O userdir padrão é o NetBeans mais novo em `~/.netbeans/`; se houver mais de um, o menu pergunta qual usar.

## Idiomas

O terminal fala português ou inglês, conforme o idioma do sistema (`LANG`): português quando ele começa com `pt`, inglês nos outros casos. Para escolher, use `--lang pt-BR` ou `--lang en`, ou a variável `NBKIT_LANG`.

Dentro do NetBeans, as dicas do JSF e a tela de Options seguem o idioma em que o NetBeans roda, que vem do sistema ou do `--locale` no `netbeans.conf`.

Para adicionar um idioma:
- **Terminal:** copie `lang/en.lang` para `lang/<idioma>.lang` (ex.: `es.lang`) e traduza os valores. O `pt-BR.lang` é a referência: uma chave que faltar sai em português.
- **NetBeans:** crie `Bundle_<idioma>.properties` ao lado do `Bundle.properties` de cada módulo em `src/` e rode `bash src/build.sh` (veja "Compilar os jars").

## Requisitos

- Linux com bash 4 ou mais novo, e Python 3.11 ou mais novo. Se faltar, o nbkit oferece instalar pelo gerenciador de pacotes do sistema (apt, dnf, pacman ou zypper), ao lado do Python que você já tem.
- Apache NetBeans, testado na versão 31. Funciona com instalação normal, Flatpak ou Snap.
- NetBeans rodando com Java 17 ou mais novo. O `check` avisa se for mais antigo.
- `curl` ou `wget`, só se a JetBrains Mono precisar ser baixada. Sem nenhum dos dois, o nbkit oferece instalar o `curl`.
- Só para a interface gráfica: GTK 4 e VTE para GTK 4 com PyGObject (o nbkit oferece instalar).

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

Um tema é uma pasta em `modules/themes/` com três arquivos de dados, sem código. O nbkit acha a pasta sozinho e o tema aparece no menu. Todo o resto fica com o motor de temas (`lib/themes.sh`):

- criar o perfil de cores como cópia do perfil base da sua versão do NetBeans, sem mexer no original;
- fazer backup, restaurar, desinstalar e voltar ao visual e ao perfil de antes;
- preservar as personalizações de quem usa;
- instalar a fonte se ela faltar, e removê-la depois só se foi o nbkit que instalou;
- instalar o módulo de coloração (`nbkit-colors.jar`): chamadas, objetos, constantes, unidades, funções, colchetes por nível, DOCTYPE...;
- aplicar a cor de seleção do terminal;
- desfazer tudo com Ctrl+C;
- conferir com o NetBeans aberto (`check`).

```
modules/themes/meu-tema/
├── theme.toml      nome, versão, fonte, terminal
├── ui.properties   cores da interface (FlatLaf)
└── colors.toml     cores do editor
```

O nome da pasta é o id do tema (`bash nbkit.sh install meu-tema`): letras minúsculas, números e hífen.

### theme.toml

```toml
[theme]
name = "Meu Tema"
version = 1                       # aumente quando mudar as cores, para o menu oferecer a atualização
profile = "Meu Tema"              # opcional: nome do perfil em Tools > Options > Fonts & Colors (padrão: name)
description = { en = "Short description", pt-BR = "Descrição curta" }

[font]                            # opcional: sem ela, a fonte não é alterada
name = "JetBrains Mono"
dir = "JetBrainsMono"             # pasta em ~/.local/share/fonts
source = "repositório oficial da JetBrains"
urls = ["https://.../Regular.ttf", "https://.../Bold.ttf"]
license = "https://.../OFL.txt"

[terminal]                        # opcional: sem ela, o terminal não é alterado
selection = "#41454e"

[base]                            # opcional: perfil e visual em que o tema se baseia
folder = "FlatLafDark"            # estes são os padrões
name = "FlatLaf Dark"
profile = "FlatLaf Dark"
laf = "com.formdev.flatlaf.FlatDarkLaf"
laf_file = "FlatDarkLaf.properties"
```

Textos como `description` e `source` podem ser um texto só ou um por idioma, como acima.

### ui.properties

Chaves do FlatLaf (`@background`, `Component.focusColor`...), no mesmo formato do arquivo do próprio FlatLaf. A linha `nb.preferred.color.profile=<perfil>` faz o NetBeans manter o perfil do tema ao trocar de visual. O motor põe a marca do tema na primeira linha e mescla as chaves que a pessoa já tinha.

```properties
nb.preferred.color.profile=Meu Tema
@background=#1e1e1e
@foreground=#d4d4d4
```

### colors.toml

```toml
[all]                             # todas as linguagens
default = "#d4d4d4 on #1e1e1e"
comment = "#6a9955 italic"
keyword = "#569cd6"
error   = "on #3a2a2a wave #f14c4c"

[highlights]                      # seleção, linha atual, busca, números de linha...
selection = "on #264f78"

[annotations]                     # sublinhados de erro e aviso dos módulos

["text/x-java"]                   # uma linguagem, pelo tipo mime
method-declaration = "#dcdcaa bold"

["text/javascript".extra]         # nomes que a linguagem não declara, como as categorias do módulo de coloração
nbkit-call = "#dcdcaa"
```

Cada valor é um texto com, em qualquer ordem:

| Parte | Significado |
|---|---|
| `#rrggbb` | cor do texto |
| `on #rrggbb` | fundo |
| `bold`, `italic`, `bold italic`, `plain` | estilo da fonte (`plain` tira o negrito ou itálico da base) |
| `underline #rrggbb`, `wave #rrggbb`, `strike #rrggbb` | sublinhado, sublinhado ondulado, tachado |
| `inherits <token>` | pega o que não foi definido de outro token |

Uma cor que o tema não define fica como no perfil base. Para descobrir o nome de um token, mude a cor dele em Tools > Options > Fonts & Colors e veja o arquivo gravado em `~/.netbeans/<versão>/config/Editors/<mime>/FontsColors/`. Nomes com ponto vão entre aspas (`"markup.bold" = "#e5c07b bold"`).

Se um arquivo tiver erro, o nbkit ignora aquele tema e diz o arquivo, a linha e o que está errado:

```
Aviso: tema "meu-tema" ignorado: palavra desconhecida: "itallic" (em all / comment, linha 3)
```

Categorias do módulo de coloração, por linguagem (em `["<mime>".extra]`):

| Linguagem | Categorias |
|---|---|
| `text/javascript` | `nbkit-call`, `nbkit-object`, `nbkit-type`, `nbkit-constant`, `nbkit-library`, `nbkit-readonly`, `nbkit-library-function`, colchetes |
| `text/css` | `nbkit-unit`, `nbkit-function`, `nbkit-tag`, `nbkit-id`, `nbkit-attribute`, `nbkit-string`, `nbkit-plain`, `nbkit-url-parameter`, colchetes |
| `text/x-el` | `nbkit-call`, `nbkit-object`, `nbkit-library`, colchetes |
| `text/html` | `nbkit-plain`, `nbkit-doctype`, `nbkit-attribute`, `nbkit-string` |
| `text/xml`, `text/xml-external-parsed-entity` | `nbkit-plain`, `nbkit-attribute`, `nbkit-string`, `nbkit-keyword`, `nbkit-documentroot`, `nbkit-doctype` |
| `text/x-java`, `text/x-json` | colchetes |

Os colchetes são `nbkit-bracket1`, `nbkit-bracket2` e `nbkit-bracket3`, um por nível, e `nbkit-bracket-unexpected` para o colchete sem par.

A `modules/themes/one-dark-pro-mix/` é um exemplo completo.

## Criar uma ferramenta

Uma ferramenta é uma pasta em `modules/tools/` com um `tool.toml`: nome, versão e, se for um módulo do NetBeans, o jar
dele. O nbkit acha sozinho e o motor de ferramentas (`lib/tools.sh`) dá a ela instalar, atualizar, desinstalar, o ponto
de restauração e o `check`. O que é específico de uma ferramenta vai num `tool.sh` opcional ao lado. Veja [como criar uma
ferramenta](modules/README.pt-BR.md).

### Compilar os jars

Os jars já vêm compilados em `lib/jars/` e `modules/tools/jsf/`. Para compilar de novo a partir do `src/`, depois de mudar o código Java ou os textos:

```bash
bash src/build.sh [pasta do netbeans]     # ou: bash nbkit.sh build
```

Ele compila contra os jars da sua instalação do NetBeans (sem a pasta: `NB_HOME`, ou o NetBeans que usou o `~/.netbeans` por último) com um JDK 17 ou mais novo, e atualiza os sha256. `bash src/build.sh --help` mostra as opções.

## Estrutura

```
nbkit/
├── nbkit.sh                     CLI: argumentos, menu e ações
├── lang/                        textos do terminal: pt-BR.lang (referência) e en.lang
├── lib/                         código usado pelo CLI
│   ├── terminal.sh              cores, idioma, funções de saída, menu de setas
│   ├── packages.sh              instala o que falta pelo gerenciador de pacotes (apt, dnf, pacman, zypper)
│   ├── registry.sh              registro dos módulos e as funções que os motores dividem
│   ├── netbeans.sh              userdirs, NetBeans aberto ou fechado, abrir e fechar
│   ├── restore.sh               ponto de restauração (tudo volta num erro ou Ctrl+C)
│   ├── backups.sh, status.sh    backups e status (também o "status --json" da interface)
│   ├── themes.sh, themes/       motor de temas e as partes em Python dele (veja "Criar um tema")
│   ├── tools.sh, tools/         motor de ferramentas e a parte em Python dele (veja "Criar uma ferramenta")
│   ├── text.py, toml_data.py    textos de lang/ e funções para os arquivos TOML, para as partes em Python
│   ├── uievents.py              eventos para a interface (perguntas) vindos das partes em Python
│   ├── gui.sh                   o que a interface precisa (GTK 4, VTE) e como achar
│   ├── gui/                     interface gráfica: model.py (sem GTK, testado sozinho) e app.py (janela)
│   └── jars/                    módulos base: nbkit-core (fecha o NetBeans) e nbkit-colors (usado pelos temas)
├── modules/                     só dados
│   ├── README.md                como criar uma ferramenta
│   ├── tools/
│   │   └── jsf/                 tool.toml + nbkit-jsf.jar
│   └── themes/
│       └── one-dark-pro-mix/    theme.toml, ui.properties, colors.toml
├── src/                         código Java dos módulos do NetBeans
│   ├── build.sh                 compila os jars (veja abaixo)
│   ├── nbkit-core/
│   ├── nbkit-colors/
│   └── nbkit-jsf/               com o teste em test/
├── tests/                       testes (veja "Testes")
└── .github/workflows/tests.yml  roda os testes no GitHub Actions
```

## Testes

```bash
bash nbkit.sh test
```

Roda tudo o que está em `tests/`, e também no GitHub Actions a cada push:

- **Lint:** shellcheck e pyflakes.
- **Testes unitários de Python** (`tests/python/`): o formato do `colors.toml` e as mensagens de erro, a validação do `theme.toml` e do `tool.toml`, os arquivos de `lang/` (mesmas chaves em todos os idiomas, toda chave usada no código existe) e o modelo da interface (status, botões, comandos, eventos, progresso e perguntas).
- **Motor** (`tests/engine.sh`): instala num NetBeans falso (`tests/netbeans/`) e confere que os arquivos são exatamente os esperados (`tests/expected/install.sha1`), que reinstalar mantém as suas personalizações, que o `check` acha um módulo faltando, que desinstalar volta exatamente ao que havia, que uma falha em qualquer passo não muda nada, que arquivos com erro são ignorados com o motivo, o que a interface usa (`status --json`, os eventos de passo e de pergunta, `restore` e `delete-backup`), uma ferramenta feita só de `tool.sh` e uma instalação por cima do que o instalador de antes do nbkit deixou.
- **Verificações de JSF** (`tests/jsf.sh`, precisa de JDK 17 ou mais novo): roda o analisador no projeto de exemplo em `src/nbkit-jsf/test/fixture`, cujas páginas marcam onde cada aviso deve aparecer, em inglês e em português.
- **Interface gráfica** (`tests/gui.sh`, numa tela virtual com Xvfb): abre a janela com o NetBeans falso e usa como uma pessoa usaria: instala e desinstala pelos botões, acompanha a barra de progresso, responde perguntas no diálogo e no terminal, apaga um backup, abre o Sobre, fecha a janela no meio de uma instalação para conferir que tudo volta e confere que segue o modo escuro do sistema.

O que precisa, além do bash e do Python 3.11:

| Ferramenta | Para | Instalar (Debian, Ubuntu, Pop!_OS) |
|---|---|---|
| shellcheck | lint dos arquivos bash | `sudo apt install shellcheck` |
| pyflakes | lint dos arquivos Python | `sudo apt install python3-pyflakes` |
| JDK 17 ou mais novo (`javac`, `jar`, `java`) | verificações de JSF | `sudo apt install openjdk-21-jdk-headless` (ou 17) |
| GTK 4, VTE e PyGObject | interface | `sudo apt install python3-gi gir1.2-gtk-4.0 gir1.2-vte-3.91` |
| xvfb-run | interface (tela virtual) | `sudo apt install xvfb` |

As verificações de JSF não precisam de mais nada: as bibliotecas que o projeto de exemplo usa (anotações do Spring e do Jakarta e um componente do PrimeFaces) são versões mínimas em `src/nbkit-jsf/test/libs/`, compiladas pelo próprio teste.

Se faltar alguma ferramenta, o `bash nbkit.sh test` oferece instalar pelo gerenciador de pacotes do sistema (apt, dnf, pacman ou zypper), com o nome certo do pacote em cada um, perguntando antes. Sem terminal para perguntar (como no GitHub Actions), ou se você disser não, aquela parte é pulada com aviso. Quando uma mudança num tema altera de propósito os arquivos instalados, `bash tests/engine.sh --update` grava de novo a lista esperada. `bash src/build.sh --test` compila os jars e roda as verificações de JSF.

Os testes não substituem abrir o NetBeans: as dicas e as cores na tela ainda precisam de uma olhada.

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
