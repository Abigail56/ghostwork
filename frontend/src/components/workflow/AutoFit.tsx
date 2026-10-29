"use client";

import { useNodesInitialized, useReactFlow, useStore } from "@xyflow/react";
import { useEffect } from "react";

/** Re-fit the view when the canvas is resized (e.g. layout settles, rotation, panel toggles). */
export function AutoFit({ padding = 0.2 }: { padding?: number }) {
  const width = useStore((s) => s.width);
  const height = useStore((s) => s.height);
  const ready = useNodesInitialized();
  const { fitView } = useReactFlow();
  useEffect(() => {
    if (ready && width > 0 && height > 0) void fitView({ padding, maxZoom: 1 });
  }, [ready, width, height, fitView, padding]);
  return null;
}
