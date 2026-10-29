"use client";

import { FileSpreadsheet, GitBranch, Plug, Plus, ShieldCheck, Trash2, Zap } from "lucide-react";
import { useState } from "react";
import { Button } from "@/components/ui/Button";
import { cx } from "@/components/ui/cx";
import { ErrorState, InlineAlert, LoadingBlock } from "@/components/ui/Feedback";
import { Field, Input, SegmentedControl, Switch } from "@/components/ui/Form";
import { Card, PageHeader } from "@/components/ui/Layout";
import { ConfirmDialog, Dialog } from "@/components/ui/Overlay";
import { StatusBadge } from "@/components/ui/StatusBadge";
import { useToast } from "@/components/ui/Toast";
import { timeAgo } from "@/lib/format";
import { PROVIDER_ICONS } from "@/lib/nodes";
import { useConnectIntegration, useIntegrationAction, useIntegrations, useProviders } from "@/lib/queries";
import type { Integration, Provider } from "@/lib/types";

const PLANNED_ICONS: Record<string, React.ElementType> = { google: FileSpreadsheet, github: GitBranch };

type FormState = Record<string, string | boolean>;

const DEFAULTS: Record<string, FormState> = {
  smtp: { name: "Email", host: "", port: "587", username: "", password: "", use_tls: true, sender: "" },
  slack: { name: "Slack", webhook_url: "" },
  http_auth: { name: "API credential", scheme: "bearer", header_name: "X-API-Key", token: "" },
};

function toConfig(provider: string, f: FormState) {
  if (provider === "smtp")
    return {
      host: String(f.host).trim(),
      port: Number(f.port),
      username: String(f.username).trim() || null,
      password: String(f.password) || null,
      use_tls: Boolean(f.use_tls),
      sender: String(f.sender).trim(),
    };
  if (provider === "slack") return { webhook_url: String(f.webhook_url).trim() };
  return {
    scheme: f.scheme,
    header_name: f.scheme === "bearer" ? "Authorization" : String(f.header_name).trim(),
    token: String(f.token),
  };
}

