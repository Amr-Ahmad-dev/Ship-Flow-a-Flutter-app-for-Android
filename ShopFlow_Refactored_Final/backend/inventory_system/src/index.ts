// =============================================================
// FILE: src/index.ts  —  SYSTEM 1: Inventory System
// PURPOSE: Single entry point. Exports all Cloud Functions.
//
// Firebase reads this file to know which functions to deploy.
// This file contains NO business logic — it only imports and
// re-exports from the domain-specific modules.
//
// DEPLOYED FUNCTIONS (callable via HTTP by System 2):
//   Auth:     registerUser, verifyEmail, getUserById,
//             resendVerificationCode, validateFirebaseToken
//   Products: addProduct, addStock, getProducts, getProductById,
//             getSellerInventory, assignTagToProduct
//   Orders:   createOrder, getOrderHistory
//   Tags:     createTag, getAllTags, searchByTag
// =============================================================

import * as admin from "firebase-admin";

// Initialize Firebase Admin SDK once at the module level
if (!admin.apps.length) {
  admin.initializeApp();
}

// Auth functions
export {
  registerUser,
  verifyEmail,
  getUserById,
  resendVerificationCode,
  validateFirebaseToken,
} from "./auth";

// Product / inventory functions
export {
  addProduct,
  addStock,
  getProducts,
  getProductById,
  getSellerInventory,
  assignTagToProduct,
} from "./products";

// Order functions
export { createOrder, getOrderHistory } from "./orders";

// Tag functions
export { createTag, getAllTags, searchByTag } from "./tags";
