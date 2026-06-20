// =============================================================
// FILE: src/middleware/errorHandler.ts  —  SYSTEM 2: Sales API
// PURPOSE: Global error handler. Every unhandled error lands here.
//
// Express error handlers have 4 parameters (err, req, res, next).
// They must be registered LAST in the middleware chain.
// =============================================================

import { Request, Response, NextFunction } from "express";
import { InventoryError } from "../services/inventoryClient";

export function errorHandler(
  err: unknown,
  _req: Request,
  res: Response,
  _next: NextFunction
): void {
  // Map Inventory System error codes to HTTP status codes
  if (err instanceof InventoryError) {
    const statusMap: Record<string, number> = {
      NOT_FOUND: 404,
      ALREADY_EXISTS: 409,
      INVALID_ARGUMENT: 400,
      UNAUTHENTICATED: 401,
      PERMISSION_DENIED: 403,
      ABORTED: 409,
      DEADLINE_EXCEEDED: 408,
      UNAVAILABLE: 503,
      INTERNAL: 500,
    };
    const httpStatus = statusMap[err.status] ?? 500;
    res.status(httpStatus).json({ success: false, error: err.message });
    return;
  }

  // Generic errors
  if (err instanceof Error) {
    console.error("Unhandled error:", err.message);
    res.status(500).json({ success: false, error: err.message });
    return;
  }

  res.status(500).json({ success: false, error: "An unexpected error occurred." });
}
