# Instrucciones de uso — Claude Code autónomo

Manual práctico de tu setup `.claude/`. Léelo una vez; después usalo como referencia.

---

## 🚀 Quick start (5 minutos)

### 1. Instalar en un proyecto nuevo

```bash
cd /ruta/al/proyecto-nuevo
cp -r /home/nhck/Escritorio/project/.claude .
cp /home/nhck/Escritorio/project/CLAUDE.md .
cp /home/nhck/Escritorio/project/.mcp.json .
# Si el proyecto ya tiene .gitignore, mergealo con el de la plantilla
cp /home/nhck/Escritorio/project/.gitignore .gitignore  # o merge manual

# Inicializar y validar
bash .claude/setup.sh
```

### 2. Abrir Claude Code

```bash
claude
```

El hook `SessionStart` detecta automáticamente:
- Stack (Node/Python/Go/Rust/Java/etc.)
- Package manager (npm/pnpm/yarn/bun/poetry/uv/cargo)
- Frameworks (Next.js/Django/FastAPI/Spring/Flutter/etc.)
- Infra (Docker/K8s/Terraform)
- Estado de git

Y te recuerda: **"DELEGATION REMINDER: Before doing non-trivial work, check .claude/agents/ and delegate."**

### 3. Primera tarea recomendada

```
/init-stack
```

Detecta y guarda un resumen del proyecto en `.claude/state/stack.md`. La próxima sesión va más rápida.

---

## 📋 Cheatsheet de slash commands

| Comando | Cuándo usarlo |
|---|---|
| `/init-stack` | Primera vez en un proyecto. Detecta y cachea el stack. |
| `/health-check` | Auditoría completa: deps, security, tests, types, build, docs. **Read-only**. |
| `/health-check --fast` | Igual pero salta build y test suite. |
| `/ship` | Antes de pushear: install → lint → typecheck → test → build. **Local, sin GitHub**. |
| `/ship --skip-tests` | Si querés iterar más rápido. |
| `/full-review` | Review multi-agente del diff actual (code + arch + security en paralelo). |
| `/feature-dev "<descripción>"` | Pipeline completo de feature: requirements → tests → impl → review → QA. |
| `/refactor-clean` | Refactor con safety checks. |
| `/tech-debt` | Surface y prioriza deuda técnica. |
| `/tdd-cycle` | Red → Green → Refactor con apoyo de agents. |
| `/security-sast` | SAST scan estático. |
| `/security-deps` | Vulnerabilidades en dependencias. |
| `/error-analysis` | Root-cause analysis de logs/traces. |
| `/explain <archivo>` | Explicación en 3 capas (overview → estructura → línea por línea). |
| `/onboard` | Onboarding a un proyecto nuevo o nuevo contribuidor. |
| `/git-workflow` | Branch + commit + (opcional) PR con quality gates. |
| `/pr-enhance` | Mejora una descripción de PR desde el diff. |

---

## 🤖 Agents (los 116 especialistas)

### Invocación automática

**No tenés que hacer nada en la mayoría de los casos.** El setup tiene tres mecanismos que delegan solos:

1. **Tabla de routing en `CLAUDE.md` §1** — Claude lee la situación y consulta la tabla.
2. **`Use PROACTIVELY` en 65 agents** — Claude Code reconoce ese patrón y auto-invoca.
3. **`UserPromptSubmit` hook** — inyecta un hint en cada prompt según palabras clave ("refactor", "deploy", "error", "security", etc.).

Ejemplos de auto-invocación:
- Editás un `.tsx` → considera `typescript-pro` + `react-specialist`
- Aparece un error → invoca `debugger` + `error-detective`
- Tocás algo con `auth` o `password` → invoca `security-auditor`
- Cambiás un `Dockerfile` → invoca `docker-expert`

### Invocación manual

Si querés forzar un agent específico:

```
@code-archaeologist analizá el módulo src/payments/
```

O en un mensaje normal:

```
Usá el agent terraform-engineer para revisar terraform/production/
```

### Listado por categoría (los más usados)

**Desarrollo core:**
`backend-developer`, `frontend-developer`, `fullstack-developer`, `mobile-developer`, `api-designer`, `microservices-architect`

**Lenguajes:**
`typescript-pro`, `javascript-pro`, `python-pro`, `golang-pro`, `rust-engineer`, `java-architect`, `swift-expert`, `kotlin-specialist`, `cpp-pro`, `csharp-developer`, `php-pro`, `sql-pro`

