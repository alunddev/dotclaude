---
name: i18n-implementation
description: Internationalization and localization patterns — message catalogs, pluralization, formatters, RTL languages, locale routing, lazy-loading translations, common pitfalls. Library-agnostic (i18next, react-intl/formatjs, next-intl, gettext, ICU MessageFormat). Use when adding i18n to an app, supporting new locales, or fixing translation/formatting bugs.
---

# Internationalization (i18n) implementation

i18n is almost always added too late. Adding it early costs little; adding it later costs months. This skill is about getting it right the first time, or surviving the retrofit.

## When to use this skill

- Starting a new app that might ever go international (= almost always)
- Adding the first non-English locale to an existing app
- Fixing pluralization, RTL, or date/currency formatting bugs
- Choosing an i18n library
- Setting up translation workflows with translators

## Vocabulary

- **i18n** = Internationalization. Making your code locale-aware.
- **l10n** = Localization. Translating to specific locales.
- **Locale** = language + region: `en-US`, `pt-BR`, `es-MX`, `zh-CN`.
- **Translation key** = stable identifier: `checkout.button.confirm`.
- **Message** = the actual string to display, possibly with placeholders.
- **ICU MessageFormat** = standard format for plurals, gender, selects.

## Core principles

1. **Never concatenate translated strings.** "Hello " + name + "!" breaks in any language with different word order.
2. **No string literals in UI code.** Every user-visible string goes through the i18n layer.
3. **Translation keys are stable.** Renaming a key invalidates translations.
4. **Plurals are not just "n != 1".** Many languages have 3+ plural forms.
5. **Dates, numbers, currencies are formatted via locale APIs.** Never hand-format.

## Library selection

| Library | Stack | Notes |
|---|---|---|
| **i18next** | JS / Node / React / Vue / etc. | Most popular, plugin ecosystem |
| **react-intl / formatjs** | React | Standards-based, ICU format |
| **next-intl** | Next.js App Router | Designed for Next.js routing |
| **vue-i18n** | Vue | Vue-native |
| **angular i18n** | Angular | Built-in, AOT-friendly |
| **gettext** | Python / Go / many | Old, but proven; uses .po files |
| **fluent** (Mozilla) | Polyglot | Powerful, less common |
| **Babel** | Python | `babel.dates`, `babel.numbers` |

Default for new React: **react-intl** (formatjs). For Next.js App Router: **next-intl**. For non-JS: **gettext** + Babel.

## Pattern 1: Translation keys (not English strings as keys)

**Bad** (English-as-key):
```javascript
t("Welcome back, {{name}}!")
```

**Good** (key as ID):
```javascript
t("homepage.welcome.returning", { name })
```

Why: when English copy changes ("Welcome back" → "Hi there"), key stays stable. Translators don't have to redo other languages.

Convention: `<area>.<component>.<purpose>` — hierarchical, greppable.

## Pattern 2: ICU MessageFormat for plurals + selects

```
{count, plural,
  =0 {No items}
  one {# item}
  other {# items}
}
```

Languages with multiple plural forms (Russian: 4 forms, Arabic: 6 forms) work correctly:

```
ru.json:
"items.count": "{count, plural, one {# элемент} few {# элемента} many {# элементов} other {# элемента}}"
```

The library handles which form to pick — you don't write `if`s.

### Gender / select

```
{gender, select,
  male {He liked your post}
  female {She liked your post}
  other {They liked your post}
}
```

Use sparingly. "They" is increasingly the default in English.

## Pattern 3: Don't concatenate

```javascript
// BAD — breaks in many languages
const greeting = t("hello") + ", " + userName + "!";

// GOOD — placeholders inside the translated string
const greeting = t("greeting", { name: userName });
// "greeting": "Hello, {name}!"
```

The order of placeholders, articles, punctuation — all need to be inside the translation.

### React: components inside translated strings

```jsx
// react-intl / formatjs
<FormattedMessage
  id="user.signup.terms"
  defaultMessage="By signing up you agree to our <link>Terms</link>."
  values={{ link: chunks => <a href="/terms">{chunks}</a> }}
/>
```

The translator gets `<link>`/`</link>` markers and can move them anywhere in the sentence.

## Pattern 4: Formatters use locale APIs

```javascript
// Dates
const f = new Intl.DateTimeFormat(locale, { dateStyle: 'long', timeStyle: 'short' });
f.format(new Date());
// en-US: "January 15, 2026 at 3:45 PM"
// es-ES: "15 de enero de 2026, 15:45"

// Numbers
new Intl.NumberFormat(locale).format(1234567.89);
// en-US: "1,234,567.89"
// de-DE: "1.234.567,89"
// fr-FR: "1 234 567,89"

// Currency
new Intl.NumberFormat(locale, { style: 'currency', currency: 'USD' }).format(99.99);
// en-US: "$99.99"
// fr-FR: "99,99 $US"

// Relative time
new Intl.RelativeTimeFormat(locale).format(-3, 'day');
// en: "3 days ago"
// es: "hace 3 días"

// List formatting
new Intl.ListFormat(locale).format(['apples', 'oranges', 'bananas']);
// en: "apples, oranges, and bananas"
// es: "apples, oranges y bananas"
```

**Never** hand-format: `${day}/${month}/${year}` will be wrong somewhere.

## Pattern 5: Locale detection and routing

### Next.js App Router with next-intl

