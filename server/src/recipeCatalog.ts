import {
  INGREDIENTS,
  MAX_CATALOG_PLAYER_COUNT,
  MIN_CATALOG_PLAYER_COUNT,
  REAL_UNITS_PER_INGREDIENT,
  VOUCHERS_PER_INGREDIENT
} from "./constants.js";
import type { Ingredient } from "./types.js";

export const RECIPE_VARIANT_COUNT = 4;
export const RECIPE_REQUIRED_ITEMS = VOUCHERS_PER_INGREDIENT - 1;
export const RECIPE_DISTINCT_COUNTS = [4, 5, 6] as const;
export const MIN_TEMPLATE_INGREDIENTS = RECIPE_DISTINCT_COUNTS[0];
export const MAX_TEMPLATE_INGREDIENTS = RECIPE_DISTINCT_COUNTS[RECIPE_DISTINCT_COUNTS.length - 1];

export const RECIPE_SLOTS = ["initial", "followup_1", "followup_2", "followup_3"] as const;

export type RecipeSlot = (typeof RECIPE_SLOTS)[number];
export type RecipeQuantityShape = "two_doubles_two_singles" | "one_double_four_singles" | "six_singles";

export const COMMITTED_INGREDIENT_SET_IDS_BY_PLAYER_COUNT: Record<number, string[]> = {
  8: ["cheese", "flour", "herbs", "vegetables", "rice", "beans", "spices", "eggs"]
};

interface DishTemplate {
  name: string;
  family: string;
  ingredientIds: string[];
  unitSingular: string;
  unitPlural: string;
}

export interface CatalogConfiguration {
  configurationId: string;
  playerCount: number;
  ingredients: Ingredient[];
  requiredItemsPerRecipe: number;
  minDistinctIngredients: number;
  maxDistinctIngredients: number;
  recipesPerIngredient: number;
}

export interface CatalogRequirement {
  recipeId: string;
  position: number;
  ingredientId: string;
  ingredientName: string;
  requiredQty: number;
}

export interface CatalogDishTemplate {
  templateId: string;
  ingredientId: string;
  ingredientName: string;
  slot: RecipeSlot;
  dishName: string;
  dishFamily: string;
  partUnitSingular: string;
  partUnitPlural: string;
  realIngredientIds: string[];
}

export interface CatalogRecipe {
  recipeId: string;
  templateId: string;
  configurationId: string;
  playerCount: number;
  slot: RecipeSlot;
  ownerIngredientId: string;
  ownerIngredientName: string;
  dishName: string;
  dishFamily: string;
  partUnitSingular: string;
  partUnitPlural: string;
  totalRequiredQty: number;
  distinctIngredientCount: number;
  quantityShape: RecipeQuantityShape;
  minDistinctIngredientCount: number;
  maxDistinctIngredientCount: number;
  activeIngredientIds: string[];
  realIngredientIds: string[];
  matchedRealIngredientIds: string[];
  fallbackIngredientIds: string[];
  requirements: CatalogRequirement[];
}

export interface RecipeCatalog {
  generatorVersion: string;
  ingredients: Ingredient[];
  dishTemplates: CatalogDishTemplate[];
  configurations: CatalogConfiguration[];
  recipes: CatalogRecipe[];
  requirements: CatalogRequirement[];
}

