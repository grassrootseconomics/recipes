import fs from "node:fs";
import http from "node:http";
import os from "node:os";
import path from "node:path";
import { spawn } from "node:child_process";

const args = new Map();
for (let index = 2; index < process.argv.length; index += 1) {
  const [key, value = "true"] = process.argv[index].split("=", 2);
  args.set(key.replace(/^--/, ""), value);
}

const url = args.get("url") ?? process.env.RECIPES_WEB_URL ?? "http://127.0.0.1:8081/";
const port = Number(args.get("port") ?? process.env.RECIPES_CDP_PORT ?? 9223);
const chromeBin = args.get("chrome") ?? process.env.CHROME_BIN ?? "google-chrome";
const outDir = path.resolve(args.get("out-dir") ?? process.env.RECIPES_WEB_SMOKE_OUT ?? path.join(os.tmpdir(), "recipes-web-visual-smoke"));
const profileDir = path.join(os.tmpdir(), `recipes-chrome-smoke-${process.pid}`);
const verbose = args.has("verbose");
const cdpCommandTimeoutMs = Number(args.get("cdp-timeout-ms") ?? 30000);
const tableLoadDelayMs = Number(args.get("table-load-ms") ?? 18000);
const strictTableScreenshots = args.has("strict-table-screenshots") || process.env.RECIPES_WEB_STRICT_TABLE_SCREENSHOTS === "1";

fs.mkdirSync(outDir, { recursive: true });

const chromeArgs = [
  "--headless=new",
  "--no-sandbox",
  "--disable-dev-shm-usage",
  "--ignore-gpu-blocklist",
  "--enable-unsafe-swiftshader",
  "--use-angle=swiftshader",
  "--remote-debugging-address=127.0.0.1",
  `--remote-debugging-port=${port}`,
  `--user-data-dir=${profileDir}`,
  "--window-size=1080,1920",
  url
];

const chrome = spawn(chromeBin, chromeArgs, { stdio: ["ignore", "pipe", "pipe"] });
let stderr = "";
chrome.stderr.on("data", (chunk) => {
  stderr += chunk.toString();
});

process.on("exit", cleanup);

try {
  const target = await waitForTarget(port);
  const cdp = await connectCdp(target.webSocketDebuggerUrl);
  await cdp.send("Page.enable");
  await cdp.send("Runtime.enable");
  await cdp.send("Page.bringToFront");
  await delay(8000);
  await assertWebgl2(cdp);

  await capture(cdp, "home", 1080, 1920);
  await clickRatio(cdp, 0.27, 0.63);
  await delay(2500);
  await capture(cdp, "lobby", 1080, 1920);
  await cdp.send("Page.navigate", { url: smokeTableUrl(url) });
  await delay(tableLoadDelayMs);
  await capture(cdp, "portrait-table", 1080, 1920, { stateOnly: !strictTableScreenshots });
  await capture(cdp, "wide-table", 1440, 900, { stateOnly: !strictTableScreenshots });
  await cdp.close();

  console.log(`Web visual smoke artifacts written to ${outDir}`);
} catch (error) {
  console.error(error instanceof Error ? error.message : error);
  if (stderr.trim() !== "") {
    console.error(stderr.trim().split("\n").slice(-12).join("\n"));
  }
  process.exitCode = 1;
} finally {
  cleanup();
}

function delay(ms) {
  return new Promise((resolve) => setTimeout(resolve, ms));
}

function cleanup() {
  try {
    chrome.kill("SIGTERM");
  } catch {
    // Chrome may already be gone.
  }
  try {
    fs.rmSync(profileDir, { recursive: true, force: true, maxRetries: 3, retryDelay: 100 });
  } catch {
    // Do not fail a successful visual smoke because Chrome released its
    // temporary profile directory a moment later than Node cleanup.
  }
}

function requestJson(targetUrl) {
  return new Promise((resolve, reject) => {
    const request = http.get(targetUrl, (response) => {
      let body = "";
      response.setEncoding("utf8");
      response.on("data", (chunk) => {
        body += chunk;
      });
      response.on("end", () => {
        if ((response.statusCode ?? 500) >= 400) {
          reject(new Error(`CDP HTTP ${response.statusCode}: ${body}`));
          return;
        }
        try {
          resolve(JSON.parse(body));
        } catch (error) {
          reject(error);
        }
      });
    });
    request.on("error", reject);
  });
}

async function waitForTarget(cdpPort) {
  const deadline = Date.now() + 15000;
  while (Date.now() < deadline) {
    try {
      const targets = await requestJson(`http://127.0.0.1:${cdpPort}/json/list`);
      const page = targets.find((target) => target.type === "page" && target.webSocketDebuggerUrl);
      if (page) {
        return page;
      }
    } catch {
      // Chrome may still be starting.
    }
    await delay(250);
  }
  throw new Error(`Timed out waiting for Chrome DevTools on port ${cdpPort}`);
}

function connectCdp(wsUrl) {
  const socket = new WebSocket(wsUrl);
  let nextId = 1;
  const pending = new Map();

  function rejectPending(error) {
    for (const { reject, timer } of pending.values()) {
      clearTimeout(timer);
      reject(error);
    }
    pending.clear();
  }

  socket.addEventListener("message", (event) => {
    const message = JSON.parse(event.data);
    if (!message.id || !pending.has(message.id)) {
      return;
    }
    const { resolve, reject, timer } = pending.get(message.id);
    clearTimeout(timer);
    pending.delete(message.id);
    if (message.error) {
      reject(new Error(`${message.error.message}: ${message.error.data ?? ""}`));
    } else {
      resolve(message.result ?? {});
    }
  });

  return new Promise((resolve, reject) => {
    socket.addEventListener("open", () => {
      resolve({
        send(method, params = {}) {
          const id = nextId;
          nextId += 1;
          socket.send(JSON.stringify({ id, method, params }));
          return new Promise((innerResolve, innerReject) => {
            const timer = setTimeout(() => {
              pending.delete(id);
              innerReject(new Error(`Timed out waiting for CDP response to ${method}`));
            }, cdpCommandTimeoutMs);
            pending.set(id, { resolve: innerResolve, reject: innerReject, timer });
          });
        },
        close() {
          socket.close();
        }
      });
    });
    socket.addEventListener("error", () => reject(new Error("CDP WebSocket connection failed")));
    socket.addEventListener("close", () => rejectPending(new Error("CDP WebSocket closed before command completed")));
  });
}

