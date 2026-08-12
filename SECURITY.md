# Segurança e Privacidade

## Modelo de privacidade

Este pipeline foi desenhado para não fazer nenhuma chamada de rede durante a transcrição ou o pós-processamento:

- A transcrição (`mlx-whisper`) roda inteiramente no processo local, usando modelos baixados uma única vez e mantidos em cache local.
- A normalização e o resumo (`mlx-lm`) também rodam localmente, sem envio de texto a nenhuma API externa.
- Nenhuma credencial, chave de API ou token é necessário para o funcionamento do pipeline.

Se você adaptar este projeto para usar um provedor de IA em nuvem (ex.: substituir `mlx-lm` por uma API externa), esteja ciente de que essa mudança altera fundamentalmente o modelo de privacidade descrito aqui — o conteúdo passaria a trafegar para fora do dispositivo.

## Reportando vulnerabilidades

Se você identificar uma vulnerabilidade de segurança neste projeto, por favor abra uma *issue* no GitHub descrevendo o problema.

**Importante:** não inclua em issues públicas nenhum áudio, transcrição ou trecho de texto que contenha dados sensíveis ou de terceiros — mesmo ao relatar um bug. Descreva o problema de forma genérica ou, se necessário, entre em contato diretamente com o autor.

## Escopo

Este projeto é um script utilitário pessoal, não um serviço hospedado. Não há superfície de ataque remota — os riscos relevantes são: (1) execução do script em ambiente com permissões excessivas, e (2) uso indevido dos dados de saída (transcrições) fora do dispositivo do usuário, que é responsabilidade de quem opera o pipeline, não do código em si.
