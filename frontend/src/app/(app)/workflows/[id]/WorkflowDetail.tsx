"use client";

import { AlertCircle, ArrowLeft, Check, Copy, History, Pause, PencilRuler, Play, RefreshCw } from "lucide-react";
import Link from "next/link";
import { useRouter } from "next/navigation";
import { use, useState } from "react";
import { ExecutionTable } from "@/components/execution/ExecutionTable";
import { WorkflowActions } from "@/components/workflow/WorkflowActions";
import { WorkflowCanvas } from "@/components/workflow/WorkflowCanvas";
import { Button, ButtonLink } from "@/components/ui/Button";
import { EmptyState, ErrorState, InlineAlert, LoadingBlock } from "@/components/ui/Feedback";
import { Card, CardHeader, KeyValue } from "@/components/ui/Layout";
import { ConfirmDialog } from "@/components/ui/Overlay";
import { StatusBadge } from "@/components/ui/StatusBadge";
import { useToast } from "@/components/ui/Toast";
import { ApiError } from "@/lib/api";
import { formatDateTime, timeAgo, triggerLabel } from "@/lib/format";
import { useExecution, useExecutions, useRotateWebhook, useRunWorkflow, useSetWorkflowStatus, useWorkflow } from "@/lib/queries";
import { summarize } from "@/lib/nodes";

export function CopyField({ value, label }: { value: string; label: string }) {
  const [copied, setCopied] = useState(false);
  return (
    <div className="flex items-center gap-2 rounded-md border border-line bg-canvas py-1 pr-1 pl-3">
      <code className="min-w-0 flex-1 truncate font-mono text-meta text-fg-secondary">{value}</code>
      <Button
        size="icon-sm"
        variant="ghost"
        aria-label={copied ? "Copied" : `Copy ${label}`}
        onClick={async () => {
          await navigator.clipboard.writeText(value);
          setCopied(true);
          setTimeout(() => setCopied(false), 1500);
        }}
      >
        {copied ? <Check size={15} className="text-success" /> : <Copy size={15} />}
      </Button>
    </div>
  );
}

