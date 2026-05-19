#!/usr/bin/env bash
# install.sh — copia el template dotclaude al directorio actual.
#
# Uso:
#   bash install.sh              # interactivo: confirma overwrite si hay conflictos
#   bash install.sh --force      # sobrescribe sin preguntar
#   bash install.sh --dry-run    # muestra qué haría sin tocar nada
#   bash install.sh --no-setup   # copia pero no corre .claude/setup.sh

set -eu

# --- Resolución de paths ---
# SOURCE_DIR = dónde vive este install.sh (el clone de dotclaude)
# TARGET_DIR = dónde se corre el comando (el proyecto del usuario)
SOURCE_DIR="$(cd "$(dirname "$0")" && pwd)"
TARGET_DIR="$(pwd)"

# --- Flags ---
FORCE=0
DRY_RUN=0
RUN_SETUP=1
for arg in "$@"; do
  case "$arg" in
    --force)    FORCE=1 ;;
    --dry-run)  DRY_RUN=1 ;;
    --no-setup) RUN_SETUP=0 ;;
    -h|--help)
      head -10 "$0" | tail -8 | sed 's/^# //; s/^#//'
      exit 0 ;;
    *) echo "Unknown flag: $arg"; exit 1 ;;
  esac
done

# --- Colores ---
if [ -t 1 ]; then
  R=$'\033[31m'; G=$'\033[32m'; Y=$'\033[33m'; B=$'\033[1m'; N=$'\033[0m'
else
  R=''; G=''; Y=''; B=''; N=''
fi

say()  { echo "${B}$*${N}"; }
ok()   { echo "  ${G}✓${N} $*"; }
warn() { echo "  ${Y}⚠${N} $*"; }
err()  { echo "  ${R}✗${N} $*"; }
plan() { echo "  ${Y}→${N} $*"; }

# --- Sanity checks ---
say "dotclaude installer"
echo ""

if [ "$SOURCE_DIR" = "$TARGET_DIR" ]; then
  err "SOURCE = TARGET. Estás corriendo el installer desde el propio repo dotclaude."
  err "Movete al proyecto donde querés instalar y volvé a correr."
  exit 1
fi

case "$TARGET_DIR" in
  /|/home|/root|/usr|/etc|/var|/tmp)
    err "TARGET = $TARGET_DIR — ubicación peligrosa. Abortando."
    exit 1 ;;
esac

if [ "$TARGET_DIR" = "$HOME" ] || [ "$TARGET_DIR" = "$HOME/Desktop" ] || [ "$TARGET_DIR" = "$HOME/Escritorio" ]; then
  err "TARGET = $TARGET_DIR — refusing to install in HOME or Desktop root."
  err "Creá un subdirectorio para tu proyecto primero."
  exit 1
fi

say "Source: $SOURCE_DIR"
say "Target: $TARGET_DIR"
[ "$DRY_RUN" = "1" ] && say "${Y}DRY-RUN: no se va a modificar nada${N}"
echo ""

# --- Confirm si hay archivos existentes ---
say "1. Detectando conflictos"
CONFLICTS=()
for item in .claude CLAUDE.md .mcp.json; do
  [ -e "$TARGET_DIR/$item" ] && CONFLICTS+=("$item")
done

if [ "${#CONFLICTS[@]}" -gt 0 ] && [ "$FORCE" = "0" ]; then
  warn "Existen ya en target: ${CONFLICTS[*]}"
  if [ "$DRY_RUN" = "0" ]; then
    read -rp "  ¿Sobrescribir? (s/N) " ans
    case "${ans,,}" in
      s|si|sí|y|yes) ;;
      *) err "Cancelado."; exit 1 ;;
    esac
  fi
else
  ok "sin conflictos"
fi
echo ""

# --- Copia ---
say "2. Copiando template"
COPY_ITEMS=(.claude CLAUDE.md .mcp.json)

for item in "${COPY_ITEMS[@]}"; do
  src="$SOURCE_DIR/$item"
  dst="$TARGET_DIR/$item"
  if [ ! -e "$src" ]; then
    err "no existe en source: $item"
    continue
  fi
  if [ "$DRY_RUN" = "1" ]; then
    plan "copy: $src → $dst"
  else
    rm -rf "$dst"
    cp -r "$src" "$dst"
    ok "$item"
  fi
done
echo ""

# --- .gitignore: merge en vez de overwrite ---
say "3. .gitignore (merge)"
if [ -f "$SOURCE_DIR/.gitignore" ]; then
  if [ -f "$TARGET_DIR/.gitignore" ]; then
    if [ "$DRY_RUN" = "1" ]; then
      plan "merge .gitignore (append claude entries si faltan)"
    else
      # Append solo las líneas relacionadas a claude si no están ya
      tmp=$(mktemp)
      cp "$TARGET_DIR/.gitignore" "$tmp"
      added=0
      while IFS= read -r line; do
        # Solo agregamos líneas de la sección "Personal Claude Code state" y secrets relacionados
        if [[ "$line" =~ \.claude/ ]] || [[ "$line" =~ CLAUDE\.local ]] || [[ "$line" =~ \.mcp\.local ]]; then
          if ! grep -qF "$line" "$tmp"; then
            echo "$line" >> "$tmp"
            added=$((added+1))
          fi
        fi
      done < "$SOURCE_DIR/.gitignore"
      mv "$tmp" "$TARGET_DIR/.gitignore"
      ok "merge completo (+$added líneas)"
    fi
  else
    if [ "$DRY_RUN" = "1" ]; then
      plan "copy .gitignore (no existía en target)"
    else
      cp "$SOURCE_DIR/.gitignore" "$TARGET_DIR/.gitignore"
      ok "copiado nuevo"
    fi
  fi
fi
echo ""

# --- Permisos ejecutables + state dir ---
say "4. Permisos + state dir"
if [ "$DRY_RUN" = "0" ]; then
  find "$TARGET_DIR/.claude/hooks" -name '*.sh' -type f -exec chmod +x {} \; 2>/dev/null
  [ -f "$TARGET_DIR/.claude/setup.sh" ]   && chmod +x "$TARGET_DIR/.claude/setup.sh"
  [ -f "$TARGET_DIR/.claude/statusline" ] && chmod +x "$TARGET_DIR/.claude/statusline"
  mkdir -p "$TARGET_DIR/.claude/state"
  ok "hooks ejecutables + state/ creado"
else
  plan "chmod +x .claude/hooks/*.sh, setup.sh, statusline; mkdir .claude/state"
fi
echo ""

# --- Setup ---
if [ "$RUN_SETUP" = "1" ] && [ "$DRY_RUN" = "0" ]; then
  say "5. Validando con setup.sh"
  if [ -f "$TARGET_DIR/.claude/setup.sh" ]; then
    bash "$TARGET_DIR/.claude/setup.sh" --check
  else
    warn ".claude/setup.sh no encontrado"
  fi
elif [ "$RUN_SETUP" = "0" ]; then
  warn "setup.sh saltado (--no-setup)"
fi

echo ""
say "${G}✅ Listo${N}"
echo ""
echo "Próximos pasos:"
echo "  1. (opcional) Editá CLAUDE.local.md con reglas específicas del proyecto"
echo "  2. Abrí Claude Code: ${B}claude${N}"
echo "  3. El SessionStart hook detecta tu stack automáticamente"
