"use client";

import { Background, BackgroundVariant, Controls, ReactFlow, ReactFlowProvider } from "@xyflow/react";
import "@xyflow/react/dist/style.css";
import { useMemo } from "react";
import type { ExecutionStep, WorkflowDefinition } from "@/lib/types";
import { AutoFit } from "./AutoFit";
import { FlowEdge } from "./FlowEdge";
import { FlowNode } from "./FlowNode";
import { edgeStateFromSteps, toFlowEdges, toFlowNodes } from "./flow";

export const nodeTypes = { gw: FlowNode };
export const edgeTypes = { gw: FlowEdge };

/** Read-only Living Workflow view. Pass `steps` to overlay real execution state. */
export function WorkflowCanvas({
  definition,
  steps,
  className = "h-[360px]",
  interactive = true,
}: {
  definition: WorkflowDefinition;
  steps?: ExecutionStep[];
  className?: string;
  interactive?: boolean;
}) {
  const { nodes, edges } = useMemo(() => {
    const byNode = new Map(steps?.map((s) => [s.node_id, s]) ?? []);
    const statuses = new Map(steps?.map((s) => [s.node_id, s.status]) ?? []);
    return {
      nodes: toFlowNodes(definition, (n) => ({
        readOnly: true,
        stepStatus: byNode.get(n.id)?.status,
        stepDuration: byNode.get(n.id)?.duration_ms,
      })),
      edges: toFlowEdges(definition, steps ? edgeStateFromSteps(statuses) : undefined),
    };
  }, [definition, steps]);

  return (
    <div className={`relative overflow-hidden rounded-lg bg-canvas ${className}`}>
      <ReactFlowProvider>
        <ReactFlow
          nodes={nodes}
          edges={edges}
          nodeTypes={nodeTypes}
          edgeTypes={edgeTypes}
          fitView
          fitViewOptions={{ padding: 0.2, maxZoom: 1 }}
          nodesDraggable={false}
          nodesConnectable={false}
          elementsSelectable={false}
          panOnDrag={interactive}
          zoomOnScroll={false}
          zoomOnPinch={interactive}
          preventScrolling={false}
          proOptions={{ hideAttribution: false }}
          colorMode="dark"
          minZoom={0.3}
        >
          <Background variant={BackgroundVariant.Dots} gap={20} size={1} color="rgba(160,168,184,0.13)" />
          {interactive && <Controls showInteractive={false} position="bottom-right" />}
          <AutoFit />
        </ReactFlow>
      </ReactFlowProvider>
    </div>
  );
}
