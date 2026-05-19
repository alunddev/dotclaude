---
description: Rules for mobile app code (RN, Expo, Flutter, native iOS/Android).
globs: ["mobile/**", "app/**", "ios/**", "android/**", "lib/**/*.dart", "**/*.swift", "**/*.kt"]
---

# Mobile code rules

## Required

- **Network code handles offline + flaky.** Every request has a timeout, a retry policy, and an error UI state. Never assume the request will complete.
- **No blocking the main/UI thread.** All I/O, computation > 16ms, image processing — off the UI thread.
- **Test on the smallest target device.** If the design targets iPhone SE / a low-end Android, that's where you test layout — not on the latest flagship.
- **Permissions are requested in context.** Ask for camera/location/notifications only when about to use them, with an in-app explainer first.
- **Crash-free targets.** Crash reporting (Sentry, Crashlytics, Bugsnag) is mandatory; aim for >99.5% crash-free sessions in production.

## State + data

- **Server state ≠ UI state.** Use React Query / Riverpod / equivalent for server data. Local UI state stays local.
- **Persist sparingly.** Only persist what you can't refetch. Bloating local storage hurts cold-start times.
- **Migrate local storage carefully.** If you change the schema of cached data, write a migration — don't trust users to clear the cache.

## Battery + performance

- **Background work is rare and accountable.** Background fetch, background sync — each one has a measurable user benefit, or it doesn't ship.
- **Images are sized appropriately.** Don't ship a 4K image to a 200px thumbnail slot.
- **Animations target 60fps.** Use Reanimated / native animations, not JS-thread setState loops.

## Don't

- Don't ship hardcoded API URLs. Use env-aware config so dev/staging/prod each point somewhere different.
- Don't ignore deep links. If the app handles URLs, every entry point goes through the same routing logic.
- Don't hardcode strings for user-facing text. Even if there's no i18n yet, centralize them so adding i18n later is mechanical.
