// FILE: src/routes/orderRoutes.ts  —  SYSTEM 2: Sales API
// POST /orders          → inventory: createOrder
// GET  /orders/history  → inventory: getOrderHistory

import { Router, Request, Response, NextFunction } from 'express';
import { inventoryApi } from '../services/inventoryClient';
import { requireAuth, requireVerifiedEmail } from '../middleware/auth';

const router = Router();

// POST /orders
router.post('/', requireAuth, requireVerifiedEmail,
  async (req: Request, res: Response, next: NextFunction) => {
    try {
      const { items } = req.body as {
        items: Array<{ productId: string; quantity: number }>;
      };
      if (!Array.isArray(items) || items.length === 0) {
        res.status(400).json({ success: false, error: 'items array is required.' });
        return;
      }
      // buyerId is injected from JWT — the client cannot override this
      const result = await inventoryApi.createOrder({
        buyerId: req.user!.userId,
        items,
      });
      res.status(201).json({ success: true, data: result });
    } catch (err) { next(err); }
  }
);

// GET /orders/history
router.get('/history', requireAuth,
  async (req: Request, res: Response, next: NextFunction) => {
    try {
      const result = await inventoryApi.getOrderHistory(req.user!.userId);
      res.json({ success: true, data: result });
    } catch (err) { next(err); }
  }
);

export default router;
