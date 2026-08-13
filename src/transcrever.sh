#!/usr/bin/env bash
# ============================================================
# transcrever.sh — Pipeline local de transcrição e pós-processamento de áudio
# Parte de: https://github.com/joaopsimoesr/pipeline_transcricao_e_tratamento_audios_local_via_MLX_on_apple_silicon
# Licença: MIT — ver LICENSE
#
# v0.2.0: suporte a .qta (QuickTime Audio, formato nativo do Voice Memos em
# iPhone 16 Pro+ desde iOS 18.2), diarização opcional via whispermlx+pyannote,
# e sanitização de texto que preserva falantes e conteúdo.
# ============================================================
# Dependências (ver README — Instalação):
#   - mlx-whisper, mlx-lm   (sempre necessários)
#   - ffmpeg                (necessário para converter .qta)
#   - whispermlx            (necessário APENAS se usar --diarizar)
#     Requer HF_TOKEN (variável de ambiente) com um token da Hugging Face que
#     tenha aceitado os termos de uso de https://huggingface.co/pyannote/speaker-diarization-community-1
#
# Uso:
#   ./transcrever.sh "arquivo.ext" [idioma] ["prompt inicial"] [--diarizar]
#
#   idioma: pt | en | es | auto  (auto = detecção automática pelo Whisper)
#
# Exemplos:
#   ./transcrever.sh "audios/reuniao.m4a" pt "Mãe Sônia, Marcos, Malunga" --diarizar
#   ./transcrever.sh "audios/apresentacao.qta" pt
# ============================================================

set -euo pipefail

# --- Parse de flags (posição livre) ---
DIARIZAR=0
POSICIONAIS=()
for arg in "$@"; do
  case "$arg" in
    --diarizar) DIARIZAR=1 ;;
    *) POSICIONAIS+=("$arg") ;;
  esac
done
set -- "${POSICIONAIS[@]}"

