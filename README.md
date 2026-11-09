# nbkit

Kit de módulos para o **Apache NetBeans** no Linux, instalado por um CLI no terminal. Hoje tem dois módulos:

- **Tema One Dark Pro Mix:** as cores do tema do VS Code, com o visual FlatLaf Dark e a fonte JetBrains Mono.
- **Verificações de JSF:** avisos no editor de xhtml para erros que o NetBeans não mostra, como `#{batataDoce}`.

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

Os ids dos módulos são `one-dark-pro-mix` e `jsf`. O userdir padrão é o NetBeans mais novo em `~/.netbeans/`; se houver mais de um, o menu pergunta qual usar.

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

## Verificações de JSF

O NetBeans checa tags, atributos e a sintaxe do EL, mas não pega erros que só aparecem rodando, ou que nem aparecem. Este módulo marca esses erros no editor:
- **Vermelho:** quebra com certeza.
- **Amarelo:** provável erro, ou depende de algo fora do arquivo.

Cada regra liga e desliga em **Tools > Options > Editor > JSF**.

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
├── modulos/
│   ├── LEIAME.md                como criar um módulo
│   ├── temas/one-dark-pro-mix.sh
│   └── jsf.sh
└── fontes/                      código Java dos módulos do NetBeans
```

Para adicionar um módulo, basta colocar um `.sh` em `modulos/` seguindo o [contrato](modulos/LEIAME.md).

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
