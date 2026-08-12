# Contribuindo

Obrigado pelo interesse em contribuir com este projeto.

## Como contribuir

1. Abra uma *issue* descrevendo o problema ou a melhoria proposta antes de submeter código, para alinhar escopo.
2. Faça um fork do repositório e crie um branch descritivo (`feat/nome-da-funcionalidade` ou `fix/nome-do-bug`).
3. Siga o estilo de commits do projeto — mensagens curtas, no imperativo, preferencialmente no padrão [Conventional Commits](https://www.conventionalcommits.org/pt-br/) (`feat:`, `fix:`, `docs:`, `chore:`).
4. Rode o lint local antes de abrir o Pull Request:
   ```bash
   uv run ruff check src/
   shellcheck src/transcrever.sh
   ```
5. Abra o Pull Request descrevendo a motivação e o que mudou.

## Escopo do projeto

Este é, antes de tudo, um projeto pessoal e um estudo de caso técnico. Contribuições que mantenham o princípio central — **processamento 100% local, sem dependência de serviços de nuvem externos** — são bem-vindas. Propostas que introduzam dependência de APIs externas para as etapas centrais (transcrição, normalização, resumo) fogem do escopo e provavelmente não serão aceitas, ainda que possam ser discutidas como extensões opcionais e claramente sinalizadas como tal.

## Código de conduta

Seja respeitoso. Críticas técnicas construtivas são sempre bem-vindas; condutas desrespeitosas não são toleradas.