if [ $# -lt 1 ]; then
  echo "Uso: $0 \"arquivo.ext\" [idioma: pt|en|es|auto] [\"prompt inicial\"] [--diarizar]"
  exit 1
fi

AUDIO_PATH_ORIGINAL="$1"
IDIOMA="${2:-auto}"
PROMPT_INICIAL="${3:-}"

if [ ! -f "$AUDIO_PATH_ORIGINAL" ]; then
  echo "✗ Arquivo não encontrado: $AUDIO_PATH_ORIGINAL"
  exit 1
fi

# --- Configuração de pastas ---
BASE="${TRANSCRICAO_BASE:-$HOME/Desktop/Transcricoes}"
DIR_AUDIOS="$BASE/audios"
DIR_TEXTOS="$BASE/textos"      # .txt bruto — NUNCA sobrescrito pela etapa de IA
DIR_MD="$BASE/markdown"        # .md final

MODEL_WHISPER="mlx-community/whisper-large-v3-turbo"
MODEL_WHISPER_DIARIZACAO="large-v3-turbo"   # nome curto usado pelo whispermlx

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

mkdir -p "$DIR_AUDIOS" "$DIR_TEXTOS" "$DIR_MD"

NOME=$(basename "$AUDIO_PATH_ORIGINAL")
NOME_SEM_EXT="${NOME%.*}"
NOME_SAFE=$(echo "$NOME_SEM_EXT" | tr '.' '_' | tr ' ' '_')
EXT_LOWER=$(echo "${NOME##*.}" | tr '[:upper:]' '[:lower:]')

AUDIO_PATH="$AUDIO_PATH_ORIGINAL"

# --- Etapa 0: converter .qta (QuickTime Audio) para .m4a, se necessário ---
# O .qta é um contêiner QuickTime/MOV com múltiplas trilhas (AAC estéreo
# compatível + áudio espacial APAC + metadados). Extraímos apenas a trilha 0
# (AAC), que é a trilha compatível com transcrição — sem reencodar (cópia
# direta, rápida e sem perda).
if [ "$EXT_LOWER" = "qta" ]; then
  echo "▶ Etapa 0/6 — Detectado .qta — extraindo trilha de áudio compatível (AAC) via ffmpeg..."
  AUDIO_CONVERTIDO="$DIR_AUDIOS/${NOME_SAFE}_convertido.m4a"
  ffmpeg -y -loglevel error -i "$AUDIO_PATH_ORIGINAL" -map 0:0 -c:a copy "$AUDIO_CONVERTIDO"
  AUDIO_PATH="$AUDIO_CONVERTIDO"
  echo "✓ Convertido para: $AUDIO_PATH"
fi

TXT_BRUTO="$DIR_TEXTOS/$NOME_SAFE.txt"

if [ "$DIARIZAR" -eq 1 ]; then
  # ========================================================
  # FLUXO COM DIARIZAÇÃO — whispermlx (mlx-whisper + pyannote)
  # ========================================================
  echo "▶ Etapa 1/6 — Transcrevendo com diarização (whispermlx)..."

  if [ -z "${HF_TOKEN:-}" ]; then
    echo "✗ Diarização requer a variável de ambiente HF_TOKEN."
    echo "  1. Gere um token em https://huggingface.co/settings/tokens"
    echo "  2. Aceite os termos em https://huggingface.co/pyannote/speaker-diarization-community-1"
    echo "  3. Rode: export HF_TOKEN=\"seu_token_aqui\""
    exit 3
  fi

  if ! command -v whispermlx >/dev/null 2>&1; then
    echo "✗ whispermlx não encontrado. Instale com: uv add whispermlx"
    exit 3
  fi

  # Nome do JSON de saída: whispermlx não tem flag para customizar o nome —
  # ele nomeia sozinho a partir do basename do áudio de entrada (confirmado
  # via --help, que não lista --output_name).
  AUDIO_BASENAME=$(basename "$AUDIO_PATH")
  AUDIO_STEM="${AUDIO_BASENAME%.*}"
  JSON_DIARIZADO="$DIR_TEXTOS/${AUDIO_STEM}.json"

  WHISPERMLX_FLAGS=(--model "$MODEL_WHISPER_DIARIZACAO" --diarize --hf_token "$HF_TOKEN" \
    --output_format json --output_dir "$DIR_TEXTOS")
  if [ "$IDIOMA" != "auto" ]; then
    WHISPERMLX_FLAGS+=(--language "$IDIOMA")
  fi
  if [ -n "$PROMPT_INICIAL" ]; then
    WHISPERMLX_FLAGS+=(--initial_prompt "$PROMPT_INICIAL")
  fi
  # Anti-alucinação, mesmo padrão do fluxo sem diarização (v0.1.1):
  WHISPERMLX_FLAGS+=(--condition_on_previous_text False)
  WHISPERMLX_FLAGS+=(--no_speech_threshold 0.6 --logprob_threshold -1.0 --compression_ratio_threshold 2.4)

  whispermlx "$AUDIO_PATH" "${WHISPERMLX_FLAGS[@]}"

  if [ ! -f "$JSON_DIARIZADO" ]; then
    echo "✗ JSON diarizado não encontrado em: $JSON_DIARIZADO"
    echo "  Confira o nome real gerado:"
    ls -la "$DIR_TEXTOS"/*.json 2>/dev/null || echo "  (nenhum .json encontrado em $DIR_TEXTOS)"
    exit 1
  fi

  echo "▶ Etapa 2/6 — Convertendo JSON diarizado em turnos de falante..."
  python3 "$SCRIPT_DIR/diarizacao_para_txt.py" "$JSON_DIARIZADO" > "$TXT_BRUTO"
  echo "✓ Transcrição bruta (por turnos) salva em: $TXT_BRUTO"

else
  # ========================================================
  # FLUXO SEM DIARIZAÇÃO — mlx-whisper simples (mais rápido, sem HF_TOKEN)
  # ========================================================
  echo "▶ Etapa 1/6 — Transcrevendo (sem diarização): $NOME (idioma: $IDIOMA)"

  FLAGS=(--model "$MODEL_WHISPER" --output-format txt --output-name "$NOME_SAFE" --output-dir "$DIR_TEXTOS")
  if [ "$IDIOMA" != "auto" ]; then
    FLAGS+=(--language "$IDIOMA")
  fi
  if [ -n "$PROMPT_INICIAL" ]; then
    FLAGS+=(--initial-prompt "$PROMPT_INICIAL")
  fi
  # Anti-alucinação ativo por padrão desde a v0.1.1 (ver CHANGELOG).
  FLAGS+=(--condition-on-previous-text False)
  FLAGS+=(--no-speech-threshold 0.6 --logprob-threshold -1.0 --compression-ratio-threshold 2.4)

  mlx_whisper "$AUDIO_PATH" "${FLAGS[@]}"

  if [ ! -f "$TXT_BRUTO" ]; then
    echo "✗ Transcrição bruta não foi gerada como esperado em $TXT_BRUTO"
    exit 1
  fi
  echo "✓ Transcrição bruta salva em: $TXT_BRUTO"
fi

# --- Etapa 3/6: Sanity check — detectar loop de repetição antes de gastar IA ---
LINHA_MAIS_REPETIDA=$(sort "$TXT_BRUTO" | uniq -c | sort -rn | head -1)
REPETICOES=$(echo "$LINHA_MAIS_REPETIDA" | awk '{print $1}')
LIMITE_REPETICOES=15

if [ -n "$REPETICOES" ] && [ "$REPETICOES" -gt "$LIMITE_REPETICOES" ]; then
  echo ""
  echo "⚠ ALERTA: possível loop de alucinação do Whisper detectado."
  echo "  A linha mais frequente se repete $REPETICOES vezes (limite: $LIMITE_REPETICOES)."
  echo "  Linha: $(echo "$LINHA_MAIS_REPETIDA" | sed -E 's/^[[:space:]]*[0-9]+[[:space:]]*//')"
  echo ""
  echo "  Pipeline interrompido ANTES da etapa de IA — o .txt bruto já está salvo em:"
  echo "  $TXT_BRUTO"
  echo ""
  echo "  Próximos passos sugeridos (ver docs/ARQUITETURA.md):"
  echo "  1. Se houver uma segunda gravação da mesma fonte, tente-a primeiro — é mais rápido."
  echo "  2. Rode em modo debug com --output-format json para localizar o timestamp exato:"
  echo '     mlx_whisper "'"$AUDIO_PATH"'" --model "'"$MODEL_WHISPER"'" --language "'"$IDIOMA"'" \'
  echo "       --output-format json --output-name debug --output-dir /tmp"
  echo "  3. Se persistir, tente um pré-processamento de ruído (ffmpeg highpass+afftdn)."
  exit 2
fi

# --- Etapa 4/6: Sanitização + título/resumo via mlx-lm ---
echo "▶ Etapa 4/6 — Sanitizando e resumindo com mlx-lm (local, offline)..."

SAIDA_MLX=$(python3 "$SCRIPT_DIR/mlx_postproc.py" "$TXT_BRUTO")

TEXTO_SANITIZADO=$(echo "$SAIDA_MLX" | awk '/^---TEXTO_NORMALIZADO---$/{flag=1;next}/^---TITULO---$/{flag=0}flag')
TITULO=$(echo "$SAIDA_MLX" | awk '/^---TITULO---$/{flag=1;next}/^---SUMARIO---$/{flag=0}flag')
SUMARIO=$(echo "$SAIDA_MLX" | awk '/^---SUMARIO---$/{flag=1;next}flag')

if [ -z "$TITULO" ]; then
  TITULO="$NOME_SEM_EXT"
fi
if [ -z "$SUMARIO" ]; then
  SUMARIO="(resumo não gerado — revisar manualmente)"
fi

# --- Etapa 5/6: Geração de ID único (Cluster-ID, Diamond System) ---
# State 121 fixo = "nota transcrita por este pipeline".
echo "▶ Etapa 5/6 — Gerando Cluster-ID..."

STATE_ID="121"
DATA_ID=$(date +%d%m%y)
HORA_ID=$(date +%H%M%S)
SEQ_ID=$(printf "%03d" $((RANDOM % 1000)))
ID_NOTA="N.${STATE_ID}.${DATA_ID}.${HORA_ID}.${SEQ_ID}"

# --- Etapa 6/6: Montagem do markdown final (CommonMark + YAML frontmatter) ---
echo "▶ Etapa 6/6 — Montando markdown final..."

ARQ_MD="$DIR_MD/$NOME_SAFE.md"

# Se diarizado, troca "[SPEAKER_00] " por "**SPEAKER_00:** " para leitura mais
# natural no markdown final — puramente cosmético, não altera conteúdo.
if [ "$DIARIZAR" -eq 1 ]; then
  TEXTO_FINAL=$(echo "$TEXTO_SANITIZADO" | sed -E 's/^\[(SPEAKER_[A-Za-z0-9_]+)\] /**\1:** /')
else
  TEXTO_FINAL="$TEXTO_SANITIZADO"
fi

cat > "$ARQ_MD" <<EOF
---
id: $ID_NOTA
titulo: "$TITULO"
data: $(date +%Y-%m-%d)
origem_audio: "$NOME"
idioma: $IDIOMA
diarizado: $([ "$DIARIZAR" -eq 1 ] && echo "true" || echo "false")
sumario: "$SUMARIO"
---

# $TITULO

> $SUMARIO

## Transcrição

$TEXTO_FINAL
EOF

echo "✓ Concluído."
echo "  Bruto:  $TXT_BRUTO"
echo "  Final:  $ARQ_MD"
