// src/hooks/auth/useSession.ts
import { useQuery } from "@tanstack/react-query";
import { authService } from "@/services/auth.service";
import { authKeys } from "@/hooks/auth/authKeys";  

export const useSession = () => {
  return useQuery({
    queryKey: authKeys.session(),
    queryFn: authService.getSession,
  });
};