function ConnectDialog({ provider, onClose }: { provider: Provider | null; onClose: () => void }) {
  const connect = useConnectIntegration();
  const toast = useToast();
  const [form, setForm] = useState<FormState>({});
  const [error, setError] = useState<string | null>(null);
  const key = provider?.key ?? "";
  const f = { ...DEFAULTS[key], ...form };
  const set = (patch: FormState) => setForm((current) => ({ ...current, ...patch }));
  const close = () => {
    setForm({});
    setError(null);
    connect.reset();
    onClose();
  };

  const submit = (e: React.FormEvent) => {
    e.preventDefault();
    setError(null);
    if (!String(f.name).trim()) return setError("Give this connection a name.");
    connect.mutate(
      { provider: key, name: String(f.name).trim(), config: toConfig(key, f) },
      {
        onSuccess: (integration) => {
          toast({ tone: "success", title: `${integration.name} connected` });
          close();
        },
        onError: (err) => setError((err as Error).message),
      },
    );
  };

  return (
    <Dialog
      open={provider !== null}
      onClose={close}
      title={`Connect ${provider?.label ?? ""}`}
      description={provider?.description}
      footer={
        <>
          <Button onClick={close}>Cancel</Button>
          <Button type="submit" form="connect-form" variant="primary" loading={connect.isPending}>
            {key === "smtp" ? "Check and connect" : "Connect"}
          </Button>
        </>
      }
    >
      <form id="connect-form" onSubmit={submit} className="flex flex-col gap-4" noValidate>
        {error && <InlineAlert>{error}</InlineAlert>}
        <Field label="Connection name">{(p) => <Input {...p} value={String(f.name)} maxLength={80} onChange={(e) => set({ name: e.target.value })} />}</Field>
        {key === "smtp" && (
          <>
            <div className="grid grid-cols-[1fr_100px] gap-2">
              <Field label="SMTP host">{(p) => <Input {...p} value={String(f.host)} placeholder="smtp.example.com" onChange={(e) => set({ host: e.target.value })} />}</Field>
              <Field label="Port">{(p) => <Input {...p} type="number" value={String(f.port)} onChange={(e) => set({ port: e.target.value })} />}</Field>
            </div>
            <div className="grid gap-2 sm:grid-cols-2">
              <Field label="Username" optional>{(p) => <Input {...p} value={String(f.username)} autoComplete="off" onChange={(e) => set({ username: e.target.value })} />}</Field>
              <Field label="Password" optional>{(p) => <Input {...p} type="password" value={String(f.password)} autoComplete="new-password" onChange={(e) => set({ password: e.target.value })} />}</Field>
            </div>
            <Field label="Send from" hint="The address recipients will see.">{(p) => <Input {...p} type="email" value={String(f.sender)} placeholder="automations@example.com" onChange={(e) => set({ sender: e.target.value })} />}</Field>
            <Switch label="Use STARTTLS" description="Port 465 always uses implicit TLS." checked={Boolean(f.use_tls)} onChange={(v) => set({ use_tls: v })} />
            <p className="text-meta text-fg-muted">GhostWork signs in to the server to check these settings before saving. Nothing is sent.</p>
          </>
        )}
        {key === "slack" && (
          <Field label="Incoming webhook URL" hint="Create one in Slack under Apps → Incoming Webhooks.">
            {(p) => <Input {...p} value={String(f.webhook_url)} placeholder="https://hooks.slack.com/services/…" autoComplete="off" onChange={(e) => set({ webhook_url: e.target.value })} />}
          </Field>
        )}
        {key === "http_auth" && (
          <>
            <div>
              <p className="mb-1.5 text-meta font-medium text-fg-secondary">How is it sent?</p>
              <SegmentedControl
                label="Credential scheme"
                value={String(f.scheme) as "bearer" | "header"}
                onChange={(v) => set({ scheme: v })}
                options={[
                  { value: "bearer", label: "Bearer token" },
                  { value: "header", label: "Custom header" },
                ]}
              />
            </div>
            {f.scheme === "header" && (
              <Field label="Header name">{(p) => <Input {...p} value={String(f.header_name)} onChange={(e) => set({ header_name: e.target.value })} />}</Field>
            )}
            <Field label="Token" hint="Encrypted at rest and never shown again.">
              {(p) => <Input {...p} type="password" value={String(f.token)} autoComplete="new-password" onChange={(e) => set({ token: e.target.value })} />}
            </Field>
          </>
        )}
        <p className="flex items-start gap-2 rounded-md border border-line-subtle bg-canvas px-3 py-2 text-meta text-fg-muted">
          <ShieldCheck size={15} className="mt-0.5 shrink-0 text-success" aria-hidden="true" />
          Secrets are encrypted before they&apos;re stored and are never sent back to your browser.
        </p>
      </form>
    </Dialog>
  );
}

function ConnectionRow({ integration }: { integration: Integration }) {
  const action = useIntegrationAction();
  const toast = useToast();
  const [confirm, setConfirm] = useState(false);
  const details = Object.entries(integration.details).filter(([k]) => !["has_password", "use_tls"].includes(k));
  const providerVerifiable = integration.provider === "smtp";
  return (
    <li className="flex flex-col gap-3 px-4 py-3 sm:flex-row sm:items-center sm:px-5">
      <div className="min-w-0 flex-1">
        <div className="flex items-center gap-2">
          <p className="truncate text-body font-medium">{integration.name}</p>
          <StatusBadge status={integration.status} size="sm" />
        </div>
        <p className="mt-0.5 truncate font-mono text-micro text-fg-muted">
          {details.map(([k, v]) => `${k}: ${String(v)}`).join(" · ")}
        </p>
        {integration.last_error && <p className="mt-1 text-meta text-danger">{integration.last_error}</p>}
        <p className="mt-0.5 text-micro text-fg-muted">
          Connected {timeAgo(integration.created_at)}
          {integration.last_verified_at && ` · checked ${timeAgo(integration.last_verified_at)}`}
        </p>
      </div>
      <div className="flex gap-2">
        {providerVerifiable && (
          <Button
            size="sm"
            loading={action.isPending && action.variables?.action === "test"}
            onClick={() =>
              action.mutate(
                { id: integration.id, action: "test" },
                {
                  onSuccess: () => toast({ tone: "success", title: "Connection works" }),
                  onError: (e) => toast({ tone: "error", title: "Connection check failed", description: (e as Error).message }),
                },
              )
            }
          >
            <Zap size={14} /> Test
          </Button>
        )}
        <Button size="sm" variant="ghost" className="text-danger hover:bg-danger-soft hover:text-danger" onClick={() => setConfirm(true)}>
          <Trash2 size={14} /> Disconnect
        </Button>
      </div>
      <ConfirmDialog
        open={confirm}
        onClose={() => setConfirm(false)}
        title={`Disconnect ${integration.name}?`}
        description="Its stored credentials will be deleted. Workflow steps that use it will fail validation until you choose another connection."
        confirmLabel="Disconnect"
        tone="danger"
        loading={action.isPending && action.variables?.action === "delete"}
        onConfirm={() =>
          action.mutate(
            { id: integration.id, action: "delete" },
            {
              onSuccess: () => {
                setConfirm(false);
                toast({ tone: "success", title: "Disconnected" });
              },
              onError: (e) => toast({ tone: "error", title: "Couldn't disconnect", description: (e as Error).message }),
            },
          )
        }
      />
    </li>
  );
}

