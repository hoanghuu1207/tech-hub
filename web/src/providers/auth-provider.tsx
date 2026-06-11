"use client";

import React, { createContext, useContext, useState, useEffect, useCallback } from "react";
import { useRouter } from "next/navigation";
import Cookies from "js-cookie";
import api from "@/lib/api";
import type { User, LoginCredentials, TokenResponse } from "@/types";

interface AuthContextType {
  user: User | null;
  isLoading: boolean;
  isAuthenticated: boolean;
  login: (credentials: LoginCredentials) => Promise<void>;
  logout: () => void;
}

const AuthContext = createContext<AuthContextType | undefined>(undefined);

export function AuthProvider({ children }: { children: React.ReactNode }) {
  const [user, setUser] = useState<User | null>(null);
  const [isLoading, setIsLoading] = useState(true);
  const router = useRouter();

  // Restore user from cookie on mount
  useEffect(() => {
    const storedUser = Cookies.get("admin_user");
    const token = Cookies.get("access_token");

    if (storedUser && token) {
      try {
        setUser(JSON.parse(storedUser));
      } catch {
        Cookies.remove("admin_user");
      }
    }
    setIsLoading(false);
  }, []);

  const login = useCallback(
    async (credentials: LoginCredentials) => {
      // Backend wraps response in StandardResponse: { success, message, data: TokenResponse }
      const response = await api.post<{ success: boolean; message: string; data: TokenResponse }>(
        "/auth/login",
        credentials
      );
      
      const tokenData = response.data.data;

      // Check admin role
      if (tokenData.user.role !== "admin") {
        throw new Error("Tài khoản không có quyền admin");
      }

      // Save tokens
      Cookies.set("access_token", tokenData.access_token, { expires: 1 });
      Cookies.set("refresh_token", tokenData.refresh_token, { expires: 7 });
      Cookies.set("admin_user", JSON.stringify(tokenData.user), { expires: 1 });

      setUser(tokenData.user);
      router.push("/dashboard");
    },
    [router]
  );

  const logout = useCallback(() => {
    // Call backend logout if needed
    api.post("/auth/logout").catch(() => {});

    Cookies.remove("access_token");
    Cookies.remove("refresh_token");
    Cookies.remove("admin_user");
    setUser(null);
    router.push("/login");
  }, [router]);

  return (
    <AuthContext.Provider
      value={{
        user,
        isLoading,
        isAuthenticated: !!user,
        login,
        logout,
      }}
    >
      {children}
    </AuthContext.Provider>
  );
}

export function useAuth() {
  const context = useContext(AuthContext);
  if (!context) {
    throw new Error("useAuth must be used within an AuthProvider");
  }
  return context;
}
