// src/services/auth.service.ts
import { supabase } from "@/supabaseClient";
import { LoginRequest, SignupRequest, AuthResponse } from "@/types/auth.types";

export const authService = {
  login: async (data: LoginRequest): Promise<AuthResponse> => {
    const { data: session, error } = await supabase.auth.signInWithPassword({
      email: data.email,
      password: data.password,
    });
    if (error) throw error;
    return {
      user: {
        id: session.user.id,
        email: session.user.email || "",
      },
      session: session.session,
    };
  },

  signup: async (data: SignupRequest): Promise<AuthResponse> => {
    const { data: session, error } = await supabase.auth.signUp({
      email: data.email,
      password: data.password,
    });
    if (error) throw error;
    return {
      user: {
        id: session.user?.id || "",
        email: session.user?.email || "",
      },
      session: session.session,
    };
  },

  logout: async () => {
    const { error } = await supabase.auth.signOut();
    if (error) throw error;
  },

  getSession: async (): Promise<AuthResponse["session"]> => {
    const { data, error } = await supabase.auth.getSession();
    if (error) throw error;
    return data.session;
  },
};
