#!/usr/bin/env bash
# -----------------------------------------------------------------------------
# Globalcad pull + limpeza (NF-fix) antes de colocar na landing
# -----------------------------------------------------------------------------
set -euo pipefail

# --- Diretórios (ajusta se no teu ambiente forem diferentes) -----------------
WORKDIR="/opt/ptin/automation/globalcad_sync_etl/work"
LANDING="/opt/ptin/sigo/uploads/globalcad"
LOGDIR="/var/log/ptin/sigo/globalcad_sync_etl"
mkdir -p "$WORKDIR" "$LANDING" "$LOGDIR"

log() { printf '%s %s\n' "$(date +'%F %T')" "$*" | tee -a "$LOGDIR/pull.log"; }

log "[START] globalcad_pull.sh"

# --- 1) PULL (SFTP) ----------------------------------------------------------
# (Mantém exatamente o que já tens aqui. Ex.: sftp, scp, etc.)
# Exemplo (comentado):
# sftp user@host <<EOF
#   cd /NWMOVEL/
#   mget globalcad_*.zip
#   bye
# EOF

# --- 2) UNZIP (se aplicável) -------------------------------------------------
# unzip -o "$WORKDIR"/globalcad_*.zip -d "$WORKDIR" >/dev/null 2>&1 || true

# --- 3) RENAME PADRÕES -------------------------------------------------------
# Normaliza extensões e nomes v_sigo_*.csv dentro do WORKDIR
find "$WORKDIR" -maxdepth 1 -type f -name '*.TXT'  -exec bash -c 'for f; do mv -f "$f" "${f%.TXT}.csv"; done' _ {} +
find "$WORKDIR" -maxdepth 1 -type f -name '*.CSV'  -exec bash -c 'for f; do mv -f "$f" "${f%.CSV}.csv"; done' _ {} +
# (Se tiveres um rename extra específico de origem -> destino, mantém aqui)

# === 3.1) LIMPEZA (TEU FOR) — ANTES DA LANDING ===============================
# Objetivo: limpar TODOS os CSV no WORKDIR antes de enviar para a landing
# Lógica: (1) protege as (NF-1) primeiras colunas, (2) limpa ruído no “rabo”,
# (3) força NF=header, (4) re-quotas ("dado";"dado")
shopt -s nullglob
for f in "$WORKDIR"/v_sigo_*.csv; do
  [ -f "$f" ] || continue

  # 0) backup rápido do bruto (auditoria)
  cp -p "$f" "${f}.bak.$(date +%F_%H%M%S)" || true

  # 1) nº de colunas do cabeçalho
  num_cols=$(head -n 1 "$f" | awk -F';' '{print NF}')
  protect=$((num_cols - 1))
  log "[cleanup] $(basename "$f"): NF(header)=$num_cols, protect=$protect"

  # 1.1) defensivo: CRLF e BOM (não altera se não existir)
  sed -i 's/\r$//' "$f"
  sed -i '1s/^\xEF\xBB\xBF//' "$f"

  # 2) remove aspas (re-quotamos já a seguir)
  sed -i 's/"//g' "$f"

  # 3) protege (NF-1) primeiras colunas e limpa ruído ; " [ ]
  #    NOTA: se quiseres incluir outros caracteres “ruins”, adiciona à classe
  sed -E -i "s/^(([^;]*;){$protect})/\1\x01/; :a; s/(\x01.*)[;\"\[\]]/\1 /; ta; s/\x01//" "$f"

  # 4) força NF=c e re-quotas ("dado";"dado")
  awk -F';' -v c="$num_cols" 'BEGIN{OFS=";"}{NF=c; print}' "$f" > "$f.tmp"
  sed -i 's/;/";"/g; s/^/"/; s/$/"/' "$f.tmp"
  mv -f "$f.tmp" "$f"
done
# === FIM LIMPEZA (TEU FOR) ===================================================

# --- 4) MOVE PARA LANDING ----------------------------------------------------
mkdir -p "$LANDING"
mv -f "$WORKDIR"/v_sigo_*.csv "$LANDING"/ 2>/dev/null || true
log "[move] ficheiros limpos enviados para: $LANDING"

# --- 5) LOG/EXIT -------------------------------------------------------------
log "[OK] Globalcad pull finalizado"
exit 0