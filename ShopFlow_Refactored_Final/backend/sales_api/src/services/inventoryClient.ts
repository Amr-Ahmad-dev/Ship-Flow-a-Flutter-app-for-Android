// =============================================================
// FILE: src/services/inventoryClient.ts  —  SYSTEM 2: Sales API
// PURPOSE: The ONLY way System 2 communicates with System 1.
//
// ╔═══════════════════════════════════════════════════════════╗
// ║  ARCHITECTURAL BOUNDARY:                                 ║
// ║  This file is the controlled interface between           ║
// ║  System 2 (Sales API) and System 1 (Inventory System).  ║
// ║                                                          ║
// ║  System 2 has NO Firebase SDK.                          ║
// ║  System 2 has NO Firestore credentials.                 ║
// ║  System 2 can ONLY call System 1 through this file.     ║
// ╚═══════════════════════════════════════════════════════════╝
//
// Firebase Cloud Functions (System 1) expose HTTPS callable
// endpoints at: {BASE_URL}/{functionName}
//
// Callable functions expect POST with body:
//   { "data": { ...your payload... } }
// And return:
//   { "result": { ok: true, data: {...} } }
//   or throw an error with { "error": { message, status } }
// =============================================================

import axios, { AxiosError } from "axios";

// Base URL from environment — points to deployed Cloud Functions
const BASE_URL = process.env.INVENTORY_BASE_URL;

if (!BASE_URL) {
  console.error("FATAL: INVENTORY_BASE_URL environment variable is not set.");
  console.error("Set it in .env to point to your Firebase Functions URL.");
  process.exit(1);
}

// =============================================================
// callInventoryFunction
// Core HTTP caller — wraps all Firebase Callable Function calls
// =============================================================
async function callInventoryFunction<T>(
  functionName: string,
  payload: Record<string, unknown>
): Promise<T> {
  const url = `${BASE_URL}/${functionName}`;

  try {
    // Firebase Callable Functions always use POST
    // and expect the data wrapped in a "data" key
    const response = await axios.post<{ result: { ok: boolean; data: T } }>(
      url,
      { data: payload },
      {
        headers: { "Content-Type": "application/json" },
        timeout: 30_000, // 30 second timeout
      }
    );

    const result = response.data.result;
    if (!result.ok) {
      throw new Error(`Inventory System returned ok:false for ${functionName}`);
    }
    return result.data;
  } catch (err: unknown) {
    if (err instanceof AxiosError) {
      // Firebase Functions errors come in error.response.data.error
      const fbError = err.response?.data?.error;
      if (fbError) {
        const message = fbError.message ?? "Inventory system error";
        const status = fbError.status ?? "INTERNAL";
        throw new InventoryError(message, status);
      }
      throw new InventoryError(
        `Network error calling ${functionName}: ${err.message}`,
        "UNAVAILABLE"
      );
    }
    throw err;
  }
}

// Custom error class so routes can identify inventory errors
export class InventoryError extends Error {
  public readonly status: string;
  constructor(message: string, status: string) {
    super(message);
    this.name = "InventoryError";
    this.status = status;
  }
}

// =============================================================
// Typed API surface — one function per System 1 callable
// These are the ONLY operations System 2 can perform.
// =============================================================

// ── Auth ─────────────────────────────────────────────────────

export interface UserData {
  userId: string;
  email: string;
  displayName: string;
  role: string;
  emailVerified: boolean;
  verificationCode?: string; // Only in dev mode
}

export const inventoryApi = {
  // Auth
  registerUser: (data: {
    email: string;
    password: string;
    displayName: string;
    role: string;
  }) => callInventoryFunction<UserData>("registerUser", data),

  verifyEmail: (data: { userId: string; code: string }) =>
    callInventoryFunction<{ message: string }>("verifyEmail", data),

  getUserById: (userId: string) =>
    callInventoryFunction<UserData>("getUserById", { userId }),

  resendCode: (userId: string) =>
    callInventoryFunction<{ message: string; verificationCode?: string }>(
      "resendVerificationCode",
      { userId }
    ),

  // Products
  getProducts: (data: { tagId?: string; limit?: number }) =>
    callInventoryFunction<{ products: ProductData[] }>("getProducts", data),

  getProductById: (productId: string) =>
    callInventoryFunction<{ product: ProductData }>("getProductById", { productId }),

  addProduct: (data: {
    name: string;
    price: number;
    quantity: number;
    tags: string[];
    sellerId: string;
  }) => callInventoryFunction<ProductData>("addProduct", data),

  addStock: (data: { productId: string; quantityToAdd: number; sellerId: string }) =>
    callInventoryFunction<{ productId: string; newQuantity: number }>("addStock", data),

  getSellerInventory: (sellerId: string) =>
    callInventoryFunction<{ products: ProductData[] }>("getSellerInventory", { sellerId }),

  assignTagToProduct: (data: { productId: string; tagId: string; sellerId: string }) =>
    callInventoryFunction<{ message: string }>("assignTagToProduct", data),

  // Orders
  createOrder: (data: {
    buyerId: string;
    items: Array<{ productId: string; quantity: number }>;
  }) =>
    callInventoryFunction<{ orderId: string; totalAmount: number; status: string }>(
      "createOrder",
      data
    ),

  getOrderHistory: (buyerId: string) =>
    callInventoryFunction<{ orders: OrderData[] }>("getOrderHistory", { buyerId }),

  // Tags
  createTag: (data: { name: string; parentTagId?: string }) =>
    callInventoryFunction<{ tagId: string; name: string }>("createTag", data),

  getAllTags: () =>
    callInventoryFunction<{ tags: TagData[] }>("getAllTags", {}),

  searchByTag: (tagId: string) =>
    callInventoryFunction<{ tagName: string; products: ProductData[]; tagsTraversed: number }>(
      "searchByTag",
      { tagId }
    ),

  // Recommendations
  trackActivity: (data: {
    userId: string;
    type: string;
    entityId?: string;
    query?: string;
  }) => callInventoryFunction<{ recorded: boolean }>("trackActivity", data),

  getRecommendations: (data: { userId: string; topN?: number }) =>
    callInventoryFunction<RecommendationData>("getRecommendations", data),
};

// ── Shared types ──────────────────────────────────────────────

export interface ProductData {
  productId: string;
  name: string;
  price: number;
  quantity: number;
  tags: string[];
  sellerId?: string;
  createdAt?: string;
}

export interface OrderData {
  orderId: string;
  items: Array<{
    productId: string;
    productName: string;
    quantity: number;
    priceAtPurchase: number;
    lineTotal: number;
  }>;
  totalAmount: number;
  status: string;
  createdAt: string | null;
}

export interface TagData {
  tagId: string;
  name: string;
  parentTagId: string | null;
  childCount: number;
  productCount: number;
}

export interface RecommendationData {
  algorithm: string;
  recommendedTags: Array<{ tagId: string; name: string }>;
  recommendedProducts: Array<{
    productId: string;
    name: string;
    price: number;
    quantity: number;
  }>;
}
