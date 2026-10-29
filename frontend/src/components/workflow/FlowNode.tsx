"use client";

import { Handle, Position, type NodeProps } from "@xyflow/react";
import { AlertCircle, CheckCircle2, Loader2, SkipForward, XCircle } from "lucide-react";
import { memo } from "react";
import { cx } from "@/components/ui/cx";
import { formatDuration } from "@/lib/format";
import { KIND_STYLE, NODE_ICONS, kindOf, summarize } from "@/lib/nodes";
import type { GwNode } from "./flow";

const STEP_RING: Record<string, string> = {
  running: "border-cyan shadow-[0_0_0_3px_rgb(85_197_242/0.15)]",
  succeeded: "border-success/55",
  failed: "border-danger/70 shadow-[0_0_0_3px_rgb(242_97_107/0.12)]",
  skipped: "opacity-55",
  pending: "",
};

function StepIndicator({ status, duration }: { status?: string; duration?: number | null }) {
  if (!status || status === "pending") return null;
  const map = {
    running: { icon: Loader2, className: "text-cyan animate-spin", label: "Running" },
    succeeded: { icon: CheckCircle2, className: "text-success", label: "Succeeded" },
    failed: { icon: XCircle, className: "text-danger", label: "Failed" },
    skipped: { icon: SkipForward, className: "text-fg-muted", label: "Skipped" },
  } as const;
  const item = map[status as keyof typeof map];
  if (!item) return null;
  const Icon = item.icon;
  return (
    <span className="ml-auto inline-flex items-center gap-1 text-micro text-fg-muted">
      {status !== "running" && status !== "skipped" && duration != null && <span className="tabular-nums">{formatDuration(duration)}</span>}
      <Icon size={14} className={item.className} aria-label={item.label} />
    </span>
  );
}

export const FlowNode = memo(function FlowNode({ data, selected }: NodeProps<GwNode>) {
  const kind = kindOf(data.type);
  const style = KIND_STYLE[kind];
  const Icon = NODE_ICONS[data.type];
  const isCondition = kind === "condition";

  return (
    <div
      className={cx(
        "w-[236px] rounded-[10px] border bg-surface text-left shadow-node transition-[border-color,box-shadow,opacity] duration-200",
        data.stepStatus ? STEP_RING[data.stepStatus] : "border-line",
        selected && "border-violet! shadow-[0_0_0_3px_rgb(133_133_255/0.2)]!",
        data.stepStatus === "running" && "animate-pulse-ring",
      )}
    >
      {kind !== "trigger" && <Handle type="target" position={Position.Top} isConnectable={!data.readOnly} />}
      <div className="flex items-center gap-2 px-3 pt-2.5">
        <span className={cx("flex h-6 w-6 shrink-0 items-center justify-center rounded-md", style.bg, style.text)}>
          {Icon && <Icon size={13.5} aria-hidden="true" />}
        </span>
        <span className={cx("text-micro font-semibold tracking-[0.06em] uppercase", style.text)}>{style.label}</span>
        <StepIndicator status={data.stepStatus} duration={data.stepDuration} />
        {!data.stepStatus && data.issueCount ? (
          <span className="ml-auto inline-flex items-center gap-1 text-micro font-medium text-warning" title="Needs setup">
            <AlertCircle size={13} aria-hidden="true" /> Setup
          </span>
        ) : null}
      </div>
      <div className="px-3 pt-1.5 pb-2.5">
        <p className="truncate text-[0.8125rem] font-semibold text-fg">{data.name}</p>
        <p className="mt-0.5 truncate font-mono text-[0.6875rem] text-fg-muted">{summarize({ type: data.type, config: data.config }) || " "}</p>
      </div>
      {isCondition ? (
        <div className="flex justify-between border-t border-line-subtle px-3 py-1 text-micro font-medium">
          <span className="text-success">True</span>
          <span className="text-fg-muted">False</span>
          <Handle id="true" type="source" position={Position.Bottom} style={{ left: "22%" }} isConnectable={!data.readOnly} />
          <Handle id="false" type="source" position={Position.Bottom} style={{ left: "78%" }} isConnectable={!data.readOnly} />
        </div>
      ) : (
        <Handle id="out" type="source" position={Position.Bottom} isConnectable={!data.readOnly} />
      )}
    </div>
  );
});
