#!/usr/bin/env bash
# install.sh — instala el template dotclaude en el directorio actual.
#
# Uso LOCAL (con el repo clonado/extraído al lado de este script):
#   bash install.sh [--force] [--dry-run] [--no-setup] [--go]
#
# Uso REMOTO (zero-config, un solo comando en cualquier server):
#   curl -fsSL https://claude.codeinfire.com/install.sh | bash
#   → si no encuentra el template al lado, se baja el tarball solo (--go arranca claude).
#
# Flags:
#   --force        sobrescribe sin preguntar
#   --dry-run      muestra qué haría, no modifica nada
#   --no-setup     copia pero no corre .claude/setup.sh
#   --go           al terminar, arranca `claude`
#   --owner=USER   chown -R de lo creado a USER (solo root). Default: dueño del dir.
#                  Como root e interactivo, lo pregunta. `--owner=none` = no cambiar.
#
# Entorno (override para self-hosting / automatización):
#   DOTCLAUDE_URL=https://mi-server/dotclaude.tar.gz   origen del tarball
#   DOTCLAUDE_OWNER=usuario                            owner sin prompt

set -eu

# ─── URL del tarball del template ────────────────────────────────────────────
# El tarball debe contener EN SU RAÍZ: .claude/  CLAUDE.md  .mcp.json  .gitignore
# (lo genera el script publish.sh de este repo). Editá DEFAULT_TARBALL_URL con
# la URL de TU server, o pasá DOTCLAUDE_URL=... por entorno.
DEFAULT_TARBALL_URL="https://claude.codeinfire.com/dotclaude.tar.gz"
TARBALL_URL="${DOTCLAUDE_URL:-$DEFAULT_TARBALL_URL}"

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

# --- Flags ---
FORCE=0
DRY_RUN=0
RUN_SETUP=1
GO=0
OWNER="${DOTCLAUDE_OWNER:-}"   # vacío = preguntar (root) o no cambiar (no-root)
for arg in "$@"; do
  case "$arg" in
    --force)    FORCE=1 ;;
    --dry-run)  DRY_RUN=1 ;;
    --no-setup) RUN_SETUP=0 ;;
    --go)       GO=1 ;;
    --owner=*)  OWNER="${arg#*=}" ;;
    -h|--help)
      sed -n '2,21p' "$0" 2>/dev/null | sed 's/^# \{0,1\}//'
      exit 0 ;;
    *) echo "Unknown flag: $arg"; exit 1 ;;
  esac
done

# --- Resolución de paths ---
# SOURCE_DIR = de dónde se copia el template.
# TARGET_DIR = dónde se corre el comando (el proyecto del usuario).
TARGET_DIR="$(pwd)"
SOURCE_DIR=""
# $0 puede no ser un path real cuando corre vía `curl | bash`.
if SELF="$(cd "$(dirname "$0")" 2>/dev/null && pwd)"; then
  [ -d "$SELF/.claude" ] && SOURCE_DIR="$SELF"
fi

# --- Bootstrap: si no hay template al lado, bajarlo del tarball ---
BOOT_TMP=""
if [ -z "$SOURCE_DIR" ]; then
  if [ "$TARBALL_URL" = "https://CHANGEME/dotclaude/dotclaude.tar.gz" ]; then
    err "No hay template al lado y TARBALL_URL no está configurada."
    err "Editá DEFAULT_TARBALL_URL en install.sh o pasá DOTCLAUDE_URL=... por entorno."
    exit 1
  fi
  BOOT_TMP="$(mktemp -d)"
  trap 'rm -rf "$BOOT_TMP"' EXIT
  say "📥 Bajando template: $TARBALL_URL"
  if command -v curl >/dev/null 2>&1; then
    curl -fsSL "$TARBALL_URL" | tar -xz -C "$BOOT_TMP"
  elif command -v wget >/dev/null 2>&1; then
    wget -qO- "$TARBALL_URL" | tar -xz -C "$BOOT_TMP"
  else
    err "Necesito curl o wget para bajar el template."
    exit 1
  fi
  if [ ! -d "$BOOT_TMP/.claude" ]; then
    err "El tarball no contiene .claude/ en su raíz. ¿URL correcta?"
    exit 1
  fi
  SOURCE_DIR="$BOOT_TMP"
fi

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
    # Bajo `curl | bash` stdin es el pipe del script; leemos del terminal real.
    if [ -e /dev/tty ]; then
      read -rp "  ¿Sobrescribir? (s/N) " ans </dev/tty
    else
      err "Conflictos y sin TTY para confirmar. Usá --force."
      exit 1
    fi
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
# Defensa: nunca dejar overrides locales que se hayan colado en un tarball viejo.
if [ "$DRY_RUN" = "0" ]; then
  rm -f "$TARGET_DIR/.claude/settings.local.json" "$TARGET_DIR/.mcp.local.json"
fi
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
  [ -f "$TARGET_DIR/.claude/setup.sh" ]       && chmod +x "$TARGET_DIR/.claude/setup.sh"
  [ -f "$TARGET_DIR/.claude/harden-root.sh" ] && chmod +x "$TARGET_DIR/.claude/harden-root.sh"
  [ -f "$TARGET_DIR/.claude/statusline" ]     && chmod +x "$TARGET_DIR/.claude/statusline"
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

