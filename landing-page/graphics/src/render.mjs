// يصيّر graphics.html إلى PNG بأحجامها الدقيقة عبر Edge/Chrome بلا واجهة.
//
//   node landing-page/graphics/src/render.mjs
//
// لا اعتمادات: Node 18+ (fetch وWebSocket مدمجان في Node 22+).
// المتصفّح: يُبحث عن Edge ثم Chrome في مساراتهما المعتادة على ويندوز، أو
// يُمرَّر مساره في المتغيّر BROWSER.
import { spawn } from "node:child_process";
import { existsSync, mkdtempSync, writeFileSync, rmSync } from "node:fs";
import { tmpdir } from "node:os";
import { join, dirname } from "node:path";
import { fileURLToPath, pathToFileURL } from "node:url";
import { setTimeout as sleep } from "node:timers/promises";

const here = dirname(fileURLToPath(import.meta.url));
const outDir = join(here, "..");
const SIZES = [
  { name: "feature-graphic", hash: "feature", w: 1024, h: 500 },
  { name: "og-image", hash: "og", w: 1200, h: 630 },
  { name: "social-square", hash: "square", w: 1080, h: 1080 },
];

const candidates = [
  process.env.BROWSER,
  "C:\\Program Files (x86)\\Microsoft\\Edge\\Application\\msedge.exe",
  "C:\\Program Files\\Microsoft\\Edge\\Application\\msedge.exe",
  "C:\\Program Files\\Google\\Chrome\\Application\\chrome.exe",
  "/usr/bin/google-chrome",
  "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome",
].filter(Boolean);
const browser = candidates.find((p) => existsSync(p));
if (!browser) throw new Error("No Edge/Chrome found — set BROWSER=/path/to/browser");

const port = 9500 + Math.floor(Math.random() * 400);
const profile = mkdtempSync(join(tmpdir(), "huruf-render-"));
const proc = spawn(browser, ["--headless=new", "--disable-gpu", "--hide-scrollbars", "--allow-file-access-from-files",
  `--remote-debugging-port=${port}`, `--user-data-dir=${profile}`, "about:blank"], { stdio: "ignore" });

let target;
for (let i = 0; i < 80 && !target; i++) {
  try { target = (await (await fetch(`http://127.0.0.1:${port}/json/list`)).json()).find((t) => t.type === "page"); } catch {}
  if (!target) await sleep(250);
}
const ws = new WebSocket(target.webSocketDebuggerUrl);
await new Promise((r) => (ws.onopen = r));
let id = 0;
const waiters = new Map();
ws.onmessage = (e) => { const m = JSON.parse(e.data); if (m.id && waiters.has(m.id)) { waiters.get(m.id)(m.result); waiters.delete(m.id); } };
const send = (method, params = {}) => new Promise((r) => { const i = ++id; waiters.set(i, r); ws.send(JSON.stringify({ id: i, method, params })); });

try {
  const page = pathToFileURL(join(here, "graphics.html")).href;
  for (const s of SIZES) {
    await send("Emulation.setDeviceMetricsOverride", { width: s.w, height: s.h, deviceScaleFactor: 1, mobile: false });
    await send("Page.navigate", { url: "about:blank" });
    await send("Page.navigate", { url: `${page}#${s.hash}` });
    await sleep(1200); // الخطوط والصور
    await send("Runtime.evaluate", { expression: "document.fonts.ready", awaitPromise: true });
    const shot = await send("Page.captureScreenshot", { format: "png", clip: { x: 0, y: 0, width: s.w, height: s.h, scale: 1 } });
    writeFileSync(join(outDir, `${s.name}.png`), Buffer.from(shot.data, "base64"));
    console.log(`${s.name}.png  ${s.w}×${s.h}`);
  }
} finally {
  try { await send("Browser.close"); } catch {}
  ws.close();
  proc.kill();
  await sleep(300);
  try { rmSync(profile, { recursive: true, force: true }); } catch {}
}
