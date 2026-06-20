// FILE: src/routes/sellerRoutes.ts  —  SYSTEM 2: Sales API
// POST /seller/products   → inventory: addProduct
// POST /seller/stock      → inventory: addStock
// GET  /seller/inventory  → inventory: getSellerInventory
// POST /seller/assign-tag → inventory: assignTagToProduct

import { Router, Request, Response, NextFunction } from 'express';
import { inventoryApi } from '../services/inventoryClient';
import { requireAuth, requireSeller, requireVerifiedEmail } from '../middleware/auth';

const router = Router();

// POST /seller/products
router.post('/products',
  requireAuth, requireSeller, requireVerifiedEmail,
  async (req: Request, res: Response, next: NextFunction) => {
    try {
      const { name, price, quantity, tags } = req.body as {
        name: string; price: number; quantity: number; tags?: string[];
      };
      if (!name || price === undefined || quantity === undefined) {
        res.status(400).json({ success: false, error: 'name, price, quantity required.' });
        return;
      }
      const result = await inventoryApi.addProduct({
        name, price, quantity,
        tags: Array.isArray(tags) ? tags : [],
        sellerId: req.user!.userId, // from JWT — cannot be spoofed
      });
      res.status(201).json({ success: true, data: result });
    } catch (err) { next(err); }
  }
);

// POST /seller/stock
router.post('/stock',
  requireAuth, requireSeller, requireVerifiedEmail,
  async (req: Request, res: Response, next: NextFunction) => {
    try {
      const { productId, quantityToAdd } = req.body as {
        productId: string; quantityToAdd: number;
      };
      if (!productId || !quantityToAdd) {
        res.status(400).json({ success: false, error: 'productId and quantityToAdd required.' });
        return;
      }
      const result = await inventoryApi.addStock({
        productId, quantityToAdd, sellerId: req.user!.userId,
      });
      res.json({ success: true, data: result });
    } catch (err) { next(err); }
  }
);

// GET /seller/inventory
router.get('/inventory', requireAuth, requireSeller,
  async (req: Request, res: Response, next: NextFunction) => {
    try {
      const result = await inventoryApi.getSellerInventory(req.user!.userId);
      res.json({ success: true, data: result });
    } catch (err) { next(err); }
  }
);

// POST /seller/assign-tag
router.post('/assign-tag', requireAuth, requireSeller,
  async (req: Request, res: Response, next: NextFunction) => {
    try {
      const { productId, tagId } = req.body as { productId: string; tagId: string; };
      if (!productId || !tagId) {
        res.status(400).json({ success: false, error: 'productId and tagId required.' });
        return;
      }
      const result = await inventoryApi.assignTagToProduct({
        productId, tagId, sellerId: req.user!.userId,
      });
      res.json({ success: true, data: result });
    } catch (err) { next(err); }
  }
);

export default router;
