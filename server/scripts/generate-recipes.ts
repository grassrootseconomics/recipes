import { mkdir, rm, writeFile } from "node:fs/promises";
import { dirname, resolve } from "node:path";
import { spawnSync } from "node:child_process";
import { fileURLToPath } from "node:url";
import {
  generateRecipeCatalog,
  RECIPE_DISTINCT_COUNTS,
  RECIPE_REQUIRED_ITEMS,
  RECIPE_VARIANT_COUNT
} from "../src/recipeCatalog.js";
import { REAL_UNITS_PER_INGREDIENT } from "../src/constants.js";

type CellValue = number | string;

const scriptDir = dirname(fileURLToPath(import.meta.url));
const serverDir = resolve(scriptDir, "..");
const repoRoot = process.env.RECIPES_REPO_ROOT ? resolve(process.env.RECIPES_REPO_ROOT) : resolve(serverDir, "..");
const docsDir = resolve(repoRoot, "docs");
const tempDir = resolve("/tmp", "recipes-catalog");
const fodsPath = resolve(tempDir, "recipes-catalog.fods");
const odsPackageDir = resolve(tempDir, "ods-package");
const odsPath = resolve(docsDir, "recipes-catalog.ods");

const catalog = generateRecipeCatalog();

await mkdir(docsDir, { recursive: true });
await mkdir(tempDir, { recursive: true });
await writeFile(fodsPath, buildFlatSpreadsheet(), "utf8");
await writeOdsPackage();

console.log(`Wrote ${odsPath}`);
console.log(`Generated ${catalog.recipes.length} recipes and ${catalog.requirements.length} requirement rows.`);

function buildFlatSpreadsheet(): string {
  return [
    `<?xml version="1.0" encoding="UTF-8"?>`,
    `<office:document office:version="1.2" office:mimetype="application/vnd.oasis.opendocument.spreadsheet"`,
    ...officeNamespaces(),
    `<office:body>`,
    `<office:spreadsheet>`,
    buildSpreadsheetTables(),
    `</office:spreadsheet>`,
    `</office:body>`,
    `</office:document>`
  ].join("\n");
}

function buildOdsContent(): string {
  return [
    `<?xml version="1.0" encoding="UTF-8"?>`,
    `<office:document-content office:version="1.2"`,
    ...officeNamespaces(),
    `<office:body>`,
    `<office:spreadsheet>`,
    buildSpreadsheetTables(),
    `</office:spreadsheet>`,
    `</office:body>`,
    `</office:document-content>`
  ].join("\n");
}

