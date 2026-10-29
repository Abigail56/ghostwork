"use client";

import { LayoutTemplate, Plus, Workflow as WorkflowIcon } from "lucide-react";
import Link from "next/link";
import { usePathname, useRouter, useSearchParams } from "next/navigation";
import { useEffect, useState } from "react";
import { WorkflowActions } from "@/components/workflow/WorkflowActions";
import { ButtonLink } from "@/components/ui/Button";
import { EmptyState, ErrorState, LoadingBlock } from "@/components/ui/Feedback";
import { Select } from "@/components/ui/Form";
import { Card, PageHeader, Pagination, SearchField } from "@/components/ui/Layout";
import { StatusBadge, StatusDot } from "@/components/ui/StatusBadge";
import { timeAgo, triggerLabel } from "@/lib/format";
import { useWorkflows } from "@/lib/queries";
import type { WorkflowStatus } from "@/lib/types";

const PAGE_SIZE = 12;

export function WorkflowList() {
  const router = useRouter();
  const pathname = usePathname();
  const params = useSearchParams();
  const q = params.get("q") ?? "";
  const status = (params.get("status") ?? "") as WorkflowStatus | "";
  const sort = params.get("sort") ?? "-updated";
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
  // Keep the input in sync when the URL changes (e.g. from the top-bar search).
  const [syncedQ, setSyncedQ] = useState(q);
  if (q !== syncedQ) {
    setSyncedQ(q);
    setSearch(q);
  }
  // Debounce typing into the URL.
  useEffect(() => {
    if (search === q) return;
    const timer = setTimeout(() => update({ q: search.trim() || null, page: 1 }), 300);
    return () => clearTimeout(timer);
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [search]);

  const query = useWorkflows({ q, status, sort, page, page_size: PAGE_SIZE });
  const filtered = Boolean(q || status);

  return (
    <>
      <PageHeader
        title="Workflows"
        description="Design, run and monitor your automations."
        actions={
          <>
            <ButtonLink href="/templates">
              <LayoutTemplate size={15} /> Templates
            </ButtonLink>
            <ButtonLink href="/workflows/new" variant="primary">
              <Plus size={15} /> New workflow
            </ButtonLink>
          </>
        }
      />
      <Card>
        <div className="flex flex-col gap-2 border-b border-line-subtle p-3 sm:flex-row sm:items-center sm:p-4">
          <SearchField value={search} onChange={setSearch} placeholder="Search by name or description" label="Search workflows" className="sm:max-w-xs sm:flex-1" />
          <div className="grid grid-cols-2 gap-2 sm:ml-auto sm:flex">
            <label className="sr-only" htmlFor="status-filter">
              Status
            </label>
            <Select id="status-filter" value={status} onChange={(e) => update({ status: e.target.value || null, page: 1 })} className="sm:w-36">
              <option value="">All statuses</option>
              <option value="active">Active</option>
              <option value="paused">Paused</option>
              <option value="draft">Draft</option>
            </Select>
            <label className="sr-only" htmlFor="sort">
              Sort
            </label>
            <Select id="sort" value={sort} onChange={(e) => update({ sort: e.target.value, page: 1 })} className="sm:w-44">
              <option value="-updated">Recently updated</option>
              <option value="-last_run">Recently run</option>
              <option value="name">Name A–Z</option>
              <option value="-name">Name Z–A</option>
              <option value="-created">Newest</option>
              <option value="created">Oldest</option>
            </Select>
          </div>
        </div>

        {query.isPending ? (
          <div className="p-4">
            <LoadingBlock label="Loading workflows" rows={5} />
          </div>
        ) : query.isError ? (
          <ErrorState title="Couldn't load workflows" error={query.error} onRetry={() => query.refetch()} />
        ) : query.data.items.length === 0 ? (
          filtered ? (
            <EmptyState title="No matching workflows" description="Try a different search or clear the filters." action={<ButtonLink href="/workflows">Clear filters</ButtonLink>} />
          ) : (
            <EmptyState
              icon={<WorkflowIcon size={18} />}
              title="No workflows yet"
              description="Create one from scratch or start from a template."
              action={
                <>
                  <ButtonLink href="/workflows/new" variant="primary">
                    <Plus size={15} /> New workflow
                  </ButtonLink>
                  <ButtonLink href="/templates">Browse templates</ButtonLink>
                </>
              }
            />
          )
        ) : (
          <>
            {/* Desktop table */}
            <div className="hidden md:block">
              <table className="w-full text-left text-body">
                <thead className="text-meta text-fg-muted">
                  <tr className="border-b border-line-subtle">
                    <th scope="col" className="py-2.5 pl-5 font-medium">Name</th>
                    <th scope="col" className="py-2.5 font-medium">Status</th>
                    <th scope="col" className="hidden py-2.5 font-medium lg:table-cell">Trigger</th>
                    <th scope="col" className="py-2.5 font-medium">Last run</th>
                    <th scope="col" className="hidden py-2.5 font-medium lg:table-cell">Updated</th>
                    <th scope="col" className="w-12 py-2.5 pr-3"><span className="sr-only">Actions</span></th>
                  </tr>
                </thead>
                <tbody className="divide-y divide-line-subtle">
                  {query.data.items.map((w) => (
                    <tr key={w.id} className="group transition-colors hover:bg-hover/60">
                      <td className="row-y max-w-0 pr-4 pl-5">
                        <Link href={`/workflows/${w.id}`} className="block truncate font-medium text-fg hover:text-violet">
                          {w.name}
                        </Link>
                        <p className="truncate text-meta text-fg-muted">{w.description || `${w.step_count} steps`}</p>
                      </td>
                      <td className="row-y w-28"><StatusBadge status={w.status} size="sm" /></td>
                      <td className="row-y hidden w-28 text-fg-secondary lg:table-cell">{triggerLabel(w.trigger_type)}</td>
                      <td className="row-y w-44">
                        {w.last_execution ? (
                          <Link href={`/executions/${w.last_execution.id}`} className="flex flex-col hover:underline">
                            <StatusDot status={w.last_execution.status} />
                            <span className="text-micro text-fg-muted">{timeAgo(w.last_execution.created_at)}</span>
                          </Link>
                        ) : (
                          <span className="text-meta text-fg-muted">Never run</span>
                        )}
                      </td>
                      <td className="row-y hidden w-32 text-meta text-fg-muted lg:table-cell">{timeAgo(w.updated_at)}</td>
                      <td className="row-y pr-3 text-right"><WorkflowActions workflow={w} /></td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
            {/* Mobile cards */}
            <ul className="divide-y divide-line-subtle md:hidden">
              {query.data.items.map((w) => (
                <li key={w.id} className="flex items-start gap-3 px-3 py-3">
                  <Link href={`/workflows/${w.id}`} className="min-w-0 flex-1">
                    <div className="flex items-center gap-2">
                      <p className="truncate text-body font-medium">{w.name}</p>
                    </div>
                    <div className="mt-1.5 flex flex-wrap items-center gap-x-2 gap-y-1 text-micro text-fg-muted">
                      <StatusBadge status={w.status} size="sm" />
                      <span>{triggerLabel(w.trigger_type)}</span>
                      <span aria-hidden="true">·</span>
                      <span>{w.last_execution ? `Ran ${timeAgo(w.last_execution.created_at)}` : "Never run"}</span>
                    </div>
                  </Link>
                  <WorkflowActions workflow={w} />
                </li>
              ))}
            </ul>
            <div className="border-t border-line-subtle">
              <Pagination page={page} pageSize={PAGE_SIZE} total={query.data.total} onPage={(p) => update({ page: p })} />
            </div>
          </>
        )}
      </Card>
    </>
  );
}
