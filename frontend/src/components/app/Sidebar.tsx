"use client";

import { LogOut } from "lucide-react";
import Link from "next/link";
import { usePathname } from "next/navigation";
import { Logo, LogoMark } from "@/components/brand/Logo";
import { cx } from "@/components/ui/cx";
import { useAuth } from "@/lib/auth";
import { initials } from "@/lib/format";
import { APP_NAV, HELP_NAV, isActive } from "./nav";

function NavLink({
  href,
  label,
  icon: Icon,
  compact,
  onNavigate,
}: {
  href: string;
  label: string;
  icon: React.ElementType;
  compact: boolean;
  onNavigate?: () => void;
}) {
  const pathname = usePathname();
  const active = isActive(pathname, href);
  return (
    <Link
      href={href}
      onClick={onNavigate}
      aria-current={active ? "page" : undefined}
      title={compact ? label : undefined}
      className={cx(
        "group relative flex h-9 items-center gap-3 rounded-md text-body font-medium transition-colors",
        compact ? "w-10 justify-center" : "px-3",
        active ? "bg-violet-soft text-fg" : "text-fg-secondary hover:bg-hover hover:text-fg",
      )}
    >
      {active && <span className="absolute top-2 bottom-2 left-0 w-[2px] rounded-full bg-violet" aria-hidden="true" />}
      <Icon size={17} className={active ? "text-violet" : "text-fg-muted group-hover:text-fg-secondary"} aria-hidden="true" />
      {compact ? <span className="sr-only">{label}</span> : label}
    </Link>
  );
}

export function SidebarContent({ compact = false, onNavigate }: { compact?: boolean; onNavigate?: () => void }) {
  const { user, logout } = useAuth();
  return (
    <div className={cx("flex h-full flex-col py-4", compact ? "items-center px-2" : "px-3")}>
      <Link href="/dashboard" onClick={onNavigate} aria-label="GhostWork dashboard" className={cx("mb-6 flex h-8 items-center rounded-md", !compact && "px-2")}>
        {compact ? <LogoMark size={26} /> : <Logo size={26} />}
      </Link>
      <nav aria-label="Application" className="flex flex-col gap-0.5">
        {APP_NAV.map((item) => (
          <NavLink key={item.href} {...item} compact={compact} onNavigate={onNavigate} />
        ))}
      </nav>
      <div className="mt-auto flex flex-col gap-0.5 pt-4">
        <NavLink {...HELP_NAV} compact={compact} onNavigate={onNavigate} />
        <button
          type="button"
          onClick={() => logout()}
          title={compact ? "Log out" : undefined}
          className={cx(
            "flex h-9 items-center gap-3 rounded-md text-body font-medium text-fg-secondary transition-colors hover:bg-hover hover:text-fg",
            compact ? "w-10 justify-center" : "px-3",
          )}
        >
          <LogOut size={17} className="text-fg-muted" aria-hidden="true" />
          {compact ? <span className="sr-only">Log out</span> : "Log out"}
        </button>
        {user && !compact && (
          <div className="mt-3 flex items-center gap-2.5 rounded-lg border border-line-subtle bg-surface px-2.5 py-2">
            <span className="flex h-8 w-8 shrink-0 items-center justify-center rounded-full bg-violet-soft text-meta font-semibold text-violet">
              {initials(user.full_name)}
            </span>
            <div className="min-w-0">
              <p className="truncate text-meta font-medium text-fg">{user.full_name}</p>
              <p className="truncate text-micro text-fg-muted">{user.email}</p>
            </div>
          </div>
        )}
      </div>
    </div>
  );
}