function buildSpreadsheetTables(): string {
  const ingredients = catalog.ingredients.map((ingredient, index) => ({
    catalog_order: index + 1,
    ingredient_id: ingredient.id,
    ingredient_name: ingredient.name
  }));

  const ingredientSets = catalog.configurations.map((configuration) => ({
    configuration_id: configuration.configurationId,
    player_count: configuration.playerCount,
    ingredient_count: configuration.ingredients.length,
    ingredient_ids: configuration.ingredients.map((ingredient) => ingredient.id).join(", "),
    ingredient_names: configuration.ingredients.map((ingredient) => ingredient.name).join(", "),
    recipes_per_ingredient: configuration.recipesPerIngredient,
    total_recipes: configuration.playerCount * RECIPE_VARIANT_COUNT,
    required_items_per_recipe: configuration.requiredItemsPerRecipe,
    real_units_per_ingredient: REAL_UNITS_PER_INGREDIENT,
    max_catalog_demand_per_ingredient: maxDemandForConfiguration(configuration.configurationId),
    allowed_distinct_ingredient_counts: RECIPE_DISTINCT_COUNTS.join(", ")
  }));

  const recipes = catalog.recipes.map((recipe) => ({
    recipe_id: recipe.recipeId,
    configuration_id: recipe.configurationId,
    player_count: recipe.playerCount,
    slot: recipe.slot,
    owner_ingredient_id: recipe.ownerIngredientId,
    owner_ingredient_name: recipe.ownerIngredientName,
    dish_name: recipe.dishName,
    dish_family: recipe.dishFamily,
    part_unit_singular: recipe.partUnitSingular,
    part_unit_plural: recipe.partUnitPlural,
    total_required_qty: recipe.totalRequiredQty,
    distinct_ingredient_count: recipe.distinctIngredientCount,
    quantity_shape: recipe.quantityShape,
    ingredient_ids: recipe.realIngredientIds.join(", "),
    requirements: recipe.requirements
      .map((requirement) => `${requirement.ingredientName} x${requirement.requiredQty}`)
      .join(", ")
  }));

  const requirements = catalog.requirements.map((requirement) => ({
    recipe_id: requirement.recipeId,
    position: requirement.position,
    ingredient_id: requirement.ingredientId,
    ingredient_name: requirement.ingredientName,
    required_qty: requirement.requiredQty
  }));

  const signatureCounts = countBy(catalog.recipes, (recipe) => `${recipe.configurationId}:${requirementSignature(recipe)}`);
  const nameCounts = countBy(catalog.recipes, (recipe) => `${recipe.configurationId}:${recipe.dishName}`);
  const configurationDemand = demandByConfiguration();

  const validation = catalog.recipes.map((recipe) => ({
    recipe_id: recipe.recipeId,
    quantity_total_ok: yesNo(recipe.totalRequiredQty === RECIPE_REQUIRED_ITEMS),
    distinct_allowed_ok: yesNo(RECIPE_DISTINCT_COUNTS.some((distinctCount) => distinctCount === recipe.distinctIngredientCount)),
    quantity_shape_ok: yesNo(quantityShapeOk(recipe.requirements.map((requirement) => requirement.requiredQty))),
    owner_included_ok: yesNo(recipe.requirements.some((requirement) => requirement.ingredientId === recipe.ownerIngredientId)),
    active_ingredients_only_ok: yesNo(
      recipe.requirements.every((requirement) => recipe.activeIngredientIds.includes(requirement.ingredientId))
    ),
    unique_requirements_ok: yesNo(signatureCounts.get(`${recipe.configurationId}:${requirementSignature(recipe)}`) === 1),
    unique_name_ok: yesNo(nameCounts.get(`${recipe.configurationId}:${recipe.dishName}`) === 1),
    catalog_demand_within_stock_ok: yesNo((configurationDemand.get(recipe.configurationId)?.maxDemand ?? 0) <= REAL_UNITS_PER_INGREDIENT),
    fallback_free_ok: yesNo(recipe.fallbackIngredientIds.length === 0),
    accurate_name_ok: yesNo(recipe.dishName.trim().length > 0),
    serving_unit_ok: yesNo(recipe.partUnitSingular.trim().length > 0 && recipe.partUnitPlural.trim().length > 0)
  }));

  return [
    tableXml("Ingredients", ingredients),
    tableXml("Player Count Ingredient Sets", ingredientSets),
    tableXml("Player Count Recipes", recipes),
    tableXml("Player Count Requirements", requirements),
    tableXml("Validation", validation)
  ].join("\n");
}

function demandByConfiguration(): Map<string, { maxDemand: number; demandByIngredient: Map<string, number> }> {
  const byConfiguration = new Map<string, { maxDemand: number; demandByIngredient: Map<string, number> }>();
  for (const recipe of catalog.recipes) {
    const entry = byConfiguration.get(recipe.configurationId) ?? { maxDemand: 0, demandByIngredient: new Map<string, number>() };
    for (const requirement of recipe.requirements) {
      const nextDemand = (entry.demandByIngredient.get(requirement.ingredientId) ?? 0) + requirement.requiredQty;
      entry.demandByIngredient.set(requirement.ingredientId, nextDemand);
      entry.maxDemand = Math.max(entry.maxDemand, nextDemand);
    }
    byConfiguration.set(recipe.configurationId, entry);
  }
  return byConfiguration;
}

function maxDemandForConfiguration(configurationId: string): number {
  return demandByConfiguration().get(configurationId)?.maxDemand ?? 0;
}

