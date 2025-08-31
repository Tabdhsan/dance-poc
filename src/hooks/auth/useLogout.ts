// src/hooks/auth/useLogout.ts
import { useMutation, useQueryClient } from "@tanstack/react-query";
import { authService } from "@/services/auth.service";
import { authKeys } from "@/hooks/auth/authKeys";  

export const useLogout = () => {
  const queryClient = useQueryClient();

  return useMutation({
    mutationKey: [...authKeys.all, "logout"],
    mutationFn: authService.logout,
    onSuccess: () => {
      queryClient.removeQueries({ queryKey: authKeys.all });
    },
  });
};
