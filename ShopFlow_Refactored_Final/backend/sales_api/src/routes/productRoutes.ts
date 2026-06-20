// FILE: src/routes/productRoutes.ts  —  SYSTEM 2: Sales API
// GET /products        → inventory: getProducts
// GET /products/:id    → inventory: getProductById

import { Router, Request, Response, NextFunction } from 'express';
import { inventoryApi } from '../services/inventoryClient';
import { requireAuth } from '../middleware/auth';

const router = Router();

// GET /products?tagId=xxx&limit=24
router.get('/', requireAuth, async (req: Request, res: Response, next: NextFunction) => {
  try {
    const tagId = req.query.tagId as string | undefined;
    const limit = Math.min(parseInt(req.query.limit as string) || 24, 50);
    const result = await inventoryApi.getProducts({ tagId, limit });
    res.json({ success: true, data: result });
  } catch (err) { next(err); }
});

// GET /products/:id
router.get('/:id', requireAuth, async (req: Request, res: Response, next: NextFunction) => {
  try {
    const result = await inventoryApi.getProductById(req.params.id);
    res.json({ success: true, data: result });
  } catch (err) { next(err); }
});

export default router;
