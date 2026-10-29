import { AlertTriangle, RefreshCw } from "lucide-react";
import { cx } from "./cx";

export function Spinner({ size = 16, className }: { size?: number; className?: string }) {
  return (
    <svg
      width={size}
      height={size}
      viewBox="0 0 24 24"
      className={cx("animate-spin", className)}
      role="presentation"
      aria-hidden="true"
    >
      <circle cx="12" cy="12" r="9" stroke="currentColor" strokeOpacity="0.25" strokeWidth="3" fill="none" />
      <path d="M21 12a9 9 0 0 0-9-9" stroke="currentColor" strokeWidth="3" strokeLinecap="round" fill="none" />
    </svg>
  );
}

export function Skeleton({ className }: { className?: string }) {
  return <div className={cx("animate-pulse rounded-md bg-elevated", className)} aria-hidden="true" />;
}

export function LoadingBlock({ label = "Loading", rows = 3 }: { label?: string; rows?: number }) {
  return (
    <div role="status" aria-label={label} className="flex flex-col gap-2.5">
      {Array.from({ length: rows }).map((_, i) => (
        <Skeleton key={i} className={cx("h-10", i === rows - 1 && "w-2/3")} />
      ))}
      <span className="sr-only">{label}…</span>
    </div>
  );
}

export function EmptyState({
  icon,
  title,
  description,
  action,
  className,
}: {
  icon?: React.ReactNode;
  title: string;
  description?: React.ReactNode;
  action?: React.ReactNode;
  className?: string;
}) {
  return (
    <div className={cx("flex flex-col items-center justify-center px-6 py-12 text-center", className)}>
      {icon && (
        <div className="mb-4 flex h-11 w-11 items-center justify-center rounded-lg border border-line bg-elevated text-fg-secondary">
          {icon}
        </div>
      )}
      <h3 className="text-section font-semibold text-fg">{title}</h3>
      {description && <p className="mt-1.5 max-w-sm text-body text-fg-muted">{description}</p>}
      {action && <div className="mt-5 flex flex-wrap justify-center gap-2">{action}</div>}
    </div>
  );
}

export function ErrorState({
  title = "Something went wrong",
  error,
  onRetry,
  className,
}: {
  title?: string;
  error?: unknown;
  onRetry?: () => void;
  className?: string;
}) {
  const message = error instanceof Error ? error.message : typeof error === "string" ? error : undefined;
  return (
    <div role="alert" className={cx("flex flex-col items-center px-6 py-10 text-center", className)}>
      <div className="mb-3 flex h-10 w-10 items-center justify-center rounded-lg bg-danger-soft text-danger">
        <AlertTriangle size={18} />
      </div>
      <h3 className="text-section font-semibold">{title}</h3>
      {message && <p className="mt-1 max-w-md text-body text-fg-muted">{message}</p>}
      {onRetry && (
        <button
          type="button"
          onClick={onRetry}
          className="mt-4 inline-flex h-8 items-center gap-2 rounded-md border border-line bg-elevated px-3 text-meta font-medium hover:bg-hover"
        >
          <RefreshCw size={14} /> Try again
        </button>
      )}
    </div>
  );
}

export function InlineAlert({
  tone = "danger",
  children,
  className,
}: {
  tone?: "danger" | "warning" | "info" | "success";
  children: React.ReactNode;
  className?: string;
}) {
  const tones = {
    danger: "border-danger/30 bg-danger-soft text-[#ffb3b8]",
    warning: "border-warning/30 bg-warning-soft text-[#ffd99a]",
    info: "border-violet/30 bg-violet-soft text-[#c9c9ff]",
    success: "border-success/30 bg-success-soft text-[#a6f0cb]",
  };
  return (
    <div role={tone === "danger" ? "alert" : "status"} className={cx("rounded-md border px-3 py-2.5 text-meta", tones[tone], className)}>
      {children}
    </div>
  );
}
