---
description: Rules for browser-side UI code — components, hooks, styling, accessibility.
globs: ["src/components/**", "components/**", "app/**", "pages/**", "**/*.tsx", "**/*.jsx", "**/*.vue", "**/*.svelte"]
---

# Frontend / UI code rules

## Required

- **Accessibility is not optional.** Every interactive element has an accessible name. Color is never the only signal. Tab order is logical. Use `accessibility-tester` agent on any UI change.
- **No `any` in TypeScript components.** If you don't know the type, model it (`unknown`, generic, or a proper interface). `any` defeats the purpose.
- **Components are pure rendering.** Side effects live in hooks/composables, not in render bodies.
- **Loading and error states exist.** Every async UI has a loading state, an error state, and a success state — not just success.
- **Keys on lists are stable.** Never use array index as `key` for lists that can reorder.

## State management

- **Local state first.** Only lift state up when two components genuinely need to share it.
- **Don't put server data in global state.** Use TanStack Query / SWR / equivalent — they handle caching, refetching, and invalidation.
- **Forms have a single source of truth.** Pick controlled or uncontrolled, not a mix.

## Styling

- **Design tokens over magic numbers.** Use the design system's spacing/color/typography scale. No `padding: 13px`.
- **No inline `style={...}`** for things the design system covers. Reserve inline styles for truly dynamic values (calculated positions, etc.).
- **Mobile-first.** Default styles work on small screens; media queries scale up.

## Performance

- **Code-split heavy routes.** Don't put a 200KB chart library in your landing page bundle.
- **Memoize selectively.** `useMemo`/`useCallback` are not free — only use them when you've measured a problem or when reference identity matters for downstream memoization.
- **Images need width + height.** Avoid layout shift. Use `next/image` or equivalent.

## Don't

- **Don't fetch in `useEffect` if a framework primitive exists.** Server Components, loaders, `getServerSideProps` — use them.
- **Don't reach for state libraries before you need them.** Most apps don't need Redux.
- **Don't write CSS-in-JS runtime libraries for new projects in 2026.** Tailwind, CSS Modules, vanilla CSS, or zero-runtime CSS-in-JS only.
