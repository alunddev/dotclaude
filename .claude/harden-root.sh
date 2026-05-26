#!/usr/bin/env bash
# harden-root.sh — confina Claude Code a este directorio para poder correr como root.
#
# Por qué: el template arranca en `bypassPermissions`, y Claude se NIEGA a usar ese
# modo como root (combinación peligrosa). Este script baja el modo a `acceptEdits`
# (root OK) y agrega un deny duro sobre los directorios del sistema.
#
# Uso (parado en el directorio del proyecto):
#   bash .claude/harden-root.sh          # crea el override si no existe
#   bash .claude/harden-root.sh --force  # sobrescribe si ya existe
#
# Genera (gitignored, queda solo en este server):
#   .claude/settings.local.json   modo no-bypass + deny del sistema
#
# La regla de comportamiento (workstation → public_html, no salir del dir) la
# escribe install.sh en CLAUDE.local.md cuando el dir se llama "workstation".

set -eu

FORCE=0
[ "${1:-}" = "--force" ] && FORCE=1

# Raíz del proyecto = el padre de la carpeta .claude donde vive este script.
PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
SETTINGS="$PROJECT_DIR/.claude/settings.local.json"

if [ -t 1 ]; then G=$'\033[32m'; Y=$'\033[33m'; B=$'\033[1m'; N=$'\033[0m'; else G=''; Y=''; B=''; N=''; fi

write_or_skip() {
  local path="$1"
  if [ -e "$path" ] && [ "$FORCE" = "0" ]; then
    echo "  ${Y}⚠${N} ya existe, no lo toco (usá --force): $path"
    return 1
  fi
  return 0
}

echo "${B}harden-root${N} — confinando Claude a: $PROJECT_DIR"

if write_or_skip "$SETTINGS"; then
  cat > "$SETTINGS" <<'JSON'
{
  "permissions": {
    "defaultMode": "acceptEdits",
    "deny": [
      "Read(/etc/**)", "Read(/root/**)", "Read(/boot/**)", "Read(/sys/**)",
      "Read(/proc/**)", "Read(/var/**)", "Read(/usr/**)", "Read(/opt/**)",
      "Read(/srv/**)", "Read(/run/**)", "Read(/home/*/.ssh/**)",
      "Edit(/etc/**)", "Edit(/root/**)", "Edit(/var/**)", "Edit(/usr/**)",
      "Edit(/boot/**)", "Edit(/opt/**)", "Edit(/srv/**)",
      "Write(/etc/**)", "Write(/root/**)", "Write(/var/**)", "Write(/usr/**)",
      "Write(/boot/**)", "Write(/opt/**)", "Write(/srv/**)",
      "Bash(sudo:*)", "Bash(su:*)"
    ]
  }
}
JSON
  echo "  ${G}✓${N} .claude/settings.local.json (modo acceptEdits + deny del sistema)"
fi

echo ""
echo "Listo. Arrancá SIEMPRE desde esta carpeta para que el scope de archivos sea correcto:"
echo "  ${B}cd $PROJECT_DIR && claude${N}"
echo ""
echo "${Y}Nota:${N} esto es un cinturón fuerte a nivel app, no una jaula de SO. La única"
echo "isolación garantizada como root sería un contenedor o un usuario no-root."
