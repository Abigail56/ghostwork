"use client";

import { use } from "react";
import { Builder, BuilderError } from "@/components/builder/Builder";
import { LoadingBlock } from "@/components/ui/Feedback";
import { useWorkflow } from "@/lib/queries";

export function BuilderLoader({ params }: { params: Promise<{ id: string }> }) {
  const { id } = use(params);
  const workflow = useWorkflow(id);
  if (workflow.isPending) return <div className="p-6"><LoadingBlock label="Loading builder" rows={4} /></div>;
  if (workflow.isError) return <BuilderError error={workflow.error} onRetry={() => workflow.refetch()} />;
  // Keyed by id so switching workflows resets editor state. Later refetches don't overwrite local edits.
  return <Builder key={workflow.data.id} workflow={workflow.data} />;
}
