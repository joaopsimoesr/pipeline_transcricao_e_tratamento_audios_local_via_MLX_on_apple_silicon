# 🕊️ IA Soberana e a Leginova

**Autoria:** João Pedro Simões Rodrigues (OAB/GO 105020056)

---

## O problema que este projeto endereça

A forma dominante de se usar IA hoje — para transcrição, resumo, análise de texto — passa por enviar dados a um servidor de terceiros, quase sempre fora do Brasil. Isso funciona bem para conteúdo genérico e não sensível. Mas para quem lida rotineiramente com dados de outra natureza — processos jurídicos, prontuários, registros institucionais, conversas de trabalho com cláusulas de confidencialidade — essa arquitetura padrão é, no mínimo, uma escolha que merece ser questionada, e no limite, um risco de conformidade.

**IA soberana**, no sentido técnico usado aqui, não é um conceito abstrato de política industrial — é uma escolha concreta de arquitetura: **processamento que acontece inteiramente no hardware do usuário, sem que o conteúdo trafegue para fora do dispositivo.** Este repositório é uma demonstração funcional de que essa escolha é viável hoje, em hardware de consumo (Apple Silicon), sem concessões relevantes de qualidade frente às alternativas em nuvem.

## Por que isso é relevante no contexto brasileiro

O Brasil tem uma peculiaridade regulatória e de mercado que torna esse debate mais do que teórico:

- A **LGPD** (Lei Geral de Proteção de Dados) estabelece a minimização de dados e a necessidade de base legal para tratamento como princípios centrais — não como cláusulas de rodapé. Processar dados localmente, sem que eles saiam do dispositivo do titular ou do controlador, é uma forma direta de atender a esses princípios por desenho, não por auditoria posterior.
- Profissões regulamentadas (advocacia, saúde, entre outras) têm deveres de sigilo que antecedem — e em muitos casos superam — a própria LGPD. Para essas profissões, a pergunta "onde meus dados são processados, e por quem" não é opcional.
- O mercado brasileiro de ferramentas de IA para profissionais — inclusive no setor jurídico — é hoje dominado por soluções que depende de infraestrutura de nuvem centralizada, majoritariamente estrangeira. Isso cria uma lacuna estrutural para soluções locais, abertas e auditáveis.

## A conexão com a Leginova

A Leginova, empresa fundada pelo autor deste repositório, tem como uma de suas frentes de trabalho um motor de jurimetria (análise de dados jurídicos) construído sobre o mesmo princípio: **100% local, de código aberto, com privacidade desde a concepção** — uma escolha estrutural que a diferencia de soluções incumbentes baseadas em nuvem centralizada.

Este repositório **não é** esse motor de jurimetria, nem um produto comercial da Leginova. É um projeto pessoal, de propósito geral (transcrição de áudio), publicado de forma independente e aberta. Sua relevância para o portfólio da Leginova está em ser **evidência técnica pública e auditável** de que o princípio de "processamento 100% local" que orienta a tese da empresa é, de fato, executável com qualidade em hardware acessível — não apenas uma promessa de posicionamento comercial.

## O que este projeto propõe contribuir

- Um exemplo funcional, aberto e replicável de pipeline de IA local em Apple Silicon, que qualquer desenvolvedor brasileiro pode auditar, clonar e adaptar.
- Uma peça de discussão pública sobre arquiteturas alternativas ao padrão "tudo na nuvem" para processamento de linguagem natural no Brasil.
- Um ponto de partida técnico para profissionais de áreas reguladas que precisam (ou preferem) manter dados sensíveis fora de infraestrutura de terceiros.

## O que este projeto **não** é

- Não é um produto comercial pronto para uso em produção por terceiros sem adaptação.
- Não é um parecer jurídico sobre conformidade com a LGPD — apenas ilustra, na prática, um padrão de arquitetura compatível com seus princípios.
- Não representa, por si só, a totalidade da tese técnica da Leginova — é uma peça adjacente e independente dela.
