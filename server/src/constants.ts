import type { Ingredient } from "./types.js";

export const MIN_ACTIVE_PARTICIPANTS = 7;
export const MAX_ACTIVE_PARTICIPANTS = 20;
export const VOUCHERS_PER_INGREDIENT = 7;
export const REAL_UNITS_PER_INGREDIENT = 30;
export const MIN_STOCK_PER_INGREDIENT = 1;
export const MAX_STOCK_PER_INGREDIENT = 999;
export const DISH_PARTS_PER_DISH = 10;
export const MIN_TARGET_DISH_COUNT = 1;
export const MAX_TARGET_DISH_COUNT = 4;
export const DEFAULT_TARGET_DISH_COUNT = 4;

export const INGREDIENTS: Ingredient[] = [
  { id: "rice", name: "Rice" },
  { id: "beans", name: "Beans" },
  { id: "maize", name: "Maize" },
  { id: "tomato", name: "Tomato" },
  { id: "onion", name: "Onion" },
  { id: "garlic", name: "Garlic" },
  { id: "ginger", name: "Ginger" },
  { id: "pepper", name: "Pepper" },
  { id: "potato", name: "Potato" },
  { id: "carrot", name: "Carrot" },
  { id: "cabbage", name: "Cabbage" },
  { id: "lentils", name: "Lentils" },
  { id: "chickpeas", name: "Chickpeas" },
  { id: "coconut", name: "Coconut" },
  { id: "plantain", name: "Plantain" },
  { id: "cassava", name: "Cassava" },
  { id: "spinach", name: "Spinach" },
  { id: "lemon", name: "Lemon" },
  { id: "salt", name: "Salt" },
  { id: "herbs", name: "Herbs" }
];

export const BOT_TYPES = ["pool_only", "barter_only", "mixed"] as const;
