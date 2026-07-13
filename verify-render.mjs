// verify-render.mjs — headless proof the app actually renders.
//
// "It builds" is not "it works." This boots your app (optional), loads each
// route in a headless browser, fails on any console error / pageerror / bad
// status, and saves a screenshot per route to ./evidence/ as merge proof.
//
// No browser window ever opens — it's headless on purpose. Attach ./evidence/
// to your PR (the included GitHub Action does this automatically).
//
// Env (set by gate.sh from gate.config.sh):
//   RENDER_URL        base url, e.g. http://localhost:4173   (required)
//   RENDER_ROUTES     comma list, e.g. "/,/login"            (default "/")
//   RENDER_START_CMD  optional server to spawn first, e.g. "npm run preview"
import { chromium } from "playwright";
import { spawn } from "node:child_process";
import { mkdirSync } from "node:fs";
import { setTimeout as sleep } from "node:timers/promises";

const BASE = process.env.RENDER_URL;
if (!BASE) { console.log("  render: RENDER_URL not set — skipped"); process.exit(0); }
const ROUTES = (process.env.RENDER_ROUTES || "/").split(",").map((r) => r.trim()).filter(Boolean);
const START = process.env.RENDER_START_CMD;

mkdirSync("evidence", { recursive: true });

let server;
async function waitForUp(url, ms = 30000) {
  const deadline = Date.now() + ms;
  while (Date.now() < deadline) {
    try { const r = await fetch(url); if (r.ok || r.status < 500) return true; } catch {}
    await sleep(500);
  }
  return false;
}

const fail = (msg) => { console.error(`render: ${msg}`); cleanup(1); };
function cleanup(code) {
  try { if (server?.pid) process.kill(-server.pid, "SIGTERM"); } catch { try { server?.kill("SIGTERM"); } catch {} }
  process.exit(code);
}

if (START) {
  console.log(`  render: starting server  $ ${START}`);
  // detached so we can kill the whole process group (the shell AND its child server)
  server = spawn(START, { shell: true, stdio: "ignore", detached: true });
  if (!(await waitForUp(BASE))) fail(`server never became reachable at ${BASE}`);
}

const browser = await chromium.launch({ headless: true });
const ctx = await browser.newContext({ viewport: { width: 1280, height: 800 } });
let bad = 0;

for (const route of ROUTES) {
  const page = await ctx.newPage();
  const errors = [];
  page.on("console", (m) => { if (m.type() === "error") errors.push(`console: ${m.text()}`); });
  page.on("pageerror", (e) => errors.push(`pageerror: ${e.message}`));
  const url = BASE.replace(/\/$/, "") + route;
  const resp = await page.goto(url, { waitUntil: "domcontentloaded", timeout: 30000 }).catch((e) => {
    errors.push(`navigation: ${e.message}`); return null;
  });
  await page.waitForLoadState("load", { timeout: 10000 }).catch(() => {}); // settle; tolerant of SPAs that never go network-idle
  const status = resp?.status() ?? 0;
  const slug = route === "/" ? "home" : route.replace(/[^\w]+/g, "-").replace(/^-|-$/g, "");
  const shot = `evidence/${slug || "home"}.png`;
  await page.screenshot({ path: shot, fullPage: true }).catch(() => {});
  if (status >= 400 || status === 0) errors.push(`status ${status}`);
  if (errors.length) { bad++; console.error(`  ✗ ${route} -> ${shot}\n      ${errors.join("\n      ")}`); }
  else console.log(`  ✓ ${route} -> ${shot} (status ${status})`);
  await page.close();
}

await browser.close();
if (bad > 0) fail(`${bad}/${ROUTES.length} route(s) had errors — see evidence/ screenshots`);
console.log(`  render: ${ROUTES.length} route(s) clean — screenshots in evidence/`);
cleanup(0);
