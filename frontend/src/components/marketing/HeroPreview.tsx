"use client";

import { CheckCircle2, ChevronRight, GitBranch, Globe, LayoutDashboard, Mail, Play, Shuffle, Webhook, Workflow, History, Plug, Settings } from "lucide-react";
import { useEffect, useRef, useState } from "react";
import { LogoMark } from "@/components/brand/Logo";
import { cx } from "@/components/ui/cx";

const DESIGN_WIDTH = 1080;
const DESIGN_HEIGHT = 610;

type Kind = "trigger" | "action" | "condition";
const KIND = {
  trigger: { text: "text-violet", bg: "bg-violet-soft", label: "Trigger" },
  action: { text: "text-cyan", bg: "bg-cyan-soft", label: "Action" },
  condition: { text: "text-warning", bg: "bg-warning-soft", label: "Condition" },
};

const NODES: { id: string; x: number; y: number; kind: Kind; icon: React.ElementType; name: string; detail: string; ms?: string; skipped?: boolean; selected?: boolean }[] = [
  { id: "a", x: 180, y: 34, kind: "trigger", icon: Webhook, name: "New signup", detail: "POST /hooks/••••", ms: "2 ms" },
  { id: "b", x: 180, y: 148, kind: "action", icon: Shuffle, name: "Normalize lead", detail: "Builds email, plan, source", ms: "3 ms" },
  { id: "c", x: 180, y: 262, kind: "condition", icon: GitBranch, name: "Is it a Pro plan?", detail: "plan = pro", ms: "1 ms", selected: true },
  { id: "d", x: 40, y: 400, kind: "action", icon: Globe, name: "Create CRM lead", detail: "POST crm.example.com/leads", ms: "184 ms" },
  { id: "e", x: 320, y: 400, kind: "action", icon: Mail, name: "Send welcome email", detail: "To {{ steps.b.email }}", skipped: true },
];

function Node({ node }: { node: (typeof NODES)[number] }) {
  const k = KIND[node.kind];
  const Icon = node.icon;
  return (
    <div
      className={cx(
        "absolute w-[220px] rounded-[10px] border bg-surface shadow-node",
        node.selected ? "border-violet shadow-[0_0_0_3px_rgb(133_133_255/0.18)]" : node.skipped ? "border-line opacity-50" : "border-success/45",
      )}
      style={{ left: node.x, top: node.y }}
    >
      <div className="flex items-center gap-2 px-3 pt-2.5">
        <span className={cx("flex h-6 w-6 items-center justify-center rounded-md", k.bg, k.text)}>
          <Icon size={13} />
        </span>
        <span className={cx("text-[10px] font-semibold tracking-[0.06em] uppercase", k.text)}>{k.label}</span>
        <span className="ml-auto flex items-center gap-1 text-[10px] text-fg-muted">
          {node.ms && <span>{node.ms}</span>}
          {node.skipped ? <span>Skipped</span> : <CheckCircle2 size={13} className="text-success" />}
        </span>
      </div>
      <div className="px-3 pt-1.5 pb-2.5">
        <p className="text-[12.5px] font-semibold text-fg">{node.name}</p>
        <p className="mt-0.5 truncate font-mono text-[10.5px] text-fg-muted">{node.detail}</p>
      </div>
      {node.kind === "condition" && (
        <div className="flex justify-between border-t border-line-subtle px-3 py-1 text-[10px] font-medium">
          <span className="text-success">True</span>
          <span className="text-fg-muted">False</span>
        </div>
      )}
    </div>
  );
}

function MobilePreview() {
  const main = NODES.filter((n) => n.id !== "e");
  return (
    <div className="rounded-xl border border-line bg-sidebar p-4 sm:hidden" aria-hidden="true">
      <div className="mb-3 flex items-center gap-2 text-[12.5px]">
        <span className="font-semibold">Lead routing</span>
        <span className="rounded-full bg-elevated px-2 py-0.5 text-[10.5px] text-fg-secondary">Example</span>
        <span className="ml-auto inline-flex items-center gap-1 rounded-full bg-success-soft px-2 py-0.5 text-[10.5px] text-success">
          <CheckCircle2 size={11} /> Succeeded
        </span>
      </div>
      <div className="grid-canvas rounded-lg p-3">
        {main.map((node, i) => {
          const k = KIND[node.kind];
          const Icon = node.icon;
          return (
            <div key={node.id}>
              <div className="flex items-center gap-2.5 rounded-[10px] border border-success/45 bg-surface px-3 py-2.5">
                <span className={cx("flex h-7 w-7 shrink-0 items-center justify-center rounded-md", k.bg, k.text)}>
                  <Icon size={14} />
                </span>
                <span className="min-w-0">
                  <span className="block truncate text-[13px] font-semibold">{node.name}</span>
                  <span className="block truncate font-mono text-[10.5px] text-fg-muted">{node.detail}</span>
                </span>
                <span className="ml-auto flex shrink-0 items-center gap-1 text-[10px] text-fg-muted">
                  {node.ms}
                  <CheckCircle2 size={13} className="text-success" />
                </span>
              </div>
              {i < main.length - 1 && <div className="ml-[25px] h-4 w-px bg-cyan/70" />}
            </div>
          );
        })}
      </div>
    </div>
  );
}

