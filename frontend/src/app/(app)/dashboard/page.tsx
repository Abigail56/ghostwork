"use client";

import {
  Activity as ActivityIcon,
  AlertTriangle,
  ArrowRight,
  CheckCircle2,
  Circle,
  History,
  LayoutTemplate,
  Plug,
  Plus,
  Workflow as WorkflowIcon,
} from "lucide-react";
import Link from "next/link";
import { TrendChart } from "@/components/dashboard/TrendChart";
import { ButtonLink } from "@/components/ui/Button";
import { cx } from "@/components/ui/cx";
import { EmptyState, ErrorState, Skeleton } from "@/components/ui/Feedback";
import { Card, CardHeader } from "@/components/ui/Layout";
import { StatusBadge } from "@/components/ui/StatusBadge";
import { useAuth } from "@/lib/auth";
import { formatDuration, greeting, timeAgo, triggerLabel } from "@/lib/format";
import { useDashboard, useIntegrations, useWorkflows } from "@/lib/queries";
import type { DashboardSummary } from "@/lib/types";

function Metric({ label, value, detail, icon: Icon }: { label: string; value: string; detail: string; icon: React.ElementType }) {
  return (
    <Card className="card-pad">
      <div className="flex items-center justify-between">
        <p className="text-meta text-fg-muted">{label}</p>
        <Icon size={16} className="text-fg-muted" aria-hidden="true" />
      </div>
      <p className="mt-2 text-[1.75rem] leading-none font-semibold tracking-tight tabular-nums">{value}</p>
      <p className="mt-2 truncate text-meta text-fg-muted">{detail}</p>
    </Card>
  );
}

function Health({ health }: { health: DashboardSummary["health"] }) {
  const items = [
    { label: "Failures (24h)", value: health.failures_24h, tone: health.failures_24h ? "text-danger" : "text-fg" },
    { label: "Successes (24h)", value: health.successes_24h, tone: "text-fg" },
    { label: "In progress", value: health.in_progress, tone: health.in_progress ? "text-cyan" : "text-fg" },
  ];
  return (
    <Card>
      <CardHeader title="Workflow health" description={`Last run ${timeAgo(health.last_execution_at)}`} />
      <div className="grid grid-cols-3 divide-x divide-line-subtle border-b border-line-subtle">
        {items.map((item) => (
          <div key={item.label} className="px-4 py-3">
            <p className={cx("text-xl font-semibold tabular-nums", item.tone)}>{item.value}</p>
            <p className="mt-0.5 text-micro text-fg-muted">{item.label}</p>
          </div>
        ))}
      </div>
      <div className="px-4 py-3 sm:px-5">
        {health.attention.length ? (
          <ul className="flex flex-col gap-2">
            {health.attention.map((item) => (
              <li key={item.workflow_id}>
                <Link href={`/workflows/${item.workflow_id}`} className="flex items-center gap-2.5 rounded-md text-body hover:text-fg">
                  <AlertTriangle size={15} className="shrink-0 text-warning" aria-hidden="true" />
                  <span className="truncate text-fg-secondary">{item.workflow_name}</span>
                  <span className="ml-auto shrink-0 text-meta text-fg-muted">{item.reason}</span>
                </Link>
              </li>
            ))}
          </ul>
        ) : (
          <p className="flex items-center gap-2 text-body text-fg-muted">
            <CheckCircle2 size={15} className="text-success" aria-hidden="true" /> No active workflows need attention.
          </p>
        )}
      </div>
    </Card>
  );
}

function Onboarding({ hasWorkflow, hasIntegration, hasRun }: { hasWorkflow: boolean; hasIntegration: boolean; hasRun: boolean }) {
  const steps = [
    { done: hasWorkflow, title: "Create your first workflow", body: "Start blank or from a template.", href: "/workflows/new", cta: "New workflow" },
    { done: hasIntegration, title: "Connect an integration", body: "Email, Slack or an API credential.", href: "/integrations", cta: "Integrations" },
    { done: hasRun, title: "Run a workflow", body: "Test it and watch each step complete.", href: "/workflows", cta: "Open workflows" },
  ];
  const remaining = steps.filter((s) => !s.done).length;
  if (!remaining) return null;
  return (
    <Card className="mb-5 overflow-hidden">
      <div className="flex flex-col gap-1 border-b border-line-subtle bg-[linear-gradient(90deg,rgb(133_133_255/0.08),transparent)] px-4 py-4 sm:px-5">
        <h2 className="text-section font-semibold">Get set up</h2>
        <p className="text-meta text-fg-muted">
          {3 - remaining} of 3 done. These steps are checked against your account.
        </p>
      </div>
      <ol className="grid divide-y divide-line-subtle md:grid-cols-3 md:divide-x md:divide-y-0">
        {steps.map((step) => (
          <li key={step.title} className="flex gap-3 px-4 py-4 sm:px-5">
            {step.done ? (
              <CheckCircle2 size={18} className="mt-0.5 shrink-0 text-success" aria-label="Done" />
            ) : (
              <Circle size={18} className="mt-0.5 shrink-0 text-fg-muted" aria-label="Not done" />
            )}
            <div className="min-w-0">
              <p className={cx("text-body font-medium", step.done && "text-fg-muted line-through")}>{step.title}</p>
              <p className="mt-0.5 text-meta text-fg-muted">{step.body}</p>
              {!step.done && (
                <Link href={step.href} className="mt-2 inline-flex items-center gap-1 text-meta font-medium text-violet hover:underline">
                  {step.cta} <ArrowRight size={13} />
                </Link>
              )}
            </div>
          </li>
        ))}
      </ol>
    </Card>
  );
}

