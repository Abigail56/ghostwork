"use client";

import { Menu as MenuIcon } from "lucide-react";
import Link from "next/link";
import { usePathname } from "next/navigation";
import { useState } from "react";
import { Logo } from "@/components/brand/Logo";
import { ButtonLink } from "@/components/ui/Button";
import { cx } from "@/components/ui/cx";
import { Drawer } from "@/components/ui/Overlay";
import { useAuth } from "@/lib/auth";

export const MARKETING_LINKS = [
  { href: "/features", label: "Features" },
  { href: "/pricing", label: "Pricing" },
  { href: "/docs", label: "Docs" },
  { href: "/about", label: "About" },
];

export function SiteHeader() {
  const pathname = usePathname();
  const { status } = useAuth();
  const [open, setOpen] = useState(false);
  const signedIn = status === "authenticated";

  return (
    <header className="sticky top-0 z-40 border-b border-line-subtle bg-canvas/85 backdrop-blur-md">
      <div className="mx-auto flex h-16 max-w-6xl items-center gap-8 px-4 sm:px-6">
        <Link href="/" aria-label="GhostWork home" className="rounded-md">
          <Logo size={26} />
        </Link>
        <nav aria-label="Main" className="hidden items-center gap-1 md:flex">
          {MARKETING_LINKS.map((link) => (
            <Link
              key={link.href}
              href={link.href}
              aria-current={pathname === link.href ? "page" : undefined}
              className={cx(
                "rounded-md px-3 py-1.5 text-body transition-colors",
                pathname === link.href ? "text-fg" : "text-fg-secondary hover:text-fg",
              )}
            >
              {link.label}
            </Link>
          ))}
        </nav>
        <div className="ml-auto hidden items-center gap-2 md:flex">
          {signedIn ? (
            <ButtonLink href="/dashboard" variant="primary">
              Open dashboard
            </ButtonLink>
          ) : (
            <>
              <ButtonLink href="/login" variant="ghost">
                Sign in
              </ButtonLink>
              <ButtonLink href="/register" variant="primary">
                Get started
              </ButtonLink>
            </>
          )}
        </div>
        <button
          type="button"
          className="ml-auto inline-flex h-10 w-10 items-center justify-center rounded-md text-fg-secondary hover:bg-hover md:hidden"
          aria-label="Open menu"
          onClick={() => setOpen(true)}
        >
          <MenuIcon size={20} />
        </button>
      </div>
      <Drawer open={open} onClose={() => setOpen(false)} title="Menu">
        <nav aria-label="Mobile" className="flex flex-col gap-1 p-3">
          {MARKETING_LINKS.map((link) => (
            <Link
              key={link.href}
              href={link.href}
              onClick={() => setOpen(false)}
              className="rounded-md px-3 py-2.5 text-[0.9375rem] text-fg-secondary hover:bg-hover hover:text-fg"
            >
              {link.label}
            </Link>
          ))}
          <div className="mt-3 flex flex-col gap-2 border-t border-line-subtle pt-4">
            {signedIn ? (
              <ButtonLink href="/dashboard" variant="primary" size="lg">
                Open dashboard
              </ButtonLink>
            ) : (
              <>
                <ButtonLink href="/register" variant="primary" size="lg">
                  Get started
                </ButtonLink>
                <ButtonLink href="/login" size="lg">
                  Sign in
                </ButtonLink>
              </>
            )}
          </div>
        </nav>
      </Drawer>
    </header>
  );
}
