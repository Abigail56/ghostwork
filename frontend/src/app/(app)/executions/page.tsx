import type { Metadata } from "next";
import { Suspense } from "react";
import { LoadingBlock } from "@/components/ui/Feedback";
import { ExecutionList } from "./ExecutionList";

export const metadata: Metadata = { title: "Executions" };
export const instant = false;

export default function ExecutionsPage() {
  return (
    <Suspense fallback={<LoadingBlock label="Loading executions" rows={6} />}>
      <ExecutionList />
    </Suspense>
  );
}
