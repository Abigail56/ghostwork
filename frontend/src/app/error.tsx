"use client";

import { AlertTriangle } from "lucide-react";

export default function GlobalError({ reset }: { error: Error & { digest?: string }; reset: () => void }) {
  return (
    <main className="flex min-h-[60dvh] flex-col items-center justify-center px-6 text-center">
      <span className="flex h-11 w-11 items-center justify-center rounded-lg bg-danger-soft text-danger">
        <AlertTriangle size={20} aria-hidden="true" />
      </span>
      <h1 className="mt-4 text-title font-semibold">Something went wrong</h1>
      <p className="mt-2 max-w-sm text-body text-fg-muted">An unexpected error stopped this page from loading. Your data is safe.</p>
      <button type="button" onClick={reset} className="mt-5 inline-flex h-9 items-center rounded-md bg-violet px-3.5 text-body font-semibold text-canvas">
        Try again
      </button>
    </main>
  );
}