**Frameworks:**
`react-specialist`, `vue-expert`, `angular-architect`, `nextjs-developer`, `django-developer`, `fastapi-developer`, `rails-expert`, `laravel-specialist`, `spring-boot-engineer`, `flutter-expert`, `expo-react-native-expert`

**Infra:**
`devops-engineer`, `docker-expert`, `kubernetes-specialist`, `terraform-engineer`, `cloud-architect`, `platform-engineer`, `sre-engineer`

**Calidad / Seguridad:**
`code-reviewer`, `debugger`, `error-detective`, `test-automator`, `security-auditor`, `performance-engineer`, `architect-reviewer`, `accessibility-tester`

**Data / AI:**
`data-engineer`, `ml-engineer`, `ai-engineer`, `prompt-engineer`, `database-administrator`, `database-optimizer`, `postgres-pro`, `vector-database-engineer`

**Custom (escritos para tu setup):**
`code-archaeologist`, `release-coordinator`, `spike-engineer`

**Lista completa:** `ls .claude/agents/`

---

## 🧠 Skills (35 paquetes de conocimiento)

Las skills cargan **on-demand**, no las invocás manualmente. Cuando Claude juzga que una skill es relevante, la lee sola.

Skills disponibles cubren:
- API design, microservices, architecture patterns
- Auth, secrets management
- Code review, debugging, testing (E2E, unit)
- Git workflows, monorepos
- K8s manifests, Helm charts, CI/CD
- Observability (Prometheus, distributed tracing, SLOs)
- Frontend (Next.js, React, RN, Tailwind)
- DB (PostgreSQL, SQL optimization)
- LLM apps (RAG, prompt engineering)
- Languages (TS advanced types, JS patterns, Python design/testing/async, Node)
- Accessibility (WCAG)

Si querés forzar el uso de una skill:

```
Usá la skill api-design-principles para revisar este endpoint
```

---

## 🎨 Output styles (cambiar el tono de respuesta)

Tenés 4 modos:

```
/output-style terse       # default — conciso
/output-style code-only   # solo código, cero prosa
/output-style paranoid    # ultra-cauto, para producción
/output-style teacher     # explicaciones extendidas, para aprender
```

Recomendados por contexto:
- **Iterando rápido** → `code-only`
- **Tocando producción / migrations / IAM** → `paranoid`
- **Aprendiendo un framework nuevo** → `teacher`
- **Día a día** → `terse`

---

## 🛡️ Permisos: cuánto te pregunta

Por defecto, **`bypassPermissions`** — Claude no pregunta nada. La denylist sigue activa para operaciones destructivas.

### Cambiar el modo temporalmente

```bash
claude --permission-mode default            # pregunta por todo
claude --permission-mode acceptEdits        # auto-acepta edits, pregunta por Bash
claude --permission-mode bypassPermissions  # default actual, sin prompts
claude --permission-mode plan               # read-only planning
```

### Cambiar el modo permanentemente

Editá `.claude/settings.json`:

```json
"permissions": {
  "defaultMode": "default",   ← cambialo
  ...
}
```

### Qué SIEMPRE está bloqueado (incluso en bypassPermissions)

- `rm -rf /` / `rm -rf ~` / `rm -rf $HOME`
- `sudo`, `su`
- `git push --force` a main/master
- `git reset --hard`, `git clean -fdx`
- `terraform destroy`, `aws rds delete`, `gcloud projects delete`
- `npm publish`, `cargo publish`, `twine upload`
- `curl … | sh`, `curl … | bash`
- Cualquier comando con `--no-verify`
- `mkfs`, `dd`, `fdisk`

Si necesitás ejecutar uno de estos, editá `.claude/settings.json` y removelo del array `deny`. O ejecutalo manualmente fuera de Claude.

---

## 📐 Reglas (path-scoped)

Tenés 8 reglas en `.claude/rules/` que cargan automáticamente según qué archivos toques:

| Regla | Aplica a |
|---|---|
| `api.md` | `src/api/**`, `apps/api/**`, `server/**` |
| `backend.md` | `backend/**`, `internal/**`, `**/handlers/**` |
| `frontend.md` | `**/*.tsx`, `**/*.jsx`, `**/*.vue`, etc. |
| `mobile.md` | `mobile/**`, `ios/**`, `android/**`, `**/*.swift`, `**/*.kt` |
| `infra.md` | `**/*.tf`, `k8s/**`, `Dockerfile*`, `.github/workflows/**` |
| `data.md` | `migrations/**`, `**/*.sql`, `etl/**`, `dbt/**` |
| `security.md` | `**/auth/**`, `**/*secret*`, `**/*token*` |
| `tests.md` | `**/*.test.*`, `**/*.spec.*`, `tests/**` |

