"use client";

import { Check, Copy, Plus, Trash2, X } from "lucide-react";
import Link from "next/link";
import { useState } from "react";
import { Button } from "@/components/ui/Button";
import { cx } from "@/components/ui/cx";
import { InlineAlert } from "@/components/ui/Feedback";
import { Field, Input, Select, Switch, Textarea } from "@/components/ui/Form";
import { KIND_STYLE, NODE_ICONS, kindOf } from "@/lib/nodes";
import type { Integration, ValidationIssue } from "@/lib/types";
import type { GwNodeData } from "@/components/workflow/flow";

type Config = Record<string, unknown>;

function issueFor(issues: ValidationIssue[], field: string) {
  return issues.find((i) => i.field === field || i.field?.startsWith(`${field}.`))?.message;
}

function CopyChip({ text }: { text: string }) {
  const [copied, setCopied] = useState(false);
  return (
    <button
      type="button"
      onClick={async () => {
        await navigator.clipboard.writeText(text);
        setCopied(true);
        setTimeout(() => setCopied(false), 1200);
      }}
      className="inline-flex max-w-full items-center gap-1 rounded border border-line bg-canvas px-1.5 py-0.5 font-mono text-[11px] text-fg-secondary hover:border-line-strong hover:text-fg"
      title="Copy reference"
    >
      <span className="truncate">{text}</span>
      {copied ? <Check size={11} className="shrink-0 text-success" /> : <Copy size={11} className="shrink-0" />}
    </button>
  );
}

function IntegrationSelect({
  provider,
  integrations,
  value,
  onChange,
  error,
  label,
}: {
  provider: string;
  integrations: Integration[];
  value: string | null | undefined;
  onChange: (value: string | null) => void;
  error?: string;
  label: string;
}) {
  const options = integrations.filter((i) => i.provider === provider);
  return (
    <Field
      label={label}
      error={error}
      hint={
        options.length === 0 ? (
          <>
            None connected yet.{" "}
            <Link href="/integrations" className="text-violet hover:underline">
              Connect one
            </Link>
          </>
        ) : undefined
      }
    >
      {(p) => (
        <Select {...p} value={value ?? ""} onChange={(e) => onChange(e.target.value || null)}>
          <option value="">{provider === "http_auth" ? "None" : "Choose…"}</option>
          {options.map((i) => (
            <option key={i.id} value={i.id}>
              {i.name}
            </option>
          ))}
        </Select>
      )}
    </Field>
  );
}

function PairList({
  items,
  onChange,
  keyLabel,
  valueLabel,
  keyPlaceholder,
  valuePlaceholder,
  addLabel,
  max,
}: {
  items: { key: string; value: string }[];
  onChange: (items: { key: string; value: string }[]) => void;
  keyLabel: string;
  valueLabel: string;
  keyPlaceholder: string;
  valuePlaceholder: string;
  addLabel: string;
  max: number;
}) {
  return (
    <div className="flex flex-col gap-2">
      {items.map((item, index) => (
        <div key={index} className="flex items-start gap-1.5">
          <Input
            aria-label={`${keyLabel} ${index + 1}`}
            value={item.key}
            placeholder={keyPlaceholder}
            onChange={(e) => onChange(items.map((it, i) => (i === index ? { ...it, key: e.target.value } : it)))}
            className="w-[38%] font-mono text-meta"
          />
          <Input
            aria-label={`${valueLabel} ${index + 1}`}
            value={item.value}
            placeholder={valuePlaceholder}
            onChange={(e) => onChange(items.map((it, i) => (i === index ? { ...it, value: e.target.value } : it)))}
            className="min-w-0 flex-1 font-mono text-meta"
          />
          <Button variant="ghost" size="icon-sm" aria-label={`Remove ${keyLabel.toLowerCase()} ${index + 1}`} onClick={() => onChange(items.filter((_, i) => i !== index))} className="mt-0.5 sm:mt-0">
            <X size={14} />
          </Button>
        </div>
      ))}
      {items.length < max && (
        <Button size="sm" variant="ghost" className="w-fit" onClick={() => onChange([...items, { key: "", value: "" }])}>
          <Plus size={14} /> {addLabel}
        </Button>
      )}
    </div>
  );
}

