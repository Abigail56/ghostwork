"use client";

import { ArrowLeft, Ban, RotateCcw } from "lucide-react";
import Link from "next/link";
import { useRouter } from "next/navigation";
import { use, useState } from "react";
import { ExecutionTimeline, JsonBlock } from "@/components/execution/ExecutionTimeline";
import { WorkflowCanvas } from "@/components/workflow/WorkflowCanvas";
import { Button } from "@/components/ui/Button";
import { ErrorState, InlineAlert, LoadingBlock } from "@/components/ui/Feedback";
import { Card, CardHeader, KeyValue } from "@/components/ui/Layout";
import { ConfirmDialog } from "@/components/ui/Overlay";
import { StatusBadge } from "@/components/ui/StatusBadge";
import { useToast } from "@/components/ui/Toast";
import { ApiError } from "@/lib/api";
import { formatDateTime, formatDuration, shortId, triggerLabel } from "@/lib/format";
import { useExecution, useExecutionAction } from "@/lib/queries";

export function ExecutionDetail({ params }: { params: Promise<{ id: string }> }) {
  const { id } = use(params);
  const router = useRouter();
  const toast = useToast();
  const execution = useExecution(id);
  const action = useExecutionAction();
  const [confirmCancel, setConfirmCancel] = useState(false);

  if (execution.isPending) return <LoadingBlock label="Loading execution" rows={6} />;
  if (execution.isError) {
    const notFound = execution.error instanceof ApiError && execution.error.status === 404;
    return (
      <Card>
        <ErrorState
          title={notFound ? "Execution not found" : "Couldn't load this execution"}
          error={notFound ? "It may belong to a deleted workflow or another account." : execution.error}
          onRetry={notFound ? undefined : () => execution.refetch()}
        />
      </Card>
    );
  }
  const e = execution.data;
  const active = e.status === "queued" || e.status === "running";
  const failedStep = e.steps.find((s) => s.status === "failed");

  return (
    <>
      <Link href="/executions" className="mb-4 inline-flex items-center gap-1.5 text-meta text-fg-muted hover:text-fg">
        <ArrowLeft size={14} /> Executions
      </Link>
      <div className="mb-5 flex flex-col gap-3 sm:flex-row sm:items-start sm:justify-between">
        <div className="min-w-0">
          <div className="flex flex-wrap items-center gap-2.5">
            <h1 className="text-title font-semibold">
              Run <span className="font-mono text-fg-secondary">{shortId(e.id)}</span>
            </h1>
            <StatusBadge status={e.status} />
          </div>
          <p className="mt-1 text-body text-fg-muted">
            <Link href={`/workflows/${e.workflow_id}`} className="text-fg-secondary hover:text-violet">
              {e.workflow_name}
            </Link>{" "}
            · {triggerLabel(e.trigger_type)} · {formatDateTime(e.created_at)}
          </p>
        </div>
        <div className="flex gap-2">
          {active && (
            <Button onClick={() => setConfirmCancel(true)}>
              <Ban size={15} /> Cancel run
            </Button>
          )}
          <Button
            variant="primary"
            loading={action.isPending && action.variables?.action === "rerun"}
            disabled={active}
            onClick={() =>
              action.mutate(
                { id: e.id, action: "rerun" },
                {
                  onSuccess: (next) => {
                    toast({ tone: "success", title: "Run queued", description: "Same trigger data, current workflow version." });
                    router.push(`/executions/${next.id}`);
                  },
                  onError: (err) => toast({ tone: "error", title: "Couldn't run again", description: (err as Error).message }),
                },
              )
            }
          >
            <RotateCcw size={15} /> Run again
          </Button>
        </div>
      </div>

      {e.status === "failed" && e.error_message && (
        <InlineAlert className="mb-5">
          <p className="font-medium">{failedStep ? `“${failedStep.node_name}” failed` : "This run failed"}</p>
          <p className="mt-0.5">{e.error_message}</p>
        </InlineAlert>
      )}

      <div className="grid grid-cols-1 gap-5 lg:grid-cols-[minmax(0,1fr)_340px]">
        <div className="flex min-w-0 flex-col gap-5">
          <Card className="overflow-hidden">
            <CardHeader title="Workflow map" description={`Version ${e.workflow_version} as it ran${active ? " — updating live" : ""}`} />
            <WorkflowCanvas definition={e.definition_snapshot} steps={e.steps} className="h-[340px] rounded-none sm:h-[400px]" />
          </Card>
          <Card>
            <CardHeader title="Steps" description="Select a step to see its output or error." />
            <div className="p-2 sm:p-3">
              <ExecutionTimeline key={`${e.id}-${e.status}`} steps={e.steps} totalMs={e.duration_ms} />
            </div>
          </Card>
        </div>
        <div className="flex flex-col gap-5">
          <Card>
            <CardHeader title="Details" />
            <dl className="divide-y divide-line-subtle px-4 py-1 sm:px-5">
              <KeyValue label="Execution ID"><span className="font-mono text-meta">{e.id}</span></KeyValue>
              <KeyValue label="Status">{e.status}</KeyValue>
              <KeyValue label="Trigger">{triggerLabel(e.trigger_type)}</KeyValue>
              <KeyValue label="Queued">{formatDateTime(e.created_at)}</KeyValue>
              <KeyValue label="Started">{formatDateTime(e.started_at)}</KeyValue>
              <KeyValue label="Finished">{formatDateTime(e.finished_at)}</KeyValue>
              <KeyValue label="Duration">{formatDuration(e.duration_ms)}</KeyValue>
            </dl>
          </Card>
          <Card>
            <CardHeader title="Trigger data" description="Available to steps as trigger.payload" />
            <div className="p-3">
              <JsonBlock value={e.trigger_payload} maxHeight="max-h-80" />
            </div>
          </Card>
        </div>
      </div>

      <ConfirmDialog
        open={confirmCancel}
        onClose={() => setConfirmCancel(false)}
        title="Cancel this run?"
        description="A queued run won't start. A running run stops before its next step; a step already in progress finishes first."
        confirmLabel="Cancel run"
        tone="danger"
        loading={action.isPending && action.variables?.action === "cancel"}
        onConfirm={() =>
          action.mutate(
            { id: e.id, action: "cancel" },
            {
              onSuccess: () => {
                setConfirmCancel(false);
                toast({ tone: "success", title: "Run cancelled" });
              },
              onError: (err) => {
                setConfirmCancel(false);
                toast({ tone: "error", title: "Couldn't cancel", description: (err as Error).message });
              },
            },
          )
        }
      />
    </>
  );
}