# Inserta/regenera un bloque marcado con la regla workstation→public_html en CLAUDE.local.md.
# No pisa el resto del archivo: solo el bloque entre marcadores.
write_workspace_rule() {
  local ws="$1" dep="$2" file="$TARGET_DIR/CLAUDE.local.md"
  local begin="<!-- BEGIN dotclaude:workspace-rule -->"
  local end="<!-- END dotclaude:workspace-rule -->"
  local block
  block="$begin
# Workspace y deploy — REGLA DURA (regenerado por install.sh; no editar entre marcadores)

- **Trabajás SOLO dentro de \`workstation\`:** \`$ws\`
  Todo lo que generes (código, builds, temporales) va ACÁ.
- **Producción es \`public_html\`:** \`$dep\`
  Es el ÚNICO lugar fuera de \`workstation\` donde se puede escribir, y SOLO para deploy.
- **No deployes por iniciativa propia.** Sincronizar/copiar a \`public_html\` se hace
  ÚNICAMENTE cuando se ordena explícitamente, paso a paso.
- **Nada fuera de esos dos directorios** (ni /etc, ni otros /home, ni el resto del server).
$end"
  if [ -f "$file" ] && grep -qF "$begin" "$file"; then
    local tmp; tmp="$(mktemp)"
    awk -v b="$begin" -v e="$end" '
      $0==b {skip=1}
      skip!=1 {print}
      $0==e {skip=0}
    ' "$file" > "$tmp"
    printf '%s\n' "$block" >> "$tmp"
    mv "$tmp" "$file"
  else
    { [ -f "$file" ] && echo ""; printf '%s\n' "$block"; } >> "$file"
  fi
}

# --- 6. Regla workstation → public_html ---
say "6. Regla de workspace"
if [ "$(basename "$TARGET_DIR")" = "workstation" ]; then
  WS_DIR="$TARGET_DIR"
  DEPLOY_DIR="$(dirname "$TARGET_DIR")/public_html"
  if [ "$DRY_RUN" = "1" ]; then
    plan "CLAUDE.local.md: trabajo=$WS_DIR · deploy=$DEPLOY_DIR"
  else
    write_workspace_rule "$WS_DIR" "$DEPLOY_DIR"
    ok "regla escrita: workstation=$WS_DIR → public_html=$DEPLOY_DIR"
  fi
else
  ok "el dir no se llama 'workstation' — sin regla de deploy"
fi
echo ""

# --- Confinamiento root (solo si se va a arrancar con --go) ---
# Como root, bypassPermissions está bloqueado; aplicamos harden-root antes de arrancar.
if [ "$GO" = "1" ] && [ "$DRY_RUN" = "0" ] && [ "$(id -u)" = "0" ] \
   && [ ! -f "$TARGET_DIR/.claude/settings.local.json" ]; then
  if [ -f "$TARGET_DIR/.claude/harden-root.sh" ]; then
    warn "root detectado — aplicando confinamiento (harden-root) antes de arrancar"
    bash "$TARGET_DIR/.claude/harden-root.sh"
    echo ""
  else
    warn "root detectado y sin harden-root.sh; claude no podrá usar bypassPermissions."
  fi
fi

# --- 7. Owner de lo creado (chown -R) ---
say "7. Owner de los archivos creados"
OWN_ITEMS=(.claude CLAUDE.md .mcp.json .gitignore CLAUDE.local.md)
if [ "$DRY_RUN" = "1" ]; then
  if [ "$(id -u)" = "0" ]; then
    plan "chown -R ${OWNER:-<dueño actual del dir>} de: ${OWN_ITEMS[*]}"
  else
    plan "no-root: sin cambio de owner"
  fi
elif [ "$(id -u)" = "0" ]; then
  # Resolver OWNER: flag/env, si no prompt (default = dueño actual del dir).
  if [ -z "$OWNER" ]; then
    DEFAULT_OWNER="$(stat -c '%U' "$TARGET_DIR" 2>/dev/null || echo root)"
    if [ -e /dev/tty ]; then
      printf "  Owner para lo creado [%s] ('none' = no cambiar): " "$DEFAULT_OWNER" >/dev/tty
      read -r OWNER </dev/tty || OWNER=""
    fi
    [ -z "$OWNER" ] && OWNER="$DEFAULT_OWNER"
  fi
  if [ "$OWNER" = "none" ]; then
    ok "sin cambios (none)"
  elif id "$OWNER" >/dev/null 2>&1; then
    OWNER_GROUP="$(id -gn "$OWNER" 2>/dev/null || echo "$OWNER")"
    for item in "${OWN_ITEMS[@]}"; do
      [ -e "$TARGET_DIR/$item" ] && chown -R "$OWNER:$OWNER_GROUP" "$TARGET_DIR/$item"
    done
    ok "owner → $OWNER:$OWNER_GROUP"
  else
    err "owner '$OWNER' no existe — sin cambios."
  fi
else
  if [ -n "$OWNER" ] && [ "$OWNER" != "none" ]; then
    warn "owner '$OWNER' pedido pero no sos root — no se puede chown. Salteando."
  else
    ok "no-root: el owner ya sos vos ($(id -un))"
  fi
fi
echo ""

say "${G}✅ Listo${N}"
echo ""

# --- Arrancar claude si se pidió --go ---
if [ "$GO" = "1" ] && [ "$DRY_RUN" = "0" ]; then
  if command -v claude >/dev/null 2>&1; then
    say "🚀 Arrancando claude..."
    if [ -e /dev/tty ]; then
      exec claude </dev/tty
    else
      exec claude
    fi
  else
    warn "--go pedido pero 'claude' no está instalado/en PATH."
  fi
fi

echo "Próximos pasos:"
echo "  1. (opcional) Editá CLAUDE.local.md con reglas específicas del proyecto"
echo "  2. Abrí Claude Code: ${B}claude${N}"
echo "  3. El SessionStart hook detecta tu stack automáticamente"
