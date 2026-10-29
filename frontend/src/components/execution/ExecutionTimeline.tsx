"use client";

import { CheckCircle2, ChevronRight, CircleDashed, Loader2, SkipForward, XCircle } from "lucide-react";
import { useState } from "react";
import { cx } from "@/components/ui/cx";
import { formatDuration } from "@/lib/format";
import { KIND_STYLE, kindOf } from "@/lib/nodes";
import type { ExecutionStep } from "@/lib/types";

const ICONS = {
  pending: { icon: CircleDashed, className: "text-fg-muted", label: "Pending" },
  running: { icon: Loader2, className: "text-cyan animate-spin", label: "Running" },
  succeeded: { icon: CheckCircle2, className: "text-success", label: "Succeeded" },
  failed: { icon: XCircle, className: "text-danger", label: "Failed" },
  skipped: { icon: SkipForward, className: "text-fg-muted", label: "Skipped" },
} as const;

export function JsonBlock({ value, maxHeight = "max-h-72" }: { value: unknown; maxHeight?: string }) {
  return (
    <pre className={cx("overflow-auto rounded-md border border-line-subtle bg-canvas p-3 font-mono text-[11.5px] leading-relaxed text-fg-secondary", maxHeight)}>
      {JSON.stringify(value, null, 2)}
    </pre>
  );
}

export function ExecutionTimeline({ steps, totalMs }: { steps: ExecutionStep[]; totalMs?: number | null }) {
  const [open, setOpen] = useState<Set<string>>(() => new Set(steps.filter((s) => s.status === "failed").map((s) => s.id)));
  const longest = Math.max(1, ...steps.map((s) => s.duration_ms ?? 0));
  const toggle = (id: string) =>
    setOpen((current) => {
      const next = new Set(current);
      if (next.has(id)) next.delete(id);
      else next.add(id);
      return next;
    });

  return (
    <ol className="flex flex-col">
      {steps.map((step, index) => {
        const meta = ICONS[step.status];
        const Icon = meta.icon;
        const expandable = Boolean(step.output || step.error_message);
        const expanded = open.has(step.id);
        const kind = KIND_STYLE[kindOf(step.node_type)];
        return (
          <li key={step.id} className="relative">
            {index < steps.length - 1 && <span className="absolute top-8 bottom-0 left-[19px] w-px bg-line" aria-hidden="true" />}
            <button
              type="button"
              onClick={() => expandable && toggle(step.id)}
              aria-expanded={expandable ? expanded : undefined}
              disabled={!expandable}
              className={cx("flex w-full items-center gap-3 rounded-md px-2 py-2 text-left", expandable && "hover:bg-hover")}
            >
              <span className="relative z-10 flex h-6 w-6 shrink-0 items-center justify-center rounded-full bg-surface">
                <Icon size={17} className={meta.className} aria-label={meta.label} />
              </span>
              <span className="min-w-0 flex-1">
                <span className={cx("block truncate text-body font-medium", step.status === "skipped" && "text-fg-muted")}>{step.node_name}</span>
                <span className="block text-micro text-fg-muted">
                  <span className={kind.text}>{kind.label}</span> · {meta.label}
                  {step.attempts > 1 && ` · ${step.attempts} attempts`}
                </span>
              </span>
              <span className="hidden w-24 sm:block" aria-hidden="true">
                {step.duration_ms != null && (
                  <span className="block h-1.5 rounded-full bg-cyan/60" style={{ width: `${Math.max(4, (step.duration_ms / longest) * 100)}%` }} />
                )}
              </span>
              <span className="w-16 shrink-0 text-right text-meta tabular-nums text-fg-muted">{formatDuration(step.duration_ms)}</span>
              {expandable ? (
                <ChevronRight size={15} className={cx("shrink-0 text-fg-muted transition-transform", expanded && "rotate-90")} aria-hidden="true" />
              ) : (
                <span className="w-[15px]" />
              )}
            </button>
            {expanded && (
              <div className="mb-2 ml-11 flex animate-fade-in flex-col gap-2 pr-2">
                {step.error_message && (
                  <p className="rounded-md border border-danger/30 bg-danger-soft px-3 py-2 text-meta text-[#ffb3b8]">{step.error_message}</p>
                )}
                {step.output && <JsonBlock value={step.output} />}
              </div>
            )}
          </li>
        );
      })}
      {totalMs != null && (
        <li className="mt-1 flex justify-end border-t border-line-subtle px-2 pt-2 text-meta text-fg-muted">
          Total <span className="ml-2 tabular-nums text-fg">{formatDuration(totalMs)}</span>
        </li>
      )}
    </ol>
  );
}