```
app/
  [locale]/
    layout.tsx
    page.tsx
    products/
      page.tsx
```

URLs: `/en/products`, `/es/productos`, `/de/produkte`.

Detection order:
1. URL path (`/es/...` wins)
2. Cookie (`NEXT_LOCALE`)
3. `Accept-Language` header
4. Default fallback (`en`)

### SPA / client-side

```javascript
function detectLocale() {
  const stored = localStorage.getItem('locale');
  if (stored) return stored;
  return navigator.language ?? 'en';
}
```

Always offer a manual override; auto-detection is wrong often.

## Pattern 6: Lazy-loading translations

Loading all locales upfront is wasteful (200KB+ for popular apps).

```javascript
// react-intl
async function loadLocale(locale) {
  const messages = await import(`../locales/${locale}.json`);
  return messages.default;
}

// At app init
const messages = await loadLocale(currentLocale);
<IntlProvider locale={currentLocale} messages={messages}>...</IntlProvider>
```

Split by route too if your app is large.

## Pattern 7: RTL (right-to-left) support

For Arabic, Hebrew, Persian, Urdu:

```html
<html lang="ar" dir="rtl">
```

CSS:
- Use **logical properties**: `padding-inline-start` instead of `padding-left`.
- Use `margin-inline`, `border-inline-start`, etc.
- Tailwind: `ms-4` (margin-start), `pe-2` (padding-end). They auto-flip on RTL.

Icons that "point" (back arrows, chevrons): mirror them in RTL.

```css
[dir="rtl"] .icon-arrow-left { transform: scaleX(-1); }
```

Numbers, dates, and code blocks remain LTR even in RTL contexts (handled by the browser if marked `dir="ltr"` inline).

## Pattern 8: Pseudo-localization (for testing)

Before translations arrive, replace text with `[!! Wéłçömé bãçk, {name} !!]`. Helps catch:

- Hardcoded English strings
- Layout breakage from longer text
- Missing placeholders
- Concatenation bugs

i18next has a `pseudo` plugin. Use it in staging.

## Translation workflow

### Storage formats
- **JSON** — universal, simple, easy to diff
- **PO/POT** (gettext) — proven, has tooling (Poedit, Transifex)
- **YAML** — readable, used by Rails/Django

### Source of truth
Translation keys defined in code → extracted to a base file (`en.json` or `en.po`) → sent to translators → translated files come back.

Tools:
- **formatjs/extract** — extracts messages from React + JS
- **i18next-parser** — extracts t() calls
- **xgettext** — for gettext-based stacks

### Translation management
- **Crowdin** / **Lokalise** / **Phrase** / **Transifex** — paid, full-featured
- **Weblate** — open source, self-hosted
- **GitHub PR-based** — works for small teams + few languages

### Translator handoff
- Provide **context** — where does this string appear? What's the screen showing? Screenshots help.
- Provide **max length** when UI is tight ("must fit in 20 chars").
- Provide **placeholders documentation** — what's `{count}`, `{name}`?
- Never give translators raw HTML — give them the strings with `<placeholder>` tags.

## Anti-patterns

- **`"You have " + n + " items"`** — see "no concatenation" above.
- **English strings as keys** — coupling translations to source copy.
- **Translating untranslatable** — product names, code, error codes. Mark them as "do not translate".
- **Hardcoded `MM/DD/YYYY`** — only correct in the US.
- **Sorting alphabetically with default `<` operator** — works in English, breaks for `ñ`, `ä`, `ø`. Use `Intl.Collator`.
- **Truncating strings by char count** for "max 20 chars" — multibyte chars (Chinese, emoji) break this. Use grapheme-aware truncation.
- **Mixing `en-US` and `en-GB`** as if they're the same — they're not (date formats, spelling, currency).
- **No fallback locale** — missing translation = blank UI.
- **Reloading the page to change locale** — should be instant; preload locale data.
- **Translating error codes meant for logs/APIs** — those stay in English.
- **Translation in the database for static UI strings** — translations belong in version-controlled files, not DB rows.

## Database-stored translations (when you DO need them)

For user-generated content (product descriptions, blog posts) translations live in DB:

```sql
CREATE TABLE product_translations (
  product_id BIGINT REFERENCES products(id),
  locale     TEXT NOT NULL,
  name       TEXT NOT NULL,
  description TEXT,
  PRIMARY KEY (product_id, locale)
);
```

Or JSON column:
```sql
CREATE TABLE products (
  id BIGINT PRIMARY KEY,
  name JSONB NOT NULL  -- {"en": "Mug", "es": "Taza"}
);
```

JSONB is faster to read, normalized is easier to query/index. Pick based on your read pattern.

## Testing locales

- **Snapshot tests per locale** — catches accidental regressions.
- **Visual regression** with each locale — RTL especially.
- **Pluralization tests** — assert correct form for n=0, 1, 2, 5, 11, 21, 100.
- **Long-string tests** — German is often 30% longer than English.

## Checklist for adding a new locale

- [ ] Add locale code to supported list
- [ ] Get translations for all keys (including new ones)
- [ ] Verify pluralization rules in the library config
- [ ] Configure date/number/currency formatting
- [ ] Add to locale switcher UI
- [ ] Test RTL if applicable
- [ ] Test pseudo-loc layout fit
- [ ] Add to SEO `hreflang` tags
- [ ] Update sitemap with locale variants
