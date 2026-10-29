"use client";

import { ArrowRight, Eye } from "lucide-react";
import Link from "next/link";
import { useRouter } from "next/navigation";
import { useState } from "react";
import { WorkflowCanvas } from "@/components/workflow/WorkflowCanvas";
import { Button } from "@/components/ui/Button";
import { cx } from "@/components/ui/cx";
import { ErrorState, InlineAlert, LoadingBlock } from "@/components/ui/Feedback";
import { Card, PageHeader } from "@/components/ui/Layout";
import { Dialog } from "@/components/ui/Overlay";
import { useToast } from "@/components/ui/Toast";
import { KIND_STYLE, NODE_ICONS, kindOf } from "@/lib/nodes";
import { useIntegrations, useTemplates, useUseTemplate } from "@/lib/queries";
import type { Template } from "@/lib/types";

const PROVIDER_LABEL: Record<string, string> = { smtp: "Email (SMTP)", slack: "Slack" };

function StepStrip({ template }: { template: Template }) {
  return (
    <ol className="flex flex-wrap items-center gap-1.5" aria-label="Steps">
      {template.definition.nodes.map((node, i) => {
        const Icon = NODE_ICONS[node.type];
        const style = KIND_STYLE[kindOf(node.type)];
        return (
          <li key={node.id} className="flex items-center gap-1.5">
            <span className={cx("flex h-7 w-7 items-center justify-center rounded-md", style.bg, style.text)} title={node.name}>
              {Icon && <Icon size={14} aria-hidden="true" />}
              <span className="sr-only">{node.name}</span>
            </span>
            {i < template.definition.nodes.length - 1 && <span className="h-px w-3 bg-line-strong" aria-hidden="true" />}
          </li>
        );
      })}
    </ol>
  );
}

export function TemplatesView() {
  const templates = useTemplates();
  const integrations = useIntegrations();
  const use = useUseTemplate();
  const router = useRouter();
  const toast = useToast();
  const [preview, setPreview] = useState<Template | null>(null);
  const connected = new Set((integrations.data ?? []).map((i) => i.provider));

  const create = (template: Template) =>
    use.mutate(
      { slug: template.slug },
      {
        onSuccess: (workflow) => {
          toast({ tone: "success", title: "Workflow created from template", description: "Review each step, then run a test." });
          router.push(`/workflows/${workflow.id}/builder`);
        },
        onError: (e) => toast({ tone: "error", title: "Couldn't create the workflow", description: (e as Error).message }),
      },
    );

  return (
    <>
      <PageHeader title="Templates" description="Start from a working pattern. Every template uses steps that are available today." />
      {templates.isPending ? (
        <LoadingBlock label="Loading templates" rows={4} />
      ) : templates.isError ? (
        <Card><ErrorState error={templates.error} onRetry={() => templates.refetch()} /></Card>
      ) : (
        <div className="grid gap-4 md:grid-cols-2 xl:grid-cols-3">
          {templates.data.map((template) => {
            const missing = template.requires.filter((r) => !connected.has(r));
            return (
              <Card key={template.slug} className="flex flex-col">
                <div className="flex flex-1 flex-col p-4 sm:p-5">
                  <p className="eyebrow">{template.category}</p>
                  <h2 className="mt-1.5 text-section font-semibold">{template.name}</h2>
                  <p className="mt-1 flex-1 text-meta text-fg-muted">{template.description}</p>
                  <div className="mt-4"><StepStrip template={template} /></div>
                  {template.requires.length > 0 && (
                    <p className={cx("mt-3 text-micro", missing.length ? "text-warning" : "text-fg-muted")}>
                      Uses {template.requires.map((r) => PROVIDER_LABEL[r] ?? r).join(", ")}
                      {missing.length ? " — not connected yet" : ""}
                    </p>
                  )}
                </div>
                <div className="flex gap-2 border-t border-line-subtle px-4 py-3 sm:px-5">
                  <Button size="sm" variant="ghost" onClick={() => setPreview(template)}>
                    <Eye size={14} /> Preview
                  </Button>
                  <Button size="sm" variant="primary" className="ml-auto" onClick={() => create(template)} loading={use.isPending && use.variables?.slug === template.slug}>
                    Use template <ArrowRight size={14} />
                  </Button>
                </div>
              </Card>
            );
          })}
        </div>
      )}

      <Dialog
        open={preview !== null}
        onClose={() => setPreview(null)}
        title={preview?.name ?? ""}
        description={preview?.description}
        size="lg"
        footer={
          preview && (
            <>
              <Button onClick={() => setPreview(null)}>Close</Button>
              <Button variant="primary" onClick={() => create(preview)} loading={use.isPending}>
                Use template <ArrowRight size={14} />
              </Button>
            </>
          )
        }
      >
        {preview && (
          <>
            <WorkflowCanvas definition={preview.definition} className="h-[340px] border border-line-subtle" />
            <ul className="mt-4 flex flex-col gap-2">
              {preview.definition.nodes.map((node) => {
                const style = KIND_STYLE[kindOf(node.type)];
                return (
                  <li key={node.id} className="flex items-baseline gap-2 text-body">
                    <span className={cx("w-20 shrink-0 text-micro font-semibold tracking-wide uppercase", style.text)}>{style.label}</span>
                    <span className="text-fg-secondary">{node.name}</span>
                  </li>
                );
              })}
            </ul>
            {preview.requires.some((r) => !connected.has(r)) && (
              <InlineAlert tone="info" className="mt-4">
                This template needs {preview.requires.map((r) => PROVIDER_LABEL[r] ?? r).join(" and ")}. You can create it now and{" "}
                <Link href="/integrations" className="underline">connect the integration</Link> before running it.
              </InlineAlert>
            )}
          </>
        )}
      </Dialog>
    </>
  );
}