const DISH_TEMPLATES: Record<string, DishTemplate[]> = {
  cheese: [
    {
      name: "Cheese Frittata",
      family: "egg bake",
      ingredientIds: ["cheese", "eggs", "vegetables", "herbs", "spices", "flour"],
      unitSingular: "slice",
      unitPlural: "slices"
    },
    {
      name: "Cheese Quesadilla",
      family: "flatbread",
      ingredientIds: ["cheese", "flour", "vegetables", "beans", "spices"],
      unitSingular: "piece",
      unitPlural: "pieces"
    },
    {
      name: "Cheesy Rice Bake",
      family: "casserole",
      ingredientIds: ["cheese", "rice", "vegetables", "herbs"],
      unitSingular: "slice",
      unitPlural: "slices"
    },
    {
      name: "Bean Enchilada Bake",
      family: "casserole",
      ingredientIds: ["cheese", "beans", "flour", "vegetables", "spices", "herbs"],
      unitSingular: "slice",
      unitPlural: "slices"
    }
  ],
  flour: [
    {
      name: "Vegetable Flatbread",
      family: "flatbread",
      ingredientIds: ["flour", "vegetables", "herbs", "rice", "beans", "spices"],
      unitSingular: "slice",
      unitPlural: "slices"
    },
    {
      name: "Bean Pupusa",
      family: "stuffed bread",
      ingredientIds: ["flour", "beans", "cheese", "vegetables", "spices"],
      unitSingular: "piece",
      unitPlural: "pieces"
    },
    {
      name: "Herb Dumplings",
      family: "dumplings",
      ingredientIds: ["flour", "herbs", "vegetables", "eggs"],
      unitSingular: "piece",
      unitPlural: "pieces"
    },
    {
      name: "Rice Pancakes",
      family: "pancakes",
      ingredientIds: ["flour", "rice", "eggs", "vegetables", "herbs", "spices"],
      unitSingular: "piece",
      unitPlural: "pieces"
    }
  ],
  herbs: [
    {
      name: "Herb Rice Bowl",
      family: "rice bowl",
      ingredientIds: ["herbs", "eggs", "cheese", "vegetables", "rice", "spices"],
      unitSingular: "scoop",
      unitPlural: "scoops"
    },
    {
      name: "Green Rice",
      family: "rice dish",
      ingredientIds: ["herbs", "rice", "vegetables", "cheese", "spices"],
      unitSingular: "scoop",
      unitPlural: "scoops"
    },
    {
      name: "Bean Herb Salad",
      family: "salad",
      ingredientIds: ["herbs", "beans", "vegetables", "spices"],
      unitSingular: "cup",
      unitPlural: "cups"
    },
    {
      name: "Herb Casserole",
      family: "casserole",
      ingredientIds: ["herbs", "vegetables", "cheese", "flour", "eggs", "rice"],
      unitSingular: "slice",
      unitPlural: "slices"
    }
  ],
  vegetables: [
    {
      name: "Veg Fried Rice",
      family: "rice dish",
      ingredientIds: ["vegetables", "rice", "eggs", "spices", "cheese", "beans"],
      unitSingular: "scoop",
      unitPlural: "scoops"
    },
    {
      name: "Vegetable Chili",
      family: "chili",
      ingredientIds: ["beans", "vegetables", "spices", "cheese", "herbs"],
      unitSingular: "cup",
      unitPlural: "cups"
    },
    {
      name: "Veggie Omelet",
      family: "omelet",
      ingredientIds: ["cheese", "herbs", "vegetables", "eggs"],
      unitSingular: "slice",
      unitPlural: "slices"
    },
    {
      name: "Vegetable Pot Pie",
      family: "pie",
      ingredientIds: ["vegetables", "flour", "cheese", "herbs", "rice", "beans"],
      unitSingular: "slice",
      unitPlural: "slices"
    }
  ],
  rice: [
    {
      name: "Fried Rice",
      family: "rice dish",
      ingredientIds: ["rice", "eggs", "vegetables", "herbs", "spices", "beans"],
      unitSingular: "scoop",
      unitPlural: "scoops"
    },
    {
      name: "Rice Bean Bowl",
      family: "rice bowl",
      ingredientIds: ["rice", "beans", "vegetables", "spices", "cheese"],
      unitSingular: "scoop",
      unitPlural: "scoops"
    },
    {
      name: "Rice Cakes",
      family: "rice cake",
      ingredientIds: ["rice", "cheese", "eggs", "herbs"],
      unitSingular: "piece",
      unitPlural: "pieces"
    },
    {
      name: "Rice Casserole",
      family: "casserole",
      ingredientIds: ["rice", "vegetables", "cheese", "flour", "herbs", "spices"],
      unitSingular: "slice",
      unitPlural: "slices"
    }
  ],
  beans: [
    {
      name: "Bean Shakshuka",
      family: "bean stew",
      ingredientIds: ["beans", "vegetables", "spices", "eggs", "herbs", "cheese"],
      unitSingular: "cup",
      unitPlural: "cups"
    },
    {
      name: "Bean Burrito",
      family: "wrap",
      ingredientIds: ["beans", "flour", "cheese", "vegetables", "spices"],
      unitSingular: "piece",
      unitPlural: "pieces"
    },
    {
      name: "Bean Dip",
      family: "dip",
      ingredientIds: ["beans", "cheese", "spices", "herbs"],
      unitSingular: "scoop",
      unitPlural: "scoops"
    },
    {
      name: "Bean Egg Skillet",
      family: "skillet",
      ingredientIds: ["beans", "eggs", "vegetables", "cheese", "flour", "herbs"],
      unitSingular: "serving",
      unitPlural: "servings"
    }
  ],
  spices: [
    {
      name: "Spiced Rice Pilaf",
      family: "rice dish",
      ingredientIds: ["spices", "rice", "vegetables", "herbs", "beans", "cheese"],
      unitSingular: "scoop",
      unitPlural: "scoops"
    },
    {
      name: "Bean Tacos",
      family: "tacos",
      ingredientIds: ["spices", "beans", "flour", "vegetables", "cheese"],
      unitSingular: "piece",
      unitPlural: "pieces"
    },
    {
      name: "Masala Omelet",
      family: "omelet",
      ingredientIds: ["spices", "eggs", "vegetables", "herbs"],
      unitSingular: "slice",
      unitPlural: "slices"
    },
    {
      name: "Spiced Pancakes",
      family: "pancakes",
      ingredientIds: ["spices", "flour", "eggs", "vegetables", "rice", "beans"],
      unitSingular: "piece",
      unitPlural: "pieces"
    }
  ],
  eggs: [
    {
      name: "Breakfast Burrito",
      family: "wrap",
      ingredientIds: ["eggs", "flour", "cheese", "vegetables", "beans", "spices"],
      unitSingular: "piece",
      unitPlural: "pieces"
    },
    {
      name: "Egg Fried Rice",
      family: "rice dish",
      ingredientIds: ["eggs", "rice", "vegetables", "herbs", "spices"],
      unitSingular: "scoop",
      unitPlural: "scoops"
    },
    {
      name: "Cheese Omelet",
      family: "omelet",
      ingredientIds: ["eggs", "cheese", "herbs", "vegetables"],
      unitSingular: "slice",
      unitPlural: "slices"
    },
    {
      name: "Egg Casserole",
      family: "casserole",
      ingredientIds: ["eggs", "cheese", "vegetables", "flour", "rice", "beans"],
      unitSingular: "slice",
      unitPlural: "slices"
    }
  ]
};

