export type ParticipantRole = "active" | "witness";
export type ParticipantKind = "human" | "bot";
export type BotType = "pool_only" | "barter_only" | "mixed";
export type TablePhase = "lobby" | "deposit" | "playing" | "settlement" | "eating" | "complete";
export type TurnMode = "round_robin";
export type VoucherLocationType = "hand" | "platter" | "placed" | "holding" | "offer_lock";
export type DishPartLocationType = "inventory" | "platter" | "eaten" | "offer_lock";
export type OfferStatus = "pending" | "accepted" | "refused" | "cancelled";
export type PlatterAssetKind = "voucher" | "dish_part";
export type AggregateAssetKind = "voucher" | "dish_part";

export interface Ingredient {
  id: string;
  name: string;
  description?: string;
  imagePath?: string;
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
  unitSingular: string;
  unitPlural: string;
  realIngredientIds: string[];
  matchedRealIngredientIds: string[];
  fallbackIngredientIds: string[];
  requirements: RecipeRequirement[];
  omittedIngredientId: string;
}

export interface PublicRecipeRequirementSummary {
  ingredientId: string;
  missingQty: number;
}

export interface PublicRecipeSummary {
  name: string;
  missingRequirements: PublicRecipeRequirementSummary[];
}

export interface Participant {
  id: string;
  name: string;
  kind: ParticipantKind;
  role: ParticipantRole;
  isHost: boolean;
  seatToken: string;
  controllerParticipantId?: string;
  botType?: BotType;
  ingredientId?: string;
  realIngredientStock?: number;
  dishCount: number;
  depositedInitial: boolean;
  openingOfferingsCount: number;
  connected: boolean;
}

export interface OfferRequest {
  ingredientId: string;
  quantity: number;
}

export type OfferAssetRequest =
  | { kind: "voucher"; ingredientId: string; ownerParticipantId?: string; quantity: number }
  | { kind: "dish_part"; dishId?: string; makerParticipantId?: string; quantity: number };

export interface Offer {
  id: string;
  fromParticipantId: string;
  toParticipantId: string;
  offeredAssets: PlatterAssetRef[];
  offeredVoucherIds: string[];
  requestedAsset?: OfferAssetRequest;
  requested?: OfferRequest;
  acceptedAssets: PlatterAssetRef[];
  acceptedVoucherIds: string[];
  status: OfferStatus;
  createdTurn: number;
}

export interface OfferSnapshot extends Offer {
  offeredVouchers: Voucher[];
  offeredDishParts: DishPart[];
  acceptedVouchers: Voucher[];
  acceptedDishParts: DishPart[];
}

export interface Dish {
  id: string;
  ownerParticipantId: string;
  name: string;
  unitSingular: string;
  unitPlural: string;
  totalParts: number;
  partsRemaining: number;
  partsEaten: number;
  totalBites: number;
  bitesRemaining: number;
  biteCounts: Record<string, number>;
}

export interface DishPartLocation {
  type: DishPartLocationType;
  participantId?: string;
  offerId?: string;
}

export interface DishPart {
  id: string;
  dishId: string;
  dishName: string;
  makerParticipantId: string;
  unitSingular: string;
  unitPlural: string;
  location: DishPartLocation;
}

export interface FoodPartLocationSummary {
  dishId: string;
  dishName: string;
  unitSingular: string;
  unitPlural: string;
  location: DishPartLocation;
  count: number;
}

export interface VoucherGroup {
  ingredientId: string;
  ownerParticipantId: string;
  count: number;
}

export interface VoucherLocationSummary extends VoucherGroup {
  location: VoucherLocation;
}

export interface DishPartGroup {
  dishId: string;
  dishName: string;
  makerParticipantId: string;
  unitSingular: string;
  unitPlural: string;
  count: number;
}

export type TransactionAction = "Deposit" | "Swap" | "Settlement Swap" | "Exchange" | "Redeem" | "Prepare" | "Share" | "Eat" | "Pass Turn";

export interface TransactionMetadata {
  redemptionSource?: "voucher" | "own_stock";
  ingredientId?: string;
  requirementId?: string;
  ownerParticipantId?: string;
}

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
  metadata?: TransactionMetadata;
}