export function ConfigPanel({
  nodeId,
  data,
  issues,
  integrations,
  references,
  webhookUrl,
  onChange,
  onRename,
  onDelete,
}: {
  nodeId: string;
  data: GwNodeData;
  issues: ValidationIssue[];
  integrations: Integration[];
  references: string[];
  webhookUrl: string | null;
  onChange: (config: Config) => void;
  onRename: (name: string) => void;
  onDelete: () => void;
}) {
  const c = data.config;
  const set = (patch: Config) => onChange({ ...c, ...patch });
  const kind = kindOf(data.type);
  const style = KIND_STYLE[kind];
  const Icon = NODE_ICONS[data.type];
  const general = issues.filter((i) => !i.field);

  return (
    <div className="flex flex-col">
      <div className="border-b border-line-subtle px-4 py-3">
        <div className="flex items-center gap-2">
          <span className={cx("flex h-7 w-7 items-center justify-center rounded-md", style.bg, style.text)}>
            {Icon && <Icon size={14} aria-hidden="true" />}
          </span>
          <span className={cx("text-micro font-semibold tracking-[0.06em] uppercase", style.text)}>{style.label}</span>
          <Button variant="ghost" size="icon-sm" className="ml-auto text-fg-muted hover:text-danger" aria-label="Delete step" onClick={onDelete}>
            <Trash2 size={15} />
          </Button>
        </div>
        <Field label="Step name" className="mt-3">
          {(p) => <Input {...p} value={data.name} maxLength={80} onChange={(e) => onRename(e.target.value)} />}
        </Field>
        <div className="mt-2 flex items-center gap-2 text-micro text-fg-muted">
          Reference as <CopyChip text={`{{ steps.${nodeId} }}`} />
        </div>
      </div>

      <div className="flex flex-col gap-4 px-4 py-4">
        {general.map((issue, i) => (
          <InlineAlert key={i} tone="warning">
            {issue.message}
          </InlineAlert>
        ))}

        {data.type === "trigger.manual" && (
          <p className="text-body text-fg-muted">This workflow runs when you press <strong className="text-fg">Test run</strong> or <strong className="text-fg">Run now</strong>. You can pass test data with each run.</p>
        )}

        {data.type === "trigger.schedule" && (
          <div className="grid grid-cols-[1fr_1.4fr] gap-2">
            <Field label="Every" error={issueFor(issues, "every")}>
              {(p) => (
                <Input
                  {...p}
                  type="number"
                  min={1}
                  max={10000}
                  value={String(c.every ?? 1)}
                  onChange={(e) => set({ every: Math.max(1, Number(e.target.value) || 1) })}
                />
              )}
            </Field>
            <Field label="Unit">
              {(p) => (
                <Select {...p} value={String(c.unit ?? "hours")} onChange={(e) => set({ unit: e.target.value })}>
                  <option value="minutes">Minutes</option>
                  <option value="hours">Hours</option>
                  <option value="days">Days</option>
                </Select>
              )}
            </Field>
            <p className="col-span-2 text-meta text-fg-muted">Runs while the workflow is active. The shortest interval is 5 minutes.</p>
          </div>
        )}

        {data.type === "trigger.webhook" && (
          <div className="text-body text-fg-muted">
            {webhookUrl ? (
              <>
                <p className="mb-2">POST to this URL to start a run. The body is available as <code className="font-mono text-fg">trigger.payload.body</code>.</p>
                <div className="flex items-center gap-1">
                  <CopyChip text={webhookUrl} />
                </div>
              </>
            ) : (
              <p>Save the workflow to generate its webhook URL.</p>
            )}
          </div>
        )}

        {data.type === "action.http_request" && (
          <>
            <div className="grid grid-cols-[96px_1fr] gap-2">
              <Field label="Method">
                {(p) => (
                  <Select {...p} value={String(c.method ?? "GET")} onChange={(e) => set({ method: e.target.value })}>
                    {["GET", "POST", "PUT", "PATCH", "DELETE"].map((m) => (
                      <option key={m}>{m}</option>
                    ))}
                  </Select>
                )}
              </Field>
              <Field label="URL" error={issueFor(issues, "url")}>
                {(p) => <Input {...p} value={String(c.url ?? "")} placeholder="https://api.example.com/items" className="font-mono text-meta" onChange={(e) => set({ url: e.target.value })} />}
              </Field>
            </div>
            <IntegrationSelect
              label="Credential"
              provider="http_auth"
              integrations={integrations}
              value={c.credential_integration_id as string | null}
              onChange={(v) => set({ credential_integration_id: v })}
              error={issueFor(issues, "credential_integration_id")}
            />
            <div>
              <p className="mb-1.5 text-meta font-medium text-fg-secondary">Headers</p>
              <PairList
                items={(c.headers as { key: string; value: string }[]) ?? []}
                onChange={(headers) => set({ headers })}
                keyLabel="Header name"
                valueLabel="Header value"
                keyPlaceholder="Accept"
                valuePlaceholder="application/json"
                addLabel="Add header"
                max={20}
              />
              {issueFor(issues, "headers") && <p className="mt-1 text-meta text-danger">{issueFor(issues, "headers")}</p>}
            </div>
            {c.method !== "GET" && (
              <Field label="Body" optional error={issueFor(issues, "body")} hint="JSON bodies get a JSON content type automatically.">
                {(p) => <Textarea {...p} rows={5} value={String(c.body ?? "")} className="font-mono text-meta" placeholder='{"id": "{{ trigger.payload.id }}"}' onChange={(e) => set({ body: e.target.value })} />}
              </Field>
            )}
            <div className="grid grid-cols-2 gap-2">
              <Field label="Timeout (s)" error={issueFor(issues, "timeout_seconds")}>
                {(p) => <Input {...p} type="number" min={1} max={30} value={String(c.timeout_seconds ?? 15)} onChange={(e) => set({ timeout_seconds: Math.min(30, Math.max(1, Number(e.target.value) || 1)) })} />}
              </Field>
              <Field label="Retries" error={issueFor(issues, "retries")}>
                {(p) => <Input {...p} type="number" min={0} max={3} value={String(c.retries ?? 0)} onChange={(e) => set({ retries: Math.min(3, Math.max(0, Number(e.target.value) || 0)) })} />}
              </Field>
            </div>
            <Switch
              label="Fail on error status"
              description="Treat HTTP 400 and above as a failed step."
              checked={c.fail_on_error_status !== false}
              onChange={(v) => set({ fail_on_error_status: v })}
            />
          </>
        )}

        {data.type === "action.transform" && (
          <div>
            <p className="mb-1.5 text-meta font-medium text-fg-secondary">Fields to build</p>
            <PairList
              items={((c.fields as { key: string; value: string }[]) ?? [])}
              onChange={(fields) => set({ fields })}
              keyLabel="Field name"
              valueLabel="Field value"
              keyPlaceholder="name"
              valuePlaceholder="{{ steps.fetch.body.name }}"
              addLabel="Add field"
              max={30}
            />
            {issueFor(issues, "fields") && <p className="mt-1 text-meta text-danger">{issueFor(issues, "fields")}</p>}
          </div>
        )}

        {data.type === "action.email" && (
          <>
            <IntegrationSelect label="Send with" provider="smtp" integrations={integrations} value={c.integration_id as string | null} onChange={(v) => set({ integration_id: v })} error={issueFor(issues, "integration_id")} />
            <Field label="To" error={issueFor(issues, "to")} hint="Separate addresses with commas.">
              {(p) => (
                <Input
                  {...p}
                  value={((c.to as string[]) ?? []).join(", ")}
                  placeholder="ops@example.com, {{ trigger.payload.email }}"
                  onChange={(e) => set({ to: e.target.value.split(",").map((s) => s.trim()).filter(Boolean).slice(0, 10) })}
                />
              )}
            </Field>
            <Field label="Subject" error={issueFor(issues, "subject")}>
              {(p) => <Input {...p} value={String(c.subject ?? "")} onChange={(e) => set({ subject: e.target.value })} />}
            </Field>
            <Field label="Body" error={issueFor(issues, "body")}>
              {(p) => <Textarea {...p} rows={6} value={String(c.body ?? "")} onChange={(e) => set({ body: e.target.value })} />}
            </Field>
          </>
        )}

        {data.type === "action.slack" && (
          <>
            <IntegrationSelect label="Slack connection" provider="slack" integrations={integrations} value={c.integration_id as string | null} onChange={(v) => set({ integration_id: v })} error={issueFor(issues, "integration_id")} />
            <Field label="Message" error={issueFor(issues, "text")}>
              {(p) => <Textarea {...p} rows={5} value={String(c.text ?? "")} onChange={(e) => set({ text: e.target.value })} />}
            </Field>
          </>
        )}

        {data.type === "condition.if" && (
          <>
            <Field label="Value" error={issueFor(issues, "left")}>
              {(p) => <Input {...p} value={String(c.left ?? "")} placeholder="{{ steps.fetch.status_code }}" className="font-mono text-meta" onChange={(e) => set({ left: e.target.value })} />}
            </Field>
            <Field label="Operator">
              {(p) => (
                <Select {...p} value={String(c.operator ?? "equals")} onChange={(e) => set({ operator: e.target.value })}>
                  <option value="equals">equals</option>
                  <option value="not_equals">does not equal</option>
                  <option value="contains">contains</option>
                  <option value="not_contains">does not contain</option>
                  <option value="greater_than">is greater than</option>
                  <option value="less_than">is less than</option>
                  <option value="is_empty">is empty</option>
                  <option value="is_not_empty">is not empty</option>
                </Select>
              )}
            </Field>
            {!["is_empty", "is_not_empty"].includes(String(c.operator)) && (
              <Field label="Compare to" error={issueFor(issues, "right")}>
                {(p) => <Input {...p} value={String(c.right ?? "")} className="font-mono text-meta" onChange={(e) => set({ right: e.target.value })} />}
              </Field>
            )}
            <p className="text-meta text-fg-muted">Connect the <span className="text-success">True</span> and False outputs to continue each branch.</p>
          </>
        )}

        {kind !== "trigger" && (
          <div className="border-t border-line-subtle pt-4">
            <p className="mb-2 text-meta font-medium text-fg-secondary">Available references</p>
            <div className="flex flex-wrap gap-1.5">
              {references.map((ref) => (
                <CopyChip key={ref} text={ref} />
              ))}
            </div>
            <p className="mt-2 text-micro text-fg-muted">Add a path after a reference, e.g. <code className="font-mono">.body.id</code>.</p>
          </div>
        )}
      </div>
    </div>
  );
}
