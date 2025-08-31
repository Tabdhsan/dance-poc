// src/hooks/auth/useLogin.ts
import { useMutation, useQueryClient } from "@tanstack/react-query";
import { authService } from "@/services/auth.service";
import { LoginRequest, AuthResponse } from "@/types/auth.types";
import { authKeys } from "@/hooks/auth/authKeys";      

export const useLogin = () => {
  const queryClient = useQueryClient();

  return useMutation<AuthResponse, Error, LoginRequest>({
    mutationKey: [...authKeys.all, "login"],
    mutationFn: authService.login,
    onSuccess: (data) => {
      queryClient.setQueryData(authKeys.session(), data.session);
    },
  });
};
