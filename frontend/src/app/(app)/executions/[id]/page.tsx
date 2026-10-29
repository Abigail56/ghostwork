import { Suspense } from "react";
import { LoadingBlock } from "@/components/ui/Feedback";
import { ExecutionDetail } from "./ExecutionDetail";

export const instant = false;

export default function ExecutionPage({ params }: PageProps<"/executions/[id]">) {
  return (
    <Suspense fallback={<LoadingBlock label="Loading execution" rows={6} />}>
      <ExecutionDetail params={params} />
    </Suspense>
  );
}