const recipeConfigurationCache = new Map<string, CatalogRecipe[]>();

export function generateRecipeCatalog(): RecipeCatalog {
  const configurations: CatalogConfiguration[] = [];
  const recipes: CatalogRecipe[] = [];

  for (let playerCount = MIN_CATALOG_PLAYER_COUNT; playerCount <= MAX_CATALOG_PLAYER_COUNT; playerCount += 1) {
    const configuration = configurationForPlayerCount(playerCount);
    configurations.push(configuration);
    recipes.push(...recipesForConfiguration(configuration));
  }

  const catalog = {
    generatorVersion: "4",
    ingredients: [...INGREDIENTS],
    dishTemplates: catalogDishTemplates(),
    configurations,
    recipes,
    requirements: recipes.flatMap((recipe) => recipe.requirements)
  };
  validateCatalog(catalog);
  return catalog;
}

export function configurationForPlayerCount(playerCount: number): CatalogConfiguration {
  if (playerCount < MIN_CATALOG_PLAYER_COUNT || playerCount > MAX_CATALOG_PLAYER_COUNT) {
    throw new Error(`Player count must be ${MIN_CATALOG_PLAYER_COUNT}.`);
  }

  return configurationForIngredients(ingredientsForPlayerCount(playerCount), `players_${playerCount}`);
}

export function ingredientsForPlayerCount(playerCount: number): Ingredient[] {
  if (playerCount < MIN_CATALOG_PLAYER_COUNT || playerCount > MAX_CATALOG_PLAYER_COUNT) {
    throw new Error(`Player count must be ${MIN_CATALOG_PLAYER_COUNT}.`);
  }

  const ingredientIds = COMMITTED_INGREDIENT_SET_IDS_BY_PLAYER_COUNT[playerCount];
  if (!ingredientIds) {
    throw new Error(`Missing committed ingredient set for ${playerCount} players.`);
  }
  const uniqueIngredientIds = new Set(ingredientIds);
  if (uniqueIngredientIds.size !== playerCount || ingredientIds.length !== playerCount) {
    throw new Error(`Committed ingredient set for ${playerCount} players must have ${playerCount} unique ingredients.`);
  }
  return ingredientIds.map(requireCatalogIngredient);
}

