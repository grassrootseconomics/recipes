import {
  INGREDIENTS,
  MAX_ACTIVE_PARTICIPANTS,
  MIN_ACTIVE_PARTICIPANTS,
  REAL_UNITS_PER_INGREDIENT,
  VOUCHERS_PER_INGREDIENT
} from "./constants.js";
import { hashString } from "./rng.js";
import type { Ingredient } from "./types.js";

export const RECIPE_VARIANT_COUNT = 4;
export const RECIPE_REQUIRED_ITEMS = VOUCHERS_PER_INGREDIENT - 1;
export const RECIPE_DISTINCT_COUNTS = [3, 4, 6] as const;
export const MIN_TEMPLATE_INGREDIENTS = RECIPE_DISTINCT_COUNTS[0];
export const MAX_TEMPLATE_INGREDIENTS = RECIPE_REQUIRED_ITEMS;

export const RECIPE_SLOTS = ["initial", "followup_1", "followup_2", "followup_3"] as const;

export type RecipeSlot = (typeof RECIPE_SLOTS)[number];
export type RecipeQuantityShape = "three_pairs" | "two_pairs_two_singles" | "six_singles";

export const COMMITTED_INGREDIENT_SET_IDS_BY_PLAYER_COUNT: Record<number, string[]> = {
  7: ["rice", "tomato", "onion", "garlic", "pepper", "salt", "potato"],
  8: ["beans", "tomato", "onion", "garlic", "pepper", "salt", "ginger", "potato"],
  9: ["maize", "tomato", "onion", "garlic", "pepper", "salt", "coconut", "beans", "potato"],
  10: ["rice", "tomato", "onion", "garlic", "pepper", "salt", "carrot", "cabbage", "lentils", "herbs"],
  11: ["chickpeas", "tomato", "onion", "garlic", "pepper", "salt", "ginger", "potato", "coconut", "cassava", "lemon"],
  12: ["rice", "beans", "tomato", "onion", "garlic", "pepper", "salt", "ginger", "potato", "carrot", "spinach", "lemon"],
  13: ["maize", "tomato", "onion", "garlic", "pepper", "salt", "coconut", "plantain", "cassava", "ginger", "beans", "rice", "herbs"],
  14: ["rice", "beans", "tomato", "onion", "garlic", "pepper", "salt", "potato", "cabbage", "lentils", "chickpeas", "spinach", "lemon", "herbs"],
  15: ["maize", "tomato", "onion", "garlic", "pepper", "salt", "coconut", "plantain", "cassava", "ginger", "potato", "carrot", "cabbage", "rice", "beans"],
  16: ["rice", "beans", "maize", "tomato", "onion", "garlic", "pepper", "salt", "coconut", "plantain", "cassava", "ginger", "lentils", "chickpeas", "spinach", "herbs"],
  17: ["rice", "beans", "maize", "tomato", "onion", "garlic", "pepper", "salt", "coconut", "plantain", "cassava", "ginger", "potato", "carrot", "cabbage", "lentils", "lemon"],
  18: ["rice", "beans", "maize", "tomato", "onion", "garlic", "pepper", "salt", "coconut", "plantain", "cassava", "ginger", "potato", "carrot", "cabbage", "lentils", "chickpeas", "spinach"],
  19: ["rice", "beans", "maize", "tomato", "onion", "garlic", "ginger", "pepper", "potato", "carrot", "cabbage", "lentils", "chickpeas", "coconut", "plantain", "cassava", "spinach", "salt", "herbs"],
  20: ["rice", "beans", "maize", "tomato", "onion", "garlic", "ginger", "pepper", "potato", "carrot", "cabbage", "lentils", "chickpeas", "coconut", "plantain", "cassava", "spinach", "lemon", "salt", "herbs"]
};

interface DishTemplate {
  name: string;
  family: string;
  ingredientIds: string[];
}

