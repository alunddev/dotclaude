#!/usr/bin/env bash
# publish.sh — arma dotclaude.tar.gz y (opcional) lo sube a tu server.
#
# El tarball contiene en su raíz: .claude/  CLAUDE.md  .mcp.json  .gitignore  install.sh
# Es lo que install.sh baja cuando corre vía `curl | bash`.
#
# Uso:
#   bash publish.sh                          # solo arma ./dotclaude.tar.gz
#   bash publish.sh user@host:/var/www/dc/   # arma + scp del tarball Y de install.sh
#   DEST=rsync bash publish.sh user@host:/var/www/dc/   # usa rsync en vez de scp
#
# Tras subir, en cualquier server el comando es:
#   curl -fsSL https://claude.codeinfire.com/install.sh | bash

set -eu
cd "$(dirname "$0")"

OUT="dotclaude.tar.gz"
ITEMS=(.claude CLAUDE.md .mcp.json .gitignore install.sh)

for f in "${ITEMS[@]}"; do
  [ -e "$f" ] || { echo "✗ falta $f — ¿estás en la raíz del repo dotclaude?"; exit 1; }
done

echo "📦 Armando $OUT ..."
# NUNCA empaquetar overrides locales/per-máquina (tar ignora .gitignore, hay que excluir a mano).
tar --exclude='.claude/state' \
    --exclude='.claude/settings.local.json' \
    --exclude='.mcp.local.json' \
    --exclude='CLAUDE.local.md' \
    --exclude='dotclaude.tar.gz' \
    -czf "$OUT" "${ITEMS[@]}"
echo "✓ $OUT ($(du -h "$OUT" | cut -f1))"
if tar -tzf "$OUT" | grep -qE 'settings\.local\.json|CLAUDE\.local\.md|\.mcp\.local\.json'; then
  echo "✗ ERROR: el tarball contiene archivos de override local. Abortando."; rm -f "$OUT"; exit 1
fi

TARGET="${1:-}"
if [ -n "$TARGET" ]; then
  echo "⬆  Subiendo a $TARGET ..."
  if [ "${DEST:-scp}" = "rsync" ]; then
    rsync -avz "$OUT" install.sh "$TARGET"
  else
    scp "$OUT" install.sh "$TARGET"
  fi
  echo "✓ Subido. Probá:  curl -fsSL https://claude.codeinfire.com/install.sh | bash"
else
  echo "ℹ  Solo armé el tarball. Subí $OUT e install.sh a tu server, o pasá user@host:/ruta/"
fi