### Agregar una regla custom

Creá `.claude/rules/mi-regla.md`:

```markdown
---
description: Reglas para mi módulo X
globs: ["src/x/**", "lib/x/**"]
---

# Reglas de X

## Required
- ...

## Don't
- ...
```

Se carga automáticamente cuando Claude trabaja en esos paths.

---

## 🔌 MCP servers

Tenés 6 servers configurados en `.mcp.json`. Arrancan automáticamente al lanzar Claude Code.

| Server | Para qué sirve |
|---|---|
| `filesystem` | Leer/escribir archivos fuera del proyecto (en `~`) |
| `fetch` | Bajar contenido HTTP (docs, APIs, scraping ligero) |
| `sequential-thinking` | Razonamiento estructurado paso a paso (problemas complejos) |
| `sqlite` | DB local en `.claude/state/local.db` (notas, prototipos) |
| `puppeteer` | Browser headless para E2E o scraping de JS-rendered |
| `memory` | Knowledge graph persistente entre sesiones |

### Requisitos

- **Node.js + npx** — todos los servers se bajan vía `npx -y` la primera vez.
- Si no tenés Node: comentá los servers que no necesités o instalá Node.

### Desactivar uno

Editá `.mcp.json` y remové la entrada del server. O renombrá a `.mcp.local.json` (gitignored) si querés desactivar solo localmente.

---

## 🪝 Hooks (lo que pasa automáticamente)

5 hooks activos:

| Hook | Cuándo dispara | Qué hace |
|---|---|---|
| `SessionStart` | Al abrir Claude Code en el proyecto | Imprime stack, git status, recordatorio de delegación |
| `UserPromptSubmit` | Cada vez que envías un mensaje | Inyecta routing hint según keywords ("refactor", "error", "deploy"...) |
| `PreCompact` | Antes de comprimir contexto | Guarda snapshot en `.claude/state/precompact-*.txt` |
| `Stop` | Al terminar cada turno | Loggea en `.claude/state/sessions-YYYY-MM-DD.log` |
| `Notification` | Cuando Claude pide atención | Manda notificación de escritorio (`notify-send`) |

### Desactivar un hook

Editá `.claude/settings.json`, remové la entrada del array `hooks.<NombreHook>`. O renombrá el `.sh` para que falle silenciosamente.

### Auto-formato al editar (opcional, está apagado)

Hay un `PostToolUse.sh` con un template de auto-formato comentado. Si querés activarlo:

1. Editá `.claude/hooks/PostToolUse.sh` y descomentá las líneas de Prettier/Black/gofmt.
2. Agregá la entrada en `settings.json`:

```json
"hooks": {
  "PostToolUse": [{
    "matcher": "Edit|Write",
    "hooks": [{ "type": "command", "command": "bash .claude/hooks/PostToolUse.sh" }]
  }],
  ...
}
```

---

## 🔄 Customización por proyecto

**Regla de oro:** `CLAUDE.md` se queda como template. Lo que es específico de un proyecto va en `CLAUDE.local.md` (gitignored).

```bash
# En el proyecto donde querés reglas extra:
cat > CLAUDE.local.md <<'EOF'
# Reglas específicas de este proyecto

- Usar Yarn Berry (no npm) — el monorepo no soporta otra cosa.
- Las migraciones DB pasan por nuestro custom CLI: `./scripts/migrate.sh`.
- Nunca tocar `legacy/payments/` sin avisar al equipo de finanzas.
EOF
```

Claude lee ambos archivos automáticamente.

---

## 🧹 Per-project state

`.claude/state/` (gitignored) tiene:
- `precompact-*.txt` — snapshots antes de compaction
- `sessions-*.log` — logs por turno
- `stack.md` — cache de `/init-stack`
- `local.db` — la DB SQLite del MCP

Para limpiar:
```bash
rm -rf .claude/state/* && bash .claude/setup.sh
```

---

## 🐛 Troubleshooting

### "Claude no está usando los agents"

Verificá:
1. `bash .claude/setup.sh --check` — corre la validación.
2. `cat CLAUDE.md` — la sección §1 debe estar presente.
3. Reiniciá Claude Code (los hooks no recargan en vivo).

### "El hook SessionStart no muestra nada"

```bash
chmod +x .claude/hooks/*.sh .claude/setup.sh .claude/statusline
bash .claude/hooks/SessionStart.sh  # corré manual para ver el error
```

### "MCP servers no arrancan"

```bash
which npx        # debe existir
node --version   # >= 18
```

Si no tenés Node, comentá los servers en `.mcp.json` o instalá Node.