interface ServingUnit {
  singular: string;
  plural: string;
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
  rice: [
    { name: "Jollof Rice", family: "rice dish", ingredientIds: ["rice", "tomato", "onion", "pepper", "garlic", "ginger", "salt", "herbs"] },
    { name: "Rice And Beans", family: "rice dish", ingredientIds: ["rice", "beans", "onion", "garlic", "tomato", "pepper", "salt"] },
    { name: "Vegetable Biryani", family: "rice dish", ingredientIds: ["rice", "onion", "garlic", "ginger", "carrot", "potato", "pepper", "herbs", "salt"] },
    { name: "Fried Rice", family: "rice dish", ingredientIds: ["rice", "onion", "garlic", "carrot", "cabbage", "pepper", "ginger", "salt"] }
  ],
  beans: [
    { name: "Red Beans And Rice", family: "bean dish", ingredientIds: ["beans", "rice", "onion", "garlic", "pepper", "tomato", "salt"] },
    { name: "Bean Stew", family: "bean dish", ingredientIds: ["beans", "tomato", "onion", "garlic", "carrot", "pepper", "herbs", "salt"] },
    { name: "Bean Chili", family: "bean dish", ingredientIds: ["beans", "tomato", "onion", "garlic", "pepper", "maize", "salt"] },
    { name: "Feijoada-Style Beans", family: "bean dish", ingredientIds: ["beans", "onion", "garlic", "cabbage", "rice", "salt", "herbs"] }
  ],
  maize: [
    { name: "Maize Porridge", family: "maize dish", ingredientIds: ["maize", "coconut", "salt"] },
    { name: "Corn Chowder", family: "maize dish", ingredientIds: ["maize", "potato", "onion", "garlic", "carrot", "herbs", "salt"] },
    { name: "Succotash", family: "maize dish", ingredientIds: ["maize", "beans", "tomato", "onion", "pepper", "herbs", "salt"] },
    { name: "Maize Arepas", family: "maize dish", ingredientIds: ["maize", "salt", "beans", "tomato", "onion", "pepper"] }
  ],
  tomato: [
    { name: "Shakshuka", family: "tomato dish", ingredientIds: ["tomato", "onion", "pepper", "garlic", "herbs", "salt"] },
    { name: "Tomato Stew", family: "tomato dish", ingredientIds: ["tomato", "onion", "garlic", "pepper", "ginger", "salt", "herbs"] },
    { name: "Tomato Rice", family: "tomato dish", ingredientIds: ["tomato", "rice", "onion", "garlic", "pepper", "salt"] },
    { name: "Ratatouille-Style Stew", family: "tomato dish", ingredientIds: ["tomato", "onion", "garlic", "pepper", "carrot", "herbs", "salt"] }
  ],
  onion: [
    { name: "Onion Soup", family: "onion dish", ingredientIds: ["onion", "garlic", "herbs", "salt"] },
    { name: "Sofrito Rice", family: "onion dish", ingredientIds: ["onion", "rice", "tomato", "garlic", "pepper", "herbs", "salt"] },
    { name: "Onion Chutney Curry", family: "onion dish", ingredientIds: ["onion", "ginger", "garlic", "pepper", "lemon", "salt", "herbs"] },
    { name: "Onion Bhaji Plate", family: "onion dish", ingredientIds: ["onion", "maize", "pepper", "ginger", "garlic", "herbs", "salt"] }
  ],
  garlic: [
    { name: "Garlic Rice", family: "garlic dish", ingredientIds: ["garlic", "rice", "onion", "salt", "herbs"] },
    { name: "Garlic Vegetable Stir-Fry", family: "garlic dish", ingredientIds: ["garlic", "cabbage", "carrot", "onion", "pepper", "ginger", "salt"] },
    { name: "Garlic Soup", family: "garlic dish", ingredientIds: ["garlic", "potato", "onion", "herbs", "salt"] },
    { name: "Garlic Lentil Stew", family: "garlic dish", ingredientIds: ["garlic", "lentils", "onion", "tomato", "carrot", "herbs", "salt"] }
  ],
  ginger: [
    { name: "Ginger Coconut Curry", family: "ginger dish", ingredientIds: ["ginger", "coconut", "onion", "garlic", "pepper", "tomato", "salt", "herbs"] },
    { name: "Ginger Fried Rice", family: "ginger dish", ingredientIds: ["ginger", "rice", "onion", "garlic", "carrot", "pepper", "salt"] },
    { name: "Ginger Lentil Stew", family: "ginger dish", ingredientIds: ["ginger", "lentils", "onion", "garlic", "tomato", "carrot", "salt"] },
    { name: "Ginger Pepper Soup", family: "ginger dish", ingredientIds: ["ginger", "pepper", "onion", "garlic", "herbs", "salt"] }
  ],
  pepper: [
    { name: "Pepper Soup", family: "pepper dish", ingredientIds: ["pepper", "onion", "garlic", "ginger", "herbs", "salt"] },
    { name: "Chili Beans", family: "pepper dish", ingredientIds: ["pepper", "beans", "tomato", "onion", "garlic", "maize", "salt"] },
    { name: "Pepper Pot", family: "pepper dish", ingredientIds: ["pepper", "cassava", "onion", "garlic", "ginger", "tomato", "herbs", "salt"] },
    { name: "Pepper Rice", family: "pepper dish", ingredientIds: ["pepper", "rice", "tomato", "onion", "garlic", "salt"] }
  ],
  potato: [
    { name: "Aloo Curry", family: "potato dish", ingredientIds: ["potato", "onion", "garlic", "ginger", "tomato", "pepper", "herbs", "salt"] },
    { name: "Potato Stew", family: "potato dish", ingredientIds: ["potato", "tomato", "onion", "garlic", "carrot", "herbs", "salt"] },
    { name: "Bubble And Squeak", family: "potato dish", ingredientIds: ["potato", "cabbage", "onion", "salt", "herbs"] },
    { name: "Potato Hash", family: "potato dish", ingredientIds: ["potato", "onion", "pepper", "garlic", "herbs", "salt"] }
  ],
  carrot: [
    { name: "Carrot Ginger Soup", family: "carrot dish", ingredientIds: ["carrot", "ginger", "onion", "garlic", "coconut", "salt", "herbs"] },
    { name: "Carrot Rice Pilaf", family: "carrot dish", ingredientIds: ["carrot", "rice", "onion", "garlic", "herbs", "salt"] },
    { name: "Moroccan Carrot Stew", family: "carrot dish", ingredientIds: ["carrot", "chickpeas", "tomato", "onion", "garlic", "ginger", "lemon", "herbs", "salt"] },
    { name: "Carrot Lentil Soup", family: "carrot dish", ingredientIds: ["carrot", "lentils", "onion", "garlic", "tomato", "herbs", "salt"] }
  ],
  cabbage: [
    { name: "Cabbage Roll Bowl", family: "cabbage dish", ingredientIds: ["cabbage", "rice", "tomato", "onion", "garlic", "beans", "salt"] },
    { name: "Colcannon", family: "cabbage dish", ingredientIds: ["cabbage", "potato", "onion", "salt", "herbs"] },
    { name: "Cabbage Stir-Fry", family: "cabbage dish", ingredientIds: ["cabbage", "carrot", "onion", "garlic", "ginger", "pepper", "salt"] },
    { name: "Cabbage Soup", family: "cabbage dish", ingredientIds: ["cabbage", "onion", "garlic", "carrot", "potato", "herbs", "salt"] }
  ],
  lentils: [
    { name: "Lentil Dal", family: "lentil dish", ingredientIds: ["lentils", "onion", "garlic", "ginger", "tomato", "pepper", "salt", "herbs"] },
    { name: "Lentil Soup", family: "lentil dish", ingredientIds: ["lentils", "onion", "garlic", "carrot", "tomato", "herbs", "salt"] },
    { name: "Mujadara", family: "lentil dish", ingredientIds: ["lentils", "rice", "onion", "salt", "herbs"] },
    { name: "Lentil Stew", family: "lentil dish", ingredientIds: ["lentils", "tomato", "onion", "garlic", "carrot", "potato", "salt"] }
  ],
  chickpeas: [
    { name: "Chana Masala", family: "chickpea dish", ingredientIds: ["chickpeas", "tomato", "onion", "garlic", "ginger", "pepper", "salt", "herbs"] },
    { name: "Chickpea Curry", family: "chickpea dish", ingredientIds: ["chickpeas", "coconut", "tomato", "onion", "garlic", "ginger", "pepper", "salt"] },
    { name: "Hummus Plate", family: "chickpea dish", ingredientIds: ["chickpeas", "garlic", "lemon", "salt", "herbs"] },
    { name: "Chickpea Stew", family: "chickpea dish", ingredientIds: ["chickpeas", "tomato", "onion", "garlic", "carrot", "potato", "herbs", "salt"] }
  ],
  coconut: [
    { name: "Coconut Rice", family: "coconut dish", ingredientIds: ["coconut", "rice", "onion", "garlic", "ginger", "salt", "herbs"] },
    { name: "Coconut Curry", family: "coconut dish", ingredientIds: ["coconut", "tomato", "onion", "garlic", "ginger", "pepper", "potato", "salt"] },
    { name: "Coconut Lentil Stew", family: "coconut dish", ingredientIds: ["coconut", "lentils", "tomato", "onion", "garlic", "ginger", "salt"] },
    { name: "Coconut Cassava Soup", family: "coconut dish", ingredientIds: ["coconut", "cassava", "onion", "garlic", "ginger", "pepper", "salt"] }
  ],
  plantain: [
    { name: "Plantain Pottage", family: "plantain dish", ingredientIds: ["plantain", "tomato", "onion", "pepper", "garlic", "salt", "herbs"] },
    { name: "Mofongo-Style Plantain", family: "plantain dish", ingredientIds: ["plantain", "garlic", "salt", "herbs", "beans"] },
    { name: "Plantain Curry", family: "plantain dish", ingredientIds: ["plantain", "coconut", "tomato", "onion", "garlic", "ginger", "pepper", "salt"] },
    { name: "Fried Plantain Plate", family: "plantain dish", ingredientIds: ["plantain", "beans", "rice", "tomato", "onion", "pepper", "salt"] }
  ],
  cassava: [
    { name: "Cassava Pot", family: "cassava dish", ingredientIds: ["cassava", "tomato", "onion", "garlic", "pepper", "ginger", "salt", "herbs"] },
    { name: "Cassava Porridge", family: "cassava dish", ingredientIds: ["cassava", "coconut", "salt", "ginger"] },
    { name: "Cassava Pepper Soup", family: "cassava dish", ingredientIds: ["cassava", "pepper", "onion", "garlic", "ginger", "herbs", "salt"] },
    { name: "Tapioca Vegetable Stew", family: "cassava dish", ingredientIds: ["cassava", "tomato", "onion", "garlic", "carrot", "cabbage", "salt"] }
  ],
  spinach: [
    { name: "Saag", family: "spinach dish", ingredientIds: ["spinach", "onion", "garlic", "ginger", "tomato", "pepper", "salt"] },
    { name: "Spinach Lentil Dal", family: "spinach dish", ingredientIds: ["spinach", "lentils", "onion", "garlic", "ginger", "tomato", "salt"] },
    { name: "Spinach Rice", family: "spinach dish", ingredientIds: ["spinach", "rice", "onion", "garlic", "lemon", "salt"] },
    { name: "Spinach Stew", family: "spinach dish", ingredientIds: ["spinach", "tomato", "onion", "garlic", "pepper", "herbs", "salt"] }
  ],
  lemon: [
    { name: "Lemon Rice", family: "lemon dish", ingredientIds: ["lemon", "rice", "onion", "garlic", "ginger", "pepper", "salt", "herbs"] },
    { name: "Lemon Herb Stew", family: "lemon dish", ingredientIds: ["lemon", "herbs", "tomato", "onion", "garlic", "carrot", "salt"] },
    {
      name: "Preserved Lemon Tagine-Style Vegetables",
      family: "lemon dish",
      ingredientIds: ["lemon", "chickpeas", "carrot", "onion", "garlic", "ginger", "tomato", "herbs", "salt"]
    },
    { name: "Lemon Lentil Soup", family: "lemon dish", ingredientIds: ["lemon", "lentils", "onion", "garlic", "carrot", "herbs", "salt"] }
  ],
  salt: [
    { name: "Salt Potatoes", family: "salt-seasoned dish", ingredientIds: ["salt", "potato", "herbs", "garlic"] },
    { name: "Seasoned Rice", family: "salt-seasoned dish", ingredientIds: ["salt", "rice", "onion", "garlic", "herbs"] },
    { name: "Salted Lentil Soup", family: "salt-seasoned dish", ingredientIds: ["salt", "lentils", "onion", "garlic", "carrot", "herbs"] },
    { name: "Salted Vegetable Stew", family: "salt-seasoned dish", ingredientIds: ["salt", "tomato", "onion", "garlic", "carrot", "potato", "cabbage", "herbs"] }
  ],
  herbs: [
    { name: "Herb Rice", family: "herb dish", ingredientIds: ["herbs", "rice", "onion", "garlic", "lemon", "salt"] },
    { name: "Herbed Vegetable Stew", family: "herb dish", ingredientIds: ["herbs", "tomato", "onion", "garlic", "carrot", "potato", "cabbage", "salt"] },
    { name: "Herb Lentil Soup", family: "herb dish", ingredientIds: ["herbs", "lentils", "onion", "garlic", "carrot", "lemon", "salt"] },
    { name: "Green Herb Chutney Bowl", family: "herb dish", ingredientIds: ["herbs", "lemon", "garlic", "ginger", "pepper", "rice", "salt"] }
  ]
};

