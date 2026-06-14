export type ParticipantRole = "active" | "witness";
export type ParticipantKind = "human" | "bot";
export type BotType = "pool_only" | "barter_only" | "mixed";
export type TablePhase = "lobby" | "deposit" | "playing" | "winner_bite" | "eating" | "complete";
export type VoucherLocationType = "hand" | "platter" | "placed" | "holding" | "offer_lock";
export type OfferStatus = "pending" | "accepted" | "refused" | "cancelled";

export interface Ingredient {
  id: string;
  name: string;
}

export interface VoucherLocation {
  type: VoucherLocationType;
  participantId?: string;
  recipeOwnerId?: string;
  requirementId?: string;
  offerId?: string;
}

export interface Voucher {
  id: string;
  ingredientId: string;
  ownerParticipantId: string;
  location: VoucherLocation;
}

export interface RecipeRequirement {
  id: string;
  ingredientId: string;
  requiredQty: number;
  redeemedQty: number;
  placedVoucherIds: string[];
}

export interface Recipe {
  id: string;
  ownerParticipantId: string;
  name: string;
  templateId: string;
  dishFamily: string;
  realIngredientIds: string[];
  matchedRealIngredientIds: string[];
  fallbackIngredientIds: string[];
  requirements: RecipeRequirement[];
  omittedIngredientId: string;
}

export interface Participant {
  id: string;
  name: string;
  kind: ParticipantKind;
  role: ParticipantRole;
  isHost: boolean;
  seatToken: string;
  botType?: BotType;
  ingredientId?: string;
  realIngredientStock?: number;
  dishCount: number;
  depositedInitial: boolean;
  connected: boolean;
}

export interface OfferRequest {
  ingredientId: string;
  quantity: number;
}

export interface Offer {
  id: string;
  fromParticipantId: string;
  toParticipantId: string;
  offeredVoucherIds: string[];
  requested: OfferRequest;
  acceptedVoucherIds: string[];
  status: OfferStatus;
  createdTurn: number;
}

export interface OfferSnapshot extends Offer {
  offeredVouchers: Voucher[];
}

export interface Dish {
  id: string;
  ownerParticipantId: string;
  name: string;
  totalBites: number;
  bitesRemaining: number;
  biteCounts: Record<string, number>;
}

export type TransactionAction = "Deposit" | "Swap" | "Exchange" | "Redeem";

export interface TransactionRecord {
  id: string;
  turn: number;
  participantId: string;
  name: string;
  action: TransactionAction;
  counterpartyParticipantId?: string;
  counterparty: string;
  itemOut: string;
  itemBack: string;
}

export interface TableTimer {
  seconds: number;
  startedAtTurn?: number;
  startedAtMs?: number;
  endsAtMs?: number;
  expiredAtMs?: number;
  pausedRemainingMs?: number;
}

export interface Table {
  code: string;
  seed: string;
  phase: TablePhase;
  paused: boolean;
  hostParticipantId: string;
  participants: Record<string, Participant>;
  participantOrder: string[];
  vouchers: Record<string, Voucher>;
  recipes: Record<string, Recipe>;
  offers: Record<string, Offer>;
  dishes: Record<string, Dish>;
  transactionHistory: TransactionRecord[];
  winnerParticipantIds: string[];
  targetDishCount: number;
  stockPerIngredient: number;
  timer?: TableTimer;
  turn: number;
  nextId: number;
}

export interface PublicParticipant {
  id: string;
  name: string;
  kind: ParticipantKind;
  role: ParticipantRole;
  isHost: boolean;
  botType?: BotType;
  ingredientId?: string;
  realIngredientStock?: number;
  offerableOwnIngredientQty: number;
  dishCount: number;
  depositedInitial: boolean;
  connected: boolean;
}

export interface Snapshot {
  tableCode: string;
  seed: string;
  phase: TablePhase;
  paused: boolean;
  viewerParticipantId?: string;
  viewerRole?: ParticipantRole;
  hostParticipantId: string;
  turn: number;
  participants: PublicParticipant[];
  ingredients: Ingredient[];
  platter: Voucher[];
  dishes: Dish[];
  transactionHistory: TransactionRecord[];
  dishCounts: Record<string, number>;
  winners: string[];
  targetDishCount: number;
  stockPerIngredient: number;
  timer?: TableTimer;
  ownHand: Voucher[];
  ownRecipe?: Recipe;
  offers: OfferSnapshot[];
  allHands?: Record<string, Voucher[]>;
  allRecipes?: Record<string, Recipe>;
  allVouchers?: Voucher[];
}

export type Intent =
  | { type: "leave_table" }
  | { type: "close_table" }
  | { type: "reset_table" }
  | { type: "set_role"; participantId: string; role: ParticipantRole }
  | { type: "add_bot"; name?: string; botType: BotType }
  | { type: "convert_to_bot"; participantId: string; botType?: BotType }
  | { type: "set_timer"; seconds: number | null }
  | { type: "set_target_dish_count"; count: number }
  | { type: "set_stock"; count: number }
  | { type: "set_pause"; paused: boolean }
  | { type: "start" }
  | { type: "stop" }
  | { type: "deposit"; voucherId: string }
  | { type: "platter_swap"; giveVoucherId: string; takeVoucherId: string }
  | { type: "create_offer"; toParticipantId: string; offeredVoucherIds: string[]; requested: OfferRequest }
  | { type: "respond_offer"; offerId: string; response: "accept" | "refuse"; voucherIds?: string[] }
  | { type: "cancel_offer"; offerId: string }
  | { type: "place_voucher"; voucherId: string; requirementId: string }
  | { type: "redeem_voucher"; voucherId: string }
  | { type: "redeem_from_hand"; voucherId: string; requirementId: string }
  | { type: "prepare" }
  | { type: "bite"; dishId: string };

export interface CreateTableResult {
  table: Table;
  participant: Participant;
  seatToken: string;
  snapshot: Snapshot;
}

export interface JoinTableResult {
  table: Table;
  participant: Participant;
  seatToken: string;
  snapshot: Snapshot;
}