### "Claude me sigue preguntando cosas"

Verificá `defaultMode` en `.claude/settings.json`:

```bash
grep defaultMode .claude/settings.json
# Debería decir: "defaultMode": "bypassPermissions"
```

Si lo cambia algo, restauralo.

### "Un comando bloqueado por la denylist"

Si tu uso legítimo está bloqueado, editá `.claude/settings.json` y remové la regla específica del array `deny`. Considerá si vale la pena el riesgo.

### "Un agent rompió algo"

Los agents son archivos `.md`, son seguros — no ejecutan código. Si un agent te da mal consejo:
1. Reportalo en tu cabeza ("este agent X no sirve para Y")
2. Editá `.claude/agents/<nombre>.md` y ajustá la descripción o el comportamiento.

---

## 🔁 Ciclo típico de uso

### Empezar el día

```bash
cd ~/proyectos/mi-app
claude
```

El SessionStart te muestra: stack, git status, recordatorio de delegación.

### Pedir una feature

```
Agregá un endpoint POST /users que valide email único y devuelva 201 con el user creado.
```

Claude (sin que pidas):
1. Invoca `api-designer` para el contrato.
2. Invoca `backend-developer` para la implementación.
3. Invoca `test-automator` para los tests.
4. Invoca `security-auditor` porque toca user input.
5. Te trae el diff.

### Antes de pushear

```
/ship
```

Si pasa: pusheás. Si no: te dice exactamente qué stage falló.

### Sacar versión

```
/feature-dev "preparar release v1.2.0"
# o directamente:
@release-coordinator generá changelog y release notes para la próxima versión
```

### Producción se cae

```
@devops-incident-responder los pods están crashloop en namespace prod-api
```

Modo paranoid recomendado:

```
/output-style paranoid
```

---

## 📚 Referencia rápida de archivos importantes

| Archivo | Para qué editarlo |
|---|---|
| `CLAUDE.md` | Reglas globales del proyecto (compartidas) |
| `CLAUDE.local.md` | Reglas tuyas, gitignored |
| `.claude/settings.json` | Permisos, modo, registro de hooks |
| `.claude/settings.local.json` | Overrides locales, gitignored |
| `.mcp.json` | Servers MCP (compartidos) |
| `.mcp.local.json` | Servers MCP locales, gitignored |
| `.claude/agents/<x>.md` | Editar comportamiento de un agent |
| `.claude/skills/<x>/SKILL.md` | Editar una skill |
| `.claude/commands/<x>.md` | Editar un slash command |
| `.claude/rules/<x>.md` | Crear/editar reglas path-scoped |
| `.claude/hooks/<x>.sh` | Editar comportamiento de un hook |

---

## ❓ FAQ

**¿Puedo usar esto sin Node.js?**
Sí, pero perdés los 6 MCP servers (todos usan `npx`). Los agents/skills/commands/hooks funcionan sin Node.

**¿Funciona sin git?**
Sí. Los hooks detectan si no hay git y se adaptan. `/ship` y `release-coordinator` funcionan con o sin git.

**¿Funciona sin GitHub?**
Sí, completamente. Nada acá depende de `gh` CLI ni de github.com.

**¿Puedo agregar mis propios agents?**
Sí. Creá `.claude/agents/mi-agent.md` con el frontmatter estándar:

```markdown
---
name: mi-agent
description: "Qué hace. Use PROACTIVELY when <trigger>."
tools: Read, Write, Edit, Bash, Grep, Glob
model: sonnet
---

# Mi agent

Instrucciones del comportamiento del agent...
```

**¿Puedo agregar mis propios commands?**
Sí. Creá `.claude/commands/mi-cmd.md`:

```markdown
---
description: Qué hace
argument-hint: "[args opcionales]"
---

# /mi-cmd

Procedimiento...
```

Se invoca como `/mi-cmd`.

**¿Cómo actualizo este setup?**
Es tuyo — no hay actualización automática. Si querés mejoras puntuales (nuevos agents, skills, fixes), las aplicás vos. La estructura está documentada en `.claude/README.md` y este archivo.

**¿Y si rompo algo?**
`bash .claude/setup.sh --check` te dice qué está roto. Si no podés arreglarlo, copiá la versión funcional desde `/home/nhck/Escritorio/project/.claude/` de nuevo.

---

## 📞 Cuando algo no es obvio

Preguntale a Claude directamente:

```
¿Qué agents tenés disponibles para X?
¿Cómo cambio Y?
¿Por qué no funcionó Z?
```

El setup está documentado en `CLAUDE.md` y `.claude/README.md` — Claude los lee y te puede explicar.
