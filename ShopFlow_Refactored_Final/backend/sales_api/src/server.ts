// =============================================================
// FILE: src/server.ts  —  SYSTEM 2: Sales API
// ENTRY POINT: `npm start` runs this file.
//
// PURPOSE: Express HTTP server. The ONLY server Flutter talks to.
//
// THIS SYSTEM:
//   ✓ Validates JWT tokens
//   ✓ Routes requests to the correct handler
//   ✓ Calls System 1 (Inventory) via inventoryClient.ts
//   ✗ Does NOT have Firebase SDK
//   ✗ Does NOT connect to Firestore
//   ✗ Does NOT have any database credentials
// =============================================================

import 'dotenv/config'; // Must be first — loads .env variables
import express from 'express';
import cors from 'cors';
import rateLimit from 'express-rate-limit';

import authRouter from './routes/authRoutes';
import productRouter from './routes/productRoutes';
import sellerRouter from './routes/sellerRoutes';
import orderRouter from './routes/orderRoutes';
import tagRouter from './routes/tagRoutes';
import recommendRouter from './routes/recommendRoutes';
import { errorHandler } from './middleware/errorHandler';

const app = express();
const PORT = parseInt(process.env.PORT ?? '3001', 10);

// ── Core middleware ────────────────────────────────────────────
app.use(express.json({ limit: '1mb' }));

app.use(cors({
  origin: '*', // Restrict in production to your domain
  methods: ['GET', 'POST', 'PUT', 'DELETE', 'OPTIONS'],
  allowedHeaders: ['Content-Type', 'Authorization'],
}));

app.use(rateLimit({
  windowMs: 15 * 60 * 1000,
  max: 300,
  standardHeaders: true,
  legacyHeaders: false,
  message: { success: false, error: 'Too many requests. Please slow down.' },
}));

// ── Health check ───────────────────────────────────────────────
// Purpose: Provides a simple endpoint to verify if the server is up and can reach System 1.
// Communication: Returns a JSON object with system status, timestamp, and configured inventory URL.
app.get('/health', (_req, res) => {
  res.json({
    success: true,
    data: {
      system: 'ShopFlow Sales API (System 2)',
      status: 'running',
      inventoryUrl: process.env.INVENTORY_BASE_URL ?? 'NOT SET',
      timestamp: new Date().toISOString(),
    },
  });
});

// ── All routes ─────────────────────────────────────────────────
// Flutter calls these. Each router calls inventoryClient → System 1.
app.use('/auth', authRouter);
app.use('/products', productRouter);
app.use('/seller', sellerRouter);
app.use('/orders', orderRouter);
app.use('/tags', tagRouter);
app.use('/recommendations', recommendRouter);
app.use('/activity', recommendRouter); // POST /activity shares the recommend router

// ── 404 ────────────────────────────────────────────────────────
// Purpose: Catch-all handler for requests to undefined endpoints.
// Communication: Returns a 404 status code and an error message.
app.use((_req, res) => {
  res.status(404).json({ success: false, error: 'Route not found.' });
});

// ── Global error handler (must be last) ───────────────────────
// Purpose: Final safety net that catches any unhandled errors in the middleware chain.
// It ensures the client receives a structured JSON error response instead of an HTML stack trace.
app.use(errorHandler);

// ── Start ──────────────────────────────────────────────────────
// Purpose: Binds and listens for connections on the specified port.
// Logs configuration details to the console once the server is successfully started.
app.listen(PORT, () => {
  console.log('╔══════════════════════════════════════════╗');
  console.log('║   ShopFlow — Sales API (System 2)        ║');
  console.log(`║   Port: ${PORT}                              ║`);
  console.log('║   No Firebase SDK. No Firestore.         ║');
  console.log('╚══════════════════════════════════════════╝');
  console.log(`\nInventory System URL: ${process.env.INVENTORY_BASE_URL}`);
  console.log(`Health:  http://localhost:${PORT}/health\n`);
});

export default app;
