import { Suspense } from "react";
import { AppShell } from "@/components/app/AppShell";
import { LogoMark } from "@/components/brand/Logo";

// Authenticated pages render client-side after the session is restored from the
// HttpOnly refresh cookie, so they have no meaningful static shell to validate.
export const instant = false;

export default function AppLayout({ children }: LayoutProps<"/">) {
  return (
    <Suspense
      fallback={
        <div className="flex min-h-dvh items-center justify-center" role="status" aria-label="Loading GhostWork">
          <LogoMark size={36} className="animate-pulse" />
        </div>
      }
    >
      <AppShell>{children}</AppShell>
    </Suspense>
  );
}
