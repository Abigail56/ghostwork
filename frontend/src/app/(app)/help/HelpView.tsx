"use client";

import { useQuery } from "@tanstack/react-query";
import { BookOpen, Code2, ExternalLink, Keyboard } from "lucide-react";
import Link from "next/link";
import { Card, CardHeader, PageHeader } from "@/components/ui/Layout";
import { StatusBadge } from "@/components/ui/StatusBadge";
import { api, API_BASE_URL } from "@/lib/api";

export function HelpView() {
  const health = useQuery({
    queryKey: ["health"],
    queryFn: () => api<{ status: string }>("/health", { auth: false }),
    refetchInterval: 30_000,
    retry: false,
  });
  return (
    <>
      <PageHeader title="Help" description="Guides, references and the state of this GhostWork server." />
      <div className="grid gap-4 md:grid-cols-2">
        <Link href="/docs" className="card flex gap-3 p-5 transition-colors hover:border-line-strong">
          <BookOpen size={19} className="mt-0.5 text-violet" aria-hidden="true" />
          <div>
            <p className="text-section font-semibold">Documentation</p>
            <p className="mt-1 text-meta text-fg-muted">Triggers, steps, references, webhooks and limits.</p>
          </div>
        </Link>
        <a href={`${API_BASE_URL}/docs`} target="_blank" rel="noreferrer" className="card flex gap-3 p-5 transition-colors hover:border-line-strong">
          <Code2 size={19} className="mt-0.5 text-cyan" aria-hidden="true" />
          <div>
            <p className="flex items-center gap-1.5 text-section font-semibold">
              API reference <ExternalLink size={13} className="text-fg-muted" aria-hidden="true" />
            </p>
            <p className="mt-1 text-meta text-fg-muted">Interactive OpenAPI documentation for the GhostWork API.</p>
          </div>
        </a>
        <Card>
          <CardHeader title="System status" />
          <div className="flex items-center justify-between px-5 py-4">
            <span className="text-body text-fg-secondary">API</span>
            {health.isPending ? (
              <StatusBadge status="pending" label="Checking" size="sm" />
            ) : health.isError ? (
              <StatusBadge status="failed" label="Unreachable" size="sm" />
            ) : (
              <StatusBadge status="succeeded" label="Operational" size="sm" />
            )}
          </div>
          <p className="border-t border-line-subtle px-5 py-3 text-meta text-fg-muted">
            This checks the API from your browser. Background workers report their health through run results.
          </p>
        </Card>
        <Card>
          <CardHeader title="Keyboard shortcuts" />
          <dl className="flex flex-col gap-2 px-5 py-4 text-body">
            {[
              ["Ctrl K", "Search workflows"],
              ["Ctrl S", "Save in the builder"],
              ["Ctrl Z / Ctrl Shift Z", "Undo / redo in the builder"],
              ["Delete", "Remove selected step or connection"],
            ].map(([key, label]) => (
              <div key={key} className="flex items-center justify-between gap-3">
                <dt className="text-fg-secondary">{label}</dt>
                <dd>
                  <kbd className="inline-flex items-center gap-1 rounded border border-line bg-canvas px-1.5 py-0.5 font-sans text-micro text-fg-muted">
                    <Keyboard size={11} aria-hidden="true" /> {key}
                  </kbd>
                </dd>
              </div>
            ))}
          </dl>
        </Card>
      </div>
    </>
  );
}
