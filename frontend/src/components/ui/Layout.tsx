"use client";

import { ChevronLeft, ChevronRight, Search } from "lucide-react";
import { useId } from "react";
import { cx } from "./cx";

export function PageHeader({
  title,
  description,
  actions,
  eyebrow,
}: {
  title: React.ReactNode;
  description?: React.ReactNode;
  actions?: React.ReactNode;
  eyebrow?: React.ReactNode;
}) {
  return (
    <div className="mb-5 flex flex-col gap-3 sm:mb-6 sm:flex-row sm:items-end sm:justify-between">
      <div className="min-w-0">
        {eyebrow && <div className="mb-1.5">{eyebrow}</div>}
        <h1 className="text-title font-semibold text-fg">{title}</h1>
        {description && <p className="mt-1 text-body text-fg-muted">{description}</p>}
      </div>
      {actions && <div className="flex shrink-0 flex-wrap items-center gap-2">{actions}</div>}
    </div>
  );
}

export function Card({ className, children, ...props }: React.HTMLAttributes<HTMLDivElement>) {
  return (
    <div className={cx("card", className)} {...props}>
      {children}
    </div>
  );
}

export function CardHeader({ title, action, description }: { title: React.ReactNode; action?: React.ReactNode; description?: React.ReactNode }) {
  return (
    <div className="flex items-start justify-between gap-3 border-b border-line-subtle px-4 py-3 sm:px-5">
      <div className="min-w-0">
        <h2 className="text-section font-semibold">{title}</h2>
        {description && <p className="mt-0.5 text-meta text-fg-muted">{description}</p>}
      </div>
      {action}
    </div>
  );
}

export function SearchField({
  value,
  onChange,
  placeholder = "Search",
  label = "Search",
  className,
}: {
  value: string;
  onChange: (value: string) => void;
  placeholder?: string;
  label?: string;
  className?: string;
}) {
  const id = useId();
  return (
    <div className={cx("relative", className)}>
      <label htmlFor={id} className="sr-only">
        {label}
      </label>
      <Search size={15} className="pointer-events-none absolute top-1/2 left-3 -translate-y-1/2 text-fg-muted" aria-hidden="true" />
      <input
        id={id}
        type="search"
        value={value}
        onChange={(e) => onChange(e.target.value)}
        placeholder={placeholder}
        className="h-10 w-full rounded-md border border-line bg-canvas pr-3 pl-9 text-body text-fg placeholder:text-fg-muted hover:border-line-strong focus:border-violet focus:ring-2 focus:ring-violet/25 focus:outline-none sm:h-9"
      />
    </div>
  );
}

export function Pagination({
  page,
  pageSize,
  total,
  onPage,
}: {
  page: number;
  pageSize: number;
  total: number;
  onPage: (page: number) => void;
}) {
  const pages = Math.max(1, Math.ceil(total / pageSize));
  const from = total === 0 ? 0 : (page - 1) * pageSize + 1;
  const to = Math.min(page * pageSize, total);
  return (
    <nav aria-label="Pagination" className="flex items-center justify-between gap-3 px-4 py-3 text-meta text-fg-muted sm:px-5">
      <span>
        {from}–{to} of {total}
      </span>
      <div className="flex items-center gap-1">
        <button
          type="button"
          onClick={() => onPage(page - 1)}
          disabled={page <= 1}
          className="inline-flex h-8 w-8 items-center justify-center rounded-md border border-line text-fg-secondary hover:bg-hover disabled:opacity-35"
          aria-label="Previous page"
        >
          <ChevronLeft size={15} />
        </button>
        <span className="px-2 tabular-nums text-fg-secondary" aria-current="page">
          {page} / {pages}
        </span>
        <button
          type="button"
          onClick={() => onPage(page + 1)}
          disabled={page >= pages}
          className="inline-flex h-8 w-8 items-center justify-center rounded-md border border-line text-fg-secondary hover:bg-hover disabled:opacity-35"
          aria-label="Next page"
        >
          <ChevronRight size={15} />
        </button>
      </div>
    </nav>
  );
}

/** Accessible tabs (roving focus with arrow keys). Content is rendered by the caller. */
export function Tabs<T extends string>({
  value,
  onChange,
  tabs,
  label,
  className,
}: {
  value: T;
  onChange: (value: T) => void;
  tabs: { value: T; label: string; icon?: React.ElementType }[];
  label: string;
  className?: string;
}) {
  const onKeyDown = (e: React.KeyboardEvent, index: number) => {
    if (e.key !== "ArrowRight" && e.key !== "ArrowLeft" && e.key !== "ArrowDown" && e.key !== "ArrowUp") return;
    e.preventDefault();
    const delta = e.key === "ArrowRight" || e.key === "ArrowDown" ? 1 : -1;
    const next = tabs[(index + delta + tabs.length) % tabs.length];
    onChange(next.value);
    document.getElementById(`tab-${next.value}`)?.focus();
  };
  return (
    <div role="tablist" aria-label={label} className={cx("flex gap-1 overflow-x-auto", className)}>
      {tabs.map((tab, index) => {
        const selected = tab.value === value;
        return (
          <button
            key={tab.value}
            id={`tab-${tab.value}`}
            type="button"
            role="tab"
            aria-selected={selected}
            aria-controls={`panel-${tab.value}`}
            tabIndex={selected ? 0 : -1}
            onClick={() => onChange(tab.value)}
            onKeyDown={(e) => onKeyDown(e, index)}
            className={cx(
              "inline-flex h-9 shrink-0 items-center gap-2 rounded-md px-3 text-body font-medium transition-colors",
              selected ? "bg-elevated text-fg" : "text-fg-muted hover:bg-hover hover:text-fg",
            )}
          >
            {tab.icon && <tab.icon size={15} aria-hidden="true" />}
            {tab.label}
          </button>
        );
      })}
    </div>
  );
}

export function KeyValue({ label, children }: { label: string; children: React.ReactNode }) {
  return (
    <div className="flex items-baseline justify-between gap-4 py-2 text-body">
      <dt className="shrink-0 text-fg-muted">{label}</dt>
      <dd className="min-w-0 truncate text-right text-fg-secondary">{children}</dd>
    </div>
  );
}
