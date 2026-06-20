// =============================================================
// FILE: src/products.ts  —  SYSTEM 1: Inventory System
// PURPOSE: Product creation and ALL stock modifications.
//
// ╔═══════════════════════════════════════════════════════════╗
// ║  CORE RULE: product.quantity is ONLY written HERE.       ║
// ║  No other file, system, or actor may change stock.       ║
// ╚═══════════════════════════════════════════════════════════╝
//
// Called by: System 2 (Sales API) via HTTP
// Writes to: products collection in Firestore
// =============================================================

import * as functions from "firebase-functions";
import { db, now, arrayUnion } from "./db";

// =============================================================
// addProduct
// Called by: Sales API POST /seller/products
// Who can call: Sellers only (Sales API enforces this via JWT role check)
// =============================================================
export const addProduct = functions.https.onCall(async (data) => {
  const { name, price, quantity, tags, sellerId } = data as {
    name: string;
    price: number;
    quantity: number;
    tags: string[];
    sellerId: string;
  };

  // Validate all fields
  if (!name?.trim()) {
    throw new functions.https.HttpsError("invalid-argument", "Product name required.");
  }
  if (typeof price !== "number" || price < 0) {
    throw new functions.https.HttpsError("invalid-argument", "Price must be a non-negative number.");
  }
  if (!Number.isInteger(quantity) || quantity < 0) {
    throw new functions.https.HttpsError("invalid-argument", "Quantity must be a non-negative integer.");
  }
  if (!sellerId) {
    throw new functions.https.HttpsError("invalid-argument", "sellerId required.");
  }

  // Confirm seller exists in Firestore
  const sellerSnap = await db.collection("users").doc(sellerId).get();
  if (!sellerSnap.exists || sellerSnap.data()?.role !== "seller") {
    throw new functions.https.HttpsError("permission-denied", "Only sellers can add products.");
  }

  const tagList: string[] = Array.isArray(tags) ? tags.filter(Boolean) : [];

  const ref = await db.collection("products").add({
    name: name.trim(),
    price,
    quantity,          // ← Initial stock. Only this function sets it initially.
    tags: tagList,
    sellerId,
    createdAt: now(),
    updatedAt: now(),
  });

  functions.logger.info(`Product created: ${ref.id} | seller: ${sellerId} | qty: ${quantity}`);

  return {
    ok: true,
    data: {
      productId: ref.id,
      name: name.trim(),
      price,
      quantity,
      tags: tagList,
    },
  };
});

// =============================================================
// addStock
// Called by: Sales API POST /seller/stock
// Who can call: Only the product's own seller
// Uses a Firestore transaction to prevent race conditions
// =============================================================
export const addStock = functions.https.onCall(async (data) => {
  const { productId, quantityToAdd, sellerId } = data as {
    productId: string;
    quantityToAdd: number;
    sellerId: string;
  };

  if (!productId || !sellerId) {
    throw new functions.https.HttpsError("invalid-argument", "productId and sellerId required.");
  }
  if (!Number.isInteger(quantityToAdd) || quantityToAdd <= 0) {
    throw new functions.https.HttpsError("invalid-argument", "quantityToAdd must be a positive integer.");
  }

  const productRef = db.collection("products").doc(productId);

  const newQuantity = await db.runTransaction(async (tx) => {
    const snap = await tx.get(productRef);
    if (!snap.exists) {
      throw new functions.https.HttpsError("not-found", "Product not found.");
    }
    const current = snap.data()!;
    if (current.sellerId !== sellerId) {
      throw new functions.https.HttpsError(
        "permission-denied",
        "Only the product's seller can add stock."
      );
    }
    const updated = (current.quantity as number) + quantityToAdd;
    tx.update(productRef, { quantity: updated, updatedAt: now() });
    return updated;
  });

  functions.logger.info(`Stock added: ${productId} +${quantityToAdd} → ${newQuantity}`);

  return { ok: true, data: { productId, newQuantity } };
});

// =============================================================
// reduceStock  ← THE MOST CRITICAL FUNCTION IN THE SYSTEM
// Called by: orders.ts ONLY (internal import, not direct HTTP call)
// This is NOT exported as an HTTP function — it's a pure
// TypeScript function called within the same process.
// This enforces that only the order creation flow can reduce stock.
// =============================================================
export async function reduceStockInternal(
  items: Array<{ productId: string; quantity: number }>,
  tx: FirebaseFirestore.Transaction
): Promise<Map<string, FirebaseFirestore.DocumentSnapshot>> {
  // Fetch all product docs inside the transaction
  const refs = items.map((i) => db.collection("products").doc(i.productId));
  const snaps = await Promise.all(refs.map((r) => tx.get(r)));

  // Map for returning to caller (used to get prices for order line items)
  const snapMap = new Map<string, FirebaseFirestore.DocumentSnapshot>();

  // Validate ALL items before writing ANY (all-or-nothing)
  for (let i = 0; i < items.length; i++) {
    const item = items[i];
    const snap = snaps[i];

    if (!snap.exists) {
      throw new Error(`Product ${item.productId} does not exist.`);
    }

    const currentQty = snap.data()!.quantity as number;
    if (currentQty < item.quantity) {
      const name = snap.data()!.name as string;
      throw new Error(
        `Insufficient stock for "${name}". Available: ${currentQty}, requested: ${item.quantity}.`
      );
    }

    snapMap.set(item.productId, snap);
  }

  // All checks passed — apply all reductions inside the transaction
  for (let i = 0; i < items.length; i++) {
    const item = items[i];
    const snap = snaps[i];
    const currentQty = snap.data()!.quantity as number;
    const newQty = currentQty - item.quantity;

    // The invariant: stock >= 0 is guaranteed by the check above
    tx.update(refs[i], { quantity: newQty, updatedAt: now() });
    functions.logger.info(`Stock reduced: ${item.productId} ${currentQty} → ${newQty}`);
  }

  return snapMap;
}

