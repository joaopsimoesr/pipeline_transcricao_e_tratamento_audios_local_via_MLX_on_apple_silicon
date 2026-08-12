#!/usr/bin/env python3
"""
diarizacao_para_txt.py — Converte a saída JSON diarizada do whispermlx em um
.txt bruto formatado por turnos de falante:

[SPEAKER_00] texto do primeiro turno...
[SPEAKER_01] texto do segundo turno...

Esse .txt entra no mesmo fluxo do restante do pipeline a partir daqui (sanity
check de repetição, depois mlx_postproc.py) — o resto do pipeline não precisa
saber se o texto veio de um fluxo diarizado ou não.

[PROVAVELMENTE INCOMPLETO - POC] O schema exato do JSON produzido por
`whispermlx --output_format json` não foi confirmado nesta implementação —
este parser assume o schema padrão do WhisperX (uma lista "segments", cada
segmento com os campos "speaker" e "text"), que é o schema documentado no
projeto original. Rode `whispermlx --help` e inspecione um JSON de saída real
antes do primeiro uso; se a estrutura divergir, ajuste `extrair_segmentos`.

Uso:
    python3 diarizacao_para_txt.py <arquivo.json>
"""
import json
import sys
from pathlib import Path


def extrair_segmentos(dados) -> list:
    if isinstance(dados, dict) and "segments" in dados:
        return dados["segments"]
    if isinstance(dados, list):
        return dados
    raise ValueError(
        "Schema do JSON não reconhecido — verifique a saída real do whispermlx "
        "e ajuste extrair_segmentos()."
    )


def agrupar_por_turno(segmentos: list) -> list:
    """Funde segmentos consecutivos do mesmo falante em um único turno."""
    turnos = []
    for seg in segmentos:
        falante = seg.get("speaker", "SPEAKER_DESCONHECIDO")
        texto = (seg.get("text") or "").strip()
        if not texto:
            continue
        if turnos and turnos[-1][0] == falante:
            anterior_falante, anterior_texto = turnos[-1]
            turnos[-1] = (anterior_falante, f"{anterior_texto} {texto}")
        else:
            turnos.append((falante, texto))
    return turnos


def main() -> None:
    if len(sys.argv) < 2:
        print("Uso: diarizacao_para_txt.py <arquivo.json>", file=sys.stderr)
        sys.exit(1)

    caminho = Path(sys.argv[1])
    if not caminho.exists():
        print(f"Arquivo não encontrado: {caminho}", file=sys.stderr)
        sys.exit(1)

    dados = json.loads(caminho.read_text(encoding="utf-8"))
    segmentos = extrair_segmentos(dados)
    turnos = agrupar_por_turno(segmentos)

    if not turnos:
        print("⚠ Nenhum turno de fala encontrado no JSON — verifique a diarização.", file=sys.stderr)
        sys.exit(1)

    for falante, texto in turnos:
        print(f"[{falante}] {texto}")


if __name__ == "__main__":
    main()
