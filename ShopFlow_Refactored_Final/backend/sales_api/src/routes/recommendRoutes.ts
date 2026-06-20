// FILE: src/routes/recommendRoutes.ts  —  SYSTEM 2: Sales API
// GET  /recommendations  → inventory: getRecommendations
// POST /activity         → inventory: trackActivity (fire-and-forget)

import { Router, Request, Response, NextFunction } from 'express';
import { inventoryApi } from '../services/inventoryClient';
import { requireAuth } from '../middleware/auth';

const router = Router();

// GET /recommendations
router.get('/', requireAuth,
  async (req: Request, res: Response, next: NextFunction) => {
    try {
      const topN = Math.min(parseInt(req.query.topN as string) || 6, 20);
      const result = await inventoryApi.getRecommendations({
        userId: req.user!.userId,
        topN,
      });
      res.json({ success: true, data: result });
    } catch (err) { next(err); }
  }
);

// POST /activity  (fire-and-forget: never blocks the response)
router.post('/activity', requireAuth,
  async (req: Request, res: Response, next: NextFunction) => {
    try {
      const { type, entityId, query } = req.body as {
        type: string; entityId?: string; query?: string;
      };
      // Respond immediately — tracking should never slow down the app
      res.json({ success: true, data: { recorded: true } });
      // Then actually record it (async, errors are silent)
      inventoryApi
        .trackActivity({ userId: req.user!.userId, type, entityId, query })
        .catch((e: Error) => console.warn('Activity track failed:', e.message));
    } catch (err) { next(err); }
  }
);

export default router;
