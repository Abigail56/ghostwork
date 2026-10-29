"use client";

import { useQueryClient } from "@tanstack/react-query";
import { createContext, useCallback, useContext, useEffect, useMemo, useRef, useState } from "react";
import { api, authRequest, refreshSession, setAccessToken, setSessionLostHandler } from "./api";
import type { TokenResponse, User } from "./types";

type Status = "loading" | "authenticated" | "anonymous";

interface AuthContextValue {
  status: Status;
  user: User | null;
  login: (email: string, password: string) => Promise<void>;
  register: (fullName: string, email: string, password: string) => Promise<void>;
  logout: () => Promise<void>;
  setUser: (user: User) => void;
}

const AuthContext = createContext<AuthContextValue | null>(null);
const CHANNEL = "ghostwork-auth";

function applyPreferences(user: User | null) {
  const root = document.documentElement;
  if (!user) {
    root.removeAttribute("data-density");
    root.removeAttribute("data-motion");
    return;
  }
  root.dataset.density = user.density;
  if (user.reduce_motion === "system") root.removeAttribute("data-motion");
  else root.dataset.motion = user.reduce_motion;
}

export function AuthProvider({ children }: { children: React.ReactNode }) {
  const queryClient = useQueryClient();
  const [status, setStatus] = useState<Status>("loading");
  const [user, setUserState] = useState<User | null>(null);
  const refreshTimer = useRef<ReturnType<typeof setTimeout> | null>(null);
  const channel = useRef<BroadcastChannel | null>(null);

  const clearSession = useCallback(() => {
    setAccessToken(null);
    setUserState(null);
    setStatus("anonymous");
    applyPreferences(null);
    queryClient.clear();
    if (refreshTimer.current) clearTimeout(refreshTimer.current);
  }, [queryClient]);

  const accept = useCallback((data: TokenResponse) => {
    setAccessToken(data.access_token);
    setUserState(data.user);
    setStatus("authenticated");
    applyPreferences(data.user);
    // Refresh one minute before the access token expires.
    if (refreshTimer.current) clearTimeout(refreshTimer.current);
    const delay = Math.max(new Date(data.expires_at).getTime() - Date.now() - 60_000, 10_000);
    refreshTimer.current = setTimeout(async () => {
      try {
        const next = await refreshSession();
        if (next) acceptRef.current(next);
        else clearSession();
      } catch {
        /* network blip: the next API call will retry the refresh */
      }
    }, delay);
  }, [clearSession]);
  const acceptRef = useRef(accept);
  useEffect(() => {
    acceptRef.current = accept;
  }, [accept]);

  useEffect(() => {
    let cancelled = false;
    refreshSession()
      .then((data) => {
        if (cancelled) return;
        if (data) accept(data);
        else clearSession();
      })
      .catch(() => !cancelled && clearSession());

    setSessionLostHandler(() => clearSession());
    if ("BroadcastChannel" in window) {
      channel.current = new BroadcastChannel(CHANNEL);
      channel.current.onmessage = (event) => {
        if (event.data === "logout") clearSession();
      };
    }
    return () => {
      cancelled = true;
      setSessionLostHandler(null);
      channel.current?.close();
      if (refreshTimer.current) clearTimeout(refreshTimer.current);
    };
  }, [accept, clearSession]);

  const login = useCallback(
    async (email: string, password: string) => {
      accept(await authRequest<TokenResponse>("/auth/login", { email, password }));
    },
    [accept],
  );

  const register = useCallback(
    async (fullName: string, email: string, password: string) => {
      accept(await authRequest<TokenResponse>("/auth/register", { full_name: fullName, email, password }));
    },
    [accept],
  );

  const logout = useCallback(async () => {
    try {
      await authRequest("/auth/logout");
    } finally {
      channel.current?.postMessage("logout");
      clearSession();
    }
  }, [clearSession]);

  const setUser = useCallback((next: User) => {
    setUserState(next);
    applyPreferences(next);
  }, []);

  const value = useMemo(
    () => ({ status, user, login, register, logout, setUser }),
    [status, user, login, register, logout, setUser],
  );
  return <AuthContext.Provider value={value}>{children}</AuthContext.Provider>;
}

export function useAuth() {
  const context = useContext(AuthContext);
  if (!context) throw new Error("useAuth must be used inside AuthProvider");
  return context;
}

export function useRequiredUser(): User {
  const { user } = useAuth();
  if (!user) throw new Error("useRequiredUser used outside an authenticated route");
  return user;
}

export { api };