export function configurationForIngredients(ingredients: Ingredient[], configurationId: string): CatalogConfiguration {
  const playerCount = ingredients.length;
  if (playerCount < MIN_CATALOG_PLAYER_COUNT || playerCount > MAX_CATALOG_PLAYER_COUNT) {
    throw new Error(`Ingredient count must be ${MIN_CATALOG_PLAYER_COUNT}.`);
  }

  return {
    configurationId,
    playerCount,
    ingredients,
    requiredItemsPerRecipe: RECIPE_REQUIRED_ITEMS,
    minDistinctIngredients: RECIPE_DISTINCT_COUNTS[0],
    maxDistinctIngredients: RECIPE_DISTINCT_COUNTS[RECIPE_DISTINCT_COUNTS.length - 1],
    recipesPerIngredient: RECIPE_VARIANT_COUNT
  };
}

export function maxIngredientDemandForPlayerCount(playerCount: number, recipeGoal = RECIPE_VARIANT_COUNT): number {
  const configuration = configurationForPlayerCount(playerCount);
  const demand = new Map(configuration.ingredients.map((ingredient) => [ingredient.id, 0]));
  for (const recipe of recipesForConfiguration(configuration)) {
    if (RECIPE_SLOTS.indexOf(recipe.slot) >= recipeGoal) {
      continue;
    }
    for (const requirement of recipe.requirements) {
      demand.set(requirement.ingredientId, (demand.get(requirement.ingredientId) ?? 0) + requirement.requiredQty);
    }
  }
  return Math.max(...demand.values(), 0);
}

export function minimumBackedStockForPlayerCount(playerCount: number, recipeGoal = RECIPE_VARIANT_COUNT): number {
  return maxIngredientDemandForPlayerCount(playerCount, recipeGoal) + VOUCHERS_PER_INGREDIENT;
}

function configurationForCatalogLookup(ingredients: Ingredient[], fallbackConfigurationId: string): CatalogConfiguration {
  const ingredientIds = ingredients.map((ingredient) => ingredient.id);
  const committedIds = COMMITTED_INGREDIENT_SET_IDS_BY_PLAYER_COUNT[8] ?? [];
  if (committedIds.length === ingredientIds.length && committedIds.every((ingredientId, index) => ingredientId === ingredientIds[index])) {
    return configurationForPlayerCount(8);
  }
  return configurationForIngredients(ingredients, fallbackConfigurationId);
}

export function catalogRecipeForIngredients(
  ingredients: Ingredient[],
  ownerIngredientId: string,
  slot: RecipeSlot,
  configurationId = `runtime_${ingredients.map((ingredient) => ingredient.id).join("_")}`
): CatalogRecipe {
  const configuration = configurationForCatalogLookup(ingredients, configurationId);
  if (RECIPE_SLOTS.indexOf(slot) < 0) {
    throw new Error(`Unknown recipe slot ${slot}.`);
  }
  const recipe = recipesForConfiguration(configuration).find(
    (candidate) => candidate.ownerIngredientId === ownerIngredientId && candidate.slot === slot
  );
  if (!recipe) {
    throw new Error(`Missing catalog recipe for ${configuration.configurationId}:${ownerIngredientId}:${slot}.`);
  }
  return recipe;
}

function recipesForConfiguration(configuration: CatalogConfiguration): CatalogRecipe[] {
  const cacheKey = `${configuration.configurationId}:${configuration.ingredients.map((ingredient) => ingredient.id).join(",")}`;
  const cachedRecipes = recipeConfigurationCache.get(cacheKey);
  if (cachedRecipes) {
    return cachedRecipes;
  }

  const recipes: CatalogRecipe[] = [];
  for (const ownerIngredient of configuration.ingredients) {
    for (const [slotIndex, slot] of RECIPE_SLOTS.entries()) {
      recipes.push(recipeForOwner(configuration, ownerIngredient, slot, slotIndex));
    }
  }
  validateRecipes(configuration, recipes);
  recipeConfigurationCache.set(cacheKey, recipes);
  return recipes;
}