// =============================================================
// getProducts
// Called by: Sales API GET /products
// Returns all in-stock products, optional tag filter
// =============================================================
export const getProducts = functions.https.onCall(async (data) => {
  const { tagId, limit = 24 } = (data ?? {}) as {
    tagId?: string;
    limit?: number;
  };

  const safeLimit = Math.min(Math.max(1, limit), 50);

  let query: FirebaseFirestore.Query = db
    .collection("products")
    .where("quantity", ">", 0)
    .orderBy("quantity")
    .orderBy("createdAt", "desc")
    .limit(safeLimit);

  if (tagId) {
    query = db
      .collection("products")
      .where("tags", "array-contains", tagId)
      .where("quantity", ">", 0)
      .orderBy("quantity")
      .limit(safeLimit);
  }

  const snap = await query.get();
  const products = snap.docs.map((d) => ({
    productId: d.id,
    name: d.data().name as string,
    price: d.data().price as number,
    quantity: d.data().quantity as number,
    tags: (d.data().tags ?? []) as string[],
    sellerId: d.data().sellerId as string,
    createdAt: d.data().createdAt?.toDate?.()?.toISOString() ?? null,
  }));

  return { ok: true, data: { products } };
});

// =============================================================
// getProductById
// Called by: Sales API GET /products/:id
// =============================================================
export const getProductById = functions.https.onCall(async (data) => {
  const { productId } = (data ?? {}) as { productId: string };
  if (!productId) {
    throw new functions.https.HttpsError("invalid-argument", "productId required.");
  }

  const snap = await db.collection("products").doc(productId).get();
  if (!snap.exists) {
    throw new functions.https.HttpsError("not-found", "Product not found.");
  }

  const d = snap.data()!;
  return {
    ok: true,
    data: {
      product: {
        productId: snap.id,
        name: d.name as string,
        price: d.price as number,
        quantity: d.quantity as number,
        tags: (d.tags ?? []) as string[],
        sellerId: d.sellerId as string,
        createdAt: d.createdAt?.toDate?.()?.toISOString() ?? null,
      },
    },
  };
});

// =============================================================
// getSellerInventory
// Called by: Sales API GET /seller/inventory
// =============================================================
export const getSellerInventory = functions.https.onCall(async (data) => {
  const { sellerId } = (data ?? {}) as { sellerId: string };
  if (!sellerId) {
    throw new functions.https.HttpsError("invalid-argument", "sellerId required.");
  }

  const snap = await db
    .collection("products")
    .where("sellerId", "==", sellerId)
    .orderBy("createdAt", "desc")
    .limit(50)
    .get();

  const products = snap.docs.map((d) => ({
    productId: d.id,
    name: d.data().name as string,
    price: d.data().price as number,
    quantity: d.data().quantity as number,
    tags: (d.data().tags ?? []) as string[],
  }));

  return { ok: true, data: { products } };
});

// =============================================================
// assignTagToProduct
// Called by: Sales API (when seller adds tags to their product)
// =============================================================
export const assignTagToProduct = functions.https.onCall(async (data) => {
  const { productId, tagId, sellerId } = data as {
    productId: string;
    tagId: string;
    sellerId: string;
  };

  if (!productId || !tagId || !sellerId) {
    throw new functions.https.HttpsError(
      "invalid-argument",
      "productId, tagId, sellerId all required."
    );
  }

  const productSnap = await db.collection("products").doc(productId).get();
  if (!productSnap.exists) {
    throw new functions.https.HttpsError("not-found", "Product not found.");
  }
  if (productSnap.data()!.sellerId !== sellerId) {
    throw new functions.https.HttpsError("permission-denied", "Not your product.");
  }

  const tagSnap = await db.collection("tags").doc(tagId).get();
  if (!tagSnap.exists) {
    throw new functions.https.HttpsError("not-found", "Tag not found.");
  }

  // Update both documents atomically
  const batch = db.batch();
  batch.update(db.collection("products").doc(productId), {
    tags: arrayUnion(tagId),
    updatedAt: now(),
  });
  batch.update(db.collection("tags").doc(tagId), {
    productIds: arrayUnion(productId),
  });
  await batch.commit();

  return { ok: true, data: { message: "Tag assigned." } };
});
