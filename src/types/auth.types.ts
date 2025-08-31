// src/lib/types/auth.types.ts
import { z } from "zod";
import { loginSchema, signupSchema } from "@/zodFormSchemas/auth.schema";
// Re-export ZodObjects
export const LoginZodObject = loginSchema;
export const SignupZodObject = signupSchema;

// Infer types
export type LoginFormData = z.infer<typeof LoginZodObject>;
export type SignupFormData = z.infer<typeof SignupZodObject>;

// Explicit request/response types
export type LoginRequest = LoginFormData;
export type SignupRequest = SignupFormData;

export interface AuthResponse {
  user: {
    id: string;
    email: string;
  } | null;
  session: {
    access_token: string;
    refresh_token: string;
  } | null;
}
