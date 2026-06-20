// =============================================================
// FILE: src/tags.ts  —  SYSTEM 1: Inventory System
// PURPOSE: Tag creation and recursive (BFS) tag search.
//
// TAG TREE EXAMPLE:
//   "Electronics"
//     ├── "Mobile Phones"
//     │     ├── "Samsung" → [product A, product B]
//     │     └── "Xiaomi"  → [product C]
//     └── "Smart Watches" → [product D]
//
// Searching "Electronics" returns A + B + C + D.
// Searching "Mobile Phones" returns A + B + C.
//
// ALGORITHM: Breadth-First Search (BFS)
//   - Start queue with the searched tag
//   - Pop each tag, collect its products, enqueue its children
//   - Track visited set to prevent infinite loops on cycles
//   - Stop when queue is empty
// =============================================================

import * as functions from "firebase-functions";
import { db, now, arrayUnion } from "./db";

// =============================================================
// createTag
// Called by: Sales API (admin/seller tool)
// =============================================================
export const createTag = functions.https.onCall(async (data) => {
  const { name, parentTagId } = data as {
    name: string;
    parentTagId?: string;
  };

  if (!name?.trim()) {
    throw new functions.https.HttpsError("invalid-argument", "Tag name required.");
  }

  const tagRef = await db.collection("tags").add({
    name: name.trim(),
    parentTagId: parentTagId ?? null,
    childTagIds: [],
    productIds: [],
    createdAt: now(),
  });

  // If this is a child tag, add its ID to the parent's childTagIds
  if (parentTagId) {
    const parentSnap = await db.collection("tags").doc(parentTagId).get();
    if (!parentSnap.exists) {
      // Clean up the orphaned tag we just created
      await tagRef.delete();
      throw new functions.https.HttpsError("not-found", "Parent tag not found.");
    }
    await db.collection("tags").doc(parentTagId).update({
      childTagIds: arrayUnion(tagRef.id),
    });
  }

  return { ok: true, data: { tagId: tagRef.id, name: name.trim() } };
});

// =============================================================
// getAllTags
// Called by: Sales API GET /tags
// Returns flat list; Flutter builds the tree from parentTagId
// =============================================================
export const getAllTags = functions.https.onCall(async () => {
  const snap = await db.collection("tags").orderBy("name").get();

  const tags = snap.docs.map((d) => ({
    tagId: d.id,
    name: d.data().name as string,
    parentTagId: d.data().parentTagId as string | null,
    childCount: ((d.data().childTagIds ?? []) as string[]).length,
    productCount: ((d.data().productIds ?? []) as string[]).length,
  }));

  return { ok: true, data: { tags } };
});

// =============================================================
// searchByTag  ← The BFS Implementation
// Called by: Sales API GET /tags/:id/search
// Returns all products in this tag and all descendant tags
// =============================================================
export const searchByTag = functions.https.onCall(async (data) => {
  const { tagId } = (data ?? {}) as { tagId: string };

  if (!tagId) {
    throw new functions.https.HttpsError("invalid-argument", "tagId required.");
  }

  // ── BFS state ─────────────────────────────────────────────
  const queue: string[] = [tagId];
  const visited = new Set<string>();         // Prevents infinite loops
  const allProductIds = new Set<string>();   // Accumulates all product IDs
  let rootTagName = "";
  let tagsTraversed = 0;

  // ── BFS loop ──────────────────────────────────────────────
  while (queue.length > 0) {
    const currentId = queue.shift()!;
    if (visited.has(currentId)) continue;    // Skip already-processed tags
    visited.add(currentId);
    tagsTraversed++;

    const snap = await db.collection("tags").doc(currentId).get();
    if (!snap.exists) continue;

    const tag = snap.data()!;

    if (currentId === tagId) {
      rootTagName = tag.name as string;
    }

    // Collect direct products of this tag
    const productIds = (tag.productIds ?? []) as string[];
    productIds.forEach((pid) => allProductIds.add(pid));

    // Enqueue children
    const children = (tag.childTagIds ?? []) as string[];
    children.forEach((cid) => {
      if (!visited.has(cid)) queue.push(cid);
    });
  }

  if (allProductIds.size === 0) {
    return {
      ok: true,
      data: { tagName: rootTagName, products: [], tagsTraversed },
    };
  }

  // Firestore "in" query: max 30 items per call
  // For larger sets, we batch into multiple queries
  const idArray = Array.from(allProductIds);
  const batches: string[][] = [];
  for (let i = 0; i < idArray.length; i += 30) {
    batches.push(idArray.slice(i, i + 30));
  }

  const productDocs: FirebaseFirestore.QueryDocumentSnapshot[] = [];
  for (const batch of batches) {
    const batchSnap = await db
      .collection("products")
      .where("__name__", "in", batch)
      .where("quantity", ">", 0)
      .get();
    productDocs.push(...batchSnap.docs);
  }

  const products = productDocs.map((d) => ({
    productId: d.id,
    name: d.data().name as string,
    price: d.data().price as number,
    quantity: d.data().quantity as number,
    tags: (d.data().tags ?? []) as string[],
  }));

  functions.logger.info(
    `Tag BFS: "${rootTagName}" → ${tagsTraversed} tags → ${products.length} products`
  );

  return {
    ok: true,
    data: { tagName: rootTagName, products, tagsTraversed },
  };
});
