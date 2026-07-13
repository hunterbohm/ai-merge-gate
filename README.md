# ai-merge-gate

The gate between "the agent said it's done" and "this is live."

If you build with Claude Code, Codex, Cursor — whatever — you already know the
feeling. The agent writes a pile of code, says it's done, the demo works. Then
you merge it, and three weeks later something it wrote does something confidently
wrong that nobody caught.

I ship production agent systems for clients. The scariest part of that job isn't
getting the agent to work — it's deciding what's allowed to merge. So I run a
gate. Not a vibe check. A script that refuses to let code through until it's
actually green and clean. This is that gate, stripped down so you can drop it
into your own project today.

It's not more tooling. It's one constraint: AI-written code doesn't merge on
trust. It earns it.

## What it does

```
./gate.sh
```

Runs in order, fails fast at the first red:

1. **typecheck → lint → test → build** — your real commands. If the basics aren't
   green, nothing else matters and it stops here.
2. **security smell scans** — three things that bit me on real production code:
   - **error/stack leaks** — code that hands a raw error or stack trace back to
     the client (now your internals are in someone's network tab).
   - **missing request id** — server handlers with no request/correlation id, so
     when prod breaks at 2am your logs say "an error happened somewhere." Useless.
   - **server-side authorization** — the one a scanner can't honestly check, so
     it's a manual checklist: every dangerous action is gated at the *server*, not
     just hidden in the UI. Hiding a button is not security.
3. **render evidence** — boots your app *headlessly* (no window opens), loads each
   route, fails on console errors / bad status, and screenshots every page to
   `evidence/` as proof it actually renders. "It builds" is not "it works."

Green means safe to merge. Red prints exactly what to fix.

## See it catch something

```
npm run demo
```

The demo scans a deliberately bad handler (raw stack sent to the client, no
request id) — watch both smells go red — then the fixed version, green. That's
the whole idea, in ten seconds. No install needed; it's just bash. (Playwright,
for the optional headless render step, is the only dependency — `npm install`
when you wire that up.)

## Wire it into your project (2 minutes)

```bash
cp gate.config.example.sh gate.config.sh
```

Set your four commands and where your source lives:

```sh
TYPECHECK_CMD="pnpm typecheck"
LINT_CMD="pnpm lint"
TEST_CMD="pnpm test"
BUILD_CMD="pnpm build"
SRC_DIR="src"
```

Anything you leave blank is skipped with a notice, so you can adopt it one stage
at a time. Then:

```bash
./gate.sh
```

Commit your `gate.config.sh` (it's deliberately not gitignored) so the GitHub
Action runs *your* commands, not the example defaults.

## Make the agent earn "done" (the good part)

If you use Claude Code, this is the move. The repo ships a **Stop hook** that runs
the gate every time the agent tries to end its turn. If the gate is red, Claude
*can't stop* — it gets the failures back and has to keep fixing.

It's in `.claude/settings.json` and `.claude/hooks/gate-stop.sh`. Copy the `hooks`
block into your project's `.claude/settings.json` (it runs `./gate.sh` in fast
mode, no screenshots, so it stays quick). Now "done" isn't the agent's opinion —
it's a green gate.

## Enforce it on every PR

`.github/workflows/gate.yml` runs the same gate on pull requests and uploads the
`evidence/` screenshots as an artifact. Red on the PR = no merge. Edit the install
step to match your package manager.

## Honest about what this is and isn't

- The smell scans are **heuristics**. They find candidates; you confirm. They'll
  occasionally flag something fine — that's why there's an allowlist — and they
  won't catch every bad pattern. They catch the three that have actually burned
  me. Treat them as a smoke alarm, not a security audit.
- The server-authz check is a **manual** checklist (`checks/server-authz.md`) on
  purpose. No grep can truthfully tell you your authorization is correct. A script
  that pretended to would be worse than nothing.
- This gates *your* pipeline. It doesn't write tests or fix code for you. It just
  refuses to let unverified work through, which turns out to be most of the battle.

Steal it, gut it, keep the parts that fit. If it stops one piece of confidently-
wrong AI code from reaching your users, it did its job.

---

Built by [Hunter Bohm](https://hunterbohm.me). I write about building AI systems
that survive contact with production — one email when I ship or break something
worth your time. MIT licensed.
