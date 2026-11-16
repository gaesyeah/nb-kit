---
title: "nbkit brainstorm"
source: "https://chatgpt.com/c/6af79548-14b4-83e9-b699-559d42dfd808"
site: ChatGPT
messages: 18
tags:
  - ai-chat
  - chatgpt
---

## User

da pra codar em js, ts, react angular e etc no NetBeans?

## ChatGPT

Sim! Dá para desenvolver **JavaScript, TypeScript, React, Angular, HTML, CSS e outras tecnologias web no NetBeans**.

Mas existe uma diferença importante: o NetBeans é tradicionalmente mais voltado para Java, então o suporte ao ecossistema JavaScript/TypeScript não é tão completo quanto no VS Code ou WebStorm.

### O que você consegue desenvolver?

| Tecnologia | NetBeans |
|---|---|
| HTML / CSS | <badge color="success">Sim</badge> |
| JavaScript | <badge color="success">Sim</badge> |
| TypeScript | <badge color="warning">Limitado</badge> |
| React | <badge color="warning">Via configuração</badge> |
| Angular | <badge color="warning">Via configuração</badge> |
| Node.js | <badge color="warning">Via configuração</badge> |
| Java / Spring | <badge color="success">Muito bom</badge> |

Você pode criar projetos React e Angular pelo terminal integrado ou externo usando npm, Vite e Angular CLI, por exemplo.

Na prática, o NetBeans consegue abrir e editar esses projetos, mas você não terá necessariamente a mesma experiência de desenvolvimento de um IDE especializado.

O Apache NetBeans atual (versão 31) continua anunciando suporte a JavaScript e HTML. Também existe suporte a editor TypeScript.[^1][^2]

### Minha recomendação

Se você pretende trabalhar com React, TypeScript, Angular e Node.js profissionalmente, eu escolheria:

- **VS Code:** melhor equilíbrio para esse ecossistema.
- **WebStorm:** IDE mais completo, mas pago.
- **NetBeans:** excelente se seu foco também for Java, Spring e projetos corporativos Java.

Você pode inclusive manter os dois instalados: NetBeans para Java e VS Code para o ecossistema JavaScript.

**Uma dúvida:** você quer usar o NetBeans porque já está acostumado com ele ou porque precisa utilizá-lo em algum projeto/empresa?