function recipeForOwner(configuration: CatalogConfiguration, ownerIngredient: Ingredient, slot: RecipeSlot, slotIndex: number): CatalogRecipe {
  const recipeId = `${configuration.configurationId}_${ownerIngredient.id}_${slot}`;
  const template = templateForIngredient(ownerIngredient.id, slotIndex);
  const ingredientIds = playableTemplateIngredientIds(template.ingredientIds);
  const quantityMap = quantitiesForIngredientIds(ingredientIds);
  const requirements = ingredientIds.map((ingredientId, index) => {
    const ingredient = requireIngredient(configuration, ingredientId);
    return {
      recipeId,
      position: index + 1,
      ingredientId,
      ingredientName: ingredient.name,
      requiredQty: quantityMap.get(ingredientId) ?? 1
    };
  });
  const totalRequiredQty = requirements.reduce((sum, requirement) => sum + requirement.requiredQty, 0);

  return {
    recipeId,
    templateId: templateIdFor(ownerIngredient.id, slot),
    configurationId: configuration.configurationId,
    playerCount: configuration.playerCount,
    slot,
    ownerIngredientId: ownerIngredient.id,
    ownerIngredientName: ownerIngredient.name,
    dishName: template.name,
    dishFamily: template.family,
    partUnitSingular: template.unitSingular,
    partUnitPlural: template.unitPlural,
    totalRequiredQty,
    distinctIngredientCount: requirements.length,
    quantityShape: quantityShapeForDistinctCount(requirements.length),
    minDistinctIngredientCount: configuration.minDistinctIngredients,
    maxDistinctIngredientCount: configuration.maxDistinctIngredients,
    activeIngredientIds: configuration.ingredients.map((ingredient) => ingredient.id),
    realIngredientIds: ingredientIds,
    matchedRealIngredientIds: ingredientIds,
    fallbackIngredientIds: [],
    requirements
  };
}

function quantitiesForIngredientIds(ingredientIds: string[]): Map<string, number> {
  if (ingredientIds.length === 6) {
    return new Map(ingredientIds.map((ingredientId) => [ingredientId, 1]));
  }
  if (ingredientIds.length === 5) {
    return new Map(ingredientIds.map((ingredientId, index) => [ingredientId, index === 0 ? 2 : 1]));
  }
  if (ingredientIds.length === 4) {
    return new Map(ingredientIds.map((ingredientId, index) => [ingredientId, index < 2 ? 2 : 1]));
  }
  throw new Error(`Recipes must use 4, 5, or 6 ingredients, got ${ingredientIds.length}.`);
}

function quantityShapeForDistinctCount(distinctCount: number): RecipeQuantityShape {
  if (distinctCount === 6) {
    return "six_singles";
  }
  if (distinctCount === 5) {
    return "one_double_four_singles";
  }
  return "two_doubles_two_singles";
}

function requireIngredient(configuration: CatalogConfiguration, ingredientId: string): Ingredient {
  const ingredient = configuration.ingredients.find((candidate) => candidate.id === ingredientId);
  if (!ingredient) {
    throw new Error(`Ingredient ${ingredientId} is not active for ${configuration.configurationId}.`);
  }
  return ingredient;
}

function requireCatalogIngredient(ingredientId: string): Ingredient {
  const ingredient = INGREDIENTS.find((candidate) => candidate.id === ingredientId);
  if (!ingredient) {
    throw new Error(`Unknown committed ingredient ${ingredientId}.`);
  }
  return ingredient;
}

function templateForIngredient(ingredientId: string, slotIndex: number): DishTemplate {
  const templates = DISH_TEMPLATES[ingredientId];
  if (!templates || templates.length < RECIPE_VARIANT_COUNT) {
    throw new Error(`Missing recipe templates for ingredient ${ingredientId}.`);
  }
  return templates[slotIndex % templates.length] as DishTemplate;
}

function catalogDishTemplates(): CatalogDishTemplate[] {
  return INGREDIENTS.flatMap((ingredient) =>
    RECIPE_SLOTS.map((slot, slotIndex) => {
      const template = templateForIngredient(ingredient.id, slotIndex);
      return {
        templateId: templateIdFor(ingredient.id, slot),
        ingredientId: ingredient.id,
        ingredientName: ingredient.name,
        slot,
        dishName: template.name,
        dishFamily: template.family,
        partUnitSingular: template.unitSingular,
        partUnitPlural: template.unitPlural,
        realIngredientIds: playableTemplateIngredientIds(template.ingredientIds)
      };
    })
  );
}

