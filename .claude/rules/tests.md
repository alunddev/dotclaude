---
description: Rules for any file matching test directories or test naming patterns.
globs: ["**/*.test.*", "**/*.spec.*", "**/test_*.py", "tests/**", "test/**", "__tests__/**"]
---

# Test code rules

## Required

- **Tests describe behavior, not implementation.** Test names should read as "what happens when..." or "should...". `describe('UserService')` → fine. `describe('UserService.create() internal logic')` → too implementation-leaky.
- **Arrange / Act / Assert.** Each test has three visually separated phases. No interleaving.
- **One behavior per test.** If you have 4 assertions checking 4 unrelated behaviors, split into 4 tests.
- **No shared mutable state across tests.** Each test sets up its own fixtures. Reset between runs.
- **Test the public contract, not internals.** Don't test private methods directly — test them through the public surface.

## Don't

- **Don't mock the thing you're testing.** Mock its collaborators, not its own internals.
- **Don't test framework code.** No tests that essentially verify the test runner or the ORM works.
- **Don't write tests that are just `expect(true).toBe(true)`** to bump coverage. Coverage means nothing if assertions are vacuous.
- **Don't `skip` failing tests** to make CI green. Either fix the test or fix the code. If you must skip, leave a TODO with an issue link or a date.

## Database-touching tests

- Use a real DB (testcontainers, sqlite, in-memory pg, etc.) — **not** mocks of the ORM.
- Each test gets a clean state: transaction rollback per test, or truncate-and-reseed.
- Don't share fixtures across unrelated test files unless they're truly stable (e.g. country codes).

## Time-dependent tests

- Inject a clock — never call `Date.now()` / `time.time()` directly in code under test.
- Use the framework's time-freezing utility (`vi.useFakeTimers`, `freezegun`, etc.).
