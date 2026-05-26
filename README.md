# dotclaude

Setup personal de Claude Code para desarrollo full-stack autónomo. Copia-pega-corré-listo.

## Quick start

Parado en el directorio del proyecto, en **cualquier** server (zero config):

```bash
curl -fsSL https://claude.codeinfire.com/install.sh | bash
```

Para instalar **y arrancar Claude** en el mismo comando:

```bash
curl -fsSL https://claude.codeinfire.com/install.sh | bash -s -- --go
```

**Como root**, `bypassPermissions` está bloqueado. Con `--go`, el installer aplica el confinamiento solo antes de arrancar. Sin `--go`, confinalo a mano tras instalar:

```bash
bash .claude/harden-root.sh && claude
```

## Contenido

| | Cantidad | Descripción |
|---|---:|---|
| 🤖 Agents | 116 | Especialistas (65 con auto-invocación PROACTIVELY) |
| 📚 Skills | 45 | Knowledge packs on-demand |
| ⚡ Commands | 15 | Slash commands (`/ship`, `/full-review`, etc.) |
| 🪝 Hooks | 5 | SessionStart, UserPromptSubmit, PreCompact, Stop, Notification |
| 📐 Rules | 8 | Path-scoped (api, backend, frontend, mobile, infra, data, security, tests) |
| 🎨 Output styles | 4 | terse, code-only, paranoid, teacher |
| 🔌 MCP servers | 6 | filesystem, fetch, sequential-thinking, sqlite, puppeteer, memory |

Tamaño total: ~2.5 MB.

## Instalación en un proyecto nuevo

### Opción 1 — comando único, zero config (recomendado)

En cualquier server o máquina, parado en el directorio del proyecto:

```bash
curl -fsSL https://claude.codeinfire.com/install.sh | bash
```

`install.sh` se baja el template solo (tarball desde tu host), copia `.claude/` + `CLAUDE.md` + `.mcp.json`, mergea `.gitignore`, valida y listo. **No requiere `gh`, ni token, ni tocar `~/.bashrc`** — el repo de GitHub queda **privado**; los servers tiran del tarball publicado en tu host.

Para que además **arranque Claude** al terminar:

```bash
curl -fsSL https://claude.codeinfire.com/install.sh | bash -s -- --go
```

> **No corras `claude init`** después. Ese comando interno de Claude Code
> genera un `CLAUDE.md` nuevo y pisaría el del template. El `.claude/` ya
> *es* la config — Claude levanta agentes, skills, comandos y hooks solo.

**Actualizar un proyecto:** volvé a correr el mismo `curl … | bash`. Tus `CLAUDE.local.md` y `.claude/state/` se preservan (gitignored, no se tocan).

### Opción 2 — funciones de shell (máquina de desarrollo)

Si trabajás desde tu propio equipo y querés tirar **directo del repo privado de GitHub** (sin pasar por el host), agregá esto a tu `~/.bashrc` / `~/.zshrc` una sola vez:

```bash
# Baja dotclaude del repo privado vía gh (tarball, sin .git) y lo extrae.
_dotclaude_fetch() {
  local repo="alunddev/dotclaude" dest="$1"; mkdir -p "$dest"
  gh api "repos/$repo/tarball/main" 2>/dev/null | tar -xz -C "$dest" --strip-components=1 \
    || { echo "❌ No pude bajar $repo. ¿Autenticado? gh auth status"; return 1; }
  [ -f "$dest/install.sh" ]
}

# claude-init [--force|--dry-run|--no-setup] [--go]   (--go arranca claude al terminar)
claude-init() {
  local tmp go=0 args=()
  for a in "$@"; do [ "$a" = "--go" ] && go=1 || args+=("$a"); done
  tmp=$(mktemp -d); echo "📥 Bajando dotclaude..."
  _dotclaude_fetch "$tmp/dc" || { rm -rf "$tmp"; return 1; }
  bash "$tmp/dc/install.sh" "${args[@]}"; local rc=$?; rm -rf "$tmp"
  [ $rc -eq 0 ] && [ $go -eq 1 ] && command -v claude >/dev/null && { echo "🚀 Arrancando claude..."; claude; return $?; }
  return $rc
}

claude-update() {  # re-instala la última versión sobre un proyecto existente
  local tmp; tmp=$(mktemp -d); echo "🔄 Actualizando dotclaude..."
  _dotclaude_fetch "$tmp/dc" || { rm -rf "$tmp"; return 1; }
  bash "$tmp/dc/install.sh" --force; local rc=$?; rm -rf "$tmp"; return $rc
}

alias ci='claude-init'      # solo instala
alias cig='claude-init --go' # instala + abre claude
```