/** Static illustration of the builder. Labelled as an example: nothing here is "running". */
export function HeroPreview() {
  const frame = useRef<HTMLDivElement>(null);
  const [scale, setScale] = useState(1);
  useEffect(() => {
    const element = frame.current;
    if (!element) return;
    const observer = new ResizeObserver(([entry]) => setScale(Math.min(1, entry.contentRect.width / DESIGN_WIDTH)));
    observer.observe(element);
    return () => observer.disconnect();
  }, []);

  return (
    <figure className="relative">
      <MobilePreview />
      <div
        ref={frame}
        className="relative hidden overflow-hidden sm:block rounded-xl border border-line bg-sidebar shadow-[0_40px_120px_-40px_rgb(133_133_255/0.35)]"
        style={{ height: DESIGN_HEIGHT * scale }}
      >
        <div className="absolute top-0 left-0 origin-top-left" style={{ width: DESIGN_WIDTH, height: DESIGN_HEIGHT, transform: `scale(${scale})` }}>
          <div className="flex h-full">
            {/* Mini sidebar */}
            <div className="flex w-14 flex-col items-center gap-3 border-r border-line-subtle bg-sidebar py-4">
              <LogoMark size={24} />
              <div className="mt-3 flex flex-col gap-1.5">
                {[LayoutDashboard, Workflow, History, Plug, Settings].map((I, i) => (
                  <span key={i} className={cx("flex h-8 w-8 items-center justify-center rounded-md", i === 1 ? "bg-violet-soft text-violet" : "text-fg-muted")}>
                    <I size={16} />
                  </span>
                ))}
              </div>
            </div>
            <div className="flex min-w-0 flex-1 flex-col">
              {/* Toolbar */}
              <div className="flex h-12 items-center gap-2 border-b border-line-subtle bg-sidebar px-4 text-[12.5px]">
                <span className="text-fg-muted">Workflows</span>
                <ChevronRight size={13} className="text-fg-muted" />
                <span className="font-semibold text-fg">Lead routing</span>
                <span className="ml-2 rounded-full bg-elevated px-2 py-0.5 text-[10.5px] text-fg-secondary">Example</span>
                <span className="ml-auto flex items-center gap-1.5 text-[11.5px] text-success">
                  <CheckCircle2 size={13} /> Valid
                </span>
                <span className="ml-3 inline-flex h-7 items-center gap-1.5 rounded-md border border-line bg-elevated px-2.5 text-[11.5px]">
                  <Play size={12} /> Test run
                </span>
                <span className="inline-flex h-7 items-center rounded-md bg-violet px-2.5 text-[11.5px] font-semibold text-canvas">Activate</span>
              </div>
              <div className="flex min-h-0 flex-1">
                {/* Canvas */}
                <div className="grid-canvas relative min-w-0 flex-1">
                  <svg className="absolute inset-0 h-full w-full" aria-hidden="true">
                    <g fill="none" strokeWidth="1.5">
                      <path d="M290 112 V148" stroke="#55c5f2" />
                      <path d="M290 222 V262" stroke="#55c5f2" />
                      <path d="M228 364 V374 Q228 382 220 382 H158 Q150 382 150 390 V400" stroke="#55c5f2" />
                      <path d="M352 364 V374 Q352 382 360 382 H422 Q430 382 430 390 V400" stroke="#2c3240" />
                    </g>
                  </svg>
                  {NODES.map((n) => (
                    <Node key={n.id} node={n} />
                  ))}
                  <div className="absolute right-4 bottom-4 left-4 flex items-center gap-3 rounded-lg border border-line bg-surface/95 px-3 py-2 text-[11px]">
                    <span className="font-semibold text-fg">Sample run</span>
                    <span className="inline-flex items-center gap-1 rounded-full bg-success-soft px-2 py-0.5 text-success">
                      <CheckCircle2 size={11} /> Succeeded
                    </span>
                    <div className="flex flex-1 items-center gap-1">
                      {[8, 10, 6, 70].map((w, i) => (
                        <span key={i} className="h-1.5 rounded-full bg-cyan/70" style={{ width: `${w}%` }} />
                      ))}
                      <span className="h-1.5 w-[6%] rounded-full bg-elevated" />
                    </div>
                    <span className="text-fg-muted tabular-nums">190 ms</span>
                  </div>
                </div>
                {/* Config panel */}
                <div className="w-[300px] border-l border-line-subtle bg-sidebar p-4">
                  <p className="text-[10px] font-semibold tracking-[0.08em] text-fg-muted uppercase">Condition</p>
                  <p className="mt-1 text-[14px] font-semibold">Is it a Pro plan?</p>
                  <div className="mt-4 space-y-3 text-[11.5px]">
                    {[
                      ["Value", "{{ steps.normalize.plan }}"],
                      ["Operator", "equals"],
                      ["Compare to", "pro"],
                    ].map(([label, value]) => (
                      <div key={label}>
                        <p className="mb-1 text-fg-secondary">{label}</p>
                        <div className="rounded-md border border-line bg-canvas px-2.5 py-2 font-mono text-[11px] text-fg">{value}</div>
                      </div>
                    ))}
                  </div>
                  <div className="mt-5 rounded-md border border-line-subtle bg-surface p-3 text-[11px] text-fg-muted">
                    Output <span className="font-mono text-success">{"{ result: true }"}</span> sends the run down the <span className="text-success">True</span> branch.
                  </div>
                </div>
              </div>
            </div>
          </div>
        </div>
      </div>
      <figcaption className="sr-only">
        Illustration of the GhostWork workflow builder showing an example lead-routing workflow with a webhook trigger,
        a transform step, a condition, and two branches.
      </figcaption>
    </figure>
  );
}
