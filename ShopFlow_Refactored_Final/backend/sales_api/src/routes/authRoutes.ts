// =============================================================
// FILE: src/routes/authRoutes.ts  —  SYSTEM 2: Sales API
// PURPOSE: Auth endpoints exposed to Flutter (System 3).
//
// Routes:
//   POST /auth/register      → calls inventoryApi.registerUser
//   POST /auth/login         → verifies user, issues JWT
//   POST /auth/verify-email  → calls inventoryApi.verifyEmail
//   POST /auth/resend-code   → calls inventoryApi.resendCode
//   GET  /auth/me            → returns current user from JWT
//
// IMPORTANT: Login works by:
//   1. Fetching user profile from System 1 (getUserById)
//   2. Verifying the password via Firebase Auth REST API
//   3. Issuing a JWT if credentials match
//
// Firebase Auth REST API: https://identitytoolkit.googleapis.com
// This is a public REST API — no SDK needed.
// =============================================================

import { Router, Request, Response, NextFunction } from "express";
import axios from "axios";
import { inventoryApi } from "../services/inventoryClient";
import { requireAuth, signToken } from "../middleware/auth";

const router = Router();

// ── POST /auth/register ───────────────────────────────────────
router.post(
  "/register",
  async (req: Request, res: Response, next: NextFunction) => {
    try {
      const { email, password, displayName, role } = req.body as {
        email: string;
        password: string;
        displayName: string;
        role: string;
      };

      if (!email || !password || !displayName || !role) {
        res.status(400).json({
          success: false,
          error: "email, password, displayName, role are all required.",
        });
        return;
      }

      // Call System 1 to create the user
      const userData = await inventoryApi.registerUser({
        email,
        password,
        displayName,
        role,
      });

      res.status(201).json({
        success: true,
        data: {
          userId: userData.userId,
          email: userData.email,
          displayName: userData.displayName,
          role: userData.role,
          // In dev, the code is returned for convenience
          verificationCode: userData.verificationCode,
          message: "Registration successful. Please verify your email.",
        },
      });
    } catch (err) {
      next(err);
    }
  }
);

// ── POST /auth/login ──────────────────────────────────────────
router.post(
  "/login",
  async (req: Request, res: Response, next: NextFunction) => {
    try {
      const { email, password } = req.body as {
        email: string;
        password: string;
      };

      if (!email || !password) {
        res.status(400).json({
          success: false,
          error: "email and password are required.",
        });
        return;
      }

      // Use Firebase Auth REST API to verify credentials
      // This does NOT require the Firebase SDK
      const FIREBASE_API_KEY = process.env.FIREBASE_API_KEY;
      if (!FIREBASE_API_KEY) {
        res.status(500).json({
          success: false,
          error: "Server misconfigured: FIREBASE_API_KEY not set.",
        });
        return;
      }

      let firebaseUid: string;
      try {
        const authResponse = await axios.post(
          `https://identitytoolkit.googleapis.com/v1/accounts:signInWithPassword?key=${FIREBASE_API_KEY}`,
          { email, password, returnSecureToken: true },
          { timeout: 10_000 }
        );
        firebaseUid = authResponse.data.localId as string;
      } catch {
        res.status(401).json({
          success: false,
          error: "Invalid email or password.",
        });
        return;
      }

      // Fetch full profile from System 1
      const userData = await inventoryApi.getUserById(firebaseUid);

      // Issue JWT — System 2's own token
      const token = signToken({
        userId: userData.userId,
        email: userData.email,
        role: userData.role as "buyer" | "seller",
        emailVerified: userData.emailVerified,
      });

      res.json({
        success: true,
        data: {
          token,
          userId: userData.userId,
          email: userData.email,
          displayName: userData.displayName,
          role: userData.role,
          emailVerified: userData.emailVerified,
        },
      });
    } catch (err) {
      next(err);
    }
  }
);

// ── POST /auth/verify-email ───────────────────────────────────
router.post(
  "/verify-email",
  async (req: Request, res: Response, next: NextFunction) => {
    try {
      const { userId, code } = req.body as { userId: string; code: string };
      if (!userId || !code) {
        res.status(400).json({
          success: false,
          error: "userId and code are required.",
        });
        return;
      }

      const result = await inventoryApi.verifyEmail({ userId, code });
      res.json({ success: true, data: result });
    } catch (err) {
      next(err);
    }
  }
);

// ── POST /auth/resend-code ────────────────────────────────────
router.post(
  "/resend-code",
  async (req: Request, res: Response, next: NextFunction) => {
    try {
      const { userId } = req.body as { userId: string };
      if (!userId) {
        res.status(400).json({ success: false, error: "userId required." });
        return;
      }
      const result = await inventoryApi.resendCode(userId);
      res.json({ success: true, data: result });
    } catch (err) {
      next(err);
    }
  }
);

// ── GET /auth/me ──────────────────────────────────────────────
router.get(
  "/me",
  requireAuth,
  async (req: Request, res: Response, next: NextFunction) => {
    try {
      // Fetch fresh profile from System 1 (in case role/verified changed)
      const userData = await inventoryApi.getUserById(req.user!.userId);
      res.json({ success: true, data: userData });
    } catch (err) {
      next(err);
    }
  }
);

export default router;
