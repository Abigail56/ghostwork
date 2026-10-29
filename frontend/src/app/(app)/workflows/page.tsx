import type { Metadata } from "next";
import { Suspense } from "react";
import { LoadingBlock } from "@/components/ui/Feedback";
import { WorkflowList } from "./WorkflowList";

export const metadata: Metadata = { title: "Workflows" };

export const instant = false;

export default function WorkflowsPage() {
  return (
    <Suspense fallback={<LoadingBlock label="Loading workflows" rows={5} />}>
      <WorkflowList />
    </Suspense>
  );
}
