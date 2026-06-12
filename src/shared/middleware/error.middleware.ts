import { NextFunction, Request, Response } from 'express';
import { ZodError } from 'zod';
export class AppError extends Error { constructor(message:string, public statusCode=400){ super(message); } }
export function errorMiddleware(error:unknown,_req:Request,res:Response,_next:NextFunction){
  if(error instanceof ZodError) return res.status(400).json({message:'Validation error',issues:error.flatten()});
  if(error instanceof AppError) return res.status(error.statusCode).json({message:error.message});
  console.error(error); return res.status(500).json({message:'Internal server error'});
}