function DashboardSkeleton() {
  return (
    <div role="status" aria-label="Loading dashboard">
      <div className="grid grid-cols-2 gap-3 lg:grid-cols-4">
        {[0, 1, 2, 3].map((i) => (
          <Skeleton key={i} className="h-[110px] rounded-lg" />
        ))}
      </div>
      <div className="mt-5 grid gap-5 lg:grid-cols-[1.6fr_1fr]">
        <Skeleton className="h-[320px] rounded-lg" />
        <Skeleton className="h-[320px] rounded-lg" />
      </div>
    </div>
  );
}

export default function DashboardPage() {
  const { user } = useAuth();
  const dashboard = useDashboard();
  const workflows = useWorkflows({ page_size: 4, sort: "-updated" });
  const integrations = useIntegrations();
  const firstName = user?.full_name.split(" ")[0] ?? "";
  const data = dashboard.data;

  return (
    <>
      <div className="mb-5 flex flex-col gap-3 sm:mb-6 sm:flex-row sm:items-end sm:justify-between">
        <div>
          <h1 className="text-title font-semibold">
            {greeting()}, {firstName}
          </h1>
          <p className="mt-1 text-body text-fg-muted">Here&apos;s what your automations have been doing.</p>
        </div>
        <div className="flex gap-2">
          <ButtonLink href="/templates" variant="secondary">
            <LayoutTemplate size={15} /> Templates
          </ButtonLink>
          <ButtonLink href="/workflows/new" variant="primary">
            <Plus size={15} /> New workflow
          </ButtonLink>
        </div>
      </div>

      {dashboard.isPending ? (
        <DashboardSkeleton />
      ) : dashboard.isError ? (
        <Card>
          <ErrorState title="Couldn't load your dashboard" error={dashboard.error} onRetry={() => dashboard.refetch()} />
        </Card>
      ) : data ? (
        <>
          <Onboarding
            hasWorkflow={data.total_workflows > 0}
            hasIntegration={(integrations.data?.length ?? 0) > 0}
            hasRun={data.total_executions > 0}
          />
          <section aria-label="Key metrics" className="grid grid-cols-2 gap-3 lg:grid-cols-4">
            <Metric label="Total workflows" value={String(data.total_workflows)} detail={`${data.total_workflows - data.active_workflows} draft or paused`} icon={WorkflowIcon} />
            <Metric label="Active workflows" value={String(data.active_workflows)} detail="Running on schedule or webhook" icon={ActivityIcon} />
            <Metric label="Total executions" value={data.total_executions.toLocaleString()} detail={`${data.executions_30d.toLocaleString()} in the last 30 days`} icon={History} />
            <Metric
              label="Success rate"
              value={data.success_rate_30d === null ? "—" : `${data.success_rate_30d}%`}
              detail={data.success_rate_30d === null ? "No finished runs in 30 days" : "Of finished runs, last 30 days"}
              icon={CheckCircle2}
            />
          </section>

          <div className="mt-5 grid gap-5 lg:grid-cols-[minmax(0,1.6fr)_minmax(0,1fr)]">
            <Card>
              <CardHeader title="Execution trend" description="Runs per day, last 14 days" />
              <div className="px-4 py-4 sm:px-5">
                <TrendChart trend={data.trend} />
              </div>
            </Card>
            <Health health={data.health} />
          </div>

          <div className="mt-5 grid gap-5 lg:grid-cols-[minmax(0,1.6fr)_minmax(0,1fr)]">
            <Card>
              <CardHeader
                title="Recent executions"
                action={
                  <Link href="/executions" className="text-meta text-violet hover:underline">
                    View all
                  </Link>
                }
              />
              {data.recent_executions.length ? (
                <ul className="divide-y divide-line-subtle">
                  {data.recent_executions.map((execution) => (
                    <li key={execution.id}>
                      <Link
                        href={`/executions/${execution.id}`}
                        className="row-y flex items-center gap-3 px-4 transition-colors hover:bg-hover sm:px-5"
                      >
                        <StatusBadge status={execution.status} size="sm" className="w-[92px] justify-center" />
                        <span className="min-w-0 flex-1">
                          <span className="block truncate text-body font-medium">{execution.workflow_name}</span>
                          <span className="block text-micro text-fg-muted">
                            {triggerLabel(execution.trigger_type)} · {timeAgo(execution.created_at)}
                          </span>
                        </span>
                        <span className="shrink-0 text-meta tabular-nums text-fg-muted">{formatDuration(execution.duration_ms)}</span>
                      </Link>
                    </li>
                  ))}
                </ul>
              ) : (
                <EmptyState
                  icon={<History size={18} />}
                  title="No runs yet"
                  description="Run a workflow and its progress will show up here."
                />
              )}
            </Card>
            <Card>
              <CardHeader title="Recent activity" />
              {data.recent_activity.length ? (
                <ol className="px-4 py-3 sm:px-5">
                  {data.recent_activity.map((event, i) => (
                    <li key={event.id} className="relative flex gap-3 pb-3 last:pb-0">
                      {i < data.recent_activity.length - 1 && (
                        <span className="absolute top-4 bottom-0 left-[4px] w-px bg-line" aria-hidden="true" />
                      )}
                      <span className="mt-1.5 h-[9px] w-[9px] shrink-0 rounded-full border-2 border-violet bg-canvas" aria-hidden="true" />
                      <div className="min-w-0">
                        <p className="text-body text-fg-secondary">{event.message}</p>
                        <p className="text-micro text-fg-muted">{timeAgo(event.created_at)}</p>
                      </div>
                    </li>
                  ))}
                </ol>
              ) : (
                <EmptyState title="Nothing yet" description="Changes you make will be listed here." />
              )}
            </Card>
          </div>

          <section aria-labelledby="your-workflows" className="mt-5">
            <div className="mb-3 flex items-center justify-between">
              <h2 id="your-workflows" className="text-section font-semibold">
                Your workflows
              </h2>
              <Link href="/workflows" className="text-meta text-violet hover:underline">
                Manage workflows
              </Link>
            </div>
            {workflows.data?.items.length ? (
              <div className="grid gap-3 sm:grid-cols-2 xl:grid-cols-4">
                {workflows.data.items.map((workflow) => (
                  <Link key={workflow.id} href={`/workflows/${workflow.id}`} className="card card-pad block transition-colors hover:border-line-strong">
                    <div className="flex items-start justify-between gap-2">
                      <p className="truncate text-body font-semibold">{workflow.name}</p>
                      <StatusBadge status={workflow.status} size="sm" />
                    </div>
                    <p className="mt-1 line-clamp-2 min-h-[2.4em] text-meta text-fg-muted">{workflow.description || "No description"}</p>
                    <div className="mt-3 flex items-center gap-2 text-micro text-fg-muted">
                      <span>{triggerLabel(workflow.trigger_type)}</span>
                      <span aria-hidden="true">·</span>
                      <span>{workflow.step_count} steps</span>
                      <span className="ml-auto">Ran {timeAgo(workflow.last_run_at)}</span>
                    </div>
                  </Link>
                ))}
              </div>
            ) : (
              <Card>
                <EmptyState
                  icon={<WorkflowIcon size={18} />}
                  title="Create your first workflow"
                  description="Automate a repetitive task: call an API on a schedule, react to a webhook, or send an alert when something fails."
                  action={
                    <>
                      <ButtonLink href="/workflows/new" variant="primary">
                        <Plus size={15} /> New workflow
                      </ButtonLink>
                      <ButtonLink href="/templates">Explore templates</ButtonLink>
                    </>
                  }
                />
              </Card>
            )}
          </section>

          <section aria-labelledby="quick-actions" className="mt-5">
            <h2 id="quick-actions" className="mb-3 text-section font-semibold">
              Quick actions
            </h2>
            <div className="grid gap-3 sm:grid-cols-3">
              {[
                { href: "/workflows/new", icon: Plus, title: "New workflow", body: "Start from a trigger" },
                { href: "/templates", icon: LayoutTemplate, title: "Use a template", body: "Monitoring, data pulls, alerts" },
                { href: "/integrations", icon: Plug, title: "Connect a service", body: "SMTP, Slack, API credentials" },
              ].map(({ href, icon: Icon, title, body }) => (
                <Link key={href} href={href} className="card flex items-center gap-3 px-4 py-3 transition-colors hover:border-line-strong">
                  <span className="flex h-9 w-9 items-center justify-center rounded-md bg-violet-soft text-violet">
                    <Icon size={16} aria-hidden="true" />
                  </span>
                  <span>
                    <span className="block text-body font-medium">{title}</span>
                    <span className="block text-meta text-fg-muted">{body}</span>
                  </span>
                  <ArrowRight size={15} className="ml-auto text-fg-muted" aria-hidden="true" />
                </Link>
              ))}
            </div>
          </section>
        </>
      ) : null}
    </>
  );
}