const GENERATED_STYLE_BY_SLOT: Record<RecipeSlot, string> = {
  initial: "Pot",
  followup_1: "Stew",
  followup_2: "Bowl",
  followup_3: "Sizzle"
};

interface RequirementCandidate {
  requirements: CatalogRequirement[];
  signature: string;
}

const recipeConfigurationCache = new Map<string, CatalogRecipe[]>();

export function generateRecipeCatalog(): RecipeCatalog {
  const configurations: CatalogConfiguration[] = [];
  const recipes: CatalogRecipe[] = [];

  for (let playerCount = MIN_ACTIVE_PARTICIPANTS; playerCount <= MAX_ACTIVE_PARTICIPANTS; playerCount += 1) {
    const configuration = configurationForPlayerCount(playerCount);
    configurations.push(configuration);
    recipes.push(...recipesForConfiguration(configuration));
  }

  return {
    generatorVersion: "3",
    ingredients: [...INGREDIENTS],
    dishTemplates: catalogDishTemplates(),
    configurations,
    recipes,
    requirements: recipes.flatMap((recipe) => recipe.requirements)
  };
}

export function configurationForPlayerCount(playerCount: number): CatalogConfiguration {
  if (playerCount < MIN_ACTIVE_PARTICIPANTS || playerCount > MAX_ACTIVE_PARTICIPANTS) {
    throw new Error(`Player count must be between ${MIN_ACTIVE_PARTICIPANTS} and ${MAX_ACTIVE_PARTICIPANTS}.`);
  }

  return configurationForIngredients(ingredientsForPlayerCount(playerCount), `players_${playerCount}`);
}

