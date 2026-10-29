"use client";

import Link from "next/link";
import { useRouter } from "next/navigation";
import { StatusBadge } from "@/components/ui/StatusBadge";
import { formatDateTime, formatDuration, shortId, timeAgo, triggerLabel } from "@/lib/format";
import type { ExecutionSummary } from "@/lib/types";

export function ExecutionTable({ items, showWorkflow = true }: { items: ExecutionSummary[]; showWorkflow?: boolean }) {
  const router = useRouter();
  return (
    <>
      <div className="hidden overflow-x-auto md:block">
        <table className="w-full text-left text-body">
          <thead className="text-meta text-fg-muted">
            <tr className="border-b border-line-subtle">
              <th scope="col" className="py-2.5 pl-5 font-medium">Execution</th>
              {showWorkflow && <th scope="col" className="py-2.5 font-medium">Workflow</th>}
              <th scope="col" className="py-2.5 font-medium">Status</th>
              <th scope="col" className="py-2.5 font-medium">Started</th>
              <th scope="col" className="py-2.5 font-medium">Duration</th>
              <th scope="col" className="py-2.5 font-medium">Trigger</th>
              <th scope="col" className="py-2.5 pr-5 text-right font-medium">Actions</th>
            </tr>
          </thead>
          <tbody className="divide-y divide-line-subtle">
            {items.map((e) => (
              <tr
                key={e.id}
                onClick={() => router.push(`/executions/${e.id}`)}
                className="cursor-pointer transition-colors hover:bg-hover/60"
              >
                <td className="row-y pl-5 font-mono text-meta text-fg-secondary">
                  <Link href={`/executions/${e.id}`} onClick={(ev) => ev.stopPropagation()} className="hover:text-violet">
                    {shortId(e.id)}
                  </Link>
                </td>
                {showWorkflow && <td className="row-y max-w-56 truncate pr-4 font-medium">{e.workflow_name}</td>}
                <td className="row-y"><StatusBadge status={e.status} size="sm" /></td>
                <td className="row-y text-meta text-fg-secondary" title={formatDateTime(e.created_at)}>
                  {formatDateTime(e.created_at)}
                </td>
                <td className="row-y text-meta tabular-nums text-fg-secondary">{formatDuration(e.duration_ms)}</td>
                <td className="row-y text-meta text-fg-secondary">{triggerLabel(e.trigger_type)}</td>
                <td className="row-y pr-5 text-right">
                  <Link
                    href={`/executions/${e.id}`}
                    onClick={(ev) => ev.stopPropagation()}
                    className="text-meta font-medium text-violet hover:underline"
                  >
                    View
                  </Link>
                </td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>
      <ul className="divide-y divide-line-subtle md:hidden">
        {items.map((e) => (
          <li key={e.id}>
            <Link href={`/executions/${e.id}`} className="block px-3 py-3 active:bg-hover">
              <div className="flex items-center gap-2">
                <StatusBadge status={e.status} size="sm" />
                <span className="font-mono text-micro text-fg-muted">{shortId(e.id)}</span>
                <span className="ml-auto text-micro tabular-nums text-fg-muted">{formatDuration(e.duration_ms)}</span>
              </div>
              {showWorkflow && <p className="mt-1.5 truncate text-body font-medium">{e.workflow_name}</p>}
              <p className="mt-0.5 text-micro text-fg-muted">
                {triggerLabel(e.trigger_type)} · {timeAgo(e.created_at)}
              </p>
              {e.status === "failed" && e.error_message && <p className="mt-1 line-clamp-2 text-meta text-danger">{e.error_message}</p>}
            </Link>
          </li>
        ))}
      </ul>
    </>
  );
}