export interface GameStats {
  activePlayerCount: number;
  mutationCount: number;
  playerTurnCount: number;
  cycleCount: number;
  interactionCount: number;
  openingOfferingCount: number;
  commonBasketSwapCount: number;
  directExchangeCount: number;
  redemptionCount: number;
  prepareCount: number;
  settlementSwapCount: number;
  foodPieceSettlementSwapCount: number;
  eatCount: number;
  assetLossCount: number;
  productivityCount: number;
  profitCount: number;
  profitGainPercent: number;
  averageTurnsPerDish: number;
  averageInteractionsPerDish: number;
  basketVelocity: number;
  directExchangeShare: number;
  settlementBurden: number;
  scarcityPressureByIngredient: Record<string, number>;
  hoardingIndex: number;
  hoardingIndexLabel: string;
  liquidityDepth: number;
  settlementTimeTurns: number;
  consumptionVariance: number;
  tradeBalanceByParticipant: Record<string, TradeBalanceStats>;
}

export type TradeBalanceStats = [given: number, received: number, net: number];

export interface TableTimer {
 seconds: number;
 startedAtTurn?: number;
 startedAtMs?: number;
 endsAtMs?: number;
 expiredAtMs?: number;
 pausedRemainingMs?: number;
}

export type IdlePromptPhase = "lobby" | "running";
export type TableClosureReason = "host_stopped" | "idle_declined" | "idle_timeout";

export interface IdlePrompt {
  id: string;
  message: string;
  phase: IdlePromptPhase;
  startedAtMs: number;
  expiresAtMs: number;
}

export interface TableClosure {
  reason: TableClosureReason;
  message: string;
  createdAtMs: number;
  returnToMenuAtMs: number;
}

export interface TableIdleState {
  lastActivityAtMs: number;
  prompt?: IdlePrompt;
  closure?: TableClosure;
}

export type AutomationDiagnosticStatus =
  | "error"
  | "fallback_pass"
  | "fallback_failed"
  | "budget_pass"
  | "pass_missing_ingredients";

export interface AutomationDiagnostic {
  atMs: number;
  tableCode: string;
  phase: TablePhase;
  turn: number;
  version: number;
  botParticipantId: string;
  botName: string;
  botType?: BotType;
  status: AutomationDiagnosticStatus;
  reason?: string;
  intentType?: string;
  missingIngredientIds?: string[];
  platterAvailableIngredientIds?: string[];
  offerTargetParticipantId?: string;
  offerTargetName?: string;
  targetOfferableQty?: number;
  noOfferReason?: string;
  errorCode?: string;
  message?: string;
}

export interface Table {
  code: string;
  seed: string;
  isPublic: boolean;
  version: number;
  phase: TablePhase;
  paused: boolean;
  hostParticipantId: string;
  participants: Record<string, Participant>;
  participantOrder: string[];
  vouchers: Record<string, Voucher>;
  recipes: Record<string, Recipe>;
  offers: Record<string, Offer>;
  dishes: Record<string, Dish>;
  dishParts: Record<string, DishPart>;
  transactionHistory: TransactionRecord[];
  scarcityPressureByIngredient: Record<string, number>;
  winnerParticipantIds: string[];
  targetDishCount: number;
  stockPerIngredient: number;
  turnMode: TurnMode;
  currentTurnParticipantId?: string;
  timer?: TableTimer;
  idle: TableIdleState;
  automationDiagnostics: AutomationDiagnostic[];
  turn: number;
  nextId: number;
}

export interface PublicParticipant {
  id: string;
  name: string;
  kind: ParticipantKind;
  role: ParticipantRole;
  isHost: boolean;
  controllerParticipantId?: string;
  botType?: BotType;
  ingredientId?: string;
  realIngredientStock?: number;
  offerableOwnIngredientQty: number;
  ownCardsInPlatter: number;
  ownCardsInHand: number;
  foreignCardsInHand: number;
  ownCardsInOtherHands: number;
  expectedOwnCardsInHand: number;
  platterDebt: number;
  platterShortfall: number;
  cleared: boolean;
  dishCount: number;
  heldFoodPartCount: number;
  heldVoucherGroups: VoucherGroup[];
  heldFoodPartGroups: DishPartGroup[];
  depositedInitial: boolean;
  openingOfferingsCount: number;
  connected: boolean;
  currentRecipe?: PublicRecipeSummary;
}

