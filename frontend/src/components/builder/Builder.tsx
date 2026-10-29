"use client";

import {
  Background,
  BackgroundVariant,
  MiniMap,
  ReactFlow,
  ReactFlowProvider,
  addEdge,
  applyEdgeChanges,
  applyNodeChanges,
  useReactFlow,
  type Connection,
  type EdgeChange,
  type NodeChange,
} from "@xyflow/react";
import "@xyflow/react/dist/style.css";
import {
  AlertCircle,
  CheckCircle2,
  ChevronRight,
  Loader2,
  Maximize,
  Minus,
  Pause,
  Play,
  Plus,
  Redo2,
  Save,
  SlidersHorizontal,
  Undo2,
  X,
} from "lucide-react";
import Link from "next/link";
import { useRouter } from "next/navigation";
import { useCallback, useEffect, useMemo, useRef, useState } from "react";
import { ExecutionTimeline } from "@/components/execution/ExecutionTimeline";
import { Button } from "@/components/ui/Button";
import { cx } from "@/components/ui/cx";
import { ErrorState, InlineAlert } from "@/components/ui/Feedback";
import { Field, Textarea } from "@/components/ui/Form";
import { ConfirmDialog, Dialog, Drawer, Tooltip } from "@/components/ui/Overlay";
import { StatusBadge } from "@/components/ui/StatusBadge";
import { useToast } from "@/components/ui/Toast";
import { AutoFit } from "@/components/workflow/AutoFit";
import { edgeTypes, nodeTypes } from "@/components/workflow/WorkflowCanvas";
import { edgeStateFromSteps, fromFlow, toFlowEdges, toFlowNodes, type GwEdge, type GwNode } from "@/components/workflow/flow";
import { ApiError } from "@/lib/api";
import { formatDuration } from "@/lib/format";
import { kindOf } from "@/lib/nodes";
import { useExecution, useIntegrations, useNodeTypes, useRunWorkflow, useSetWorkflowStatus, useUpdateWorkflow } from "@/lib/queries";
import type { NodeType, ValidationIssue, Workflow, WorkflowDefinition } from "@/lib/types";
import { ConfigPanel } from "./ConfigPanel";
import { DRAG_MIME, NodeLibrary } from "./NodeLibrary";

const SLUGS: Record<string, string> = {
  "trigger.manual": "trigger",
  "trigger.schedule": "trigger",
  "trigger.webhook": "trigger",
  "action.http_request": "http",
  "action.transform": "transform",
  "action.email": "email",
  "action.slack": "slack",
  "condition.if": "condition",
};

function nextId(type: string, existing: GwNode[]) {
  const slug = SLUGS[type] ?? "step";
  const taken = new Set(existing.map((n) => n.id));
  for (let i = 1; ; i++) {
    const id = `${slug}_${i}`;
    if (!taken.has(id)) return id;
  }
}

/** Key-order-independent JSON (PostgreSQL JSONB doesn't preserve key order). */
function canonical(value: unknown): unknown {
  if (Array.isArray(value)) return value.map(canonical);
  if (value && typeof value === "object") {
    return Object.fromEntries(
      Object.keys(value as Record<string, unknown>)
        .sort()
        .map((k) => [k, canonical((value as Record<string, unknown>)[k])]),
    );
  }
  return value;
}

function serialize(definition: WorkflowDefinition) {
  return JSON.stringify(canonical(definition));
}

function useIsDesktop() {
  const [desktop, setDesktop] = useState(true);
  useEffect(() => {
    const query = window.matchMedia("(min-width: 1024px)");
    const update = () => setDesktop(query.matches);
    update();
    query.addEventListener("change", update);
    return () => query.removeEventListener("change", update);
  }, []);
  return desktop;
}

