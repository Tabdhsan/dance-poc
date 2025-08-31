// src/hooks/auth/useSignup.ts
import { useMutation, useQueryClient } from "@tanstack/react-query";
import { authService } from "@/services/auth.service";
import { SignupRequest, AuthResponse } from "@/types/auth.types";
import { authKeys } from "@/hooks/auth/authKeys";      

export const useSignup = () => {
  const queryClient = useQueryClient();

  return useMutation<AuthResponse, Error, SignupRequest>({
    mutationKey: [...authKeys.all, "signup"],
    mutationFn: authService.signup,
    onSuccess: (data) => {
      queryClient.setQueryData(authKeys.session(), data.session);
    },
  });
};
