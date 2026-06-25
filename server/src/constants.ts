import type { Ingredient } from "./types.js";

export const MIN_ACTIVE_PARTICIPANTS = 8;
export const MAX_ACTIVE_PARTICIPANTS = 8;
export const MIN_CATALOG_PLAYER_COUNT = 8;
export const MAX_CATALOG_PLAYER_COUNT = 8;
export const VOUCHERS_PER_INGREDIENT = 8;
export const OPENING_OFFERINGS_PER_PLAYER = 2;
export const REAL_UNITS_PER_INGREDIENT = 40;
export const MIN_STOCK_PER_INGREDIENT = 1;
export const MAX_STOCK_PER_INGREDIENT = 999;
export const DISH_PARTS_PER_DISH = 10;
export const MIN_TARGET_DISH_COUNT = 1;
export const MAX_TARGET_DISH_COUNT = 3;
export const DEFAULT_TARGET_DISH_COUNT = 3;

export const INGREDIENTS: Ingredient[] = [
  {
    id: "cheese",
    name: "Cheese",
    description: "Melts, toppings, fillings, casseroles",
    imagePath: "art/ingredients/cheese_64.png"
  },
  {
    id: "flour",
    name: "Flour",
    description: "Bread, tortillas, pancakes, dumplings, thickening",
    imagePath: "art/ingredients/flour_open_sack_64.png"
  },
  {
    id: "herbs",
    name: "Herbs",
    description: "Basil, parsley, cilantro, oregano, thyme",
    imagePath: "art/ingredients/herbs_64.png"
  },
  {
    id: "vegetables",
    name: "Vegetables",
    description: "Onions, peppers, carrots, tomatoes, spinach, etc.",
    imagePath: "art/ingredients/vegetables_64.png"
  },
  {
    id: "rice",
    name: "Rice",
    description: "Bowls, fried rice, casseroles, sides",
    imagePath: "art/ingredients/rice_64.png"
  },
  {
    id: "beans",
    name: "Beans",
    description: "Chili, tacos, stews, bowls, dips",
    imagePath: "art/ingredients/beans_64.png"
  },
  {
    id: "spices",
    name: "Spices",
    description: "Salt, pepper, cumin, paprika, chili powder, curry powder",
    imagePath: "art/ingredients/spices_64.png"
  },
  {
    id: "eggs",
    name: "Eggs",
    description: "Breakfasts, fried rice, baking, binders, toppings",
    imagePath: "art/ingredients/eggs_64.png"
  }
];

export const BOT_TYPES = ["pool_only", "barter_only", "mixed"] as const;
