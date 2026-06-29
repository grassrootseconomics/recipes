import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");
const catalogPath = path.join(root, "client", "data", "recipe_catalog.json");
const catalog = JSON.parse(fs.readFileSync(catalogPath, "utf8"));

const failures = [];

function slugify(value) {
  return String(value).toLowerCase().replace(/[^a-z0-9]+/g, "_").replace(/^_+|_+$/g, "") || "dish";
}

function expectFile(relativePath) {
  const absolutePath = path.join(root, relativePath);
  if (!fs.existsSync(absolutePath)) {
    failures.push(relativePath);
  }
}

for (const ingredient of catalog.ingredients ?? []) {
  const fallbackPath = path.join("client", ingredient.imagePath ?? "");
  const highPath = fallbackPath.replace(/_64\.png$/, "_256.png");
  expectFile(fallbackPath);
  expectFile(highPath);
}

for (const recipe of catalog.recipes ?? []) {
  const slug = slugify(recipe.dishName);
  expectFile(path.join("client", "art", "dishes", `${slug}_64.png`));
  expectFile(path.join("client", "art", "dishes", `${slug}_256.png`));
}

for (let index = 1; index <= 8; index += 1) {
  expectFile(path.join("client", "art", "avatars", `cook_${index}_32.png`));
  expectFile(path.join("client", "art", "avatars", `cook_${index}_128.png`));
}

if (failures.length > 0) {
  console.error("Missing visual assets:");
  for (const failure of failures) {
    console.error(`- ${failure}`);
  }
  process.exit(1);
}

console.log(`Visual asset coverage OK: ${catalog.ingredients?.length ?? 0} ingredients, ${catalog.recipes?.length ?? 0} dishes, 8 avatars.`);
