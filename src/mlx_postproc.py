#!/usr/bin/env python3
"""
mlx_postproc.py — Sanitização e resumo de transcrição via mlx-lm (100% local, MLX)

Parte do pipeline "Transcrição Local via MLX" — https://github.com/joaopsimoesr/
pipeline_transcricao_e_tratamento_audios_local_via_MLX_on_apple_silicon

Suporta dois formatos de entrada, detectados automaticamente:
  - Texto corrido (fluxo sem diarização): normalização pontual — corrige
    ruído de transcrição sem alterar conteúdo.
  - Texto por turnos de falante (fluxo com diarização, linhas no formato
    "[SPEAKER_00] texto..."): sanitização por turno, em lotes, preservando as
    etiquetas de falante e removendo apenas ruído de fala (hesitações,
    muletas, falsos começos) — nunca conteúdo substantivo.

Uso:
    python3 mlx_postproc.py <arquivo_txt_bruto>

Saída (stdout), em três blocos delimitados para o bash extrair com awk/sed:
    ---TEXTO_NORMALIZADO---
    <texto>
    ---TITULO---
    <titulo>
    ---SUMARIO---
    <sumario>
"""
import re
import sys
from collections import Counter
from pathlib import Path
from mlx_lm import load, generate

# Modelo padrão: pequeno o suficiente para RAM unificada limitada (ex.: 8 GB).
MODEL_PATH = "mlx-community/Llama-3.2-3B-Instruct-4bit"

# Limite de repetição consecutiva — mesmo critério do sanity check em
# transcrever.sh. Segunda camada de defesa, caso este script seja chamado
# diretamente.
LIMITE_REPETICOES = 15

# Quantos turnos de falante são sanitizados por chamada ao modelo. Existe para
# não estourar o orçamento de tokens de saída em reuniões longas — o objetivo
# aqui é PRESERVAR conteúdo, então cada lote sanitizado deve sair com tamanho
# próximo ao do lote original, não menor.
TURNOS_POR_LOTE = 12

PADRAO_TURNO = re.compile(r"^\[(SPEAKER_[\w\d]+)\]\s*(.*)$")


def texto_parece_loop_de_alucinacao(texto: str) -> tuple[bool, str, int]:
    linhas = [l.strip() for l in texto.splitlines() if l.strip()]
    if not linhas:
        return False, "", 0
    # Compara pelo conteúdo, ignorando a etiqueta de falante quando presente —
    # o loop de alucinação pode se repetir sob o mesmo falante ou alternando
    # entre etiquetas diferentes.
    conteudos = []
    for l in linhas:
        m = PADRAO_TURNO.match(l)
        conteudos.append(m.group(2) if m else l)
    contagem = Counter(conteudos)
    mais_comum, freq = contagem.most_common(1)[0]
    return freq > LIMITE_REPETICOES, mais_comum, freq


def eh_diarizado(texto: str) -> bool:
    primeiras_linhas = [l for l in texto.splitlines() if l.strip()][:5]
    return any(PADRAO_TURNO.match(l) for l in primeiras_linhas)


def ask(model, tokenizer, prompt: str, max_tokens: int) -> str:
    messages = [{"role": "user", "content": prompt}]
    formatted = tokenizer.apply_chat_template(messages, add_generation_prompt=True)
    return generate(model, tokenizer, prompt=formatted, max_tokens=max_tokens, verbose=False).strip()


def sanitizar_flat(model, tokenizer, texto: str) -> str:
    prompt = f"""Você é um revisor de transcrições. Corrija APENAS erros óbvios de \
transcrição (palavras trocadas por foneticamente parecidas, pontuação, nomes próprios \
reconhecíveis pelo contexto). NÃO resuma, NÃO corte trechos, NÃO acrescente informação, \
NÃO altere o sentido ou o estilo de fala original. Devolva SOMENTE o texto corrigido, \
sem comentários, sem introdução.

TEXTO:
{texto}"""
    return ask(model, tokenizer, prompt, max_tokens=2000)


