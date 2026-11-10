# Test fixtures

- `real-*` files are real responses captured by `.github/workflows/capture-fixtures.yml` (menus for
  the week of 2026-10-25, athletics results and schedule from the same week). Don't edit them by
  hand; re-run the workflow and update the tests that read them.
- `synthetic-*` files are hand-written, in the same shape as the real responses, for cases the real
  data doesn't cover (malformed rows, menus without station headers, holidays). Replace them with
  real captures if such responses are ever seen.
- `synthetic-store-charges.json` is a signed-in `get_charges.php` response in the real shape, filled
  with random, made-up purchases. A real response is one student's purchase history, so never commit
  one.
