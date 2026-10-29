"use client";

import { BaseEdge, EdgeLabelRenderer, getSmoothStepPath, type EdgeProps } from "@xyflow/react";
import { memo } from "react";
import type { GwEdge } from "./flow";

const STROKES = {
  idle: "#3a4254",
  traversed: "#55c5f2",
  active: "#55c5f2",
  skipped: "#262c38",
};

export const FlowEdge = memo(function FlowEdge(props: EdgeProps<GwEdge>) {
  const { sourceX, sourceY, targetX, targetY, sourcePosition, targetPosition, data, selected, markerEnd } = props;
  const [path, labelX, labelY] = getSmoothStepPath({
    sourceX,
    sourceY,
    targetX,
    targetY,
    sourcePosition,
    targetPosition,
    borderRadius: 10,
  });
  const state = data?.state ?? "idle";
  const handle = data?.handle;
  return (
    <>
      <BaseEdge
        path={path}
        markerEnd={markerEnd}
        style={{
          stroke: selected ? "#8585ff" : STROKES[state],
          strokeWidth: selected ? 2 : 1.5,
        }}
      />
      {state === "active" && (
        <path d={path} fill="none" stroke="#bfeaff" strokeWidth={2} className="edge-flow" pointerEvents="none" />
      )}
      {(handle === "true" || handle === "false") && (
        <EdgeLabelRenderer>
          <span
            className="nodrag nopan absolute rounded-full border border-line bg-elevated px-1.5 py-px text-[10px] font-semibold tracking-wide uppercase"
            style={{
              transform: `translate(-50%, -50%) translate(${labelX}px, ${labelY}px)`,
              color: handle === "true" ? "#3dd68c" : "#a0a8b8",
            }}
          >
            {handle}
          </span>
        </EdgeLabelRenderer>
      )}
    </>
  );
});
