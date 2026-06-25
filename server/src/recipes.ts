import { INGREDIENTS } from "./constants.js";
import { catalogRecipeForIngredients, RECIPE_SLOTS, type RecipeSlot } from "./recipeCatalog.js";
import type { Ingredient, Recipe, RecipeRequirement, Table } from "./types.js";

function activeIngredients(table: Table): Ingredient[] {
  return table.participantOrder
    .map((participantId) => table.participants[participantId])
    .filter((participant) => participant?.role === "active" && participant.ingredientId)
    .map((participant) => requireIngredient(participant.ingredientId as string));
}

export function generateRecipe(table: Table, ownerParticipantId: string): Recipe {
  const participant = table.participants[ownerParticipantId];
  if (!participant?.ingredientId) {
    throw new Error("Cannot generate recipe before ingredient assignment.");
  }

  const recipeNumber = participant.dishCount + 1;
  const recipeId = `recipe_${ownerParticipantId}_${recipeNumber}_${table.turn}`;
  const ingredients = activeIngredients(table);
  const slot = slotForRecipeNumber(table, ownerParticipantId, recipeNumber);
  const catalogRecipe = catalogRecipeForIngredients(ingredients, participant.ingredientId, slot);
  const requirements: RecipeRequirement[] = catalogRecipe.requirements.map((requirement, index) => ({
    id: `${recipeId}:req:${index + 1}`,
    ingredientId: requirement.ingredientId,
    requiredQty: requirement.requiredQty,
    redeemedQty: 0,
    placedVoucherIds: []
  }));
  const requirementIngredientIds = new Set(requirements.map((requirement) => requirement.ingredientId));

  return {
    id: recipeId,
    ownerParticipantId,
    name: catalogRecipe.dishName,
    templateId: catalogRecipe.templateId,
    dishFamily: catalogRecipe.dishFamily,
    unitSingular: catalogRecipe.partUnitSingular,
    unitPlural: catalogRecipe.partUnitPlural,
    realIngredientIds: [...catalogRecipe.realIngredientIds],
    matchedRealIngredientIds: [...catalogRecipe.matchedRealIngredientIds],
    fallbackIngredientIds: [...catalogRecipe.fallbackIngredientIds],
    requirements,
    omittedIngredientId:
      ingredients.find((ingredient) => !requirementIngredientIds.has(ingredient.id))?.id ?? ingredients[0]?.id ?? ""
  };
}

function slotForRecipeNumber(table: Table, ownerParticipantId: string, recipeNumber: number): RecipeSlot {
  const participant = table.participants[ownerParticipantId];
  const seed = `${table.seed}:recipe-order:${ownerParticipantId}:${participant?.ingredientId ?? ""}`;
  const slots = deterministicShuffle(RECIPE_SLOTS, seed);
  return slots[(recipeNumber - 1) % slots.length] as RecipeSlot;
}

function requireIngredient(ingredientId: string): Ingredient {
  const ingredient = INGREDIENTS.find((candidate) => candidate.id === ingredientId);
  if (!ingredient) {
    throw new Error(`Unknown ingredient ${ingredientId}.`);
  }
  return ingredient;
}

function deterministicShuffle<T extends string>(items: readonly T[], seed: string): T[] {
  return [...items].sort((left, right) => {
    const rank = hashString(`${seed}:${left}`) - hashString(`${seed}:${right}`);
    return rank === 0 ? left.localeCompare(right) : rank;
  });
}

function hashString(value: string): number {
  let hash = 2166136261;
  for (let index = 0; index < value.length; index += 1) {
    hash ^= value.charCodeAt(index);
    hash = Math.imul(hash, 16777619);
  }
  return hash >>> 0;
}
