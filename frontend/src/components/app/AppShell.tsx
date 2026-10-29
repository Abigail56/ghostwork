"use client";

import { usePathname, useRouter } from "next/navigation";
import { useEffect, useState } from "react";
import { LogoMark } from "@/components/brand/Logo";
import { cx } from "@/components/ui/cx";
import { Drawer } from "@/components/ui/Overlay";
import { useAuth } from "@/lib/auth";
import { SidebarContent } from "./Sidebar";
import { Topbar } from "./Topbar";

export function AppShell({ children }: { children: React.ReactNode }) {
  const { status } = useAuth();
  const router = useRouter();
  const pathname = usePathname();
  const [navOpen, setNavOpen] = useState(false);
  const fullBleed = pathname.endsWith("/builder");

  useEffect(() => {
    if (status === "anonymous") {
      router.replace(`/login?next=${encodeURIComponent(pathname)}`);
    }
  }, [status, pathname, router]);

  if (status !== "authenticated") {
    return (
      <div className="flex min-h-dvh items-center justify-center" role="status" aria-label="Loading GhostWork">
        <LogoMark size={36} className="animate-pulse" />
      </div>
    );
  }

  return (
    <div className="flex min-h-dvh">
      <a href="#app-main" className="sr-only z-50 rounded-md bg-violet px-3 py-2 text-canvas focus:not-sr-only focus:fixed focus:top-3 focus:left-3">
        Skip to content
      </a>
      {/* Tablet & builder: icon rail. Desktop: full sidebar. Mobile: drawer. */}
      <aside
        className={cx(
          "sticky top-0 hidden h-dvh shrink-0 border-r border-line-subtle bg-sidebar md:block",
          fullBleed ? "w-sidebar-compact" : "w-sidebar-compact xl:w-sidebar",
        )}
      >
        <div className={cx("h-full", !fullBleed && "xl:hidden")}>
          <SidebarContent compact />
        </div>
        {!fullBleed && (
          <div className="hidden h-full xl:block">
            <SidebarContent />
          </div>
        )}
      </aside>
      <Drawer open={navOpen} onClose={() => setNavOpen(false)} title="Navigation" side="left" width="w-[min(17rem,calc(100vw-3rem))]">
        <SidebarContent onNavigate={() => setNavOpen(false)} />
      </Drawer>
      <div className="flex min-w-0 flex-1 flex-col">
        <Topbar onOpenNav={() => setNavOpen(true)} />
        <main
          id="app-main"
          className={cx("min-w-0 flex-1", fullBleed ? "flex flex-col" : "mx-auto w-full max-w-[1400px] px-4 py-5 sm:px-6 sm:py-7")}
        >
          {children}
        </main>
      </div>
    </div>
  );
}