async function assertWebgl2(cdp) {
  const result = await cdp.send("Runtime.evaluate", {
    returnByValue: true,
    expression: `(() => {
      const canvas = document.createElement("canvas");
      return Boolean(window.WebGL2RenderingContext && canvas.getContext("webgl2"));
    })()`
  });
  if (!result.result?.value) {
    throw new Error("Chrome launched, but WebGL2 is unavailable. Check SwiftShader flags and Chrome version.");
  }
}

async function clickRatio(cdp, xRatio, yRatio) {
  const metrics = await cdp.send("Runtime.evaluate", {
    returnByValue: true,
    expression: `({ width: window.innerWidth, height: window.innerHeight })`
  });
  const width = Number(metrics.result?.value?.width ?? 1080);
  const height = Number(metrics.result?.value?.height ?? 1920);
  const x = Math.round(width * xRatio);
  const y = Math.round(height * yRatio);
  if (verbose) {
    console.log(`click ${xRatio},${yRatio} -> ${x},${y} in ${width}x${height}`);
  }
  await cdp.send("Input.dispatchMouseEvent", { type: "mouseMoved", x, y, button: "none" });
  await cdp.send("Input.dispatchMouseEvent", { type: "mousePressed", x, y, button: "left", clickCount: 1 });
  await cdp.send("Input.dispatchMouseEvent", { type: "mouseReleased", x, y, button: "left", clickCount: 1 });
}

function smokeTableUrl(baseUrl) {
  const nextUrl = new URL(baseUrl);
  nextUrl.searchParams.set("recipes_smoke", "table");
  return nextUrl.toString();
}

async function capture(cdp, name, width, height, options = {}) {
  await cdp.send("Emulation.setDeviceMetricsOverride", {
    width,
    height,
    deviceScaleFactor: 1,
    mobile: false
  });
  await delay(name === "wide-table" ? 3500 : 1200);
  const canvas = await canvasState(cdp, name);
  if (!canvas) {
    throw new Error(`No Godot canvas found before ${name} screenshot`);
  }
  if (Math.abs(Number(canvas.width) - width) > 2 || Math.abs(Number(canvas.height) - height) > 2) {
    throw new Error(`Godot canvas size mismatch for ${name}: expected ${width}x${height}, got ${canvas.width}x${canvas.height}`);
  }
  if (options.stateOnly) {
    const filePath = path.join(outDir, `${name}-${width}x${height}.json`);
    fs.writeFileSync(filePath, JSON.stringify({ name, expected: { width, height }, canvas }, null, 2));
    return;
  }
  const screenshot = await captureCanvasPng(cdp, name);
  const filePath = path.join(outDir, `${name}-${width}x${height}.png`);
  fs.writeFileSync(filePath, screenshot);
  if (fs.statSync(filePath).size < 20_000) {
    throw new Error(`Screenshot ${filePath} is unexpectedly small`);
  }
}

async function canvasState(cdp, name) {
  let result;
  try {
    result = await cdp.send("Runtime.evaluate", {
      returnByValue: true,
      expression: `(() => {
        const canvas = document.querySelector("canvas");
        if (!canvas) {
          return null;
        }
        const rect = canvas.getBoundingClientRect();
        return {
          width: canvas.width,
          height: canvas.height,
          rectWidth: Math.round(rect.width),
          rectHeight: Math.round(rect.height),
          visible: rect.width > 0 && rect.height > 0
        };
      })()`
    });
  } catch (error) {
    const message = error instanceof Error ? error.message : String(error);
    throw new Error(`Failed to inspect ${name}: ${message}`);
  }
  const value = result.result?.value;
  if (!value || !value.visible || value.width < 320 || value.height < 240) {
    throw new Error(`Godot canvas is not renderable for ${name}: ${JSON.stringify(value)}`);
  }
  return value;
}

async function captureCanvasPng(cdp, name) {
  let result;
  try {
    result = await cdp.send("Runtime.evaluate", {
      awaitPromise: true,
      returnByValue: true,
      expression: `new Promise((resolve) => {
        requestAnimationFrame(() => requestAnimationFrame(() => {
          const canvas = document.querySelector("canvas");
          if (!canvas) {
            resolve(null);
            return;
          }
          try {
            resolve(canvas.toDataURL("image/png"));
          } catch (error) {
            resolve({ error: String(error?.message ?? error) });
          }
        }));
      })`
    });
  } catch (error) {
    const message = error instanceof Error ? error.message : String(error);
    throw new Error(`Failed to capture ${name}: ${message}`);
  }
  const value = result.result?.value;
  if (!value) {
    throw new Error(`Failed to capture ${name}: no canvas data URL returned`);
  }
  if (typeof value === "object" && value.error) {
    throw new Error(`Failed to capture ${name}: ${value.error}`);
  }
  if (typeof value !== "string" || !value.startsWith("data:image/png;base64,")) {
    throw new Error(`Failed to capture ${name}: invalid canvas data URL`);
  }
  return Buffer.from(value.slice("data:image/png;base64,".length), "base64");
}
