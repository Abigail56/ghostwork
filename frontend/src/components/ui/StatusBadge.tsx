import { Ban, CheckCircle2, CircleDashed, CircleDot, Clock3, FilePen, Info, Loader2, PauseCircle, SkipForward, XCircle, AlertTriangle } from "lucide-react";
import { cx } from "./cx";

export type Status =
  | "succeeded"
  | "failed"
  | "running"
  | "queued"
  | "cancelled"
  | "pending"
  | "skipped"
  | "active"
  | "paused"
  | "draft"
  | "warning"
  | "info"
  | "connected"
  | "error";

const STYLES: Record<Status, { label: string; className: string; icon: React.ElementType }> = {
  succeeded: { label: "Succeeded", className: "text-success bg-success-soft", icon: CheckCircle2 },
  failed: { label: "Failed", className: "text-danger bg-danger-soft", icon: XCircle },
  running: { label: "Running", className: "text-running bg-cyan-soft", icon: Loader2 },
  queued: { label: "Queued", className: "text-queued bg-violet-soft", icon: Clock3 },
  cancelled: { label: "Cancelled", className: "text-fg-secondary bg-elevated", icon: Ban },
  pending: { label: "Pending", className: "text-fg-muted bg-elevated", icon: CircleDashed },
  skipped: { label: "Skipped", className: "text-fg-muted bg-elevated", icon: SkipForward },
  active: { label: "Active", className: "text-success bg-success-soft", icon: CircleDot },
  paused: { label: "Paused", className: "text-paused bg-warning-soft", icon: PauseCircle },
  draft: { label: "Draft", className: "text-draft bg-elevated", icon: FilePen },
  warning: { label: "Warning", className: "text-warning bg-warning-soft", icon: AlertTriangle },
  info: { label: "Info", className: "text-info bg-violet-soft", icon: Info },
  connected: { label: "Connected", className: "text-success bg-success-soft", icon: CheckCircle2 },
  error: { label: "Needs attention", className: "text-danger bg-danger-soft", icon: AlertTriangle },
};

export function StatusBadge({ status, label, className, size = "md" }: { status: Status; label?: string; className?: string; size?: "sm" | "md" }) {
  const style = STYLES[status] ?? STYLES.info;
  const Icon = style.icon;
  return (
    <span
      className={cx(
        "inline-flex items-center gap-1.5 rounded-full font-medium whitespace-nowrap",
        size === "sm" ? "h-5 px-2 text-micro" : "h-6 px-2.5 text-[0.75rem]",
        style.className,
        className,
      )}
    >
      <Icon size={size === "sm" ? 11 : 12} className={cx(status === "running" && "animate-spin")} aria-hidden="true" />
      {label ?? style.label}
    </span>
  );
}

/** Small colored dot + label, for dense rows. */
export function StatusDot({ status }: { status: Status }) {
  const style = STYLES[status] ?? STYLES.info;
  const color = style.className.split(" ")[0].replace("text-", "bg-");
  return (
    <span className="inline-flex items-center gap-1.5 text-meta text-fg-secondary">
      <span className={cx("h-1.5 w-1.5 rounded-full", color, status === "running" && "animate-pulse-ring")} />
      {style.label}
    </span>
  );
}