def sanitizar_turnos(model, tokenizer, linhas: list) -> str:
    """Sanitiza turnos diarizados em lotes, preservando etiquetas de falante
    e o máximo possível do conteúdo original de cada turno."""
    lotes = [linhas[i:i + TURNOS_POR_LOTE] for i in range(0, len(linhas), TURNOS_POR_LOTE)]
    resultado = []

    for i, lote in enumerate(lotes, start=1):
        print(f"  Sanitizando lote {i}/{len(lotes)} ({len(lote)} turnos)...", file=sys.stderr)
        bloco = "\n".join(lote)
        prompt = f"""Você é um revisor de transcrições de reunião. O texto abaixo está \
dividido em turnos de fala, cada um começando com uma etiqueta de falante entre colchetes \
(ex.: [SPEAKER_00]). Para cada turno:
1. Mantenha a etiqueta do falante EXATAMENTE como está.
2. Remova apenas ruído de fala: hesitações ("é", "tipo", "né"), repetições de palavra \
usadas como muleta, falsos começos que o próprio falante abandonou.
3. NÃO remova nenhuma informação substantiva — decisões, números, nomes, prazos, \
opiniões. Preserve o conteúdo com o máximo de fidelidade possível.
4. NÃO funda turnos de falantes diferentes em um só.
5. NÃO resuma nenhum turno.
Devolva os turnos sanitizados no mesmo formato (uma linha por turno, etiqueta + texto), \
sem comentários adicionais.

TURNOS:
{bloco}"""
        # max_tokens generoso e proporcional ao lote — o objetivo é preservar
        # conteúdo, não comprimir, então a saída não deve ficar menor que a entrada.
        max_tokens_lote = max(1500, len(bloco.split()) * 3)
        saida = ask(model, tokenizer, prompt, max_tokens=max_tokens_lote)
        resultado.append(saida)

    return "\n".join(resultado)


def gerar_titulo_resumo(model, tokenizer, texto: str) -> tuple:
    # Para textos longos, usa uma amostra representativa (início + meio + fim)
    # em vez do texto inteiro — o resumo não precisa ler tudo para entender do
    # que se trata, e isso evita gerar uma chamada desnecessariamente cara.
    if len(texto) < 6000:
        amostra = texto
    else:
        meio = len(texto) // 2
        amostra = (
            texto[:2000] + "\n[...]\n"
            + texto[meio - 1000: meio + 1000] + "\n[...]\n"
            + texto[-2000:]
        )

    prompt = f"""Leia o texto abaixo (pode ser um trecho representativo de um texto maior) \
e devolva EXATAMENTE duas linhas, sem comentários extras:
LINHA 1: um título curto (até 8 palavras) para o assunto.
LINHA 2: um resumo de 2 a 3 frases sobre do que se trata.

TEXTO:
{amostra}"""
    bruto = ask(model, tokenizer, prompt, max_tokens=200)
    linhas = [l for l in bruto.splitlines() if l.strip()]
    titulo = linhas[0] if len(linhas) > 0 else "Desconhecido"
    sumario = linhas[1] if len(linhas) > 1 else "(resumo não gerado — revisar manualmente)"
    return titulo, sumario


def main() -> None:
    if len(sys.argv) < 2:
        print("Uso: mlx_postproc.py <arquivo_txt_bruto>", file=sys.stderr)
        sys.exit(1)

    txt_path = Path(sys.argv[1])
    if not txt_path.exists():
        print(f"Arquivo não encontrado: {txt_path}", file=sys.stderr)
        sys.exit(1)

    texto_original = txt_path.read_text(encoding="utf-8")

    tem_loop, conteudo_repetido, freq = texto_parece_loop_de_alucinacao(texto_original)
    if tem_loop:
        print(
            f"⚠ Loop de repetição detectado ({freq}x): \"{conteudo_repetido[:80]}\" — "
            "abortando antes de carregar o modelo. Corrija a transcrição bruta primeiro.",
            file=sys.stderr,
        )
        sys.exit(2)

    print(f"Carregando modelo local ({MODEL_PATH})...", file=sys.stderr)
    model, tokenizer = load(MODEL_PATH)

    diarizado = eh_diarizado(texto_original)

    if diarizado:
        print("Formato diarizado detectado — sanitizando por turnos de falante...", file=sys.stderr)
        linhas = [l for l in texto_original.splitlines() if l.strip()]
        texto_sanitizado = sanitizar_turnos(model, tokenizer, linhas)
    else:
        print("Normalizando texto (fluxo sem diarização)...", file=sys.stderr)
        texto_sanitizado = sanitizar_flat(model, tokenizer, texto_original)

    print("Gerando título e resumo...", file=sys.stderr)
    titulo, sumario = gerar_titulo_resumo(model, tokenizer, texto_sanitizado)

    print("---TEXTO_NORMALIZADO---")
    print(texto_sanitizado)
    print("---TITULO---")
    print(titulo)
    print("---SUMARIO---")
    print(sumario)


if __name__ == "__main__":
    main()