export interface Snapshot {
  tableCode: string;
  seed: string;
  isPublic: boolean;
  version: number;
  phase: TablePhase;
  paused: boolean;
  viewerParticipantId?: string;
  connectionParticipantId?: string;
  viewerRole?: ParticipantRole;
  controlledParticipantIds: string[];
  viewerCanUseHostControls: boolean;
  hostParticipantId: string;
  turn: number;
  turnMode: TurnMode;
  currentTurnParticipantId?: string;
  participants: PublicParticipant[];
  ingredients: Ingredient[];
  platter: Voucher[];
  platterFoodParts: DishPart[];
  ownHandGroups: VoucherGroup[];
  platterVoucherGroups: VoucherGroup[];
  ownFoodPartGroups: DishPartGroup[];
  platterFoodPartGroups: DishPartGroup[];
  dishes: Dish[];
  dishParts: DishPart[];
  foodPartLocationSummary?: FoodPartLocationSummary[];
  transactionHistory: TransactionRecord[];
  transactionCursor: number;
  transactionHistoryComplete?: boolean;
  transactionHistoryTotal?: number;
  gameStats: GameStats;
  dishCounts: Record<string, number>;
  winners: string[];
  targetDishCount: number;
  stockPerIngredient: number;
  timer?: TableTimer;
  idlePrompt?: IdlePrompt;
  tableClosure?: TableClosure;
  ownHand: Voucher[];
  ownFoodParts: DishPart[];
  ownRecipe?: Recipe;
  offers: OfferSnapshot[];
  allHands?: Record<string, Voucher[]>;
  allFoodParts?: DishPart[];
  allRecipes?: Record<string, Recipe>;
  voucherLocationSummary?: VoucherLocationSummary[];
  allVouchers?: Voucher[];
}

export interface PlatterAssetRef {
  kind: PlatterAssetKind;
  id: string;
}

export type AggregatePlatterAssetRef =
  | { kind: "voucher"; ingredientId: string; ownerParticipantId?: string }
  | { kind: "dish_part"; dishId: string; makerParticipantId?: string };

export interface SnapshotDelta {
  type: "delta";
  tableCode: string;
  viewerParticipantId?: string;
  baseVersion: number;
  version: number;
  patch: Partial<Snapshot> & Record<string, unknown>;
  append: {
    transactionHistory?: TransactionRecord[];
    dishes?: Dish[];
    participants?: PublicParticipant[];
  };
}

export type Intent =
  | { type: "leave_table" }
  | { type: "close_table" }
  | { type: "reset_table" }
  | { type: "idle_response"; promptId: string; response: "yes" | "no" }
  | { type: "set_table_visibility"; isPublic: boolean }
  | { type: "set_role"; participantId: string; role: ParticipantRole }
  | { type: "rename_participant"; participantId: string; name: string }
  | { type: "add_bot"; name?: string; botType: BotType }
  | { type: "add_controlled_seat"; name?: string; participantId?: string }
  | { type: "convert_to_bot"; participantId: string; botType?: BotType }
  | { type: "set_timer"; seconds: number | null }
  | { type: "set_target_dish_count"; count: number }
  | { type: "set_stock"; count: number }
  | { type: "set_pause"; paused: boolean }
  | { type: "start" }
  | { type: "stop" }
  | { type: "pass_turn" }
  | { type: "redeem_all_and_pass_turn" }
  | { type: "deposit"; voucherId: string }
  | { type: "deposit_ingredient"; ingredientId?: string }
  | { type: "platter_swap"; giveVoucherId: string; takeVoucherId: string }
  | { type: "platter_swap_ingredient"; giveIngredientId: string; takeIngredientId: string; quantity?: number }
  | { type: "platter_asset_swap"; give: PlatterAssetRef; take: PlatterAssetRef }
  | { type: "platter_asset_swap_aggregate"; give: AggregatePlatterAssetRef; take: AggregatePlatterAssetRef; quantity?: number }
  | {
      type: "create_offer";
      toParticipantId: string;
      offeredVoucherIds?: string[];
      offeredAssets?: PlatterAssetRef[];
      requested?: OfferRequest;
      requestedAsset?: OfferAssetRequest;
    }
  | { type: "respond_offer"; offerId: string; response: "accept" | "refuse"; voucherIds?: string[]; assets?: PlatterAssetRef[] }
  | { type: "cancel_offer"; offerId: string }
  | { type: "place_voucher"; voucherId: string; requirementId: string }
  | { type: "redeem_voucher"; voucherId: string }
  | { type: "redeem_from_hand"; voucherId: string; requirementId: string }
  | { type: "prepare" }
  | { type: "bite"; dishId: string }
  | { type: "bite_all" };

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

export interface PublicTableSummary {
  code: string;
  hostName: string;
  activeSeats: number;
  humanSeats: number;
  openSeats: number;
}
