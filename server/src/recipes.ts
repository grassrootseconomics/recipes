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
  const slot = slotForRecipeNumber(recipeNumber);
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

function slotForRecipeNumber(recipeNumber: number): RecipeSlot {
  return RECIPE_SLOTS[(recipeNumber - 1) % RECIPE_SLOTS.length] as RecipeSlot;
}

function requireIngredient(ingredientId: string): Ingredient {
  const ingredient = INGREDIENTS.find((candidate) => candidate.id === ingredientId);
  if (!ingredient) {
    throw new Error(`Unknown ingredient ${ingredientId}.`);
  }
  return ingredient;
}
