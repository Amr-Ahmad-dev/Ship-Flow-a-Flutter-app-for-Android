// =============================================================
// FILE: src/recommendations.ts  —  SYSTEM 1: Inventory System
// PURPOSE: Track user activity + compute personalized scores.
//
// ALGORITHM: Frequency-Weighted Recency Scoring
//   score(interaction) = 1 / (1 + hoursAgo)
//   Total score for entity = sum of all interaction scores
//
//   Recent interactions score close to 1.0
//   Old interactions score close to 0.0
//   Repeated interactions accumulate → frequency bonus
//
// LIMITATION: No collaborative filtering. New users get
//   fallback (newest products). Max 100 activities stored.
// =============================================================

import * as functions from "firebase-functions";
import { db, now } from "./db";

// =============================================================
// trackActivity
// Called by: Sales API POST /activity
// Stores: one activity entry, trims to last 100
// =============================================================
export const trackActivity = functions.https.onCall(async (data) => {
  const { userId, type, entityId, query } = data as {
    userId: string;
    type: "search" | "product_click" | "tag_view";
    entityId?: string;
    query?: string;
  };

  if (!userId || !type) {
    // Tracking failures are silent — don't break UX
    return { ok: true, data: { recorded: false } };
  }

  const validTypes = ["search", "product_click", "tag_view"];
  if (!validTypes.includes(type)) {
    return { ok: true, data: { recorded: false } };
  }

  const entry = {
    type,
    entityId: entityId ?? null,
    query: query ?? null,
    timestampMs: Date.now(),
    timestamp: now(),
  };

  const ref = db.collection("user_activity").doc(userId);
  const snap = await ref.get();

  if (!snap.exists) {
    await ref.set({ userId, activities: [entry], updatedAt: now() });
  } else {
    const existing = (snap.data()?.activities ?? []) as unknown[];
    const updated = [...existing, entry].slice(-100); // Keep last 100
    await ref.update({ activities: updated, updatedAt: now() });
  }

  return { ok: true, data: { recorded: true } };
});

// =============================================================
// getRecommendations
// Called by: Sales API GET /recommendations
// Returns top-N tags and products based on activity history
// =============================================================
export const getRecommendations = functions.https.onCall(async (data) => {
  const { userId, topN = 6 } = (data ?? {}) as {
    userId: string;
    topN?: number;
  };

  if (!userId) {
    throw new functions.https.HttpsError("invalid-argument", "userId required.");
  }

  const activitySnap = await db.collection("user_activity").doc(userId).get();

  // Cold start: no activity yet → return newest products
  if (!activitySnap.exists || !activitySnap.data()?.activities?.length) {
    return getFallback(topN);
  }

  const activities = activitySnap.data()!.activities as Array<{
    type: string;
    entityId: string | null;
    timestampMs: number;
  }>;

  const now = Date.now();
  const ONE_HOUR = 3_600_000;

  // Score each entity
  const tagScores = new Map<string, number>();
  const productScores = new Map<string, number>();

  for (const activity of activities) {
    if (!activity.entityId) continue;
    const hoursAgo = (now - (activity.timestampMs ?? now)) / ONE_HOUR;
    const score = 1 / (1 + hoursAgo); // Decays over time

    if (activity.type === "tag_view") {
      tagScores.set(activity.entityId, (tagScores.get(activity.entityId) ?? 0) + score);
    } else if (activity.type === "product_click") {
      productScores.set(activity.entityId, (productScores.get(activity.entityId) ?? 0) + score);
    }
  }

  // Sort and pick top N
  const topTagIds = [...tagScores.entries()]
    .sort((a, b) => b[1] - a[1])
    .slice(0, topN)
    .map(([id]) => id);

  const topProductIds = [...productScores.entries()]
    .sort((a, b) => b[1] - a[1])
    .slice(0, topN)
    .map(([id]) => id);

  // Fetch details in parallel
  const [tags, products] = await Promise.all([
    fetchTagDetails(topTagIds),
    fetchProductDetails(topProductIds),
  ]);

  return {
    ok: true,
    data: {
      algorithm: "frequency_weighted_recency",
      recommendedTags: tags,
      recommendedProducts: products,
    },
  };
});

// ── Helpers ───────────────────────────────────────────────────

async function fetchTagDetails(ids: string[]) {
  if (!ids.length) return [];
  const snaps = await Promise.all(
    ids.map((id) => db.collection("tags").doc(id).get())
  );
  return snaps
    .filter((s) => s.exists)
    .map((s) => ({ tagId: s.id, name: s.data()!.name as string }));
}

async function fetchProductDetails(ids: string[]) {
  if (!ids.length) return [];
  const snaps = await Promise.all(
    ids.map((id) => db.collection("products").doc(id).get())
  );
  return snaps
    .filter((s) => s.exists && (s.data()!.quantity as number) > 0)
    .map((s) => ({
      productId: s.id,
      name: s.data()!.name as string,
      price: s.data()!.price as number,
      quantity: s.data()!.quantity as number,
    }));
}

async function getFallback(topN: number) {
  const snap = await db
    .collection("products")
    .where("quantity", ">", 0)
    .orderBy("quantity")
    .orderBy("createdAt", "desc")
    .limit(topN)
    .get();

  return {
    ok: true,
    data: {
      algorithm: "fallback_newest",
      recommendedTags: [],
      recommendedProducts: snap.docs.map((d) => ({
        productId: d.id,
        name: d.data().name as string,
        price: d.data().price as number,
        quantity: d.data().quantity as number,
      })),
    },
  };
}