function templateIdFor(ownerIngredientId: string, slot: RecipeSlot): string {
  return `${ownerIngredientId}_${slot}`;
}

function playableTemplateIngredientIds(ingredientIds: string[]): string[] {
  const unique = uniqueIngredientIds(ingredientIds);
  if (!RECIPE_DISTINCT_COUNTS.some((count) => count === unique.length)) {
    throw new Error(`Recipe templates must define 4, 5, or 6 unique ingredients.`);
  }
  return unique;
}

function uniqueIngredientIds(ingredientIds: string[]): string[] {
  const knownIngredientIds = new Set(INGREDIENTS.map((ingredient) => ingredient.id));
  const unique: string[] = [];
  for (const ingredientId of ingredientIds) {
    if (!knownIngredientIds.has(ingredientId)) {
      throw new Error(`Unknown recipe ingredient ${ingredientId}.`);
    }
    if (!unique.includes(ingredientId)) {
      unique.push(ingredientId);
    }
  }
  return unique;
}

function validateCatalog(catalog: RecipeCatalog): void {
  if (catalog.ingredients.length !== 8) {
    throw new Error(`Recipes MVP requires exactly 8 ingredients, got ${catalog.ingredients.length}.`);
  }
  if (catalog.configurations.length !== 1 || catalog.configurations[0]?.playerCount !== 8) {
    throw new Error("Recipes MVP requires one 8-player catalog configuration.");
  }
  if (catalog.recipes.length !== 8 * RECIPE_VARIANT_COUNT) {
    throw new Error(`Recipes MVP requires 32 recipes, got ${catalog.recipes.length}.`);
  }
}

function validateRecipes(configuration: CatalogConfiguration, recipes: CatalogRecipe[]): void {
  const nameCounts = new Map<string, number>();
  const signatureCounts = new Map<string, number>();
  const demandCounts = new Map(configuration.ingredients.map((ingredient) => [ingredient.id, 0]));
  const activeIngredientIds = new Set(configuration.ingredients.map((ingredient) => ingredient.id));

  for (const recipe of recipes) {
    nameCounts.set(recipe.dishName, (nameCounts.get(recipe.dishName) ?? 0) + 1);
    const signature = requirementSignature(recipe.requirements);
    signatureCounts.set(signature, (signatureCounts.get(signature) ?? 0) + 1);
    if (!recipe.requirements.some((requirement) => requirement.ingredientId === recipe.ownerIngredientId)) {
      throw new Error(`${recipe.recipeId} must include owner ingredient ${recipe.ownerIngredientId}.`);
    }
    if (recipe.totalRequiredQty !== RECIPE_REQUIRED_ITEMS) {
      throw new Error(`${recipe.recipeId} must require exactly ${RECIPE_REQUIRED_ITEMS} items.`);
    }
    if (!RECIPE_DISTINCT_COUNTS.some((count) => count === recipe.distinctIngredientCount)) {
      throw new Error(`${recipe.recipeId} must use 4, 5, or 6 ingredients.`);
    }
    for (const requirement of recipe.requirements) {
      if (!activeIngredientIds.has(requirement.ingredientId)) {
        throw new Error(`${recipe.recipeId} uses inactive ingredient ${requirement.ingredientId}.`);
      }
      demandCounts.set(requirement.ingredientId, (demandCounts.get(requirement.ingredientId) ?? 0) + requirement.requiredQty);
    }
  }

  for (const [name, count] of nameCounts.entries()) {
    if (count > 1) {
      throw new Error(`Duplicate recipe name: ${name}.`);
    }
  }
  for (const [signature, count] of signatureCounts.entries()) {
    if (count > 1) {
      throw new Error(`Duplicate recipe requirement signature: ${signature}.`);
    }
  }
  for (const [ingredientId, demand] of demandCounts.entries()) {
    const requiredStock = demand + VOUCHERS_PER_INGREDIENT;
    if (requiredStock > REAL_UNITS_PER_INGREDIENT) {
      throw new Error(`${ingredientId} catalog demand ${demand} plus voucher backing ${VOUCHERS_PER_INGREDIENT} exceeds stock ${REAL_UNITS_PER_INGREDIENT}.`);
    }
  }
}

function requirementSignature(requirements: CatalogRequirement[]): string {
  return requirements
    .map((requirement) => `${requirement.ingredientId}:${requirement.requiredQty}`)
    .sort()
    .join("|");
}