function countBy<T>(values: T[], keyForValue: (value: T) => string): Map<string, number> {
  const counts = new Map<string, number>();
  for (const value of values) {
    const key = keyForValue(value);
    counts.set(key, (counts.get(key) ?? 0) + 1);
  }
  return counts;
}

function requirementSignature(recipe: { requirements: Array<{ ingredientId: string; requiredQty: number }> }): string {
  return recipe.requirements
    .map((requirement) => `${requirement.ingredientId}:${requirement.requiredQty}`)
    .sort()
    .join("|");
}

function quantityShapeOk(quantities: number[]): boolean {
  const sorted = [...quantities].sort((left, right) => right - left);
  return (
    sorted.join(",") === "2,2,2" ||
    sorted.join(",") === "2,2,1,1" ||
    sorted.join(",") === "1,1,1,1,1,1"
  );
}

async function writeOdsPackage(): Promise<void> {
  const metaInfDir = resolve(odsPackageDir, "META-INF");
  await rm(odsPackageDir, { recursive: true, force: true });
  await rm(odsPath, { force: true });
  await mkdir(metaInfDir, { recursive: true });
  await writeFile(resolve(odsPackageDir, "mimetype"), "application/vnd.oasis.opendocument.spreadsheet", "utf8");
  await writeFile(resolve(odsPackageDir, "content.xml"), buildOdsContent(), "utf8");
  await writeFile(resolve(metaInfDir, "manifest.xml"), buildManifest(), "utf8");

  runZip(["-X", "-0", odsPath, "mimetype"]);
  runZip(["-X", "-r", odsPath, "content.xml", "META-INF"]);
}

function runZip(args: string[]): void {
  const result = spawnSync("zip", args, { cwd: odsPackageDir, encoding: "utf8" });
  if (result.status !== 0) {
    throw new Error(`zip failed:\n${result.stdout}\n${result.stderr}`);
  }
}

function buildManifest(): string {
  return [
    `<?xml version="1.0" encoding="UTF-8"?>`,
    `<manifest:manifest manifest:version="1.2" xmlns:manifest="urn:oasis:names:tc:opendocument:xmlns:manifest:1.0">`,
    `<manifest:file-entry manifest:full-path="/" manifest:media-type="application/vnd.oasis.opendocument.spreadsheet"/>`,
    `<manifest:file-entry manifest:full-path="content.xml" manifest:media-type="text/xml"/>`,
    `</manifest:manifest>`
  ].join("\n");
}

function officeNamespaces(): string[] {
  return [
    `  xmlns:office="urn:oasis:names:tc:opendocument:xmlns:office:1.0"`,
    `  xmlns:table="urn:oasis:names:tc:opendocument:xmlns:table:1.0"`,
    `  xmlns:text="urn:oasis:names:tc:opendocument:xmlns:text:1.0">`
  ];
}

function tableXml(name: string, rows: Array<Record<string, CellValue>>): string {
  const headers = Object.keys(rows[0] ?? {});
  return [
    `<table:table table:name="${escapeXml(name)}">`,
    rowXml(headers),
    ...rows.map((row) => rowXml(headers.map((header) => row[header] ?? ""))),
    `</table:table>`
  ].join("\n");
}

function rowXml(values: CellValue[]): string {
  return `<table:table-row>${values.map(cellXml).join("")}</table:table-row>`;
}

function cellXml(value: CellValue): string {
  if (typeof value === "number") {
    return `<table:table-cell office:value-type="float" office:value="${value}"><text:p>${value}</text:p></table:table-cell>`;
  }
  return `<table:table-cell office:value-type="string"><text:p>${escapeXml(value)}</text:p></table:table-cell>`;
}

function escapeXml(value: string): string {
  return value
    .replace(/&/g, "&amp;")
    .replace(/</g, "&lt;")
    .replace(/>/g, "&gt;")
    .replace(/"/g, "&quot;")
    .replace(/'/g, "&apos;");
}

function yesNo(value: boolean): string {
  return value ? "YES" : "NO";
}

function ingredientName(ingredientId: string): string {
  return catalog.ingredients.find((ingredient) => ingredient.id === ingredientId)?.name ?? ingredientId;
}