export function WorkflowDetail({ params }: { params: Promise<{ id: string }> }) {
  const { id } = use(params);
  const router = useRouter();
  const toast = useToast();
  const workflow = useWorkflow(id);
  const executions = useExecutions({ workflow_id: id, page_size: 10 });
  const latestId = executions.data?.items[0]?.id ?? null;
  const latest = useExecution(latestId);
  const run = useRunWorkflow();
  const setStatus = useSetWorkflowStatus();
  const rotate = useRotateWebhook();
  const [confirm, setConfirm] = useState<"activate" | "rotate" | null>(null);
  const [actionError, setActionError] = useState<string | null>(null);

  if (workflow.isPending) return <LoadingBlock label="Loading workflow" rows={6} />;
  if (workflow.isError) {
    const notFound = workflow.error instanceof ApiError && workflow.error.status === 404;
    return (
      <Card>
        <ErrorState
          title={notFound ? "Workflow not found" : "Couldn't load this workflow"}
          error={notFound ? "It may have been deleted, or it belongs to another account." : workflow.error}
          onRetry={notFound ? undefined : () => workflow.refetch()}
        />
      </Card>
    );
  }
  const w = workflow.data;
  const trigger = w.definition.nodes.find((n) => n.type.startsWith("trigger."));
  const recent = executions.data?.items ?? [];
  const succeeded = recent.filter((e) => e.status === "succeeded").length;
  const failed = recent.filter((e) => e.status === "failed").length;

  const startRun = () =>
    run.mutate(
      { id: w.id },
      {
        onSuccess: (execution) => {
          toast({ tone: "success", title: "Run queued", description: "Opening the live execution view." });
          router.push(`/executions/${execution.id}`);
        },
        onError: (e) => toast({ tone: "error", title: "Couldn't start the run", description: (e as Error).message }),
      },
    );

  return (
    <>
      <Link href="/workflows" className="mb-4 inline-flex items-center gap-1.5 text-meta text-fg-muted hover:text-fg">
        <ArrowLeft size={14} /> Workflows
      </Link>
      <div className="mb-5 flex flex-col gap-4 lg:flex-row lg:items-start lg:justify-between">
        <div className="min-w-0">
          <div className="flex flex-wrap items-center gap-2.5">
            <h1 className="truncate text-title font-semibold">{w.name}</h1>
            <StatusBadge status={w.status} />
          </div>
          <p className="mt-1 text-body text-fg-muted">{w.description || "No description"}</p>
        </div>
        <div className="flex flex-wrap items-center gap-2">
          <Button onClick={startRun} loading={run.isPending} disabled={w.validation.length > 0} title={w.validation.length ? "Fix validation issues first" : undefined}>
            <Play size={15} /> Run now
          </Button>
          {w.status === "active" ? (
            <Button
              loading={setStatus.isPending}
              onClick={() =>
                setStatus.mutate(
                  { id: w.id, status: "paused" },
                  { onSuccess: () => toast({ tone: "success", title: "Workflow paused" }), onError: (e) => toast({ tone: "error", title: "Couldn't pause", description: (e as Error).message }) },
                )
              }
            >
              <Pause size={15} /> Pause
            </Button>
          ) : (
            <Button onClick={() => (setActionError(null), setConfirm("activate"))} disabled={w.validation.length > 0}>
              <Check size={15} /> Activate
            </Button>
          )}
          <ButtonLink href={`/workflows/${w.id}/builder`} variant="primary">
            <PencilRuler size={15} /> Open builder
          </ButtonLink>
          <WorkflowActions workflow={w} showView={false} onDeleted={() => router.replace("/workflows")} />
        </div>
      </div>

      {w.validation.length > 0 && (
        <InlineAlert tone="warning" className="mb-5">
          <p className="flex items-center gap-1.5 font-medium">
            <AlertCircle size={14} /> {w.validation.length} issue{w.validation.length > 1 ? "s" : ""} to fix before this workflow can run
          </p>
          <ul className="mt-1.5 list-disc pl-5">
            {w.validation.slice(0, 5).map((issue, i) => (
              <li key={i}>{issue.message}</li>
            ))}
          </ul>
        </InlineAlert>
      )}

      <div className="grid grid-cols-1 gap-5 lg:grid-cols-[minmax(0,1fr)_320px]">
        <Card className="overflow-hidden">
          <CardHeader
            title="Workflow map"
            description={
              latest.data
                ? `Showing the latest run (${latest.data.status}, ${timeAgo(latest.data.created_at)})`
                : "No runs yet — step results will appear here after the first run"
            }
          />
          {w.definition.nodes.length ? (
            <WorkflowCanvas definition={w.definition} steps={latest.data?.workflow_version === w.version ? latest.data.steps : undefined} className="h-[380px] rounded-none" />
          ) : (
            <EmptyState title="No steps yet" action={<ButtonLink href={`/workflows/${w.id}/builder`} variant="primary">Open builder</ButtonLink>} />
          )}
        </Card>
        <div className="flex flex-col gap-5">
          <Card>
            <CardHeader title="Trigger" />
            <div className="px-4 py-2 sm:px-5">
              <dl className="divide-y divide-line-subtle">
                <KeyValue label="Type">{triggerLabel(w.trigger_type)}</KeyValue>
                {trigger && <KeyValue label="Setting">{summarize(trigger)}</KeyValue>}
                {w.trigger_type === "trigger.schedule" && (
                  <KeyValue label="Next run">{w.status === "active" ? formatDateTime(w.next_run_at) : "When active"}</KeyValue>
                )}
                <KeyValue label="Last run">{timeAgo(w.last_run_at)}</KeyValue>
              </dl>
              {w.webhook_url && (
                <div className="py-3">
                  <p className="mb-1.5 text-meta text-fg-muted">Webhook URL</p>
                  <CopyField value={w.webhook_url} label="webhook URL" />
                  <button type="button" onClick={() => (setActionError(null), setConfirm("rotate"))} className="mt-2 inline-flex items-center gap-1.5 text-meta text-fg-muted hover:text-fg">
                    <RefreshCw size={13} /> Regenerate URL
                  </button>
                  {w.status !== "active" && <p className="mt-1 text-meta text-warning">Activate the workflow to accept webhook calls.</p>}
                </div>
              )}
            </div>
          </Card>
          <Card>
            <CardHeader title="Recent health" description={recent.length ? `Last ${recent.length} runs` : undefined} />
            <div className="grid grid-cols-3 divide-x divide-line-subtle">
              {[
                ["Succeeded", succeeded, "text-success"],
                ["Failed", failed, failed ? "text-danger" : "text-fg"],
                ["Other", recent.length - succeeded - failed, "text-fg"],
              ].map(([label, value, tone]) => (
                <div key={label as string} className="px-4 py-3">
                  <p className={`text-xl font-semibold tabular-nums ${tone}`}>{value}</p>
                  <p className="text-micro text-fg-muted">{label}</p>
                </div>
              ))}
            </div>
          </Card>
        </div>
      </div>

      <Card className="mt-5">
        <CardHeader
          title="Execution history"
          action={
            <Link href={`/executions?workflow_id=${w.id}`} className="text-meta text-violet hover:underline">
              View all
            </Link>
          }
        />
        {executions.isPending ? (
          <div className="p-4"><LoadingBlock rows={3} /></div>
        ) : executions.isError ? (
          <ErrorState error={executions.error} onRetry={() => executions.refetch()} />
        ) : recent.length ? (
          <ExecutionTable items={recent} showWorkflow={false} />
        ) : (
          <EmptyState icon={<History size={18} />} title="No runs yet" description="Press Run now to test this workflow." />
        )}
      </Card>

      <ConfirmDialog
        open={confirm === "activate"}
        onClose={() => setConfirm(null)}
        title="Activate workflow?"
        description="Its schedule or webhook will start runs automatically. You can pause it at any time."
        confirmLabel="Activate"
        loading={setStatus.isPending}
        error={actionError}
        onConfirm={() =>
          setStatus.mutate(
            { id: w.id, status: "active" },
            { onSuccess: () => (setConfirm(null), toast({ tone: "success", title: `${w.name} is active` })), onError: (e) => setActionError((e as Error).message) },
          )
        }
      />
      <ConfirmDialog
        open={confirm === "rotate"}
        onClose={() => setConfirm(null)}
        title="Regenerate webhook URL?"
        description="The current URL will stop working immediately. Update any service that calls it."
        confirmLabel="Regenerate"
        tone="danger"
        loading={rotate.isPending}
        error={actionError}
        onConfirm={() =>
          rotate.mutate(w.id, {
            onSuccess: () => (setConfirm(null), toast({ tone: "success", title: "Webhook URL regenerated" })),
            onError: (e) => setActionError((e as Error).message),
          })
        }
      />
    </>
  );
}