Recargá `source ~/.bashrc` y usá `cig` (instala + abre claude) o `ci` (solo instala) en cualquier proyecto. `claude-update` re-instala la última versión sobre un proyecto ya inicializado. Requiere `gh` autenticado.

### Flags del installer

```bash
--force        # sobrescribe sin preguntar
--dry-run      # muestra qué haría, no modifica
--no-setup     # copia pero no corre .claude/setup.sh
--go           # tras instalar, arranca claude (combinable con los de arriba)
--owner=USER   # chown -R de lo creado a USER (solo root)
```

Vía curl se pasan con `bash -s --`, p.ej.: `curl -fsSL …/install.sh | bash -s -- --force --go`

### Owner de los archivos creados

Al correr **como root**, los archivos quedarían de `root`. El paso 6 del installer deja todo lo creado (`.claude/`, `CLAUDE.md`, `.mcp.json`, `.gitignore`, `CLAUDE.local.md`) con el dueño que elijas:

- **Interactivo** (root): pregunta el owner, con default = dueño actual del directorio (p.ej. `codeinfire`). `none` no cambia nada.
- **No interactivo** (`curl … | bash`): pasá `--owner=USER` o `DOTCLAUDE_OWNER=USER`. Sin eso, usa el dueño actual del directorio.
- **No-root**: no puede cambiar owner; lo saltea (los archivos ya son tuyos).

```bash
curl -fsSL https://claude.codeinfire.com/install.sh | bash -s -- --owner=codeinfire --go
# o:  DOTCLAUDE_OWNER=codeinfire curl -fsSL …/install.sh | bash -s -- --go
```

## Publicar cambios del template (mantenedor)

El comando `curl … | bash` sirve el tarball desde `claude.codeinfire.com`. Cuando edites el template (agents, skills, CLAUDE.md, etc.), commiteá a GitHub y **re-publicá el tarball** a tu host con `publish.sh`:

```bash
bash publish.sh                                   # solo arma ./dotclaude.tar.gz
bash publish.sh usuario@host:/ruta/al/webroot/    # arma + sube tarball e install.sh por scp
DEST=rsync bash publish.sh usuario@host:/ruta/    # idem con rsync
```

El tarball debe quedar accesible en `https://claude.codeinfire.com/dotclaude.tar.gz` e `install.sh` en `https://claude.codeinfire.com/install.sh`. La URL del tarball está fijada en `install.sh` (`DEFAULT_TARBALL_URL`); para apuntar a otro host sin editar, exportá `DOTCLAUDE_URL=...`.

## Correr como root (confinado)

El template arranca en `bypassPermissions` (autónomo, sin confirmaciones). **Claude se niega a usar ese modo como root** por seguridad. Si necesitás correrlo como root en un server, después de instalar:

```bash
bash .claude/harden-root.sh        # o --force para sobrescribir overrides previos
```

> Si instalás con `--go` **como root** y todavía no hay `settings.local.json`, el installer corre `harden-root.sh` automáticamente antes de arrancar Claude (así el comando único también sirve en root).

Eso genera dos overrides **locales** (gitignored, solo en ese server):

