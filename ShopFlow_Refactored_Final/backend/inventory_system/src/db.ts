// =============================================================
// FILE: src/db.ts  —  SYSTEM 1: Inventory System
// PURPOSE: Single Firestore instance shared across all modules.
//
// WHY A SINGLETON?
//   Calling admin.firestore() multiple times in different files
//   is fine, but exporting one shared instance is cleaner and
//   prevents accidentally initializing Admin SDK twice.
//
// CRITICAL: This file is ONLY used inside Cloud Functions.
//   The Sales API (System 2) has NO reference to this file.
//   The Flutter app (System 3) has NO reference to this file.
//   This is how the separation is enforced at the file level.
// =============================================================

import * as admin from "firebase-admin";

// Initialize once. Firebase Functions auto-provides credentials.
if (!admin.apps.length) {
  admin.initializeApp();
}

// The database instance — passed to all service modules
export const db = admin.firestore();

// Timestamp helper — always use server time, never client time
export const now = () => admin.firestore.FieldValue.serverTimestamp();

// Helper to delete a field
export const deleteField = () => admin.firestore.FieldValue.delete();

// Helper for array union (no duplicates)
export const arrayUnion = (...items: unknown[]) =>
  admin.firestore.FieldValue.arrayUnion(...items);
