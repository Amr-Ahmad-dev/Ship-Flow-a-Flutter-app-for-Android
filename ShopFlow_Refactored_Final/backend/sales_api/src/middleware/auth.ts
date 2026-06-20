// =============================================================
// FILE: src/middleware/auth.ts  —  SYSTEM 2: Sales API
// PURPOSE: JWT verification middleware for protected routes.
//
// HOW AUTH WORKS IN THIS SYSTEM:
//   1. User registers/logs in → Sales API issues a JWT
//   2. JWT contains: { userId, email, role, emailVerified }
//   3. Flutter stores JWT in local storage
//   4. Flutter sends JWT in: Authorization: Bearer <token>
//   5. This middleware verifies the JWT signature
//   6. Attaches decoded user to req.user
//
// WHY JWT (not Firebase Auth tokens)?
//   System 2 has NO Firebase SDK. It cannot call Firebase Auth
//   to verify Firebase ID tokens without the SDK. Instead,
//   System 2 issues its OWN JWT after verifying credentials
//   with System 1. This keeps System 2 fully independent.
// =============================================================

import { Request, Response, NextFunction } from "express";
import jwt from "jsonwebtoken";

// The JWT payload shape stored in our tokens
export interface JwtPayload {
  userId: string;
  email: string;
  role: "buyer" | "seller";
  emailVerified: boolean;
}

// Extend Express Request to carry the decoded user
declare global {
  namespace Express {
    interface Request {
      user?: JwtPayload;
    }
  }
}

const JWT_SECRET = process.env.JWT_SECRET;
if (!JWT_SECRET) {
  console.error("FATAL: JWT_SECRET environment variable is not set.");
  process.exit(1);
}

// =============================================================
// requireAuth
// Middleware: any route that needs a logged-in user
// =============================================================
export function requireAuth(req: Request, res: Response, next: NextFunction): void {
  const authHeader = req.headers["authorization"];

  if (!authHeader?.startsWith("Bearer ")) {
    res.status(401).json({ success: false, error: "Authorization header missing." });
    return;
  }

  const token = authHeader.slice(7); // Remove "Bearer " prefix

  try {
    const decoded = jwt.verify(token, JWT_SECRET!) as JwtPayload;
    req.user = decoded;
    next();
  } catch {
    res.status(401).json({ success: false, error: "Invalid or expired token." });
  }
}

// =============================================================
// requireSeller
// Middleware: routes only accessible to sellers
// Apply AFTER requireAuth
// =============================================================
export function requireSeller(req: Request, res: Response, next: NextFunction): void {
  if (req.user?.role !== "seller") {
    res.status(403).json({ success: false, error: "Seller account required." });
    return;
  }
  next();
}

// =============================================================
// requireVerifiedEmail
// Middleware: routes that need verified email
// =============================================================
export function requireVerifiedEmail(
  req: Request,
  res: Response,
  next: NextFunction
): void {
  if (!req.user?.emailVerified) {
    res.status(403).json({
      success: false,
      error: "Please verify your email before continuing.",
    });
    return;
  }
  next();
}

// =============================================================
// signToken  —  Helper to create JWT tokens
// =============================================================
export function signToken(payload: JwtPayload): string {
  return jwt.sign(payload, JWT_SECRET!, {
    expiresIn: (process.env.JWT_EXPIRES_IN ?? "7d") as jwt.SignOptions["expiresIn"],
  });
}
