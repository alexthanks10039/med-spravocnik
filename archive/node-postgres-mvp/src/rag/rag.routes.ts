import { Router } from 'express';
import { z } from 'zod';
import { ragLibrary, searchRag } from './library.js';
export const ragRouter=Router();
ragRouter.get('/',(req,res)=>{const parsed=z.object({q:z.string().default(''),space:z.enum(['commercial','development','content']).optional()}).parse(req.query);res.json({spaces:Object.keys(ragLibrary),items:searchRag(parsed.q,parsed.space)});});
