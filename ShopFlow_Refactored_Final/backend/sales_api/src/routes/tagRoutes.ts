// FILE: src/routes/tagRoutes.ts  —  SYSTEM 2: Sales API
// GET  /tags              → inventory: getAllTags
// GET  /tags/:id/search   → inventory: searchByTag (BFS)
// POST /tags              → inventory: createTag (sellers only)

import { Router, Request, Response, NextFunction } from 'express';
import { inventoryApi } from '../services/inventoryClient';
import { requireAuth, requireSeller } from '../middleware/auth';

const router = Router();

// GET /tags
router.get('/', requireAuth, async (_req: Request, res: Response, next: NextFunction) => {
  try {
    const result = await inventoryApi.getAllTags();
    res.json({ success: true, data: result });
  } catch (err) { next(err); }
});

// GET /tags/:id/search
router.get('/:id/search', requireAuth,
  async (req: Request, res: Response, next: NextFunction) => {
    try {
      const result = await inventoryApi.searchByTag(req.params.id);
      res.json({ success: true, data: result });
    } catch (err) { next(err); }
  }
);

// POST /tags  (sellers create tags)
router.post('/', requireAuth, requireSeller,
  async (req: Request, res: Response, next: NextFunction) => {
    try {
      const { name, parentTagId } = req.body as {
        name: string; parentTagId?: string;
      };
      if (!name?.trim()) {
        res.status(400).json({ success: false, error: 'Tag name required.' });
        return;
      }
      const result = await inventoryApi.createTag({ name, parentTagId });
      res.status(201).json({ success: true, data: result });
    } catch (err) { next(err); }
  }
);

export default router;
