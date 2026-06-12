import { NextFunction, Request, Response } from 'express';
import jwt from 'jsonwebtoken';
import { env } from '../../config/env.js';
import { AppError } from './error.middleware.js';
type JwtPayload={userId:string;role:'USER'|'ADMIN'};
declare global { namespace Express { interface Request { user?:JwtPayload } } }
export function authMiddleware(req:Request,_res:Response,next:NextFunction){ const header=req.headers.authorization; if(!header?.startsWith('Bearer ')) throw new AppError('Unauthorized',401); try{req.user=jwt.verify(header.slice(7),env.JWT_SECRET) as JwtPayload;next();}catch{throw new AppError('Invalid token',401);} }
export function adminMiddleware(req:Request,_res:Response,next:NextFunction){if(req.user?.role!=='ADMIN') throw new AppError('Forbidden',403);next();}
