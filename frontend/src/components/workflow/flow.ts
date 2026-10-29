import type { Edge, Node } from "@xyflow/react";
import type { EdgeDefinition, NodeDefinition, StepStatus, WorkflowDefinition } from "@/lib/types";

export interface GwNodeData extends Record<string, unknown> {
  type: string;
  name: string;
  config: Record<string, unknown>;
  stepStatus?: StepStatus;
  stepDuration?: number | null;
  issueCount?: number;
  readOnly?: boolean;
}

export type GwNode = Node<GwNodeData, "gw">;

export interface GwEdgeData extends Record<string, unknown> {
  state?: "idle" | "traversed" | "active" | "skipped";
  handle?: string;
}

export type GwEdge = Edge<GwEdgeData, "gw">;

export function toFlowNodes(definition: WorkflowDefinition, extras?: (node: NodeDefinition) => Partial<GwNodeData>): GwNode[] {
  return definition.nodes.map((node) => ({
    id: node.id,
    type: "gw",
    position: node.position,
    data: { type: node.type, name: node.name, config: node.config, ...(extras?.(node) ?? {}) },
  }));
}

export function toFlowEdges(definition: WorkflowDefinition, state?: (edge: EdgeDefinition) => GwEdgeData["state"]): GwEdge[] {
  return definition.edges.map((edge) => ({
    id: edge.id,
    type: "gw",
    source: edge.source,
    target: edge.target,
    sourceHandle: edge.source_handle,
    data: { handle: edge.source_handle, state: state?.(edge) ?? "idle" },
  }));
}

export function fromFlow(nodes: GwNode[], edges: GwEdge[]): WorkflowDefinition {
  return {
    nodes: nodes.map((n) => ({
      id: n.id,
      type: n.data.type,
      name: n.data.name,
      position: { x: Math.round(n.position.x), y: Math.round(n.position.y) },
      config: n.data.config,
    })),
    edges: edges.map((e) => ({
      id: e.id,
      source: e.source,
      target: e.target,
      source_handle: e.sourceHandle ?? "out",
    })),
  };
}

/** Edge state derived from real step results: only animate when a run is actually in progress. */
export function edgeStateFromSteps(steps: Map<string, StepStatus>) {
  return (edge: EdgeDefinition): GwEdgeData["state"] => {
    const source = steps.get(edge.source);
    const target = steps.get(edge.target);
    if (!source) return "idle";
    if (source === "succeeded" && target === "running") return "active";
    if (source === "succeeded" && (target === "succeeded" || target === "failed")) return "traversed";
    if (target === "skipped") return "skipped";
    return "idle";
  };
}
