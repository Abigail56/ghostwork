import type { TokenResponse } from "./types";

export const API_BASE_URL = (process.env.NEXT_PUBLIC_API_BASE_URL ?? "http://localhost:8000").replace(/\/$/, "");
const API = `${API_BASE_URL}/api/v1`;

export class ApiError extends Error {
  status: number;
  issues: { message: string; node_id: string | null; field: string | null }[];

  constructor(status: number, message: string, issues: ApiError["issues"] = []) {
    super(message);
    this.status = status;
    this.issues = issues;
  }
}

type Query = Record<string, string | number | boolean | null | undefined>;

interface RequestOptions {
  method?: "GET" | "POST" | "PATCH" | "PUT" | "DELETE";
  body?: unknown;
  query?: Query;
  /** Attach the access token and refresh on 401. Default true. */
  auth?: boolean;
  signal?: AbortSignal;
}

let accessToken: string | null = null;
let onSessionLost: (() => void) | null = null;
let refreshInFlight: Promise<TokenResponse | null> | null = null;

export function setAccessToken(token: string | null) {
  accessToken = token;
}

export function setSessionLostHandler(handler: (() => void) | null) {
  onSessionLost = handler;
}

function buildUrl(path: string, query?: Query) {
  const url = new URL(`${API}${path}`);
  for (const [key, value] of Object.entries(query ?? {})) {
    if (value !== undefined && value !== null && value !== "") url.searchParams.set(key, String(value));
  }
  return url.toString();
}

async function parseError(response: Response): Promise<ApiError> {
  let message = `Request failed (${response.status}).`;
  let issues: ApiError["issues"] = [];
  try {
    const data = await response.json();
    const detail = data?.detail;
    if (typeof detail === "string") message = detail;
    else if (detail && typeof detail === "object" && !Array.isArray(detail)) {
      message = detail.message ?? message;
      issues = detail.issues ?? [];
    } else if (Array.isArray(detail)) {
      // FastAPI request validation errors
      message = detail
        .map((d: { msg?: string; loc?: string[] }) => {
          const field = d.loc?.filter((p) => p !== "body").join(".");
          return `${field ? `${field}: ` : ""}${(d.msg ?? "").replace(/^Value error, /, "")}`;
        })
        .join(" ");
    }
  } catch {
    /* non-JSON error body */
  }
  if (response.status === 429 && !message.includes("Too many")) message = "Too many requests. Please wait a moment.";
  return new ApiError(response.status, message, issues);
}

async function rawFetch(url: string, init: RequestInit): Promise<Response> {
  try {
    return await fetch(url, init);
  } catch (error) {
    if ((error as Error).name === "AbortError") throw error;
    throw new ApiError(0, "Can't reach the GhostWork API. Check your connection and that the server is running.");
  }
}

/** Exchange the HttpOnly refresh cookie for a new access token. Deduplicated across callers. */
export function refreshSession(): Promise<TokenResponse | null> {
  if (!refreshInFlight) {
    refreshInFlight = (async () => {
      for (let attempt = 0; attempt < 2; attempt++) {
        const response = await rawFetch(`${API}/auth/refresh`, {
          method: "POST",
          credentials: "include",
          headers: { "X-GhostWork-CSRF": "1" },
        });
        if (response.status === 204) {
          accessToken = null;
          return null;
        }
        if (response.ok) {
          const data = (await response.json()) as TokenResponse;
          accessToken = data.access_token;
          return data;
        }
        // 409: another tab rotated the cookie a moment ago; retry with the new cookie.
        if (response.status === 409 && attempt === 0) {
          await new Promise((r) => setTimeout(r, 350));
          continue;
        }
        if (response.status === 401 || response.status === 403) {
          accessToken = null;
          return null;
        }
        throw await parseError(response);
      }
      return null;
    })().finally(() => {
      refreshInFlight = null;
    });
  }
  return refreshInFlight;
}

export async function api<T>(path: string, options: RequestOptions = {}): Promise<T> {
  const { method = "GET", body, query, auth = true, signal } = options;
  const send = () => {
    const headers: Record<string, string> = {};
    if (body !== undefined) headers["Content-Type"] = "application/json";
    if (auth && accessToken) headers.Authorization = `Bearer ${accessToken}`;
    return rawFetch(buildUrl(path, query), {
      method,
      headers,
      body: body !== undefined ? JSON.stringify(body) : undefined,
      credentials: path.startsWith("/auth/") ? "include" : "omit",
      signal,
    });
  };

  let response = await send();
  if (response.status === 401 && auth) {
    const refreshed = await refreshSession();
    if (refreshed) {
      response = await send();
    } else {
      onSessionLost?.();
      throw new ApiError(401, "Your session has ended. Please sign in again.");
    }
  }
  if (!response.ok) throw await parseError(response);
  if (response.status === 204) return undefined as T;
  return (await response.json()) as T;
}

/** POST to an auth endpoint that sets or clears the refresh cookie. */
export async function authRequest<T>(path: string, body?: unknown): Promise<T> {
  const response = await rawFetch(`${API}${path}`, {
    method: "POST",
    credentials: "include",
    headers: { "Content-Type": "application/json", "X-GhostWork-CSRF": "1" },
    body: body !== undefined ? JSON.stringify(body) : undefined,
  });
  if (!response.ok) throw await parseError(response);
  return (await response.json()) as T;
}
