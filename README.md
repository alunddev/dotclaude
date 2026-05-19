# dotclaude

Setup personal de Claude Code para desarrollo full-stack autónomo. Copia-pega-corré-listo.

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

### Opción 1 — función shell (recomendado)

Una sola vez, agregá esto a tu `~/.bashrc` o `~/.zshrc`:

```bash
claude-init() {
  local repo="alunddev/dotclaude"
  local tmp; tmp=$(mktemp -d)
  echo "📥 Clonando $repo..."
  gh repo clone "$repo" "$tmp/dc" -- --depth 1 --quiet
  bash "$tmp/dc/install.sh" "$@"
  rm -rf "$tmp"
}
```

Recargá: `source ~/.bashrc`

En cualquier proyecto nuevo:

```bash
cd ~/proyectos/mi-app
claude-init
```

### Opción 2 — manual

```bash
gh repo clone alunddev/dotclaude /tmp/dc
bash /tmp/dc/install.sh
rm -rf /tmp/dc
```

### Flags del installer

```bash
claude-init             # interactivo, pregunta antes de sobrescribir
claude-init --force     # sobrescribe sin preguntar
claude-init --dry-run   # muestra qué haría, no modifica
claude-init --no-setup  # copia pero no corre .claude/setup.sh
```

## Qué hace `install.sh`

1. Copia `.claude/`, `CLAUDE.md`, `.mcp.json` al directorio actual.
2. Hace **merge** del `.gitignore` (no overwrite — si ya tenés uno, agrega solo las líneas faltantes relacionadas con `.claude/state/`, `CLAUDE.local.md`, etc).
3. Da `+x` a los hooks y a `setup.sh`/`statusline`.
4. Corre `.claude/setup.sh --check` para validar que todo quedó bien.
5. Te imprime los pasos siguientes.

## Requisitos

- `bash`
- `gh` CLI autenticado (para `claude-init`)
- `git`
- `python3` (lo usa `setup.sh` para validar JSON)
- `node` + `npx` (opcional — solo para MCP servers)

## Estructura del repo

```
dotclaude/
├── README.md              ← este archivo
├── INSTRUCCIONES.md       ← manual de uso completo
├── install.sh             ← installer
├── .gitignore             ← template (se mergea al usar)
├── CLAUDE.md              ← reglas globales (template)
├── .mcp.json              ← MCP servers (template)
└── .claude/
    ├── settings.json      ← permisos + hooks
    ├── statusline
    ├── README.md          ← doc interna
    ├── setup.sh           ← validador idempotente
    ├── hooks/             ← 6 hooks (5 activos)
    ├── commands/          ← 15 slash commands
    ├── skills/            ← 45 knowledge packs
    ├── agents/            ← 116 especialistas
    ├── output-styles/     ← 4 perfiles
    ├── rules/             ← 8 path-scoped
    └── plugins/           ← reservado
```

## Personalización

- **Reglas globales** (compartidas entre proyectos): editar `CLAUDE.md` en este repo y volver a `claude-init` los proyectos.
- **Reglas por proyecto** (no van al repo): crear `CLAUDE.local.md` en el proyecto (ya está gitignored).
- **Agregar agents/skills/commands custom**: editá los `.md` correspondientes en este repo, commit, push. La próxima `claude-init` los baja.

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
