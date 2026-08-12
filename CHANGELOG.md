# Changelog

Todas as mudanças notáveis deste projeto são documentadas neste arquivo.

O formato segue [Keep a Changelog](https://keepachangelog.com/pt-BR/1.1.0/), adaptado ao padrão de changelog já usado nos demais projetos do autor, e o versionamento segue [Semantic Versioning](https://semver.org/lang/pt-BR/).

---

## [0.2.0] - 2026-08-12 - FUNCIONALIDADE

### Descrição Geral
Adiciona diarização opcional (identificação de falantes), sanitização de texto que preserva conteúdo por turno, e suporte automático a `.qta` (QuickTime Audio, formato nativo do Voice Memos em iPhones recentes).

### Detalhes Técnicos
- `src/transcrever.sh`: nova flag `--diarizar`, que troca `mlx-whisper` por `whispermlx` (mlx-whisper + pyannote.audio) na transcrição; detecção e conversão automática de `.qta` → `.m4a` via `ffmpeg -map 0:0 -c:a copy`
- `src/diarizacao_para_txt.py` (novo): converte o JSON diarizado do `whispermlx` em turnos de falante (`[SPEAKER_00] texto...`)
- `src/mlx_postproc.py`: detecta automaticamente entrada diarizada vs. texto corrido; para diarizada, sanitiza em lotes de turnos preservando etiquetas de falante e conteúdo substantivo, em vez da normalização pontual de texto corrido
- `pyproject.toml`: novo grupo opcional `diarizacao` (`whispermlx`)
- `docs/ARQUITETURA.md`: documentação da diarização (pré-requisitos, o que muda no modelo de privacidade) e do suporte a `.qta`

### Justificativa
Reuniões com múltiplos participantes (ex.: com Mãe Sônia e Marcos) geravam um bloco de texto corrido sem identificação de quem falou o quê — uma limitação real, não cosmética, para uso como ata. A sanitização por turnos responde ao pedido de "texto final sanitizado, preservando ao máximo o conteúdo das falas": remove ruído de fala sem cortar substância. O suporte a `.qta` responde ao formato nativo de gravações mais recentes do iPhone, que passou a substituir o `.m4a` como padrão do Voice Memos.

### Arquivos/Documentos Afetados
- `src/transcrever.sh`
- `src/mlx_postproc.py`
- `src/diarizacao_para_txt.py` (novo)
- `pyproject.toml`
- `docs/ARQUITETURA.md`

### Autor
João Pedro Simões Rodrigues

---

## [0.1.1] - 2026-08-09 - CORREÇÃO

### Descrição Geral
Correção de loop de repetição/alucinação do Whisper, observado no primeiro teste real do pipeline (transcrição travou repetindo a mesma frase centenas de vezes até o fim do áudio).

### Detalhes Técnicos
- `src/transcrever.sh`: ativa por padrão `--condition-on-previous-text False` e os limiares anti-alucinação (`--no-speech-threshold`, `--logprob-threshold`, `--compression-ratio-threshold`), antes deixados comentados/opcionais
- `src/transcrever.sh`: nova Etapa 1.5 — sanity check pós-transcrição que interrompe o pipeline antes da etapa de IA se qualquer linha do `.txt` bruto se repetir mais de 15 vezes
- `src/mlx_postproc.py`: mesma verificação de repetição como segunda camada de defesa, caso o script seja chamado diretamente
- `docs/ARQUITETURA.md`: nova seção "Diagnóstico de loop de repetição" com passo a passo de debug (JSON com timestamps, pré-processamento de ruído)

### Justificativa
O primeiro teste real (áudio de apresentação de tarefa) gerou um `.md` com centenas de repetições de "Não sei o que é" — falha conhecida do Whisper causada por conditioning em texto já corrompido, agravada por não haver limiares anti-alucinação ativos por padrão. Sem um sanity check, o pipeline geraria silenciosamente um artefato sem valor a cada nova ocorrência do mesmo problema.

### Arquivos/Documentos Afetados
- `src/transcrever.sh`
- `src/mlx_postproc.py`
- `docs/ARQUITETURA.md`

### Autor
João Pedro Simões Rodrigues

---

## [0.1.0] - 2026-08-09 - GÊNESE

### Descrição Geral
Primeira versão pública do pipeline: transcrição local via `mlx-whisper`, normalização e resumo via `mlx-lm`, saída final em Markdown (CommonMark) com frontmatter YAML.

### Detalhes Técnicos
- `src/transcrever.sh`: orquestra as cinco etapas do pipeline (transcrição → normalização → resumo → geração de ID → montagem do markdown final)
- `src/mlx_postproc.py`: carrega o modelo `mlx-lm` uma única vez por execução, reaproveitado nas etapas de normalização e resumo
- Suporte a `.m4a`, `.mp3`, `.wav`, `.aac`, `.opus`; idiomas `pt`, `en`, `es` ou detecção automática (`auto`)
- Publicação sob licença MIT

### Justificativa
Consolidação de um pipeline pessoal de IA local como prova de conceito pública para a tese de "IA soberana" — processamento de dados sensíveis sem dependência de provedores de nuvem externos — que orienta parte do trabalho técnico da Leginova.

### Arquivos/Documentos Afetados
- Todo o repositório (versão inicial)

### Autor
João Pedro Simões Rodrigues
