"use client";

import { Bell, CheckCheck, LogOut, Menu as MenuIcon, Search, Settings, User } from "lucide-react";
import Link from "next/link";
import { usePathname, useRouter } from "next/navigation";
import { useEffect, useRef, useState } from "react";
import { cx } from "@/components/ui/cx";
import { Menu } from "@/components/ui/Overlay";
import { useAuth } from "@/lib/auth";
import { initials, timeAgo } from "@/lib/format";
import { useMarkNotifications, useNotifications } from "@/lib/queries";
import { pageTitle } from "./nav";

function GlobalSearch() {
  const router = useRouter();
  const [value, setValue] = useState("");
  const input = useRef<HTMLInputElement>(null);
  useEffect(() => {
    const onKey = (e: KeyboardEvent) => {
      if ((e.metaKey || e.ctrlKey) && e.key.toLowerCase() === "k") {
        e.preventDefault();
        input.current?.focus();
      }
    };
    window.addEventListener("keydown", onKey);
    return () => window.removeEventListener("keydown", onKey);
  }, []);
  return (
    <form
      role="search"
      onSubmit={(e) => {
        e.preventDefault();
        router.push(`/workflows?q=${encodeURIComponent(value.trim())}`);
      }}
      className="relative hidden w-full max-w-xs md:block"
    >
      <label htmlFor="global-search" className="sr-only">
        Search workflows
      </label>
      <Search size={15} className="pointer-events-none absolute top-1/2 left-3 -translate-y-1/2 text-fg-muted" aria-hidden="true" />
      <input
        ref={input}
        id="global-search"
        value={value}
        onChange={(e) => setValue(e.target.value)}
        placeholder="Search workflows…"
        className="h-9 w-full rounded-md border border-line bg-surface pr-12 pl-9 text-body text-fg placeholder:text-fg-muted hover:border-line-strong focus:border-violet focus:ring-2 focus:ring-violet/25 focus:outline-none"
      />
      <kbd className="pointer-events-none absolute top-1/2 right-2 -translate-y-1/2 rounded border border-line px-1.5 font-sans text-micro text-fg-muted">
        Ctrl K
      </kbd>
    </form>
  );
}

function Notifications() {
  const { data } = useNotifications();
  const mark = useMarkNotifications();
  const router = useRouter();
  const [open, setOpen] = useState(false);
  const box = useRef<HTMLDivElement>(null);
  useEffect(() => {
    if (!open) return;
    const onDown = (e: PointerEvent) => !box.current?.contains(e.target as Node) && setOpen(false);
    const onKey = (e: KeyboardEvent) => e.key === "Escape" && setOpen(false);
    document.addEventListener("pointerdown", onDown);
    document.addEventListener("keydown", onKey);
    return () => {
      document.removeEventListener("pointerdown", onDown);
      document.removeEventListener("keydown", onKey);
    };
  }, [open]);
  const unread = data?.unread ?? 0;
  return (
    <div ref={box} className="relative">
      <button
        type="button"
        onClick={() => setOpen((v) => !v)}
        aria-expanded={open}
        aria-label={unread ? `Notifications, ${unread} unread` : "Notifications"}
        className="relative flex h-9 w-9 items-center justify-center rounded-md text-fg-secondary hover:bg-hover hover:text-fg"
      >
        <Bell size={18} />
        {unread > 0 && (
          <span className="absolute top-1 right-1 flex h-4 min-w-4 items-center justify-center rounded-full bg-violet px-1 text-[10px] font-bold text-canvas">
            {unread > 9 ? "9+" : unread}
          </span>
        )}
      </button>
      {open && (
        <div className="fixed inset-x-3 top-14 z-50 animate-pop-in rounded-lg border border-line bg-elevated shadow-pop sm:absolute sm:inset-x-auto sm:top-full sm:right-0 sm:mt-1.5 sm:w-[22rem]">
          <div className="flex items-center justify-between border-b border-line-subtle px-4 py-2.5">
            <p className="text-body font-semibold">Notifications</p>
            {unread > 0 && (
              <button
                type="button"
                onClick={() => mark.mutate("all")}
                className="inline-flex items-center gap-1 text-meta text-violet hover:underline"
              >
                <CheckCheck size={14} /> Mark all read
              </button>
            )}
          </div>
          <ul className="max-h-[60vh] overflow-y-auto py-1">
            {!data?.items.length && <li className="px-4 py-8 text-center text-body text-fg-muted">You&apos;re all caught up.</li>}
            {data?.items.map((n) => (
              <li key={n.id}>
                <button
                  type="button"
                  onClick={() => {
                    if (!n.read_at) mark.mutate(n.id);
                    setOpen(false);
                    if (n.link) router.push(n.link);
                  }}
                  className="flex w-full gap-3 px-4 py-2.5 text-left hover:bg-hover"
                >
                  <span
                    className={cx(
                      "mt-1.5 h-2 w-2 shrink-0 rounded-full",
                      n.read_at ? "bg-transparent" : n.kind === "execution_failed" ? "bg-danger" : n.kind === "security" ? "bg-warning" : "bg-success",
                    )}
                    aria-hidden="true"
                  />
                  <span className="min-w-0">
                    <span className={cx("block text-body", n.read_at ? "text-fg-secondary" : "font-medium text-fg")}>{n.title}</span>
                    {n.body && <span className="mt-0.5 line-clamp-2 block text-meta text-fg-muted">{n.body}</span>}
                    <span className="mt-0.5 block text-micro text-fg-muted">{timeAgo(n.created_at)}</span>
                  </span>
                </button>
              </li>
            ))}
          </ul>
        </div>
      )}
    </div>
  );
}

export function Topbar({ onOpenNav }: { onOpenNav: () => void }) {
  const pathname = usePathname();
  const router = useRouter();
  const { user, logout } = useAuth();
  return (
    <header className="sticky top-0 z-30 flex h-topbar shrink-0 items-center gap-3 border-b border-line-subtle bg-canvas/90 px-3 backdrop-blur-md sm:px-5">
      <button
        type="button"
        onClick={onOpenNav}
        className="flex h-10 w-10 items-center justify-center rounded-md text-fg-secondary hover:bg-hover md:hidden"
        aria-label="Open navigation"
      >
        <MenuIcon size={20} />
      </button>
      <p className="text-body font-medium text-fg-secondary">{pageTitle(pathname)}</p>
      <div className="ml-auto flex flex-1 items-center justify-end gap-1.5">
        <GlobalSearch />
        <Link
          href="/workflows"
          className="flex h-9 w-9 items-center justify-center rounded-md text-fg-secondary hover:bg-hover md:hidden"
          aria-label="Search workflows"
        >
          <Search size={18} />
        </Link>
        <Notifications />
        <Menu
          label="Account"
          trigger={(props) => (
            <button
              type="button"
              {...props}
              aria-label="Account menu"
              className="ml-0.5 flex h-9 w-9 items-center justify-center rounded-full bg-violet-soft text-meta font-semibold text-violet ring-violet/40 hover:ring-2"
            >
              {user ? initials(user.full_name) : <User size={16} />}
            </button>
          )}
          items={[
            { label: "Profile", icon: User, onSelect: () => router.push("/settings?tab=profile") },
            { label: "Settings", icon: Settings, onSelect: () => router.push("/settings") },
            "separator",
            { label: "Log out", icon: LogOut, onSelect: () => logout() },
          ]}
        />
      </div>
    </header>
  );
}
