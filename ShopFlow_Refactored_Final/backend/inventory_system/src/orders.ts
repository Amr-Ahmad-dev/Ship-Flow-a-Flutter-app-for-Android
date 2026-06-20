// =============================================================
// FILE: src/orders.ts  —  SYSTEM 1: Inventory System
// PURPOSE: Order creation with atomic Firestore transaction.
//
// This is the critical cross-domain operation:
//   1. Validate items and prices (from DB, never from caller)
//   2. Create order document (status: "pending")
//   3. Reduce stock via reduceStockInternal() — ATOMICALLY
//   4. Update order status → "confirmed" or "failed"
//
// All four steps happen inside ONE Firestore transaction.
// If stock reduction fails for ANY item, the entire transaction
// rolls back — no order created, no stock changed.
//
// Called by: Sales API POST /orders
// =============================================================

import * as functions from "firebase-functions";
import { db, now } from "./db";
import { reduceStockInternal } from "./products";

// =============================================================
// createOrder
// Called by: Sales API POST /orders
// Data: { buyerId, items: [{productId, quantity}] }
// =============================================================
export const createOrder = functions.https.onCall(async (data) => {
  const { buyerId, items } = data as {
    buyerId: string;
    items: Array<{ productId: string; quantity: number }>;
  };

  // ── Input validation ──────────────────────────────────────
  if (!buyerId) {
    throw new functions.https.HttpsError("invalid-argument", "buyerId required.");
  }
  if (!Array.isArray(items) || items.length === 0) {
    throw new functions.https.HttpsError("invalid-argument", "items must be a non-empty array.");
  }
  for (const item of items) {
    if (!item.productId) {
      throw new functions.https.HttpsError("invalid-argument", "Each item must have a productId.");
    }
    if (!Number.isInteger(item.quantity) || item.quantity <= 0) {
      throw new functions.https.HttpsError(
        "invalid-argument",
        `Item ${item.productId}: quantity must be a positive integer.`
      );
    }
  }

  // Confirm buyer exists
  const buyerSnap = await db.collection("users").doc(buyerId).get();
  if (!buyerSnap.exists) {
    throw new functions.https.HttpsError("not-found", "Buyer not found.");
  }

  // ── Run everything in a single atomic transaction ─────────
  let orderId: string;
  let totalAmount: number;

  try {
    const result = await db.runTransaction(async (tx) => {
      // Step 1: Reduce stock (validates availability + applies reductions)
      // This throws if ANY item is out of stock — entire transaction aborts
      const snapMap = await reduceStockInternal(items, tx);

      // Step 2: Calculate total from DB prices (NEVER trust caller prices)
      let total = 0;
      const enrichedItems = items.map((item) => {
        const snap = snapMap.get(item.productId)!;
        const d = snap.data()!;
        const price = d.price as number;
        const lineTotal = price * item.quantity;
        total += lineTotal;
        return {
          productId: item.productId,
          productName: d.name as string,
          quantity: item.quantity,
          priceAtPurchase: price,  // Price locked at purchase time
          lineTotal,
        };
      });

      // Step 3: Create order document inside the transaction
      const orderRef = db.collection("orders").doc(); // auto-ID
      tx.set(orderRef, {
        buyerId,
        items: enrichedItems,
        totalAmount: total,
        status: "confirmed",   // If we get here, stock was reduced OK
        createdAt: now(),
        updatedAt: now(),
      });

      return { orderId: orderRef.id, totalAmount: total, items: enrichedItems };
    });

    orderId = result.orderId;
    totalAmount = result.totalAmount;
    functions.logger.info(`Order confirmed: ${orderId} for buyer ${buyerId}`);
  } catch (err: unknown) {
    // Transaction failed (stock insufficient or DB error)
    const msg = err instanceof Error ? err.message : "Order failed.";
    functions.logger.error(`Order failed for buyer ${buyerId}: ${msg}`);
    throw new functions.https.HttpsError("aborted", msg);
  }

  return {
    ok: true,
    data: {
      orderId,
      totalAmount,
      status: "confirmed",
    },
  };
});

// =============================================================
// getOrderHistory
// Called by: Sales API GET /orders/history
// Returns orders for a specific buyer (most recent first)
// =============================================================
export const getOrderHistory = functions.https.onCall(async (data) => {
  const { buyerId } = (data ?? {}) as { buyerId: string };

  if (!buyerId) {
    throw new functions.https.HttpsError("invalid-argument", "buyerId required.");
  }

  const snap = await db
    .collection("orders")
    .where("buyerId", "==", buyerId)
    .orderBy("createdAt", "desc")
    .limit(30)
    .get();

  const orders = snap.docs.map((d) => ({
    orderId: d.id,
    items: d.data().items as unknown[],
    totalAmount: d.data().totalAmount as number,
    status: d.data().status as string,
    createdAt: d.data().createdAt?.toDate?.()?.toISOString() ?? null,
  }));

  return { ok: true, data: { orders } };
});
