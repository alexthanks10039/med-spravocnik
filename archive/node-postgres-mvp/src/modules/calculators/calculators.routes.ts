import { Router } from 'express';
import { z } from 'zod';
export const calculatorsRouter=Router();
calculatorsRouter.post('/bmi',(req,res)=>{const d=z.object({weightKg:z.number().positive(),heightCm:z.number().positive()}).parse(req.body);const value=d.weightKg/((d.heightCm/100)**2);res.json({value:Number(value.toFixed(1)),unit:'kg/m2',category:value<18.5?'low':value<25?'normal':value<30?'high':'obesity'});});
calculatorsRouter.post('/egfr',(req,res)=>{const d=z.object({age:z.number().int().min(18),creatinine:z.number().positive(),sex:z.enum(['female','male'])}).parse(req.body);const k=d.sex==='female'?0.7:0.9;const alpha=d.sex==='female'?-0.241:-0.302;const ratio=d.creatinine/k;const value=142*Math.pow(Math.min(ratio,1),alpha)*Math.pow(Math.max(ratio,1),-1.2)*Math.pow(0.9938,d.age)*(d.sex==='female'?1.012:1);res.json({value:Math.round(value),unit:'mL/min/1.73m2',formula:'CKD-EPI 2021'});});
