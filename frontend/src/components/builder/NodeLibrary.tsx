"use client";

import { Plus } from "lucide-react";
import { cx } from "@/components/ui/cx";
import { Skeleton } from "@/components/ui/Feedback";
import { KIND_STYLE, NODE_ICONS } from "@/lib/nodes";
import type { NodeType } from "@/lib/types";

export const DRAG_MIME = "application/x-ghostwork-node";

const GROUPS: { kind: NodeType["kind"]; title: string }[] = [
  { kind: "trigger", title: "Triggers" },
  { kind: "action", title: "Actions" },
  { kind: "condition", title: "Logic" },
];

export function NodeLibrary({
  nodeTypes,
  loading,
  hasTrigger,
  connectedProviders,
  onAdd,
}: {
  nodeTypes: NodeType[] | undefined;
  loading: boolean;
  hasTrigger: boolean;
  connectedProviders: Set<string>;
  onAdd: (type: NodeType) => void;
}) {
  if (loading || !nodeTypes) {
    return (
      <div className="flex flex-col gap-2 p-3" role="status" aria-label="Loading steps">
        {[0, 1, 2, 3, 4].map((i) => (
          <Skeleton key={i} className="h-14" />
        ))}
      </div>
    );
  }
  return (
    <div className="flex flex-col gap-5 p-3">
      <p className="px-1 text-meta text-fg-muted">Click to add, or drag onto the canvas.</p>
      {GROUPS.map((group) => (
        <section key={group.kind} aria-labelledby={`lib-${group.kind}`}>
          <h3 id={`lib-${group.kind}`} className="eyebrow mb-2 px-1">
            {group.title}
          </h3>
          <ul className="flex flex-col gap-1.5">
            {nodeTypes
              .filter((n) => n.kind === group.kind)
              .map((n) => {
                const Icon = NODE_ICONS[n.type];
                const style = KIND_STYLE[n.kind];
                const needsIntegration = n.integration_provider && !connectedProviders.has(n.integration_provider);
                return (
                  <li key={n.type}>
                    <button
                      type="button"
                      draggable
                      onDragStart={(e) => {
                        e.dataTransfer.setData(DRAG_MIME, n.type);
                        e.dataTransfer.effectAllowed = "move";
                      }}
                      onClick={() => onAdd(n)}
                      className="group flex w-full cursor-grab items-start gap-2.5 rounded-lg border border-line-subtle bg-surface px-2.5 py-2 text-left transition-colors hover:border-line-strong hover:bg-elevated active:cursor-grabbing"
                      aria-label={`Add ${n.label}${n.kind === "trigger" && hasTrigger ? " (replaces the current trigger)" : ""}`}
                    >
                      <span className={cx("mt-0.5 flex h-7 w-7 shrink-0 items-center justify-center rounded-md", style.bg, style.text)}>
                        {Icon && <Icon size={14} aria-hidden="true" />}
                      </span>
                      <span className="min-w-0 flex-1">
                        <span className="block text-body font-medium text-fg">{n.label}</span>
                        <span className="block text-micro leading-snug text-fg-muted">
                          {n.kind === "trigger" && hasTrigger ? "Replaces the current trigger" : n.description}
                        </span>
                        {needsIntegration && <span className="mt-0.5 block text-micro text-warning">Needs a connected integration</span>}
                      </span>
                      <Plus size={14} className="mt-1 shrink-0 text-fg-muted opacity-0 transition-opacity group-hover:opacity-100" aria-hidden="true" />
                    </button>
                  </li>
                );
              })}
          </ul>
        </section>
      ))}
    </div>
  );
}
