// =============================================================
// FILE: src/auth.ts  —  SYSTEM 1: Inventory System
// PURPOSE: User registration, email verification, profile fetch.
//
// ALL THESE FUNCTIONS ARE HTTPS CALLABLE.
// They are called by System 2 (Sales API) via HTTP.
// System 3 (Flutter) never calls these directly.
//
// FLOW:
//   Flutter → POST /auth/register (Sales API)
//           → calls this Cloud Function via HTTP
//           → writes user to Firestore (only System 1 does this)
//           → returns JWT-friendly user data to Sales API
//           → Sales API issues JWT → Flutter stores JWT
// =============================================================

import * as functions from "firebase-functions";
import * as admin from "firebase-admin";
import { db, now, deleteField } from "./db";

// ── Helper: generate a 6-digit code ──────────────────────────
function makeCode(): string {
  return Math.floor(100000 + Math.random() * 900000).toString();
}

// ── Helper: standard response shape ──────────────────────────
// All functions return { ok: true, data: {...} } or throw HttpsError.
// The Sales API reads result.data and re-wraps for Flutter.

// =============================================================
// registerUser
// Called by: Sales API POST /auth/register
// Writes to: users collection (only System 1 may do this)
// =============================================================
export const registerUser = functions.https.onCall(async (data) => {
  const { email, password, displayName, role } = data as {
    email: string;
    password: string;
    displayName: string;
    role: string;
  };

  // Validate inputs
  if (!email?.trim() || !password || !displayName?.trim()) {
    throw new functions.https.HttpsError(
      "invalid-argument",
      "email, password, and displayName are required."
    );
  }
  if (!["buyer", "seller"].includes(role)) {
    throw new functions.https.HttpsError(
      "invalid-argument",
      "role must be 'buyer' or 'seller'."
    );
  }
  if (password.length < 6) {
    throw new functions.https.HttpsError(
      "invalid-argument",
      "Password must be at least 6 characters."
    );
  }

  // Create Firebase Auth user (handles password hashing)
  let userRecord: admin.auth.UserRecord;
  try {
    userRecord = await admin.auth().createUser({
      email: email.trim().toLowerCase(),
      password,
      displayName: displayName.trim(),
    });
  } catch (err: unknown) {
    const e = err as { code?: string; message?: string };
    if (e.code === "auth/email-already-exists") {
      throw new functions.https.HttpsError(
        "already-exists",
        "An account with this email already exists."
      );
    }
    throw new functions.https.HttpsError("internal", e.message ?? "Registration failed.");
  }

  const code = makeCode();

  // Write user profile to Firestore — ONLY System 1 does this
  await db.collection("users").doc(userRecord.uid).set({
    email: email.trim().toLowerCase(),
    displayName: displayName.trim(),
    role,
    emailVerified: false,
    verificationCode: code,
    codeCreatedAt: now(),
    createdAt: now(),
  });

  functions.logger.info(`User registered: ${userRecord.uid} (${role})`);

  // In production: send code via email (Mailgun, SendGrid, etc.)
  // For prototype: return code directly so it can be shown in the app
  return {
    ok: true,
    data: {
      userId: userRecord.uid,
      email: email.trim().toLowerCase(),
      displayName: displayName.trim(),
      role,
      // REMOVE IN PRODUCTION — send via email instead:
      verificationCode: code,
    },
  };
});

// =============================================================
// verifyEmail
// Called by: Sales API POST /auth/verify-email
// Reads/Writes: users collection
// =============================================================
export const verifyEmail = functions.https.onCall(async (data) => {
  const { userId, code } = data as { userId: string; code: string };

  if (!userId || !code) {
    throw new functions.https.HttpsError(
      "invalid-argument",
      "userId and code are required."
    );
  }

  const userRef = db.collection("users").doc(userId);
  const snap = await userRef.get();

  if (!snap.exists) {
    throw new functions.https.HttpsError("not-found", "User not found.");
  }

  const user = snap.data()!;

  if (user.emailVerified === true) {
    return { ok: true, data: { message: "Already verified." } };
  }

  if (user.verificationCode !== code) {
    throw new functions.https.HttpsError("unauthenticated", "Invalid verification code.");
  }

  // Check expiry: 15 minutes
  const created = user.codeCreatedAt?.toDate?.() as Date | undefined;
  if (created) {
    const ageMs = Date.now() - created.getTime();
    if (ageMs > 15 * 60 * 1000) {
      throw new functions.https.HttpsError(
        "deadline-exceeded",
        "Code expired. Request a new one."
      );
    }
  }

  await userRef.update({
    emailVerified: true,
    verificationCode: deleteField(),
    codeCreatedAt: deleteField(),
  });

  return { ok: true, data: { message: "Email verified successfully." } };
});

// =============================================================
// getUserById
// Called by: Sales API (for JWT validation / profile fetch)
// Reads: users collection
// =============================================================
export const getUserById = functions.https.onCall(async (data) => {
  const { userId } = data as { userId: string };

  if (!userId) {
    throw new functions.https.HttpsError("invalid-argument", "userId required.");
  }

  const snap = await db.collection("users").doc(userId).get();
  if (!snap.exists) {
    throw new functions.https.HttpsError("not-found", "User not found.");
  }

  const u = snap.data()!;
  return {
    ok: true,
    data: {
      userId,
      email: u.email as string,
      displayName: u.displayName as string,
      role: u.role as string,
      emailVerified: u.emailVerified as boolean,
    },
  };
});

// =============================================================
// resendVerificationCode
// Called by: Sales API POST /auth/resend-code
// =============================================================
export const resendVerificationCode = functions.https.onCall(async (data) => {
  const { userId } = data as { userId: string };
  if (!userId) {
    throw new functions.https.HttpsError("invalid-argument", "userId required.");
  }

  const code = makeCode();
  await db.collection("users").doc(userId).update({
    verificationCode: code,
    codeCreatedAt: now(),
  });

  return {
    ok: true,
    data: {
      message: "New code issued.",
      // REMOVE IN PRODUCTION:
      verificationCode: code,
    },
  };
});

// =============================================================
// validateFirebaseToken
// Called by: Sales API middleware to verify Firebase ID tokens
// This lets the Sales API confirm a user is authenticated
// without having its own user database.
// =============================================================
export const validateFirebaseToken = functions.https.onCall(async (data) => {
  const { idToken } = data as { idToken: string };
  if (!idToken) {
    throw new functions.https.HttpsError("invalid-argument", "idToken required.");
  }

  try {
    const decoded = await admin.auth().verifyIdToken(idToken);
    const snap = await db.collection("users").doc(decoded.uid).get();
    if (!snap.exists) {
      throw new functions.https.HttpsError("not-found", "User profile not found.");
    }
    const u = snap.data()!;
    return {
      ok: true,
      data: {
        userId: decoded.uid,
        email: u.email as string,
        role: u.role as string,
        emailVerified: u.emailVerified as boolean,
      },
    };
  } catch {
    throw new functions.https.HttpsError("unauthenticated", "Invalid or expired token.");
  }
});
