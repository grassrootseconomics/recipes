import fs from "node:fs";
import path from "node:path";

const targetPath = path.resolve(process.argv[2] ?? "client/web/index.html");
const marker = "RECIPES_WEB_SHELL_PATCH_VERSION:1";

let html = fs.readFileSync(targetPath, "utf8");
if (html.includes(marker)) {
  process.exit(0);
}

function replaceExact(source, search, replacement) {
  if (!source.includes(search)) {
    throw new Error(`Could not patch ${targetPath}; missing expected web shell fragment: ${search.slice(0, 80)}`);
  }
  return source.replace(search, replacement);
}

html = replaceExact(
  html,
  "\tlet initializing = true;\n\tlet statusMode = '';",
  `\tlet initializing = true;\n\tlet statusMode = '';\n\t// ${marker}\n\tconst recipesStartupTimeoutMs = 45000;\n\tlet recipesStartupTimeout = window.setTimeout(() => {\n\t\tdisplayFailureNotice('Recipes is taking too long to start on this browser.\\n\\nClose other tabs and reload. If this keeps happening, this device may not support the WebGL2 features needed by the web build.');\n\t}, recipesStartupTimeoutMs);\n\n\tfunction clearRecipesStartupTimeout() {\n\t\tif (recipesStartupTimeout != null) {\n\t\t\twindow.clearTimeout(recipesStartupTimeout);\n\t\t\trecipesStartupTimeout = null;\n\t\t}\n\t}`
);

html = replaceExact(
  html,
  "\t\tif (mode === 'hidden') {\n\t\t\tstatusOverlay.remove();",
  "\t\tif (mode === 'hidden') {\n\t\t\tclearRecipesStartupTimeout();\n\t\t\tstatusOverlay.remove();"
);

html = replaceExact(
  html,
  "\tfunction displayFailureNotice(err) {\n\t\tconsole.error(err);",
  "\tfunction displayFailureNotice(err) {\n\t\tclearRecipesStartupTimeout();\n\t\tconsole.error(err);"
);

html = replaceExact(
  html,
  "\tconst missing = Engine.getMissingFeatures({\n\t\tthreads: GODOT_THREADS_ENABLED,\n\t});\n\n\tif (missing.length !== 0) {",
  `\tfunction recipesHasWebGL2() {\n\t\ttry {\n\t\t\tconst testCanvas = document.createElement('canvas');\n\t\t\treturn Boolean(window.WebGL2RenderingContext && testCanvas.getContext('webgl2'));\n\t\t} catch (err) {\n\t\t\treturn false;\n\t\t}\n\t}\n\n\tconst missing = Engine.getMissingFeatures({\n\t\tthreads: GODOT_THREADS_ENABLED,\n\t});\n\n\tif (!recipesHasWebGL2()) {\n\t\tdisplayFailureNotice('Recipes needs WebGL2 to run in the browser.\\n\\nUpdate Chrome if possible, close other tabs, then reload. On some older phones the desktop or Android app build may be required.');\n\t} else if (missing.length !== 0) {`
);

fs.writeFileSync(targetPath, html);
