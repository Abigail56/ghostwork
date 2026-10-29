import { Suspense } from "react";
import { LoadingBlock } from "@/components/ui/Feedback";
import { WorkflowDetail } from "./WorkflowDetail";

export const instant = false;

export default function WorkflowPage({ params }: PageProps<"/workflows/[id]">) {
  return (
    <Suspense fallback={<LoadingBlock label="Loading workflow" rows={6} />}>
      <WorkflowDetail params={params} />
    </Suspense>
  );
}