export function ingredientsForPlayerCount(playerCount: number): Ingredient[] {
  if (playerCount < MIN_ACTIVE_PARTICIPANTS || playerCount > MAX_ACTIVE_PARTICIPANTS) {
    throw new Error(`Player count must be between ${MIN_ACTIVE_PARTICIPANTS} and ${MAX_ACTIVE_PARTICIPANTS}.`);
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
  if (playerCount < MIN_ACTIVE_PARTICIPANTS || playerCount > MAX_ACTIVE_PARTICIPANTS) {
    throw new Error(`Ingredient count must be between ${MIN_ACTIVE_PARTICIPANTS} and ${MAX_ACTIVE_PARTICIPANTS}.`);
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

function configurationForCatalogLookup(ingredients: Ingredient[], fallbackConfigurationId: string): CatalogConfiguration {
  const ingredientIds = ingredients.map((ingredient) => ingredient.id);
  for (let playerCount = MIN_ACTIVE_PARTICIPANTS; playerCount <= MAX_ACTIVE_PARTICIPANTS; playerCount += 1) {
    const committedIds = COMMITTED_INGREDIENT_SET_IDS_BY_PLAYER_COUNT[playerCount] ?? [];
    if (committedIds.length === ingredientIds.length && committedIds.every((ingredientId, index) => ingredientId === ingredientIds[index])) {
      return configurationForPlayerCount(playerCount);
    }
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

  const usedRequirementSignatures = new Set<string>();
  const usedDishNames = new Set<string>();
  const demandCounts = new Map(configuration.ingredients.map((ingredient) => [ingredient.id, 0]));
  const recipes: CatalogRecipe[] = [];
  for (const ownerIngredient of configuration.ingredients) {
    for (const [slotIndex, slot] of RECIPE_SLOTS.entries()) {
      recipes.push(recipeForOwner(configuration, ownerIngredient, slot, slotIndex, usedRequirementSignatures, usedDishNames, demandCounts));
    }
  }
  recipeConfigurationCache.set(cacheKey, recipes);
  return recipes;
}

function recipeForOwner(
  configuration: CatalogConfiguration,
  ownerIngredient: Ingredient,
  slot: RecipeSlot,
  slotIndex: number,
  usedRequirementSignatures = new Set<string>(),
  usedDishNames = new Set<string>(),
  demandCounts?: Map<string, number>
): CatalogRecipe {
  const recipeId = `${configuration.configurationId}_${ownerIngredient.id}_${slot}`;
  const template = templateForIngredient(ownerIngredient.id, slotIndex);
  const templateIngredientIds = playableTemplateIngredientIds(template.ingredientIds);
  const candidate = selectRequirementCandidate(
    requirementCandidatesForRecipe(configuration, ownerIngredient, recipeId, template, usedRequirementSignatures),
    demandCounts,
    configuration,
    recipeId
  );
  usedRequirementSignatures.add(candidate.signature);
  applyDemandCounts(candidate, demandCounts);
  const requirements = candidate.requirements;
  const totalRequiredQty = requirements.reduce((sum, requirement) => sum + requirement.requiredQty, 0);
  const requirementIngredientIds = requirements.map((requirement) => requirement.ingredientId);
  const exactTemplateMatch = requirementsMatchTemplate(requirements, templateIngredientIds);
  const dishName = exactTemplateMatch && !usedDishNames.has(template.name)
    ? template.name
    : generatedDishName(ownerIngredient, slot, requirements, usedDishNames);
  usedDishNames.add(dishName);
  const servingUnit = servingUnitForTemplate(template);

  return {
    recipeId,
    templateId: templateIdFor(ownerIngredient.id, slot),
    configurationId: configuration.configurationId,
    playerCount: configuration.playerCount,
    slot,
    ownerIngredientId: ownerIngredient.id,
    ownerIngredientName: ownerIngredient.name,
    dishName,
    dishFamily: template.family,
    partUnitSingular: servingUnit.singular,
    partUnitPlural: servingUnit.plural,
    totalRequiredQty,
    distinctIngredientCount: requirements.length,
    quantityShape: quantityShapeForDistinctCount(requirements.length),
    minDistinctIngredientCount: configuration.minDistinctIngredients,
    maxDistinctIngredientCount: configuration.maxDistinctIngredients,
    activeIngredientIds: configuration.ingredients.map((ingredient) => ingredient.id),
    realIngredientIds: requirementIngredientIds,
    matchedRealIngredientIds: requirementIngredientIds,
    fallbackIngredientIds: [],
    requirements
  };
}

function requirementsMatchTemplate(requirements: CatalogRequirement[], templateIngredientIds: string[]): boolean {
  if (requirements.length !== templateIngredientIds.length) {
    return false;
  }
  const templateIngredientSet = new Set(templateIngredientIds);
  if (!requirements.every((requirement) => templateIngredientSet.has(requirement.ingredientId))) {
    return false;
  }

  const templateQuantities = quantitiesForDistinctCount(templateIngredientIds.length, templateIngredientIds);
  return requirements.every((requirement) => templateQuantities.get(requirement.ingredientId) === requirement.requiredQty);
}

function quantitiesForDistinctCount(distinctCount: number, ingredientIds: string[]): Map<string, number> {
  const doubleCount = RECIPE_REQUIRED_ITEMS - distinctCount;
  return new Map(ingredientIds.map((ingredientId, index) => [ingredientId, index < doubleCount ? 2 : 1]));
}

function generatedDishName(
  ownerIngredient: Ingredient,
  slot: RecipeSlot,
  requirements: CatalogRequirement[],
  usedDishNames: Set<string>
): string {
  const ownerRequirement = requirements.find((requirement) => requirement.ingredientId === ownerIngredient.id);
  const otherRequirements = requirements.filter((requirement) => requirement.ingredientId !== ownerIngredient.id);
  const ownerName = ownerRequirement?.ingredientName ?? ownerIngredient.name;
  const otherNames = uniqueNames(
    otherRequirements
      .sort((left, right) => right.requiredQty - left.requiredQty || left.ingredientName.localeCompare(right.ingredientName))
      .map((requirement) => requirement.ingredientName)
  );
  const style = GENERATED_STYLE_BY_SLOT[slot];
  const candidates = [
    [ownerName, otherNames[0], style],
    [ownerName, otherNames[1], style],
    [ownerName, otherNames[0], otherNames[1], style],
    [ownerName, otherNames[0], otherNames[1], otherNames[2], style],
    [ownerName, style]
  ]
    .map((parts) => parts.filter((part): part is string => Boolean(part)).join(" "))
    .filter((name) => name.trim().length > 0);

  for (const candidate of candidates) {
    if (!usedDishNames.has(candidate)) {
      return candidate;
    }
  }

  const suffixes = ["Feast", "Hash", "Curry", "Pilaf", "Supper", "Mix"];
  for (const suffix of suffixes) {
    const candidate = `${ownerName} ${style} ${suffix}`;
    if (!usedDishNames.has(candidate)) {
      return candidate;
    }
  }

  return `${ownerName} ${style} ${usedDishNames.size + 1}`;
}

function uniqueNames(names: string[]): string[] {
  const unique: string[] = [];
  for (const name of names) {
    if (!unique.includes(name)) {
      unique.push(name);
    }
  }
  return unique;
}

function uniqueNumbers(values: number[]): number[] {
  const unique: number[] = [];
  for (const value of values) {
    if (!unique.includes(value)) {
      unique.push(value);
    }
  }
  return unique;
}

function requirementCandidatesForRecipe(
  configuration: CatalogConfiguration,
  ownerIngredient: Ingredient,
  recipeId: string,
  template: DishTemplate,
  usedRequirementSignatures: Set<string>
): RequirementCandidate[] {
  const activeIngredientIds = new Set(configuration.ingredients.map((ingredient) => ingredient.id));
  const templateIngredientIds = playableTemplateIngredientIds(template.ingredientIds);
  const preferredIngredientIds = uniqueIngredientIds([ownerIngredient.id, ...templateIngredientIds]);
  const activePreferredIds = preferredIngredientIds.filter((ingredientId) => activeIngredientIds.has(ingredientId));
  const distinctCount = distinctCountForActivePreferred(activePreferredIds.length);
  const candidates: RequirementCandidate[] = [];

  if (templateIngredientIds.every((ingredientId) => activeIngredientIds.has(ingredientId))) {
    candidates.push(buildRequirementCandidate(configuration, recipeId, templateIngredientIds, quantitiesForDistinctCount(templateIngredientIds.length, templateIngredientIds)));
  }

  const distinctCountPriority = uniqueNumbers([distinctCount, 6, 4, 3]).filter(
    (candidateDistinctCount) => candidateDistinctCount <= configuration.ingredients.length
  );
  for (const candidateDistinctCount of distinctCountPriority) {
    const ingredientCombinations = ingredientCombinationsForDistinctCount(
      configuration,
      ownerIngredient.id,
      candidateDistinctCount,
      preferredIngredientIds,
      recipeId
    );
    for (const ingredientIds of ingredientCombinations) {
      for (const quantityMap of quantityMapsForIngredientIds(ingredientIds, ownerIngredient.id, preferredIngredientIds, recipeId)) {
        candidates.push(buildRequirementCandidate(configuration, recipeId, ingredientIds, quantityMap));
      }
    }
  }

  const localSignatures = new Set<string>();
  const uniqueCandidates: RequirementCandidate[] = [];
  for (const candidate of candidates) {
    if (localSignatures.has(candidate.signature)) {
      continue;
    }
    localSignatures.add(candidate.signature);
    if (!usedRequirementSignatures.has(candidate.signature)) {
      uniqueCandidates.push(candidate);
    }
  }

  if (uniqueCandidates.length === 0) {
    throw new Error(`Could not generate a unique recipe for ${configuration.configurationId}:${ownerIngredient.id}:${recipeId}.`);
  }
  return uniqueCandidates;
}

function buildRequirementCandidate(
  configuration: CatalogConfiguration,
  recipeId: string,
  ingredientIds: string[],
  quantityMap: Map<string, number>
): RequirementCandidate {
  const activeOrder = new Map(configuration.ingredients.map((ingredient, index) => [ingredient.id, index]));
  const requirements = [...ingredientIds]
    .sort((left, right) => (activeOrder.get(left) ?? 0) - (activeOrder.get(right) ?? 0))
    .map((ingredientId, index) => {
      const ingredient = requireIngredient(configuration, ingredientId);
      return {
        recipeId,
        position: index + 1,
        ingredientId,
        ingredientName: ingredient.name,
        requiredQty: quantityMap.get(ingredientId) ?? 1
      };
    });
  return {
    requirements,
    signature: requirementSignature(requirements)
  };
}

function selectRequirementCandidate(
  candidates: RequirementCandidate[],
  demandCounts: Map<string, number> | undefined,
  configuration: CatalogConfiguration,
  recipeId: string
): RequirementCandidate {
  if (!demandCounts) {
    return candidates[0] as RequirementCandidate;
  }

  const ranked = candidates
    .map((candidate, index) => ({ candidate, index }))
    .filter(({ candidate }) => demandFits(candidate, demandCounts))
    .sort((left, right) => {
      const demandDifference =
        demandScore(left.candidate, demandCounts, configuration) - demandScore(right.candidate, demandCounts, configuration);
      return demandDifference !== 0 ? demandDifference : left.index - right.index;
    });

  if (ranked.length === 0) {
    throw new Error(`Could not keep ${recipeId} within ${REAL_UNITS_PER_INGREDIENT} real ingredient units.`);
  }
  return ranked[0].candidate;
}

function demandFits(candidate: RequirementCandidate, demandCounts: Map<string, number>): boolean {
  return candidate.requirements.every(
    (requirement) => (demandCounts.get(requirement.ingredientId) ?? 0) + requirement.requiredQty <= REAL_UNITS_PER_INGREDIENT
  );
}

function demandScore(candidate: RequirementCandidate, demandCounts: Map<string, number>, configuration: CatalogConfiguration): number {
  const additions = new Map(candidate.requirements.map((requirement) => [requirement.ingredientId, requirement.requiredQty]));
  let maxDemand = 0;
  let squareDemand = 0;
  for (const ingredient of configuration.ingredients) {
    const projected = (demandCounts.get(ingredient.id) ?? 0) + (additions.get(ingredient.id) ?? 0);
    maxDemand = Math.max(maxDemand, projected);
    squareDemand += projected * projected;
  }
  return maxDemand * 100000 + squareDemand;
}

function applyDemandCounts(candidate: RequirementCandidate, demandCounts: Map<string, number> | undefined): void {
  if (!demandCounts) {
    return;
  }
  for (const requirement of candidate.requirements) {
    demandCounts.set(requirement.ingredientId, (demandCounts.get(requirement.ingredientId) ?? 0) + requirement.requiredQty);
  }
}

function ingredientCombinationsForDistinctCount(
  configuration: CatalogConfiguration,
  ownerIngredientId: string,
  distinctCount: number,
  preferredIngredientIds: string[],
  recipeId: string
): string[][] {
  const activeIngredientIds = configuration.ingredients.map((ingredient) => ingredient.id);
  const activeOrder = new Map(activeIngredientIds.map((ingredientId, index) => [ingredientId, index]));
  const otherIngredientIds = activeIngredientIds.filter((ingredientId) => ingredientId !== ownerIngredientId);
  const preferred = new Map(preferredIngredientIds.map((ingredientId, index) => [ingredientId, index]));
  const combinationsForCount: string[][] = [];
  const seen = new Set<string>();
  const attempts = Math.max(16, configuration.ingredients.length * 2);

  for (let attempt = -1; attempt < attempts; attempt += 1) {
    const ordered = [...otherIngredientIds].sort((left, right) => {
      const leftPreferred = preferred.has(left) ? 100000 - (preferred.get(left) ?? 0) : 0;
      const rightPreferred = preferred.has(right) ? 100000 - (preferred.get(right) ?? 0) : 0;
      const preferredDifference = attempt < 8 ? rightPreferred - leftPreferred : 0;
      if (preferredDifference !== 0) {
        return preferredDifference;
      }
      return hashString(`${recipeId}:combo:${attempt}:${left}`) - hashString(`${recipeId}:combo:${attempt}:${right}`);
    });
    const selected = [ownerIngredientId, ...ordered.slice(0, distinctCount - 1)].sort(
      (left, right) => (activeOrder.get(left) ?? 0) - (activeOrder.get(right) ?? 0)
    );
    const signature = selected.join("|");
    if (!seen.has(signature)) {
      seen.add(signature);
      combinationsForCount.push(selected);
    }
  }

  return combinationsForCount;
}

function quantityMapsForIngredientIds(
  ingredientIds: string[],
  ownerIngredientId: string,
  preferredIngredientIds: string[],
  recipeId: string
): Array<Map<string, number>> {
  if (ingredientIds.length === 6) {
    return [new Map(ingredientIds.map((ingredientId) => [ingredientId, 1]))];
  }
  if (ingredientIds.length === 3) {
    return [new Map(ingredientIds.map((ingredientId) => [ingredientId, 2]))];
  }

  const priority = new Map(preferredIngredientIds.map((ingredientId, index) => [ingredientId, index]));
  return combinations(ingredientIds, 2)
    .sort((left, right) => doublePairScore(right, ownerIngredientId, priority, recipeId) - doublePairScore(left, ownerIngredientId, priority, recipeId))
    .map((doubleIds) => {
      const doubled = new Set(doubleIds);
      return new Map(ingredientIds.map((ingredientId) => [ingredientId, doubled.has(ingredientId) ? 2 : 1]));
    });
}

function doublePairScore(
  ingredientIds: string[],
  ownerIngredientId: string,
  priority: Map<string, number>,
  recipeId: string
): number {
  const ownerScore = ingredientIds.includes(ownerIngredientId) ? 10000 : 0;
  const preferredScore = ingredientIds.reduce((sum, ingredientId) => sum + 1000 - (priority.get(ingredientId) ?? 1000), 0);
  return ownerScore + preferredScore - hashString(`${recipeId}:double:${ingredientIds.join(",")}`);
}

function combinations(values: string[], count: number): string[][] {
  if (count === 0) {
    return [[]];
  }
  if (count > values.length) {
    return [];
  }
  const result: string[][] = [];
  for (let index = 0; index <= values.length - count; index += 1) {
    const head = values[index] as string;
    for (const tail of combinations(values.slice(index + 1), count - 1)) {
      result.push([head, ...tail]);
    }
  }
  return result;
}

function requirementSignature(requirements: CatalogRequirement[]): string {
  return requirements
    .map((requirement) => `${requirement.ingredientId}:${requirement.requiredQty}`)
    .sort()
    .join("|");
}

function distinctCountForActivePreferred(activePreferredCount: number): number {
  if (activePreferredCount >= 6) {
    return 6;
  }
  if (activePreferredCount >= 4) {
    return 4;
  }
  return 3;
}

function quantityShapeForDistinctCount(distinctCount: number): RecipeQuantityShape {
  if (distinctCount === 6) {
    return "six_singles";
  }
  if (distinctCount === 4) {
    return "two_pairs_two_singles";
  }
  return "three_pairs";
}

function deterministicOrder(values: string[], seed: string): string[] {
  return [...values].sort((left, right) => hashString(`${seed}:${left}`) - hashString(`${seed}:${right}`));
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
      const servingUnit = servingUnitForTemplate(template);
      return {
        templateId: templateIdFor(ingredient.id, slot),
        ingredientId: ingredient.id,
        ingredientName: ingredient.name,
        slot,
        dishName: template.name,
        dishFamily: template.family,
        partUnitSingular: servingUnit.singular,
        partUnitPlural: servingUnit.plural,
        realIngredientIds: playableTemplateIngredientIds(template.ingredientIds)
      };
    })
  );
}

function servingUnitForTemplate(template: DishTemplate): ServingUnit {
  const name = template.name.toLowerCase();
  const family = template.family.toLowerCase();
  if (
    name.includes("soup") ||
    name.includes("stew") ||
    name.includes("curry") ||
    name.includes("dal") ||
    name.includes("chili") ||
    name.includes("porridge") ||
    name.includes("chowder") ||
    name.includes("pottage") ||
    name.includes("tagine")
  ) {
    return { singular: "cup", plural: "cups" };
  }
  if (name.includes("rice") || name.includes("biryani") || name.includes("pilaf") || family.includes("rice")) {
    return { singular: "scoop", plural: "scoops" };
  }
  if (name.includes("arepa") || name.includes("bhaji") || name.includes("mofongo") || name.includes("plantain")) {
    return { singular: "piece", plural: "pieces" };
  }
  if (name.includes("plate") || name.includes("bowl")) {
    return { singular: "portion", plural: "portions" };
  }
  return { singular: "serving", plural: "servings" };
}

function templateIdFor(ownerIngredientId: string, slot: RecipeSlot): string {
  return `${ownerIngredientId}_${slot}`;
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

function playableTemplateIngredientIds(ingredientIds: string[]): string[] {
  const unique = uniqueIngredientIds(ingredientIds);
  const capped = unique.slice(0, MAX_TEMPLATE_INGREDIENTS);
  const playable = capped.length === 5 ? capped.slice(0, 4) : capped;
  if (playable.length < MIN_TEMPLATE_INGREDIENTS) {
    throw new Error(`Recipe templates must define at least ${MIN_TEMPLATE_INGREDIENTS} playable ingredients.`);
  }
  return playable;
}