export function IntegrationsView() {
  const providers = useProviders();
  const integrations = useIntegrations();
  const [connecting, setConnecting] = useState<Provider | null>(null);

  if (providers.isPending || integrations.isPending) return <LoadingBlock label="Loading integrations" rows={5} />;
  if (providers.isError || integrations.isError)
    return (
      <Card>
        <ErrorState
          title="Couldn't load integrations"
          error={providers.error ?? integrations.error}
          onRetry={() => (providers.refetch(), integrations.refetch())}
        />
      </Card>
    );

  const available = providers.data.filter((p) => p.available);
  const planned = providers.data.filter((p) => !p.available);
  const byProvider = (key: string) => integrations.data.filter((i) => i.provider === key);

  return (
    <>
      <PageHeader title="Integrations" description="Connect services once, then use them in any workflow step." />
      <div className="grid gap-4 lg:grid-cols-3">
        {available.map((provider) => {
          const Icon = PROVIDER_ICONS[provider.key] ?? Plug;
          const connected = byProvider(provider.key);
          return (
            <Card key={provider.key} className="flex flex-col">
              <div className="flex items-start gap-3 p-4 sm:p-5">
                <span className="flex h-10 w-10 shrink-0 items-center justify-center rounded-lg border border-line bg-elevated text-cyan">
                  <Icon size={18} aria-hidden="true" />
                </span>
                <div className="min-w-0 flex-1">
                  <div className="flex items-center gap-2">
                    <h2 className="text-section font-semibold">{provider.label}</h2>
                    {connected.length > 0 && <StatusBadge status="connected" label={`${connected.length} connected`} size="sm" />}
                  </div>
                  <p className="mt-1 text-meta text-fg-muted">{provider.description}</p>
                </div>
              </div>
              <div className="mt-auto border-t border-line-subtle px-4 py-3 sm:px-5">
                <Button size="sm" variant={connected.length ? "secondary" : "primary"} onClick={() => setConnecting(provider)}>
                  <Plus size={14} /> {connected.length ? "Add another" : "Connect"}
                </Button>
              </div>
            </Card>
          );
        })}
      </div>

      <Card className="mt-5">
        <div className="border-b border-line-subtle px-4 py-3 sm:px-5">
          <h2 className="text-section font-semibold">Your connections</h2>
        </div>
        {integrations.data.length ? (
          <ul className="divide-y divide-line-subtle">
            {integrations.data.map((integration) => (
              <ConnectionRow key={integration.id} integration={integration} />
            ))}
          </ul>
        ) : (
          <p className="px-5 py-8 text-center text-body text-fg-muted">No connections yet. Connect a service above to use it in workflows.</p>
        )}
      </Card>

      <section aria-labelledby="planned" className="mt-5">
        <h2 id="planned" className="mb-3 text-section font-semibold">
          Planned
        </h2>
        <div className="grid gap-3 sm:grid-cols-2">
          {planned.map((provider) => {
            const Icon = PLANNED_ICONS[provider.key] ?? Plug;
            return (
              <div key={provider.key} className={cx("flex items-center gap-3 rounded-lg border border-dashed border-line-strong px-4 py-3")}>
                <Icon size={18} className="text-fg-disabled" aria-hidden="true" />
                <div className="min-w-0">
                  <p className="text-body font-medium text-fg-secondary">{provider.label}</p>
                  <p className="text-meta text-fg-muted">{provider.description}</p>
                </div>
                <span className="ml-auto shrink-0 rounded-full bg-elevated px-2 py-0.5 text-micro text-fg-muted">Not available yet</span>
              </div>
            );
          })}
        </div>
      </section>

      <ConnectDialog provider={connecting} onClose={() => setConnecting(null)} />
    </>
  );
}