function BuilderInner({ workflow }: { workflow: Workflow }) {
  const router = useRouter();
  const toast = useToast();
  const flow = useReactFlow<GwNode, GwEdge>();
  const isDesktop = useIsDesktop();
  const catalog = useNodeTypes();
  const integrations = useIntegrations();
  const update = useUpdateWorkflow(workflow.id);
  const setStatus = useSetWorkflowStatus();
  const run = useRunWorkflow();

  const [nodes, setNodes] = useState<GwNode[]>(() => toFlowNodes(workflow.definition));
  const [edges, setEdges] = useState<GwEdge[]>(() => toFlowEdges(workflow.definition));
  const [saved, setSaved] = useState<Workflow>(workflow);
  const [selectedId, setSelectedId] = useState<string | null>(null);
  const [panel, setPanel] = useState<"library" | "config" | null>(null);
  const [executionId, setExecutionId] = useState<string | null>(null);
  const [runDialog, setRunDialog] = useState(false);
  const [runPayload, setRunPayload] = useState("{}");
  const [runError, setRunError] = useState<string | null>(null);
  const [confirmActivate, setConfirmActivate] = useState(false);
  const [leaveTo, setLeaveTo] = useState<string | null>(null);
  const [statusError, setStatusError] = useState<string | null>(null);
  const [runCollapsed, setRunCollapsed] = useState(false);

  const definition = useMemo(() => fromFlow(nodes, edges), [nodes, edges]);
  const currentJson = serialize(definition);
  const savedJson = useMemo(() => serialize(saved.definition), [saved.definition]);
  const dirty = currentJson !== savedJson;
  const issues: ValidationIssue[] = saved.validation;

  /* ---------- Undo / redo: snapshot the definition after edits settle ---------- */
  const [history, setHistory] = useState({ stack: [savedJson], cursor: 0 });
  const restoring = useRef(false);
  useEffect(() => {
    if (restoring.current) {
      restoring.current = false;
      return;
    }
    const timer = setTimeout(() => {
      setHistory((h) => {
        if (h.stack[h.cursor] === currentJson) return h;
        const stack = [...h.stack.slice(0, h.cursor + 1), currentJson].slice(-100);
        return { stack, cursor: stack.length - 1 };
      });
    }, 400);
    return () => clearTimeout(timer);
  }, [currentJson]);

  const restore = useCallback((json: string) => {
    restoring.current = true;
    const def = JSON.parse(json) as WorkflowDefinition;
    setNodes(toFlowNodes(def));
    setEdges(toFlowEdges(def));
    setSelectedId(null);
  }, []);
  const canUndo = history.cursor > 0;
  const canRedo = history.cursor < history.stack.length - 1;
  const undo = useCallback(() => {
    if (history.cursor <= 0) return;
    const cursor = history.cursor - 1;
    restore(history.stack[cursor]);
    setHistory({ ...history, cursor });
  }, [history, restore]);
  const redo = useCallback(() => {
    if (history.cursor >= history.stack.length - 1) return;
    const cursor = history.cursor + 1;
    restore(history.stack[cursor]);
    setHistory({ ...history, cursor });
  }, [history, restore]);

  /* ---------- Live execution overlay (real step state only) ---------- */
  const execution = useExecution(executionId);
  const steps = execution.data?.steps;
  const running = execution.data ? ["queued", "running"].includes(execution.data.status) : false;
  const displayNodes = useMemo(() => {
    const byNode = new Map(steps?.map((s) => [s.node_id, s]) ?? []);
    const issueCount = new Map<string, number>();
    if (!dirty) for (const issue of issues) if (issue.node_id) issueCount.set(issue.node_id, (issueCount.get(issue.node_id) ?? 0) + 1);
    return nodes.map((n) => ({
      ...n,
      data: {
        ...n.data,
        stepStatus: byNode.get(n.id)?.status,
        stepDuration: byNode.get(n.id)?.duration_ms,
        issueCount: issueCount.get(n.id) ?? 0,
      },
    }));
  }, [nodes, steps, issues, dirty]);
  const displayEdges = useMemo(() => {
    if (!steps) return edges;
    const state = edgeStateFromSteps(new Map(steps.map((s) => [s.node_id, s.status])));
    return edges.map((e) => ({ ...e, data: { ...e.data, state: state({ id: e.id, source: e.source, target: e.target, source_handle: e.sourceHandle ?? "out" }) } }));
  }, [edges, steps]);

  /* ---------- Editing ---------- */
  const onNodesChange = useCallback((changes: NodeChange<GwNode>[]) => {
    setNodes((current) => applyNodeChanges(changes, current));
    for (const change of changes) {
      if (change.type === "select" && change.selected) setSelectedId(change.id);
      if (change.type === "remove") setSelectedId((id) => (id === change.id ? null : id));
    }
  }, []);
  const onEdgesChange = useCallback((changes: EdgeChange<GwEdge>[]) => setEdges((current) => applyEdgeChanges(changes, current)), []);

  const isValidConnection = useCallback(
    (connection: Connection | GwEdge) => {
      if (connection.source === connection.target) return false;
      const target = nodes.find((n) => n.id === connection.target);
      if (!target || kindOf(target.data.type) === "trigger") return false;
      const handle = connection.sourceHandle ?? "out";
      return !edges.some((e) => e.source === connection.source && e.target === connection.target && (e.sourceHandle ?? "out") === handle);
    },
    [nodes, edges],
  );

  const onConnect = useCallback((connection: Connection) => {
    const handle = connection.sourceHandle ?? "out";
    setEdges((current) =>
      addEdge<GwEdge>(
        { ...connection, sourceHandle: handle, id: `e_${connection.source}_${handle}_${connection.target}`, type: "gw", data: { handle, state: "idle" } },
        current,
      ),
    );
  }, []);

  const addNode = useCallback(
    (type: NodeType, position?: { x: number; y: number }) => {
      const kind = type.kind;
      const existingTrigger = nodes.find((n) => kindOf(n.data.type) === "trigger");
      if (kind === "trigger" && existingTrigger) {
        // Only one trigger per workflow: swap its type in place and keep its connections.
        setNodes((current) =>
          current.map((n) =>
            n.id === existingTrigger.id ? { ...n, data: { ...n.data, type: type.type, name: type.label, config: { ...type.default_config } } } : n,
          ),
        );
        setSelectedId(existingTrigger.id);
        toast({ tone: "info", title: `Trigger changed to ${type.label}` });
        return;
      }
      const id = nextId(type.type, nodes);
      const anchor = nodes.find((n) => n.id === selectedId) ?? [...nodes].sort((a, b) => b.position.y - a.position.y)[0];
      const pos = position ?? (anchor ? { x: anchor.position.x, y: anchor.position.y + 170 } : { x: 0, y: 0 });
      const node: GwNode = {
        id,
        type: "gw",
        position: pos,
        selected: true,
        data: { type: type.type, name: type.label, config: { ...type.default_config } },
      };
      setNodes((current) => [...current.map((n) => ({ ...n, selected: false })), node]);
      // Clicking to add continues the flow from the selected (or last) step.
      if (!position && anchor && kind !== "trigger" && kindOf(anchor.data.type) !== "condition") {
        const edgeId = `e_${anchor.id}_out_${id}`;
        setEdges((current) => [...current, { id: edgeId, source: anchor.id, target: id, sourceHandle: "out", type: "gw", data: { handle: "out", state: "idle" } }]);
      }
      setSelectedId(id);
      if (!isDesktop) setPanel("config");
      requestAnimationFrame(() => flow.fitView({ padding: 0.25, maxZoom: 1, duration: 200 }));
    },
    [nodes, selectedId, isDesktop, flow, toast],
  );

  const onDrop = useCallback(
    (event: React.DragEvent) => {
      event.preventDefault();
      const type = event.dataTransfer.getData(DRAG_MIME);
      const spec = catalog.data?.find((t) => t.type === type);
      if (!spec) return;
      const position = flow.screenToFlowPosition({ x: event.clientX - 118, y: event.clientY - 30 });
      addNode(spec, position);
    },
    [catalog.data, flow, addNode],
  );

  const selected = nodes.find((n) => n.id === selectedId) ?? null;
  const updateSelected = (patch: Partial<GwNode["data"]>) =>
    setNodes((current) => current.map((n) => (n.id === selectedId ? { ...n, data: { ...n.data, ...patch } } : n)));
  const deleteSelected = () => {
    if (!selectedId) return;
    setNodes((current) => current.filter((n) => n.id !== selectedId));
    setEdges((current) => current.filter((e) => e.source !== selectedId && e.target !== selectedId));
    setSelectedId(null);
    setPanel(null);
  };

  // Steps that run before the selected node, for the reference helper.
  const references = useMemo(() => {
    if (!selectedId) return [];
    const parents = new Map<string, string[]>();
    for (const e of edges) parents.set(e.target, [...(parents.get(e.target) ?? []), e.source]);
    const seen = new Set<string>();
    const stack = [...(parents.get(selectedId) ?? [])];
    while (stack.length) {
      const id = stack.pop()!;
      if (seen.has(id)) continue;
      seen.add(id);
      stack.push(...(parents.get(id) ?? []));
    }
    const ancestors = nodes.filter((n) => seen.has(n.id) && kindOf(n.data.type) !== "trigger").map((n) => `{{ steps.${n.id} }}`);
    return ["{{ trigger.payload }}", ...ancestors, "{{ execution.id }}", "{{ workflow.name }}"];
  }, [selectedId, edges, nodes]);

  /* ---------- Saving ---------- */
  const save = useCallback(async (): Promise<Workflow | null> => {
    try {
      const result = await update.mutateAsync({ definition, expected_version: saved.version });
      setSaved(result);
      setHistory({ stack: [serialize(result.definition)], cursor: 0 });
      return result;
    } catch (error) {
      const e = error as ApiError;
      toast({
        tone: "error",
        title: e.status === 409 ? "Saved elsewhere" : "Couldn't save",
        description: e.issues?.length ? e.issues.slice(0, 2).map((i) => i.message).join(" ") : e.message,
      });
      return null;
    }
  }, [update, definition, saved.version, toast]);

  const onSaveClick = async () => {
    const result = await save();
    if (result) toast({ tone: "success", title: "Workflow saved", description: result.validation.length ? `${result.validation.length} issue(s) to fix before it can run.` : "Ready to run." });
  };

  /* ---------- Keyboard shortcuts & leave protection ---------- */
  useEffect(() => {
    const onKey = (e: KeyboardEvent) => {
      const typing = (e.target as HTMLElement).closest("input, textarea, select, [contenteditable]");
      if ((e.ctrlKey || e.metaKey) && e.key.toLowerCase() === "s") {
        e.preventDefault();
        if (dirty && !update.isPending) void onSaveClick();
      } else if (!typing && (e.ctrlKey || e.metaKey) && e.key.toLowerCase() === "z") {
        e.preventDefault();
        if (e.shiftKey) redo();
        else undo();
      } else if (!typing && (e.ctrlKey || e.metaKey) && e.key.toLowerCase() === "y") {
        e.preventDefault();
        redo();
      }
    };
    window.addEventListener("keydown", onKey);
    return () => window.removeEventListener("keydown", onKey);
  });
  useEffect(() => {
    if (!dirty) return;
    const handler = (e: BeforeUnloadEvent) => {
      e.preventDefault();
    };
    window.addEventListener("beforeunload", handler);
    return () => window.removeEventListener("beforeunload", handler);
  }, [dirty]);

  const navigate = (href: string) => (dirty ? setLeaveTo(href) : router.push(href));

  /* ---------- Run & activate ---------- */
  const startRun = async () => {
    setRunError(null);
    let payload: Record<string, unknown> = {};
    try {
      payload = runPayload.trim() ? JSON.parse(runPayload) : {};
      if (typeof payload !== "object" || Array.isArray(payload) || payload === null) throw new Error();
    } catch {
      setRunError("Test data must be a JSON object, like {\"name\": \"Ada\"}.");
      return;
    }
    let current = saved;
    if (dirty) {
      const result = await save();
      if (!result) return;
      current = result;
    }
    if (current.validation.length) {
      setRunError("Fix the validation issues before running.");
      return;
    }
    run.mutate(
      { id: workflow.id, payload },
      {
        onSuccess: (exec) => {
          setRunDialog(false);
          setRunCollapsed(false);
          setExecutionId(exec.id);
        },
        onError: (e) => setRunError((e as Error).message),
      },
    );
  };

  const activate = async () => {
    setStatusError(null);
    if (dirty && !(await save())) return;
    setStatus.mutate(
      { id: workflow.id, status: "active" },
      {
        onSuccess: (result) => {
          setSaved(result);
          setConfirmActivate(false);
          toast({ tone: "success", title: "Workflow activated" });
        },
        onError: (e) => setStatusError((e as ApiError).issues?.length ? (e as ApiError).issues.map((i) => i.message).join(" ") : (e as Error).message),
      },
    );
  };

  const pause = () =>
    setStatus.mutate(
      { id: workflow.id, status: "paused" },
      {
        onSuccess: (result) => {
          setSaved(result);
          toast({ tone: "success", title: "Workflow paused" });
        },
        onError: (e) => toast({ tone: "error", title: "Couldn't pause", description: (e as Error).message }),
      },
    );

  const connectedProviders = useMemo(() => new Set((integrations.data ?? []).map((i) => i.provider)), [integrations.data]);
  const hasTrigger = nodes.some((n) => kindOf(n.data.type) === "trigger");

  /* ---------- Panels ---------- */
  const library = (
    <NodeLibrary
      nodeTypes={catalog.data}
      loading={catalog.isPending}
      hasTrigger={hasTrigger}
      connectedProviders={connectedProviders}
      onAdd={(t) => {
        addNode(t);
        if (!isDesktop && t.kind === "trigger") setPanel(null);
      }}
    />
  );

  const settingsPanel = (
    <div className="flex flex-col gap-4 p-4">
      <div>
        <p className="eyebrow">Workflow</p>
        <p className="mt-1 text-section font-semibold">{saved.name}</p>
        <div className="mt-2 flex items-center gap-2">
          <StatusBadge status={saved.status} size="sm" />
          <span className="text-micro text-fg-muted">Version {saved.version}</span>
        </div>
      </div>
      <p className="text-body text-fg-muted">Select a step to configure it. Rename the workflow or edit its description on the workflow page.</p>
      <div>
        <p className="mb-2 text-meta font-medium text-fg-secondary">Validation {dirty && <span className="font-normal text-fg-muted">(as of last save)</span>}</p>
        {issues.length ? (
          <ul className="flex flex-col gap-1.5">
            {issues.map((issue, i) => (
              <li key={i}>
                <button
                  type="button"
                  onClick={() => issue.node_id && (setSelectedId(issue.node_id), setNodes((c) => c.map((n) => ({ ...n, selected: n.id === issue.node_id }))))}
                  className="flex w-full gap-2 rounded-md border border-warning/25 bg-warning-soft px-2.5 py-2 text-left text-meta text-[#ffd99a] hover:border-warning/50"
                >
                  <AlertCircle size={14} className="mt-0.5 shrink-0" aria-hidden="true" /> {issue.message}
                </button>
              </li>
            ))}
          </ul>
        ) : (
          <p className="flex items-center gap-1.5 text-body text-success">
            <CheckCircle2 size={15} /> No issues found.
          </p>
        )}
      </div>
      <div className="rounded-lg border border-line-subtle bg-surface p-3 text-meta text-fg-muted">
        <p className="font-medium text-fg-secondary">Shortcuts</p>
        <ul className="mt-1.5 flex flex-col gap-1">
          <li><kbd className="font-sans text-fg-secondary">Ctrl S</kbd> save · <kbd className="font-sans text-fg-secondary">Ctrl Z</kbd> undo · <kbd className="font-sans text-fg-secondary">Ctrl Shift Z</kbd> redo</li>
          <li><kbd className="font-sans text-fg-secondary">Delete</kbd> remove the selected step or connection</li>
        </ul>
      </div>
    </div>
  );

  const configPanel = selected ? (
    <ConfigPanel
      key={selected.id}
      nodeId={selected.id}
      data={selected.data}
      issues={dirty ? [] : issues.filter((i) => i.node_id === selected.id)}
      integrations={integrations.data ?? []}
      references={references}
      webhookUrl={saved.webhook_url}
      onChange={(config) => updateSelected({ config })}
      onRename={(name) => updateSelected({ name })}
      onDelete={deleteSelected}
    />
  ) : (
    settingsPanel
  );

  const validationPill = dirty ? (
    <span className="inline-flex items-center gap-1.5 text-meta text-fg-muted">
      <span className="h-1.5 w-1.5 rounded-full bg-warning" aria-hidden="true" /> Unsaved changes
    </span>
  ) : issues.length ? (
    <button type="button" onClick={() => (setSelectedId(null), !isDesktop && setPanel("config"))} className="inline-flex items-center gap-1.5 text-meta text-warning hover:underline">
      <AlertCircle size={14} /> {issues.length} issue{issues.length > 1 ? "s" : ""}
    </button>
  ) : (
    <span className="inline-flex items-center gap-1.5 text-meta text-success">
      <CheckCircle2 size={14} /> Saved · valid
    </span>
  );

  return (
    <div className="flex h-[calc(100dvh-var(--spacing-topbar))] flex-col">
      {/* Toolbar */}
      <div className="flex min-h-12 flex-wrap items-center gap-x-3 gap-y-2 border-b border-line-subtle bg-sidebar px-3 py-2 sm:px-4">
        <nav aria-label="Breadcrumb" className="flex min-w-0 items-center gap-1.5 text-body">
          <button type="button" onClick={() => navigate("/workflows")} className="hidden text-fg-muted hover:text-fg sm:inline">
            Workflows
          </button>
          <ChevronRight size={14} className="hidden text-fg-muted sm:inline" aria-hidden="true" />
          <button type="button" onClick={() => navigate(`/workflows/${workflow.id}`)} className="truncate font-semibold text-fg hover:underline">
            {saved.name}
          </button>
        </nav>
        <StatusBadge status={saved.status} size="sm" className="hidden sm:inline-flex" />
        <div className="hidden md:block">{validationPill}</div>

        <div className="ml-auto flex items-center gap-1">
          <div className="hidden items-center gap-0.5 sm:flex">
            <Tooltip label="Undo" side="bottom">
              <Button variant="ghost" size="icon-sm" aria-label="Undo" onClick={undo} disabled={!canUndo}>
                <Undo2 size={15} />
              </Button>
            </Tooltip>
            <Tooltip label="Redo" side="bottom">
              <Button variant="ghost" size="icon-sm" aria-label="Redo" onClick={redo} disabled={!canRedo}>
                <Redo2 size={15} />
              </Button>
            </Tooltip>
            <span className="mx-1 h-5 w-px bg-line" aria-hidden="true" />
            <Tooltip label="Zoom out" side="bottom">
              <Button variant="ghost" size="icon-sm" aria-label="Zoom out" onClick={() => flow.zoomOut({ duration: 150 })}>
                <Minus size={15} />
              </Button>
            </Tooltip>
            <Tooltip label="Zoom in" side="bottom">
              <Button variant="ghost" size="icon-sm" aria-label="Zoom in" onClick={() => flow.zoomIn({ duration: 150 })}>
                <Plus size={15} />
              </Button>
            </Tooltip>
            <Tooltip label="Fit to screen" side="bottom">
              <Button variant="ghost" size="icon-sm" aria-label="Fit to screen" onClick={() => flow.fitView({ padding: 0.25, maxZoom: 1, duration: 200 })}>
                <Maximize size={14} />
              </Button>
            </Tooltip>
            <span className="mx-1 h-5 w-px bg-line" aria-hidden="true" />
          </div>
          <Button size="sm" onClick={onSaveClick} disabled={!dirty} loading={update.isPending}>
            <Save size={14} /> <span className="hidden sm:inline">Save</span>
          </Button>
          <Button size="sm" onClick={() => (setRunError(null), setRunDialog(true))} disabled={running}>
            {running ? <Loader2 size={14} className="animate-spin" /> : <Play size={14} />}
            <span className="hidden sm:inline">{running ? "Running" : "Test run"}</span>
          </Button>
          {saved.status === "active" ? (
            <Button size="sm" onClick={pause} loading={setStatus.isPending}>
              <Pause size={14} /> <span className="hidden sm:inline">Pause</span>
            </Button>
          ) : (
            <Button size="sm" variant="primary" onClick={() => (setStatusError(null), setConfirmActivate(true))}>
              Activate
            </Button>
          )}
        </div>
      </div>

      <div className="relative flex min-h-0 flex-1">
        {isDesktop && <aside aria-label="Steps library" className="w-64 shrink-0 overflow-y-auto border-r border-line-subtle bg-sidebar">{library}</aside>}

        <div className="relative min-w-0 flex-1" onDragOver={(e) => (e.preventDefault(), (e.dataTransfer.dropEffect = "move"))} onDrop={onDrop}>
          <ReactFlow<GwNode, GwEdge>
            nodes={displayNodes}
            edges={displayEdges}
            nodeTypes={nodeTypes}
            edgeTypes={edgeTypes}
            onNodesChange={onNodesChange}
            onEdgesChange={onEdgesChange}
            onConnect={onConnect}
            isValidConnection={isValidConnection}
            onNodeClick={(_, node) => {
              setSelectedId(node.id);
              if (!isDesktop) setPanel("config");
            }}
            onPaneClick={() => setSelectedId(null)}
            deleteKeyCode={["Delete", "Backspace"]}
            fitView
            fitViewOptions={{ padding: 0.25, maxZoom: 1 }}
            minZoom={0.25}
            maxZoom={1.75}
            snapToGrid
            snapGrid={[10, 10]}
            colorMode="dark"
            defaultEdgeOptions={{ type: "gw" }}
            proOptions={{ hideAttribution: false }}
          >
            <Background variant={BackgroundVariant.Dots} gap={20} size={1} color="rgba(160,168,184,0.14)" />
            <AutoFit padding={0.25} />
            {isDesktop && <MiniMap pannable zoomable nodeColor={(n) => ({ trigger: "#8585ff", action: "#55c5f2", condition: "#f5b74f" })[kindOf((n.data as GwNode["data"]).type)]} nodeStrokeWidth={0} className="!rounded-md !border !border-line" />}
          </ReactFlow>

          {nodes.length === 0 && (
            <div className="pointer-events-none absolute inset-0 flex items-center justify-center p-6">
              <div className="pointer-events-auto max-w-xs rounded-lg border border-dashed border-line-strong bg-surface/90 p-5 text-center">
                <p className="text-body font-medium">Start with a trigger</p>
                <p className="mt-1 text-meta text-fg-muted">Choose how this workflow starts from the steps library.</p>
                {!isDesktop && (
                  <Button size="sm" variant="primary" className="mt-3" onClick={() => setPanel("library")}>
                    <Plus size={14} /> Add a step
                  </Button>
                )}
              </div>
            </div>
          )}

          {/* Mobile/tablet panel switches */}
          {!isDesktop && (
            <div className="absolute bottom-4 left-1/2 z-10 flex -translate-x-1/2 gap-2 rounded-lg border border-line bg-elevated p-1 shadow-pop">
              <Button size="sm" variant="ghost" onClick={() => setPanel("library")}>
                <Plus size={14} /> Add step
              </Button>
              <Button size="sm" variant="ghost" onClick={() => setPanel("config")}>
                <SlidersHorizontal size={14} /> {selected ? "Configure" : "Details"}
              </Button>
            </div>
          )}

          {/* Execution timeline overlay: shows real results of the test run */}
          {execution.data && (
            <section
              aria-label="Test run"
              className={cx(
                "absolute right-3 z-10 flex max-h-[45%] w-[min(26rem,calc(100%-1.5rem))] animate-pop-in flex-col rounded-lg border border-line bg-surface shadow-pop",
                isDesktop ? "bottom-3" : "bottom-16",
              )}
            >
              <div className="flex items-center gap-2 border-b border-line-subtle px-3 py-2">
                <p className="text-body font-semibold">Test run</p>
                <StatusBadge status={execution.data.status} size="sm" />
                <span className="text-micro tabular-nums text-fg-muted">{formatDuration(execution.data.duration_ms)}</span>
                <Link href={`/executions/${execution.data.id}`} className="ml-auto text-meta text-violet hover:underline">
                  Details
                </Link>
                <Button
                  variant="ghost"
                  size="icon-sm"
                  aria-label={runCollapsed ? "Expand test run" : "Collapse test run"}
                  aria-expanded={!runCollapsed}
                  onClick={() => setRunCollapsed((v) => !v)}
                >
                  <ChevronRight size={14} className={cx("transition-transform", runCollapsed ? "-rotate-90" : "rotate-90")} />
                </Button>
                <Button variant="ghost" size="icon-sm" aria-label="Close test run" onClick={() => setExecutionId(null)}>
                  <X size={14} />
                </Button>
              </div>
              {!runCollapsed && (
                <>
                  {execution.data.error_message && <InlineAlert className="mx-3 mt-2">{execution.data.error_message}</InlineAlert>}
                  <div className="overflow-y-auto p-1.5">
                    <ExecutionTimeline key={execution.data.status} steps={execution.data.steps} />
                  </div>
                </>
              )}
            </section>
          )}
        </div>

        {isDesktop && (
          <aside aria-label={selected ? "Step configuration" : "Workflow details"} className="w-80 shrink-0 overflow-y-auto border-l border-line-subtle bg-sidebar xl:w-[22rem]">
            <div key={selected?.id ?? "settings"} className="animate-fade-in">
              {configPanel}
            </div>
          </aside>
        )}
      </div>

      {!isDesktop && (
        <>
          <Drawer open={panel === "library"} onClose={() => setPanel(null)} title="Add a step" side="left">
            {library}
          </Drawer>
          <Drawer open={panel === "config"} onClose={() => setPanel(null)} title={selected ? "Configure step" : "Workflow details"}>
            {configPanel}
          </Drawer>
        </>
      )}

      <Dialog
        open={runDialog}
        onClose={() => setRunDialog(false)}
        title="Test run"
        description={dirty ? "Your changes will be saved first. The run uses the saved version." : "Run the saved workflow now and watch each step."}
        footer={
          <>
            <Button onClick={() => setRunDialog(false)}>Cancel</Button>
            <Button variant="primary" onClick={startRun} loading={run.isPending || update.isPending}>
              <Play size={14} /> Run now
            </Button>
          </>
        }
      >
        <Field label="Test data (JSON)" optional hint="Available to steps as {{ trigger.payload }}." error={runError ?? undefined}>
          {(p) => <Textarea {...p} rows={5} value={runPayload} onChange={(e) => setRunPayload(e.target.value)} className="font-mono text-meta" spellCheck={false} />}
        </Field>
      </Dialog>

      <ConfirmDialog
        open={confirmActivate}
        onClose={() => setConfirmActivate(false)}
        title="Activate this workflow?"
        description={
          <>
            {dirty && <p className="mb-2">Unsaved changes will be saved first.</p>}
            {saved.trigger_type === "trigger.schedule"
              ? "It will run automatically on its schedule until you pause it."
              : saved.trigger_type === "trigger.webhook"
                ? "Its webhook URL will start accepting requests and running the workflow."
                : "Manual workflows only run when you start them, but activating marks it as in use."}
          </>
        }
        confirmLabel="Activate"
        loading={setStatus.isPending || update.isPending}
        error={statusError}
        onConfirm={activate}
      />

      <ConfirmDialog
        open={leaveTo !== null}
        onClose={() => setLeaveTo(null)}
        title="Leave without saving?"
        description="You have unsaved changes in this workflow. They'll be lost if you leave now."
        confirmLabel="Discard changes"
        tone="danger"
        onConfirm={() => {
          const target = leaveTo!;
          setLeaveTo(null);
          router.push(target);
        }}
      />
    </div>
  );
}

export function Builder({ workflow }: { workflow: Workflow }) {
  return (
    <ReactFlowProvider>
      <BuilderInner workflow={workflow} />
    </ReactFlowProvider>
  );
}

export function BuilderError({ error, onRetry }: { error: unknown; onRetry: () => void }) {
  return <ErrorState title="Couldn't open the builder" error={error} onRetry={onRetry} className="m-auto" />;
}
