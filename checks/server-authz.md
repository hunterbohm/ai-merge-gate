# Smell #3 — server-side authorization (the one a scanner can't check for you)

This is the smell that scared me most on a production build, and it's the one no
grep can honestly verify. So this is a manual gate: a short checklist you (or your
reviewer) run before merge. If you can't tick every box, it doesn't ship.

The failure mode: an AI agent builds a feature, hides the dangerous button in the
UI for the wrong role, and calls it "secured." But the mutation is a plain RPC /
API route. Anyone who opens the network tab and replays the request — or just
guesses the URL — runs it. **UI hiding is not authorization.**

## The checklist

- [ ] **Every mutating action checks permission at the server/data layer**, not
      just by hiding the UI control. Re-running the raw request as a lower-privilege
      (or unauthenticated) user must fail server-side.
- [ ] **Seeded / system / "template" records are guarded against direct calls.**
      If a record isn't meant to be edited or deleted, the *server* refuses it —
      not just a missing button. (Try it: hit the edit/delete RPC for a seeded row
      by id. It must 403.)
- [ ] **IDs in the request are authorized against the caller.** Changing an id in
      the body/URL to one you don't own returns 403/404, never someone else's data
      (no IDOR).
- [ ] **Privileged RPCs are not reachable from the public/anon client role.** If
      you use row-level security or a policy layer, there's an actual policy — not
      a default-allow with a UI gate.
- [ ] **The check lives at the lowest layer that owns the data**, so every caller
      (UI, mobile, a future integration, a curl) goes through it.

## Fast way to actually test it

```bash
# Replay a privileged mutation as an unauthenticated / low-priv caller.
# It must be rejected by the SERVER, not just absent from the UI.
curl -i -X POST https://your-app/api/<privileged-action> \
  -H 'content-type: application/json' \
  -d '{"id":"<a-seeded-or-not-yours id>"}'
# Expect: 401/403/404 — never 200 with the action performed.
```

If that returns success, the gate fails — fix the server-side check before merge.