[^1]: [Welcome to Apache NetBeans](https://netbeans.apache.org/front/main/index.html?RewriteStatus=1&utm_source=chatgpt.com)
[^2]: [Apache NetBeans 12.0 Features](https://netbeans.apache.org/front/main/download/nb120/?utm_source=chatgpt.com)

## User

só curiosidade, oq falta é oq? os temas n funcionam direito? n tem validação?

## ChatGPT

É mais ou menos isso! Mas não significa que o NetBeans não tenha essas funcionalidades. A diferença é o **quanto elas estão integradas e adaptadas ao ecossistema**.

Vou separar por funcionalidade:

### 1. Temas e aparência

- Temas escuros e claros: sim.
- Coloração de sintaxe: sim.
- Personalização de cores: sim.
- Temas específicos para React, JSX e TSX: pode haver limitações na cobertura e na qualidade da coloração.

Não é que os temas necessariamente não funcionem, mas a experiência pode ser menos refinada.

### 2. Autocomplete e IntelliSense

Aqui começa uma diferença mais importante.

No VS Code, com as extensões adequadas, você tem integração profunda com TypeScript e os frameworks.

Por exemplo, em React:

```tsx
function UserCard({ name, age }: UserProps) {
  return <h1>{name}</h1>;
}
```

O editor consegue:
- Sugerir propriedades de componentes.
- Identificar propriedades inexistentes.
- Inferir tipos.
- Navegar até a definição de componentes.
- Mostrar documentação ao passar o mouse.

No NetBeans, não conte com a mesma qualidade de integração para TSX e JSX.

### 3. Validação e diagnóstico

Aqui vale distinguir duas coisas:

| Recurso | NetBeans |
|---|---|
| Identificar erros de sintaxe JS | Sim |
| Identificar erros de TypeScript | Suporte menos integrado |
| Validar JSX/TSX | Limitado |
| ESLint | Integração menos completa |
| Prettier | Pode usar externamente |
| TypeScript Compiler (`tsc`) | Pode executar normalmente |
| Testes com Jest/Vitest | Via ferramentas externas |

Ou seja: **o NetBeans não impede que você tenha validação**. O compilador TypeScript, ESLint e os próprios frameworks continuam funcionando independentemente do editor.

### 4. Angular e React

Uma diferença particularmente relevante é o suporte aos serviços de linguagem.

O Angular Language Service, por exemplo, oferece autocomplete, diagnóstico de erros e navegação em templates. Sua integração oficial contempla VS Code, WebStorm, Sublime Text, Zed, Neovim e Eclipse, mas não NetBeans.[^3]

### 5. O que você realmente perde?

Principalmente produtividade e integração:

- Refatoração inteligente de componentes.
- Autocomplete contextual.
- Diagnósticos em tempo real.
- Navegação entre componentes e templates.
- Integração com ferramentas de desenvolvimento.
- Ecossistema de extensões.

O próprio Apache tem uma documentação que trata essas funcionalidades como partes distintas da implementação de suporte a uma linguagem.[^4]

**Minha conclusão:** você consegue desenvolver praticamente qualquer aplicação web no NetBeans. O problema não é capacidade de executar o projeto, mas a qualidade das ferramentas que ajudam você enquanto escreve o código. É justamente aí que VS Code e WebStorm levam vantagem.

[^3]: [Language Service](https://angular.dev/tools/language-service?utm_source=chatgpt.com)
[^4]: [Adding New Language Support - NetBeans](https://cwiki.apache.org/confluence/spaces/NETBEANS/pages/173084490/Adding%2BNew%2BLanguage%2BSupport?utm_source=chatgpt.com)

## User

uma dúvida, o NetBeans é bem customizável, certo? inclusive com código, java, posso criar módulos que conversam com a api do NetBeans e fazer customizações agressivas... teoricamente não posso implementar tudo que falta nele de js/ts, jsx e tax?

## ChatGPT

Exatamente. E vou além: **você poderia transformar o NetBeans em uma IDE bastante completa para desenvolvimento moderno com JavaScript, TypeScript, React e Angular, sem precisar reinventar os compiladores ou ferramentas dessas tecnologias.**

Sua ideia é perfeitamente viável. A arquitetura modular do NetBeans foi pensada justamente para permitir esse tipo de extensão.

Inclusive, a documentação oficial da Apache tem um guia específico chamado *Adding New Language Support*.[^5][^6]

## Como eu faria isso

Eu dividiria o desenvolvimento em módulos independentes.

**NetBeans Web Development Suite**

**Core Web Support**

<small>Infraestrutura compartilhada</small>

{#each [{name:"JavaScript",desc:"Editor, análise e debugging"},{name:"TypeScript",desc:"Tipos, inferência e refatoração"},{name:"JSX / TSX",desc:"Componentes e templates"},{name:"HTML / CSS",desc:"Validação e IntelliSense"},{name:"React",desc:"Hooks, props e componentes"},{name:"Angular",desc:"Templates e Language Service"}] as item} **{item.name}** {item.desc} {/each}

**Integração com ferramentas externas**

<small>TypeScript Server · Angular Language Service · ESLint · Prettier · Vite · npm</small>

## 1. Não implemente tudo em Java

Esse é provavelmente o maior segredo para não transformar o projeto em um monstro.

Você pode aproveitar ferramentas que já existem:

| Ferramenta | Responsabilidade |
|---|---|
| TypeScript Language Server | Inteligência de TypeScript |
| Angular Language Service | Templates Angular |
| ESLint | Análise estática |
| Prettier | Formatação |
| Vite | Desenvolvimento React |
| npm | Gerenciamento de dependências |

O NetBeans funcionaria como cliente dessas ferramentas.

## 2. Use LSP

O Language Server Protocol é particularmente interessante.

Ele permite que o NetBeans converse com servidores especializados por JSON-RPC, sem precisar implementar toda a inteligência das linguagens em Java.

O próprio NetBeans possui uma API para integração com LSP e documentação oficial mostrando como implementar `LanguageServerProvider`.[^7][^8]

Isso abre caminho para:

- Autocomplete inteligente.
- Go to Definition.
- Find References.
- Diagnósticos em tempo real.
- Documentação ao passar o mouse.
- Code Actions.
- Refatoração.

## 3. Desenvolva os recursos nativos que faltarem

Nem tudo precisa ser delegado ao LSP.

Você pode criar módulos Java para:

- Integração com o gerenciador de projetos.
- Templates de projetos React e Angular.
- Interface de configuração.
- Gerenciamento de servidores de desenvolvimento.
- Integração com npm e scripts.
- Painel de problemas.
- Integração com Git.
- Personalização do editor e atalhos.

O NetBeans oferece APIs e SPIs para várias dessas funcionalidades.[^9][^10]

## 4. O maior cuidado: manutenção

Existem alguns desafios reais:

- Compatibilidade entre versões das APIs do NetBeans.
- Integração de JSX/TSX com o editor.
- Desempenho em projetos grandes.
- Sincronização de diagnósticos de diferentes ferramentas.
- Gerenciamento de processos externos.
- Experiência consistente entre os módulos.

Outro detalhe: algumas APIs internas do editor ainda estão em evolução, então é importante priorizar APIs públicas e estáveis quando possível.

---

## Minha conclusão

Sim, você poderia chegar a uma experiência comparável à de IDEs especializadas.

E tem uma vantagem interessante: não precisaria abandonar a arquitetura Java do NetBeans. Seus módulos poderiam ser escritos em Java, enquanto os servidores de linguagem e ferramentas seriam executados separadamente.

Eu particularmente começaria com um projeto chamado **NetBeans Web Tools**, com suporte completo a TypeScript e TSX via LSP. Depois adicionaria React, Angular e ferramentas de build.

Isso seria um projeto de extensão bastante interessante, inclusive com potencial para contribuir com o próprio Apache NetBeans.

[^5]: [NetBeans Platform Learning Trail](https://netbeans.apache.org/tutorial/main/kb/docs/platform/?utm_source=chatgpt.com)
[^6]: [Adding New Language Support - NetBeans](https://cwiki.apache.org/confluence/spaces/NETBEANS/pages/173084490/Adding%2BNew%2BLanguage%2BSupport?utm_source=chatgpt.com)
[^7]: [Using Language Server Protocol (LSP) - NetBeans](https://cwiki.apache.org/confluence/spaces/NETBEANS/pages/263425900/Using%2BLanguage%2BServer%2BProtocol%2BLSP?utm_source=chatgpt.com)
[^8]: [Official page for Language Server Protocol](https://microsoft.github.io/language-server-protocol/?utm_source=chatgpt.com)
[^9]: [Apache NetBeans Development Version Documentation](https://bits.netbeans.org/dev/javadoc/?utm_source=chatgpt.com)
[^10]: [NetBeans Platform Tutorials](https://netbeans.apache.org/tutorial/main/tutorials/?utm_source=chatgpt.com)

## User

consegue ler projetos opensource do git? só por curiosidade

## ChatGPT

Sim! Consigo analisar projetos open source hospedados no GitHub e em outros serviços Git.

Posso examinar tanto projetos pequenos quanto repositórios grandes, incluindo:

- Estrutura de diretórios e arquitetura.
- Código-fonte em Java, JavaScript, TypeScript etc.
- APIs públicas e internas.
- Sistema de módulos e dependências.
- Issues, pull requests e histórico de commits.
- Como determinada funcionalidade foi implementada.
- Pontos de extensão para criar plugins ou modificar o projeto.

Também posso comparar versões e investigar como uma funcionalidade funciona internamente.

Inclusive, podemos fazer algo bem interessante: analisar o próprio código-fonte do NetBeans para descobrir exatamente onde implementar cada recurso.

Por exemplo, o repositório oficial:

| | |
|---|---|
| ** | apache/netbeans · ** · Open source |

Ele tem milhares de commits e centenas de módulos. A estrutura inclui `webcommon`, `ide`, `platform`, `extide` e outros.[^11][^12]

**Uma coisa importante:** não fico limitado ao README ou à documentação. Posso investigar implementações concretas, acompanhar chamadas entre classes e entender como os módulos se comunicam.

Se você me passar uma URL de um repositório, posso fazer uma análise arquitetural ou investigar uma funcionalidade específica.

[^11]: [GitHub](https://github.com/apache/netbeans?utm_source=chatgpt.com)
[^12]: [There sure are a lot of modules in the source tree. What are they for?](https://netbeans.apache.org//wiki/main/netbeansdevelopperfaq/DevFaqSourceTreeModuleDescriptions/?utm_source=chatgpt.com)

## User

na verdade, eu já tenho um início de projeto pra isso

https://github.com/gaesyeah/nb-kit

ele começou sendo só um bash pra aplicar o one dark pro mix do vs code no netbeans, e hoje estou trabalhando pra ele melhorar as validações de jsf 

eu sou dev Full stack com foco em front end, com mais experiência em react, e fui codar em jsf e achei estranho, porque lá é muito fraco, acontecem vários erros invisíveis, e descobri que o suporte a jsf do netbeans é fraco, já que não usam muito hj em dia não tem porque dar tanto suporte, existem coisas mais importantes....

hj esse projeto funciona com uma mistura de muita coisa, bash, python, java (que faz as validações jsf) e gtk, ainda estou melhorando ele e tem mt ainda pra deixar as validações 100%, depois disso vou fazer o backend dele ser todo em Java, e o front tmb em java, mas com swing e flatleaf, e aí ele vai rodar dentro do próprio netbeans 

oq quero saber é, vale a pena já estando tão avançado eu usar lsp? ou deixo para quando eu for criar os módulos de ts, TSX e etc

## ChatGPT

Opa, agora que você explicou o contexto do `nb-kit`, minha recomendação muda um pouco: **eu não migraria o projeto inteiro para LSP agora. Mas também não deixaria para pensar nisso só quando chegar ao TypeScript.**

Acho que existe uma oportunidade arquitetural interessante no que você já está construindo.

Seu projeto tem dois objetivos diferentes:

1. Melhorar funcionalidades que o NetBeans já deveria oferecer, como as validações de JSF.
2. Adicionar suporte de qualidade a tecnologias modernas, como TypeScript, React, JSX e TSX.

Esses dois objetivos podem compartilhar uma infraestrutura, mas não precisam compartilhar a implementação de todas as regras.

Quero olhar a estrutura real do seu repositório antes de recomendar uma divisão mais concreta.

## O que observei no nb-kit

Dei uma olhada no repositório e gostei de uma decisão arquitetural que você já tomou: a separação entre o motor de instalação e os módulos.

Hoje você já tem:

- `nbkit-jsf`: módulo Java de validação.
- `nbkit-colors`: módulo de coloração.
- `nbkit-core`: funcionalidades compartilhadas.
- `lib/tools.sh` e `lib/themes.sh`: motores de gerenciamento dos módulos.
- Testes separados para o mecanismo de instalação, interface e validações JSF.[^13]

Isso é importante porque você já está caminhando para uma arquitetura extensível, em vez de criar um programa monolítico.

E tem um detalhe: seu módulo JSF já faz algo que um servidor LSP precisaria fazer de qualquer maneira: entender o contexto do projeto, consultar classes compiladas, bibliotecas do classpath e até código-fonte ainda não compilado.[^13]

## Minha recomendação: não coloque LSP no coração do nb-kit

Eu separaria três camadas:

**nb-kit core**

<small>Análise semântica, regras, diagnósticos e configurações</small>

| | |
|---|---|
|  |  |

**NetBeans adapter** Hints, editor, projetos, classpath e APIs nativas JSF atual **LSP adapter** Diagnostics, completion, navigation e code actions Futuro

Assim, suas regras de validação não ficam acopladas ao NetBeans nem ao protocolo LSP.

Se um dia você quiser executar o analisador JSF fora do NetBeans, por exemplo em outra IDE, poderia criar um servidor LSP reaproveitando o mesmo motor.

Mas eu não faria isso agora.

## Por que eu manteria JSF nativo?

Porque JSF tem particularidades que tornam a integração com o NetBeans muito valiosa.

Pense nas validações que você já implementou:

- Resolução de EL (`#{bean.property}`).
- Identificação de beans CDI, Spring e ManagedBean.
- Resolução de propriedades e métodos Java.
- Verificação de componentes PrimeFaces.
- Análise de escopo de variáveis de `ui:repeat` e `p:dataTable`.
- Resolução de IDs e referências entre componentes.

Para isso, o NetBeans já possui infraestrutura de projetos Java, parsing, indexação, classpath e integração com o editor.

Um servidor LSP independente teria que receber e manter boa parte desse contexto. Você poderia acabar duplicando infraestrutura que já existe.

**Eu aproveitaria as APIs nativas do NetBeans para JSF ao máximo.**

## E para TypeScript, React e Angular?

Aí minha resposta é diferente.

| Tecnologia | Minha escolha |
|---|---|
| JSF / Facelets / EL | APIs nativas do NetBeans |
| JavaScript | Avaliar suporte nativo + LSP |
| TypeScript | LSP |
| JSX / TSX | LSP + integração de editor |
| Angular | Angular Language Service |
| CSS / HTML | Suporte nativo + ferramentas especializadas |

Para TypeScript, você já tem um ecossistema maduro de servidores de linguagem. Seria desperdício implementar do zero coisas que o TypeScript Language Server já resolve.

## Uma observação sobre sua futura interface

Como o NetBeans é construído sobre Swing, eu também consideraria utilizar diretamente a infraestrutura visual da plataforma:

- Window System para janelas e painéis.
- Options API para configurações.
- Nodes API para árvores de projetos.
- Explorer API para visualizações.
- Editor APIs para integração com o código.

FlatLaf pode continuar fazendo parte da identidade visual, mas você não precisa construir uma aplicação Swing independente dentro do NetBeans.

---

## Minha decisão para o nb-kit

<badge color="success">Recomendação</badge>

1. Continue evoluindo o analisador JSF atual.
2. Migre a lógica para Java, separando as regras de análise das APIs de apresentação do NetBeans.
3. Faça essa lógica funcionar independentemente da interface.
4. Quando começar TypeScript/TSX, implemente uma infraestrutura de integração LSP.
5. Se fizer sentido posteriormente, crie um adaptador LSP para o próprio analisador JSF.

A ideia central é: **o nb-kit deve ser dono da inteligência das funcionalidades que ele implementa, mas não precisa ser dono dos motores de linguagem que já existem.**

E sinceramente, acho que seu projeto está tomando um rumo bem mais interessante do que simplesmente criar um instalador de temas. Você está construindo uma camada de melhorias para o NetBeans, preenchendo lacunas que a IDE deixou de priorizar.

[^13]: [GitHub - gaesyeah/nb-kit: Kit of modules for Apache NetBeans on Linux: One Dark Pro Mix theme and JSF checks, installed by a terminal CLI.](https://github.com/gaesyeah/nb-kit?utm_source=chatgpt.com)

## User

as extensões do vscode para react, angular e etc usam lsp? são código aberto?

## ChatGPT

Sim! E tem uma informação muito interessante para o seu projeto: **boa parte da inteligência que faz o VS Code ser tão bom com React, TypeScript e Angular já está disponível em projetos open source.**

Mas existe uma particularidade: nem todas as extensões usam LSP. O VS Code tem uma API própria de extensões e também permite integração com Language Servers.

## 1. TypeScript e JavaScript

| | |
|---|---|
| **TypeScript Language Features** Microsoft · Código aberto [Código-fonte no GitHub](https://github.com/microsoft/vscode/tree/main/extensions/typescript-language-features) |  |

Essa é uma das partes mais importantes do VS Code.

Ela utiliza o `tsserver`, que é o servidor de inteligência do próprio TypeScript.

Oferece:
- Autocomplete.
- Inferência de tipos.
- Diagnósticos.
- Go to Definition.
- Refatoração.
- Rename Symbol.
- Code Actions.

**Detalhe importante:** a implementação original do VS Code não utiliza LSP para conversar com o `tsserver`. Utiliza uma API própria do TypeScript.[^14][^15]

Existe uma alternativa que utiliza LSP:

[typescript-language-server](https://github.com/typescript-language-server/typescript-language-server)

É open source e mantido pela comunidade TypeFox.[^16]

## 2. React

| | |
|---|---|
| **ES7+ React/Redux/React-Native snippets** Comunidade · Código aberto [Código-fonte](https://github.com/ults-io/vscode-react-javascript-snippets) |  |

React é um caso interessante porque não depende de um único servidor de linguagem.

O suporte costuma ser composto por:

- TypeScript Language Features para TSX.
- JavaScript/TypeScript para análise.
- Extensões de snippets.
- ESLint para diagnóstico.
- Prettier para formatação.
- Extensões específicas para JSX e React.

Ou seja, não existe necessariamente um único React Language Server responsável por tudo.

## 3. Angular

| | |
|---|---|
| **Angular Language Service** Equipe oficial Angular · Código aberto [Extensão VS Code](https://github.com/angular/vscode-ng-language-service) [Código-fonte do Angular](https://github.com/angular/angular) |  |

Esse é especialmente interessante para o nb-kit.

Ele oferece:
- Autocomplete em templates.
- Validação de propriedades.
- Verificação de tipos em templates.
- Navegação entre componentes.
- Diagnósticos.
- Informações sobre diretivas e pipes.

Uma particularidade: o Angular Language Service utiliza o `tsserver` e não segue exatamente a especificação LSP.[^17][^18]

## 4. O que eu estudaria para o nb-kit

| | |
|---|---|
| **TypeScript Language Service** Aproveitar a inteligência de JS/TS e TSX. | Prioridade |
| **Angular Language Service** Reutilizar validações e inteligência de templates. |  |
| **ESLint** Diagnósticos e correções automáticas. |  |
| **VS Code Extension API** Estudar como a integração entre editor e ferramentas funciona. |  |

## 5. Uma descoberta importante para sua arquitetura

Eu não assumiria que LSP é obrigatório só porque você quer aproveitar ferramentas do VS Code.

Existem duas abordagens:

| Abordagem | Vantagem |
|---|---|
| LSP | Protocolo padronizado, reutilizável entre IDEs |
| API própria do servidor | Acesso a recursos específicos que o LSP não expõe |

O `tsserver`, por exemplo, oferece uma interface própria que o VS Code utiliza diretamente.

Minha sugestão é estudar os dois modelos antes de definir a arquitetura definitiva do nb-kit.

**E uma possibilidade muito interessante:** você poderia construir uma integração Java com o `tsserver` por meio de seu protocolo, sem precisar implementar um servidor TypeScript em Java ou depender exclusivamente de um servidor LSP intermediário.

Isso seria uma excelente linha de investigação para o projeto.

[^14]: [Language Extensions Overview](https://code.visualstudio.com/api/language-extensions/overview?ocid=AID3042760&utm_source=chatgpt.com)
[^15]: [Debugging Language Service in VS Code · microsoft/TypeScript Wiki](https://github.com/microsoft/TypeScript/wiki/Debugging-Language-Service-in-VS-Code?utm_source=chatgpt.com)
[^16]: [GitHub - typescript-language-server/typescript-language-server: Unofficial TypeScript & JavaScript Language Server](https://github.com/typescript-language-server/typescript-language-server?utm_source=chatgpt.com)
[^17]: [Language Service](https://angular.dev/tools/language-service?utm_source=chatgpt.com)
[^18]: [Language Service](https://v21.angular.dev/tools/language-service?utm_source=chatgpt.com)

## User

então depois de finalizar o jsf usando java, e migrar o projeto inteiro pra java/swing usando as apis do netbeans, a ideia vai ser estudar tudo isso e tentar implementar suporte para o ecossistema ts, usando o mínimo de código novo e invenções novas possível?

## ChatGPT

Exatamente. E acho que essa é a estratégia mais inteligente para o nb-kit.

Eu resumiria sua filosofia de desenvolvimento assim:

**Não reinventar ferramentas que já resolvem o problema. Construir a integração que falta entre essas ferramentas e o NetBeans.**

Seu roadmap ficaria mais ou menos assim:

## Roadmap do nb-kit

  <list-item>
    **Finalizar o suporte a JSF**

    - Completar as validações.
    - Melhorar a análise semântica.
    - Resolver falsos positivos e erros invisíveis.
    - Garantir testes abrangentes.
  </list-item>
  <list-item>
    **Consolidar a arquitetura Java**

    - Migrar o backend para Java.
    - Migrar a interface para Swing.
    - Utilizar FlatLaf.
    - Integrar com as APIs nativas do NetBeans.
    - Transformar o nb-kit em módulos instaláveis na IDE.
  </list-item>
  <list-item>
    **Estudar o ecossistema TypeScript**

    Investigar:
    - TypeScript Compiler API.
    - TypeScript Language Server.
    - tsserver.
    - LSP.
    - Angular Language Service.
    - ESLint e Prettier.
  </list-item>
  <list-item>
    **Implementar suporte ao ecossistema JS/TS**

    - JavaScript.
    - TypeScript.
    - JSX / TSX.
    - React.
    - Angular.
    - Diagnósticos, autocomplete e navegação.
  </list-item>
  <list-item>
    **Consolidar o ecossistema nb-kit**

    Criar uma experiência integrada, com módulos independentes, configurações compartilhadas e ferramentas reutilizáveis.
  </list-item>

## Três princípios que eu manteria

1. **Reutilizar antes de implementar:** se o TypeScript já faz inferência de tipos, não implemente outra inferência em Java.
2. **Integração nativa quando possível:** se o NetBeans já oferece uma API para determinada funcionalidade, aproveite-a.
3. **Independência entre regras e interfaces:** suas validações devem poder funcionar sem depender diretamente de Swing, GTK ou componentes visuais do NetBeans.

Uma ressalva arquitetural: eu não faria a migração para Swing significar necessariamente abandonar as APIs visuais próprias do NetBeans. Usaria a plataforma para janelas, painéis, opções e integração com o editor.

**E tem algo que considero especialmente interessante:** você começou tentando resolver um problema visual de temas, encontrou problemas de validação em JSF e acabou chegando à possibilidade de construir uma camada de modernização do NetBeans.

Isso pode se tornar um projeto muito maior do que um conjunto de plugins. Pode ser um ecossistema de ferramentas que prolongue a utilidade do NetBeans para desenvolvedores que trabalham com tecnologias modernas.

## User

mais ainda, ele poderia ter apis próprias para outras pessoas desenvolverem suporte a outras tecnologias modernas, imagina aí codar em go no netbeans

## ChatGPT

Rapaz, aí você começou a descrever algo muito maior que um conjunto de extensões. Você está falando de criar uma espécie de **plataforma de modernização e extensibilidade do NetBeans**.

E a parte mais interessante é justamente essa: o nb-kit não precisaria implementar suporte a todas as linguagens. Ele poderia fornecer uma infraestrutura para que outras pessoas implementassem esse suporte.

Imagina o seguinte:

## nb-kit como uma plataforma

**nb-kit**

Core Platform

<small>Infraestrutura compartilhada</small>

{#each [{n:"Language API",d:"Integração de linguagens"},{n:"Diagnostics API",d:"Validações e problemas"},{n:"Project API",d:"Projetos e configurações"},{n:"Editor API",d:"Autocomplete e navegação"},{n:"Tooling API",d:"Compiladores e ferramentas"},{n:"UI API",d:"Painéis e configurações"}] as x} **{x.n}** {x.d} {/each}

**Extensões desenvolvidas pela comunidade**

{#each [{n:"Go",i:"🐹"},{n:"Rust",i:"🦀"},{n:"Python",i:"🐍"},{n:"TypeScript",i:"💙"},{n:"Kotlin",i:"🟣"},{n:"PHP",i:"🐘"}] as x} {x.i} **{x.n}** {/each}

## Imagina desenvolver em Go no NetBeans

Uma extensão `nbkit-go`, por exemplo, poderia integrar:

- `gopls`: autocomplete, navegação, diagnósticos e refatoração.
- `go build`: compilação.
- `go test`: execução de testes.
- `go fmt`: formatação.
- Delve (`dlv`): debugging.
- Go Modules: gerenciamento de dependências.

Boa parte da inteligência já existe. O trabalho seria conectar essas ferramentas às APIs do nb-kit e às APIs do NetBeans.

O mesmo princípio serviria para Rust com `rust-analyzer`, Python com Pyright, PHP com Intelephense ou outros servidores e ferramentas.

## O segredo seria criar uma API realmente boa

Eu pensaria em algo como:

```java
public interface LanguageSupport {

    String getLanguageId();

    void registerEditorSupport();

    void registerDiagnostics();

    void registerProjectSupport();

    void registerTooling();

}
```

Isso é apenas uma ilustração inicial, não uma API pronta. Na implementação real, eu separaria os contratos em serviços menores, com registro por Lookup/Service Provider e integração com as APIs da plataforma.

Também criaria uma API para integração com servidores externos, abstraindo:
- Inicialização e encerramento de processos.
- Comunicação LSP.
- Gerenciamento de configurações.
- Diagnósticos.
- Ciclo de vida dos projetos.
- Gerenciamento de dependências.

Assim, um desenvolvedor não precisaria conhecer toda a arquitetura interna do NetBeans para criar uma extensão.

## Existe até uma oportunidade de ecossistema

Você poderia ter repositórios independentes:

| Projeto | Responsabilidade |
|---|---|
| `nb-kit` | Plataforma central |
| `nbkit-typescript` | JavaScript e TypeScript |
| `nbkit-react` | React e TSX |
| `nbkit-angular` | Angular |
| `nbkit-go` | Go |
| `nbkit-rust` | Rust |
| `nbkit-python` | Python |

Cada extensão poderia evoluir independentemente.

## Mas eu faria uma escolha estratégica

Não tentaria criar uma segunda plataforma de IDE inteira dentro do NetBeans.

O NetBeans já oferece uma infraestrutura enorme: módulos, sistema de janelas, editor, projetos, indexação, serviços e APIs de integração.

O nb-kit deveria atuar como uma camada de compatibilidade e modernização, aproveitando o que já existe.

E teria três preocupações fundamentais:

1. **API pública estável:** terceiros precisam conseguir desenvolver sem acompanhar cada mudança interna do nb-kit.
2. **Extensões independentes:** instalar suporte a Go não deveria exigir instalar suporte a Angular.
3. **Licenciamento e distribuição:** respeitar as licenças das ferramentas integradas e permitir que extensões de terceiros tenham suas próprias licenças.

---

Sabe o que acho mais legal nessa ideia?

Você começou com um problema de aparência do editor, encontrou uma deficiência real no suporte a JSF e agora está pensando em permitir que qualquer desenvolvedor amplie o conjunto de tecnologias suportadas pela IDE.

**O nb-kit poderia se tornar uma comunidade de extensões que mantém o NetBeans relevante para o desenvolvimento moderno.**

E Go no NetBeans seria um excelente exemplo para demonstrar que a proposta funciona.

## User

e assim, se hoje qualquer pessoa poderia fazer a mesma coisa do zero, usando o NetBeans que já é enorme, o nbkit como API deveria facilitar esse processo:

- netbeans pode ser muito modificado em vários sentidos 
- nbkit: direciona e facilita certos desses sentidos, como por exemplo, mais customizações de tema, e justamente adicionar suporte completo a outros eccosistemas de programação

## ChatGPT

Sim. Agora entendi melhor a proposta, e acho que essa distinção é fundamental para definir a identidade do nb-kit.

Você não quer criar uma alternativa ao NetBeans. Também não quer simplesmente criar um pacote de extensões.

Você quer criar uma **camada de abstração sobre as possibilidades de customização do NetBeans**, tornando determinadas modificações muito mais acessíveis, organizadas e padronizadas.

Eu descreveria assim:

## A relação entre NetBeans e nb-kit

**Apache NetBeans**

<small>Plataforma extensível e infraestrutura de IDE</small>

Fundação

**nb-kit — Customization & Extension Framework**

<small>Direciona, simplifica e padroniza extensões avançadas.</small>

**Visual** Temas, cores, editor e aparência. **Linguagens** JS, TS, JSX, TSX, Go, Rust etc. **Validação** Diagnósticos, análise semântica e inspeções. **Extensibilidade** APIs, serviços e módulos de terceiros.

**Ecossistema de extensões**

<small>Desenvolvedores e comunidade</small>

## A diferença entre fazer do zero e usar o nb-kit

Imagine dois desenvolvedores querendo adicionar suporte a Go.

**Sem nb-kit:**

O desenvolvedor precisa estudar a arquitetura do NetBeans, descobrir quais APIs utilizar, entender a integração com o editor, gerenciar processos externos, implementar configurações, integrar diagnósticos e construir toda a infraestrutura necessária.

**Com nb-kit:**

O desenvolvedor encontra uma API documentada, interfaces padronizadas, serviços compartilhados e exemplos de implementação.

Ele concentra seu esforço naquilo que realmente importa: integrar o ecossistema Go.

Essa é a proposta de valor.

## Eu dividiria a API em quatro grandes áreas

| API | O que facilita |
|---|---|
| `nbkit.visual` | Temas, estilos e personalização visual |
| `nbkit.language` | Integração de linguagens e servidores |
| `nbkit.analysis` | Validações, diagnósticos e inspeções |
| `nbkit.project` | Gerenciamento e integração de projetos |

E deixaria uma quinta área como infraestrutura:

`nbkit.core`: ciclo de vida, serviços, configurações, registro de extensões e utilitários compartilhados.

Esses nomes são sugestões de organização, não necessariamente pacotes definitivos.

## Um cuidado importante: não criar uma abstração desnecessária

O NetBeans já possui APIs excelentes. O nb-kit não deveria embrulhar todas elas simplesmente por embrulhar.

Eu estabeleceria uma regra:

- Se o NetBeans já resolve muito bem, exponha ou documente sua API.
- Se a implementação é repetitiva e complexa, ofereça uma abstração do nb-kit.
- Se existe uma ferramenta especializada, integre-a.
- Se existe uma lacuna real, implemente a funcionalidade.

Isso evita que o nb-kit vire uma segunda plataforma gigantesca que precisa manter tudo em duplicidade.

---

## O que eu acho que você está construindo

Uma espécie de *framework de modernização do Apache NetBeans*.

E existe uma diferença importante entre essa proposta e simplesmente desenvolver plugins:

**Plugins adicionam funcionalidades. O nb-kit pode facilitar que outras pessoas desenvolvam funcionalidades.**

Essa é uma proposta muito mais interessante para um projeto open source de longo prazo.

Eu até consideraria documentar essa visão desde cedo no README, deixando claro que o objetivo final não é apenas melhorar sua própria experiência com JSF, mas criar uma infraestrutura comunitária para expandir as possibilidades do NetBeans.