- `.claude/settings.local.json` — baja el modo a `acceptEdits` (root OK) y agrega `deny` duro sobre `/etc`, `/root`, `/var`, `/usr`, claves SSH, `sudo`/`su`, etc.
- `CLAUDE.local.md` — regla de comportamiento dura: **no salir del directorio del proyecto** y **no deployar nada** sin orden explícita. El directorio se detecta solo (la ruta actual).

Arrancá siempre desde la carpeta del proyecto para que el scope de archivos sea correcto: `cd <proyecto> && claude`.

> ⚠️ Es un cinturón fuerte a nivel app, **no una jaula de SO**. La única isolación garantizada como root sería un contenedor o un usuario no-root.

## Qué hace `install.sh`

0. **Bootstrap**: si no encuentra el template al lado (caso `curl | bash`), baja el tarball de `claude.codeinfire.com` a un temporal.
1. Copia `.claude/`, `CLAUDE.md`, `.mcp.json` al directorio actual.
2. Hace **merge** del `.gitignore` (no overwrite — si ya tenés uno, agrega solo las líneas faltantes relacionadas con `.claude/state/`, `CLAUDE.local.md`, etc).
3. Da `+x` a los hooks y a `setup.sh`/`statusline`.
4. Corre `.claude/setup.sh --check` para validar que todo quedó bien.
5. Con `--go`, arranca `claude`; si no, te imprime los pasos siguientes.

## Requisitos

En el server donde instalás (Opción 1):

- `bash` + (`curl` o `wget`)
- `python3` (lo usa `setup.sh` para validar JSON)
- `node` + `npx` (opcional — solo para MCP servers)
- `claude` (solo si usás `--go`)

Solo para la Opción 2 (funciones de shell) o publicar: `gh` CLI autenticado.

## Estructura del repo

```
dotclaude/
├── README.md              ← este archivo
├── INSTRUCCIONES.md       ← manual de uso completo
├── install.sh             ← installer (con bootstrap por tarball)
├── publish.sh             ← arma/sube dotclaude.tar.gz al host
├── .gitignore             ← template (se mergea al usar)
├── CLAUDE.md              ← reglas globales (template)
├── .mcp.json              ← MCP servers (template)
└── .claude/
    ├── settings.json      ← permisos + hooks
    ├── statusline
    ├── README.md          ← doc interna
    ├── setup.sh           ← validador idempotente
    ├── harden-root.sh     ← confina Claude para correr como root
    ├── hooks/             ← 6 hooks (5 activos)
    ├── commands/          ← 15 slash commands
    ├── skills/            ← 45 knowledge packs
    ├── agents/            ← 116 especialistas
    ├── output-styles/     ← 4 perfiles
    ├── rules/             ← 8 path-scoped
    └── plugins/           ← reservado
```

## Personalización

- **Reglas globales** (compartidas entre proyectos): editar `CLAUDE.md` en este repo, `bash publish.sh user@host:/ruta/`, y re-instalar los proyectos.
- **Reglas por proyecto** (no van al repo): crear `CLAUDE.local.md` en el proyecto (ya está gitignored).
- **Agregar agents/skills/commands custom**: editá los `.md` correspondientes en este repo, commit, push, `publish.sh`. La próxima instalación los baja.

## Documentación

- `INSTRUCCIONES.md` — manual completo de uso (slash commands, agents, skills, output styles, troubleshooting).
- `.claude/README.md` — referencia interna de la estructura.
- `CLAUDE.md` — reglas globales que Claude lee al iniciar.

## Filosofía

- **Autónomo**: `bypassPermissions` por defecto. Denylist hard-block para operaciones destructivas.
- **VCS-agnóstico**: nada depende de GitHub para funcionar — solo este repo usa GitHub.
- **Multi-stack**: cubre TS/JS/Py/Go/Rust/Java/Kotlin/Swift/C++/C#/PHP/Ruby/Elixir/Dart + sus frameworks.
- **Portable**: una sola convención de archivos para todos los proyectos.
- **Curado**: cada agent/skill revisado, tool hygiene aplicada, ghost references purgadas.

## Licencia

Personal. Reutilizable según tu criterio.
