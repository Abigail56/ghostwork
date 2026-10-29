"use client";

import { History, X } from "lucide-react";
import { usePathname, useRouter, useSearchParams } from "next/navigation";
import { useEffect, useState } from "react";
import { ExecutionTable } from "@/components/execution/ExecutionTable";
import { Button, ButtonLink } from "@/components/ui/Button";
import { EmptyState, ErrorState, LoadingBlock } from "@/components/ui/Feedback";
import { Input, Select } from "@/components/ui/Form";
import { Card, PageHeader, Pagination, SearchField } from "@/components/ui/Layout";
import { useExecutions, useWorkflows } from "@/lib/queries";

const PAGE_SIZE = 20;

/** yyyy-mm-dd (local) -> ISO at local midnight; `endOfDay` shifts to the next midnight. */
function dayToIso(day: string, endOfDay = false) {
  if (!day) return undefined;
  const date = new Date(`${day}T00:00:00`);
  if (endOfDay) date.setDate(date.getDate() + 1);
  return date.toISOString();
}

export function ExecutionList() {
  const router = useRouter();
  const pathname = usePathname();
  const params = useSearchParams();
  const q = params.get("q") ?? "";
  const status = params.get("status") ?? "";
  const workflowId = params.get("workflow_id") ?? "";
  const from = params.get("from") ?? "";
  const to = params.get("to") ?? "";
  const page = Number(params.get("page") ?? 1) || 1;
  const [search, setSearch] = useState(q);

  const update = (next: Record<string, string | number | null>) => {
    const merged = new URLSearchParams(params.toString());
    for (const [key, value] of Object.entries(next)) {
      if (value === null || value === "" || (key === "page" && value === 1)) merged.delete(key);
      else merged.set(key, String(value));
    }
    router.replace(`${pathname}${merged.size ? `?${merged}` : ""}`, { scroll: false });
  };

  // Keep the input in sync when the URL changes (e.g. from the top-bar search).
  const [syncedQ, setSyncedQ] = useState(q);
  if (q !== syncedQ) {
    setSyncedQ(q);
    setSearch(q);
  }
  useEffect(() => {
    if (search === q) return;
    const timer = setTimeout(() => update({ q: search.trim() || null, page: 1 }), 300);
    return () => clearTimeout(timer);
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [search]);

  const workflows = useWorkflows({ page_size: 100, sort: "name" });
  const query = useExecutions({
    q,
    status,
    workflow_id: workflowId,
    from: dayToIso(from),
    to: dayToIso(to, true),
    page,
    page_size: PAGE_SIZE,
  });
  const filtered = Boolean(q || status || workflowId || from || to);

  return (
    <>
      <PageHeader title="Executions" description="Every run of every workflow, step by step." />
      <Card>
        <div className="flex flex-col gap-2 border-b border-line-subtle p-3 sm:p-4 xl:flex-row xl:items-center">
          <SearchField value={search} onChange={setSearch} placeholder="Search by workflow or execution ID" label="Search executions" className="xl:max-w-xs xl:flex-1" />
          <div className="grid grid-cols-2 gap-2 sm:grid-cols-4 xl:ml-auto xl:flex">
            <label htmlFor="exec-status" className="sr-only">Status</label>
            <Select id="exec-status" value={status} onChange={(e) => update({ status: e.target.value || null, page: 1 })} className="xl:w-36">
              <option value="">All statuses</option>
              <option value="succeeded">Succeeded</option>
              <option value="failed">Failed</option>
              <option value="running">Running</option>
              <option value="queued">Queued</option>
              <option value="cancelled">Cancelled</option>
            </Select>
            <label htmlFor="exec-workflow" className="sr-only">Workflow</label>
            <Select id="exec-workflow" value={workflowId} onChange={(e) => update({ workflow_id: e.target.value || null, page: 1 })} className="xl:w-48">
              <option value="">All workflows</option>
              {workflows.data?.items.map((w) => (
                <option key={w.id} value={w.id}>{w.name}</option>
              ))}
            </Select>
            <label htmlFor="exec-from" className="sr-only">From date</label>
            <Input id="exec-from" type="date" value={from} max={to || undefined} onChange={(e) => update({ from: e.target.value || null, page: 1 })} className="xl:w-40" />
            <label htmlFor="exec-to" className="sr-only">To date</label>
            <Input id="exec-to" type="date" value={to} min={from || undefined} onChange={(e) => update({ to: e.target.value || null, page: 1 })} className="xl:w-40" />
          </div>
          {filtered && (
            <Button variant="ghost" size="sm" onClick={() => router.replace(pathname)} className="w-fit">
              <X size={14} /> Clear
            </Button>
          )}
        </div>
        {query.isPending ? (
          <div className="p-4"><LoadingBlock label="Loading executions" rows={6} /></div>
        ) : query.isError ? (
          <ErrorState title="Couldn't load executions" error={query.error} onRetry={() => query.refetch()} />
        ) : query.data.items.length === 0 ? (
          filtered ? (
            <EmptyState title="No matching executions" description="Try different filters." />
          ) : (
            <EmptyState
              icon={<History size={18} />}
              title="No executions yet"
              description="When a workflow runs — manually, on a schedule or from a webhook — it appears here."
              action={<ButtonLink href="/workflows" variant="primary">Go to workflows</ButtonLink>}
            />
          )
        ) : (
          <>
            <ExecutionTable items={query.data.items} />
            <div className="border-t border-line-subtle">
              <Pagination page={page} pageSize={PAGE_SIZE} total={query.data.total} onPage={(p) => update({ page: p })} />
            </div>
          </>
        )}
      </Card>
    </>
  );
}
