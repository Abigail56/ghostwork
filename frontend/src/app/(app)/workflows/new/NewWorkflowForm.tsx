"use client";

import { zodResolver } from "@hookform/resolvers/zod";
import { ArrowLeft, CalendarClock, FileUp, Hand, LayoutTemplate, Webhook } from "lucide-react";
import Link from "next/link";
import { useRouter } from "next/navigation";
import { useState } from "react";
import { useForm } from "react-hook-form";
import { z } from "zod";
import { Button } from "@/components/ui/Button";
import { cx } from "@/components/ui/cx";
import { InlineAlert } from "@/components/ui/Feedback";
import { Field, Input, Textarea } from "@/components/ui/Form";
import { Card, PageHeader } from "@/components/ui/Layout";
import { useCreateWorkflow } from "@/lib/queries";
import type { WorkflowDefinition } from "@/lib/types";

const TRIGGERS = [
  { type: "trigger.manual", icon: Hand, title: "Manual", body: "Run on demand from GhostWork.", name: "Manual trigger", config: {} },
  { type: "trigger.schedule", icon: CalendarClock, title: "Schedule", body: "Repeat every few minutes, hours or days.", name: "Every hour", config: { every: 1, unit: "hours" } },
  { type: "trigger.webhook", icon: Webhook, title: "Webhook", body: "Run when a unique URL receives a POST.", name: "Incoming webhook", config: {} },
] as const;

const schema = z.object({
  name: z.string().trim().min(1, "Give your workflow a name.").max(120, "Keep it under 120 characters."),
  description: z.string().max(1000).optional(),
});
type Values = z.infer<typeof schema>;

export function NewWorkflowForm() {
  const router = useRouter();
  const create = useCreateWorkflow();
  const [trigger, setTrigger] = useState<(typeof TRIGGERS)[number]["type"]>("trigger.manual");
  const [imported, setImported] = useState<{ file: string; definition: WorkflowDefinition } | null>(null);
  const [importError, setImportError] = useState<string | null>(null);
  const {
    register,
    handleSubmit,
    setValue,
    formState: { errors },
  } = useForm<Values>({ resolver: zodResolver(schema) });

  const onImport = async (file: File | undefined) => {
    setImportError(null);
    if (!file) return;
    if (file.size > 1_000_000) return setImportError("That file is too large to be a GhostWork workflow.");
    try {
      const data = JSON.parse(await file.text());
      const definition = data.definition ?? data;
      if (!Array.isArray(definition?.nodes) || !Array.isArray(definition?.edges)) throw new Error();
      setImported({ file: file.name, definition });
      if (data.name) setValue("name", String(data.name).slice(0, 120), { shouldValidate: true });
      if (data.description) setValue("description", String(data.description).slice(0, 1000));
    } catch {
      setImportError("This file isn't a GhostWork workflow export.");
    }
  };

  const onSubmit = (values: Values) => {
    const chosen = TRIGGERS.find((t) => t.type === trigger)!;
    const definition: WorkflowDefinition = imported?.definition ?? {
      nodes: [{ id: "trigger", type: chosen.type, name: chosen.name, position: { x: 0, y: 0 }, config: { ...chosen.config } }],
      edges: [],
    };
    create.mutate(
      { name: values.name, description: values.description ?? "", definition },
      { onSuccess: (workflow) => router.push(`/workflows/${workflow.id}/builder`) },
    );
  };

  return (
    <div className="mx-auto max-w-2xl">
      <Link href="/workflows" className="mb-4 inline-flex items-center gap-1.5 text-meta text-fg-muted hover:text-fg">
        <ArrowLeft size={14} /> Workflows
      </Link>
      <PageHeader title="New workflow" description="Name it, choose how it starts, then build the steps." />
      <Card>
        <form onSubmit={handleSubmit(onSubmit)} className="flex flex-col gap-5 p-4 sm:p-6" noValidate>
          {create.isError && <InlineAlert>{create.error.message}</InlineAlert>}
          <Field label="Name" error={errors.name?.message}>
            {(p) => <Input {...p} placeholder="e.g. Nightly order sync" autoFocus {...register("name")} />}
          </Field>
          <Field label="Description" optional error={errors.description?.message}>
            {(p) => <Textarea {...p} rows={3} placeholder="What does this workflow do?" {...register("description")} />}
          </Field>
          {imported ? (
            <div className="flex items-center gap-3 rounded-lg border border-violet/40 bg-violet-soft px-3 py-2.5">
              <FileUp size={16} className="text-violet" aria-hidden="true" />
              <p className="min-w-0 flex-1 truncate text-body">
                Importing <span className="font-medium">{imported.file}</span> · {imported.definition.nodes.length} steps
              </p>
              <Button size="sm" variant="ghost" onClick={() => setImported(null)}>
                Remove
              </Button>
            </div>
          ) : (
          <fieldset>
            <legend className="mb-2 text-meta font-medium text-fg-secondary">How should it start?</legend>
            <div role="radiogroup" className="grid gap-2 sm:grid-cols-3">
              {TRIGGERS.map(({ type, icon: Icon, title, body }) => (
                <button
                  key={type}
                  type="button"
                  role="radio"
                  aria-checked={trigger === type}
                  onClick={() => setTrigger(type)}
                  className={cx(
                    "flex flex-col items-start rounded-lg border p-3 text-left transition-colors",
                    trigger === type ? "border-violet bg-violet-soft" : "border-line bg-canvas hover:border-line-strong",
                  )}
                >
                  <Icon size={17} className={trigger === type ? "text-violet" : "text-fg-muted"} aria-hidden="true" />
                  <span className="mt-2 text-body font-medium">{title}</span>
                  <span className="mt-0.5 text-meta text-fg-muted">{body}</span>
                </button>
              ))}
            </div>
            <p className="mt-2 text-meta text-fg-muted">You can change the trigger later in the builder.</p>
          </fieldset>
          )}
          <div>
            <label className="inline-flex cursor-pointer items-center gap-1.5 text-meta text-fg-muted hover:text-fg">
              <FileUp size={14} aria-hidden="true" /> Import from a GhostWork JSON export
              <input type="file" accept="application/json,.json" className="sr-only" onChange={(e) => onImport(e.target.files?.[0])} />
            </label>
            {importError && <p className="mt-1 text-meta text-danger" role="alert">{importError}</p>}
          </div>
          <div className="flex flex-col-reverse gap-2 border-t border-line-subtle pt-5 sm:flex-row sm:items-center">
            <Link href="/templates" className="inline-flex items-center justify-center gap-1.5 text-meta text-fg-muted hover:text-fg sm:justify-start">
              <LayoutTemplate size={14} /> Start from a template instead
            </Link>
            <Button type="submit" variant="primary" loading={create.isPending} className="sm:ml-auto">
              Create and open builder
            </Button>
          </div>
        </form>
      </Card>
    </div>
  );
}
