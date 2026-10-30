"use client";

import { zodResolver } from "@hookform/resolvers/zod";
import { Bell, KeyRound, Laptop, MonitorSmartphone, Palette, ScrollText, Smartphone, User } from "lucide-react";
import { usePathname, useRouter, useSearchParams } from "next/navigation";
import { useQuery } from "@tanstack/react-query";
import { useEffect, useState } from "react";
import { useForm, useWatch } from "react-hook-form";
import { z } from "zod";
import { PasswordInput, PasswordStrength, passwordProblems } from "@/components/app/PasswordInput";
import { Button } from "@/components/ui/Button";
import { EmptyState, ErrorState, InlineAlert, LoadingBlock } from "@/components/ui/Feedback";
import { Field, Input, SegmentedControl, Switch } from "@/components/ui/Form";
import { Card, CardHeader, Pagination, Tabs } from "@/components/ui/Layout";
import { ConfirmDialog, Dialog } from "@/components/ui/Overlay";
import { useToast } from "@/components/ui/Toast";
import { api } from "@/lib/api";
import { useAuth, useRequiredUser } from "@/lib/auth";
import { currentSubscription, disablePush, enablePush, pushSupported } from "@/lib/push";
import { formatDate, formatDateTime, initials, timeAgo } from "@/lib/format";
import { useActivity, useChangeEmail, useChangePassword, useDeleteAccount, useSessionAction, useSessions, useUpdateProfile } from "@/lib/queries";
import type { User as UserType } from "@/lib/types";

const TABS = [
  { value: "profile", label: "Profile", icon: User },
  { value: "security", label: "Security", icon: KeyRound },
  { value: "sessions", label: "Sessions", icon: MonitorSmartphone },
  { value: "notifications", label: "Notifications", icon: Bell },
  { value: "appearance", label: "Appearance", icon: Palette },
  { value: "activity", label: "Activity", icon: ScrollText },
] as const;
type Tab = (typeof TABS)[number]["value"];

function useSavePreferences() {
  const { setUser } = useAuth();
  const update = useUpdateProfile();
  const toast = useToast();
  return {
    pending: update.isPending,
    save: (patch: Partial<UserType>, message = "Preferences saved") =>
      update.mutate(patch, {
        onSuccess: (user) => {
          setUser(user);
          toast({ tone: "success", title: message });
        },
        onError: (e) => toast({ tone: "error", title: "Couldn't save", description: (e as Error).message }),
      }),
  };
}

function ChangeEmailButton() {
  const { setUser } = useAuth();
  const change = useChangeEmail();
  const toast = useToast();
  const [open, setOpen] = useState(false);
  const [email, setEmail] = useState("");
  const [password, setPassword] = useState("");
  const close = () => {
    setOpen(false);
    setEmail("");
    setPassword("");
    change.reset();
  };
  return (
    <>
      <button type="button" onClick={() => setOpen(true)} className="text-violet hover:underline">
        Change email
      </button>
      <Dialog
        open={open}
        onClose={close}
        title="Change email"
        description="You'll sign in with the new address. We'll notify your current address about the change."
        size="sm"
        footer={
          <>
            <Button onClick={close}>Cancel</Button>
            <Button type="submit" form="change-email" variant="primary" loading={change.isPending}>
              Change email
            </Button>
          </>
        }
      >
        <form
          id="change-email"
          className="flex flex-col gap-4"
          onSubmit={(e) => {
            e.preventDefault();
            change.mutate(
              { new_email: email.trim(), password },
              {
                onSuccess: (user) => {
                  setUser(user);
                  toast({ tone: "success", title: "Email updated", description: user.email });
                  close();
                },
              },
            );
          }}
        >
          {change.isError && <InlineAlert>{change.error.message}</InlineAlert>}
          <Field label="New email">{(p) => <Input {...p} type="email" required autoComplete="email" value={email} onChange={(e) => setEmail(e.target.value)} />}</Field>
          <Field label="Current password">{(p) => <PasswordInput {...p} required autoComplete="current-password" value={password} onChange={(e) => setPassword(e.target.value)} />}</Field>
        </form>
      </Dialog>
    </>
  );
}

function DangerZone() {
  const remove = useDeleteAccount();
  const { logout } = useAuth();
  const [open, setOpen] = useState(false);
  const [password, setPassword] = useState("");
  const [confirmText, setConfirmText] = useState("");
  return (
    <Card className="mt-5 border-danger/30">
      <CardHeader title="Delete account" description="Permanently delete your account, workflows, run history and connected integrations." />
      <div className="flex justify-end p-4 sm:p-5">
        <Button variant="danger" onClick={() => setOpen(true)}>
          Delete account
        </Button>
      </div>
      <Dialog
        open={open}
        onClose={() => (setOpen(false), setPassword(""), setConfirmText(""), remove.reset())}
        title="Delete your account?"
        description="This can't be undone. Active schedules and webhooks stop immediately."
        size="sm"
        footer={
          <>
            <Button onClick={() => setOpen(false)}>Cancel</Button>
            <Button
              variant="danger"
              loading={remove.isPending}
              disabled={confirmText !== "DELETE" || !password}
              onClick={() =>
                remove.mutate(password, {
                  onSuccess: async () => {
                    // The account is gone; clear local session state everywhere, then leave.
                    await logout("/").catch(() => undefined);
                  },
                })
              }
            >
              Delete forever
            </Button>
          </>
        }
      >
        <div className="flex flex-col gap-4">
          {remove.isError && <InlineAlert>{remove.error.message}</InlineAlert>}
          <Field label="Current password">{(p) => <PasswordInput {...p} autoComplete="current-password" value={password} onChange={(e) => setPassword(e.target.value)} />}</Field>
          <Field label='Type "DELETE" to confirm'>{(p) => <Input {...p} value={confirmText} onChange={(e) => setConfirmText(e.target.value)} autoComplete="off" />}</Field>
        </div>
      </Dialog>
    </Card>
  );
}

const profileSchema = z.object({ full_name: z.string().trim().min(1, "Enter your name.").max(120) });

function ProfileTab() {
  const user = useRequiredUser();
  const { setUser } = useAuth();
  const update = useUpdateProfile();
  const toast = useToast();
  const {
    register,
    handleSubmit,
    reset,
    formState: { errors, isDirty },
  } = useForm<{ full_name: string }>({ resolver: zodResolver(profileSchema), defaultValues: { full_name: user.full_name } });

  return (
    <Card>
      <CardHeader title="Profile" description="How you appear in GhostWork." />
      <form
        className="flex flex-col gap-5 p-4 sm:p-5"
        onSubmit={handleSubmit((values) =>
          update.mutate(values, {
            onSuccess: (next) => {
              setUser(next);
              reset({ full_name: next.full_name });
              toast({ tone: "success", title: "Profile updated" });
            },
          }),
        )}
        noValidate
      >
        <div className="flex items-center gap-4">
          <span className="flex h-14 w-14 items-center justify-center rounded-full bg-violet-soft text-lg font-semibold text-violet">{initials(user.full_name)}</span>
          <div>
            <p className="text-body font-medium">{user.full_name}</p>
            <p className="text-meta text-fg-muted">Member since {formatDate(user.created_at)}</p>
          </div>
        </div>
        {update.isError && <InlineAlert>{update.error.message}</InlineAlert>}
        <div className="grid gap-4 sm:grid-cols-2">
          <Field label="Full name" error={errors.full_name?.message}>
            {(p) => <Input {...p} autoComplete="name" {...register("full_name")} />}
          </Field>
          <Field label="Email" hint={<ChangeEmailButton />}>
            {(p) => <Input {...p} value={user.email} disabled readOnly />}
          </Field>
        </div>
        <div className="flex justify-end border-t border-line-subtle pt-4">
          <Button type="submit" variant="primary" loading={update.isPending} disabled={!isDirty}>
            Save profile
          </Button>
        </div>
      </form>
    </Card>
  );
}

const passwordSchema = z
  .object({
    current_password: z.string().min(1, "Enter your current password."),
    new_password: z.string().superRefine((v, ctx) => {
      const problem = passwordProblems(v);
      if (problem) ctx.addIssue({ code: "custom", message: problem });
    }),
    confirm: z.string(),
  })
  .refine((v) => v.new_password === v.confirm, { path: ["confirm"], message: "Passwords don't match." });

function SecurityTab() {
  const user = useRequiredUser();
  const change = useChangePassword();
  const toast = useToast();
  const {
    register,
    handleSubmit,
    reset,
    control,
    formState: { errors },
  } = useForm<z.infer<typeof passwordSchema>>({ resolver: zodResolver(passwordSchema), defaultValues: { new_password: "" } });
  const newPassword = useWatch({ control, name: "new_password" }) ?? "";
  return (
    <Card>
      <CardHeader
        title="Password"
        description={user.password_changed_at ? `Last changed ${timeAgo(user.password_changed_at)}` : "Use at least 10 characters, with a letter and a number."}
      />
      <form
        className="flex flex-col gap-4 p-4 sm:p-5"
        noValidate
        onSubmit={handleSubmit(({ current_password, new_password }) =>
          change.mutate(
            { current_password, new_password },
            {
              onSuccess: (r) => {
                reset({ current_password: "", new_password: "", confirm: "" });
                toast({ tone: "success", title: "Password updated", description: r.message });
              },
            },
          ),
        )}
      >
        {change.isError && <InlineAlert>{change.error.message}</InlineAlert>}
        <Field label="Current password" error={errors.current_password?.message}>
          {(p) => <PasswordInput {...p} autoComplete="current-password" {...register("current_password")} />}
        </Field>
        <div className="grid gap-4 sm:grid-cols-2">
          <Field label="New password" error={errors.new_password?.message}>
            {(p) => (
              <div>
                <PasswordInput {...p} autoComplete="new-password" {...register("new_password")} />
                <PasswordStrength value={newPassword} />
              </div>
            )}
          </Field>
          <Field label="Confirm new password" error={errors.confirm?.message}>
            {(p) => <PasswordInput {...p} autoComplete="new-password" {...register("confirm")} />}
          </Field>
        </div>
        <p className="text-meta text-fg-muted">Changing your password signs you out everywhere except this browser.</p>
        <div className="flex justify-end border-t border-line-subtle pt-4">
          <Button type="submit" variant="primary" loading={change.isPending}>
            Update password
          </Button>
        </div>
      </form>
    </Card>
  );
}

function describeAgent(ua: string | null) {
  if (!ua) return { label: "Unknown device", mobile: false };
  const mobile = /Mobile|Android|iPhone|iPad/i.test(ua);
  const browser = /Edg\//.test(ua) ? "Edge" : /Firefox\//.test(ua) ? "Firefox" : /Chrome\//.test(ua) ? "Chrome" : /Safari\//.test(ua) ? "Safari" : /python|httpx|curl|dart/i.test(ua) ? "API client" : "Browser";
  const os = /Windows/.test(ua) ? "Windows" : /Mac OS X/.test(ua) && !mobile ? "macOS" : /Android/.test(ua) ? "Android" : /iPhone|iPad/.test(ua) ? "iOS" : /Linux/.test(ua) ? "Linux" : "";
  return { label: os ? `${browser} on ${os}` : browser, mobile };
}

function SessionsTab() {
  const sessions = useSessions();
  const action = useSessionAction();
  const toast = useToast();
  const [confirm, setConfirm] = useState(false);
  if (sessions.isPending) return <LoadingBlock rows={3} />;
  if (sessions.isError) return <Card><ErrorState error={sessions.error} onRetry={() => sessions.refetch()} /></Card>;
  const others = sessions.data.filter((s) => !s.current).length;
  return (
    <Card>
      <CardHeader
        title="Active sessions"
        description="Devices currently signed in to your account."
        action={
          others > 0 && (
            <Button size="sm" onClick={() => setConfirm(true)}>
              Sign out others
            </Button>
          )
        }
      />
      <ul className="divide-y divide-line-subtle">
        {sessions.data.map((s) => {
          const agent = describeAgent(s.user_agent);
          const Icon = agent.mobile ? Smartphone : Laptop;
          return (
            <li key={s.id} className="flex items-center gap-3 px-4 py-3 sm:px-5">
              <Icon size={18} className="shrink-0 text-fg-muted" aria-hidden="true" />
              <div className="min-w-0 flex-1">
                <p className="flex items-center gap-2 text-body font-medium">
                  {agent.label}
                  {s.current && <span className="rounded-full bg-success-soft px-2 py-0.5 text-micro text-success">This browser</span>}
                </p>
                <p className="truncate text-micro text-fg-muted">
                  {s.ip_address ?? "Unknown IP"} · signed in {formatDateTime(s.created_at)} · active {timeAgo(s.last_used_at)}
                </p>
              </div>
              {!s.current && (
                <Button
                  size="sm"
                  variant="ghost"
                  loading={action.isPending && action.variables === s.id}
                  onClick={() =>
                    action.mutate(s.id, {
                      onSuccess: () => toast({ tone: "success", title: "Session signed out" }),
                      onError: (e) => toast({ tone: "error", title: "Couldn't sign out session", description: (e as Error).message }),
                    })
                  }
                >
                  Sign out
                </Button>
              )}
            </li>
          );
        })}
      </ul>
      <ConfirmDialog
        open={confirm}
        onClose={() => setConfirm(false)}
        title="Sign out other sessions?"
        description={`${others} other session${others === 1 ? "" : "s"} will be signed out immediately.`}
        confirmLabel="Sign out others"
        loading={action.isPending}
        onConfirm={() =>
          action.mutate("others", {
            onSuccess: (r) => {
              setConfirm(false);
              toast({ tone: "success", title: r.message });
            },
            onError: (e) => toast({ tone: "error", title: "Couldn't sign out sessions", description: (e as Error).message }),
          })
        }
      />
    </Card>
  );
}

function BrowserPush() {
  const toast = useToast();
  const config = useQuery({ queryKey: ["push-config"], queryFn: () => api<{ web_push_public_key: string | null }>("/push/config", { auth: false }) });
  const [enabled, setEnabled] = useState(false);
  const [busy, setBusy] = useState(false);
  useEffect(() => {
    if (!pushSupported()) return;
    currentSubscription().then((s) => setEnabled(Boolean(s))).catch(() => setEnabled(false));
  }, []);
  const key = config.data?.web_push_public_key;
  if (!pushSupported()) return <p className="text-meta text-fg-muted">This browser doesn&apos;t support push notifications.</p>;
  if (config.isPending) return null;
  if (!key) return <p className="text-meta text-fg-muted">Browser push isn&apos;t configured on this server.</p>;
  return (
    <div className="flex flex-col gap-3">
      <Switch
        label="Push notifications in this browser"
        description="Show a system notification on this device when a run fails, even when GhostWork isn't open."
        checked={enabled}
        disabled={busy}
        onChange={async (next) => {
          setBusy(true);
          try {
            if (next) await enablePush(key);
            else await disablePush();
            setEnabled(next);
            toast({ tone: "success", title: next ? "Push turned on for this browser" : "Push turned off for this browser" });
          } catch (e) {
            toast({ tone: "error", title: "Couldn't change push notifications", description: (e as Error).message });
          } finally {
            setBusy(false);
          }
        }}
      />
      {enabled && (
        <Button
          size="sm"
          className="w-fit"
          onClick={() =>
            api<{ message: string }>("/push/test", { method: "POST" }).then(
              (r) => toast({ tone: "success", title: "Test notification sent", description: r.message }),
              (e) => toast({ tone: "error", title: "Couldn't send a test", description: (e as Error).message }),
            )
          }
        >
          Send a test
        </Button>
      )}
    </div>
  );
}

function NotificationsTab() {
  const user = useRequiredUser();
  const { save, pending } = useSavePreferences();
  return (
    <Card>
      <CardHeader title="Notifications" description="Choose when GhostWork tells you about runs. Changes save immediately." />
      <div className="flex flex-col gap-5 p-4 sm:p-5">
        <Switch label="Failed runs" description="Show an in-app notification when a run fails." checked={user.notify_on_failure} disabled={pending} onChange={(v) => save({ notify_on_failure: v })} />
        <Switch label="Successful runs" description="Show an in-app notification when a run succeeds. Can be noisy for frequent schedules." checked={user.notify_on_success} disabled={pending} onChange={(v) => save({ notify_on_success: v })} />
        <Switch
          label="Email me when a run fails"
          description="Sent to your account email if this server has outgoing email configured."
          checked={user.email_on_failure}
          disabled={pending}
          onChange={(v) => save({ email_on_failure: v })}
        />
        <Switch
          label="Push me when a run fails"
          description="Sent to every device where push is turned on."
          checked={user.push_on_failure}
          disabled={pending}
          onChange={(v) => save({ push_on_failure: v })}
        />
        <div className="border-t border-line-subtle pt-5">
          <BrowserPush />
        </div>
      </div>
    </Card>
  );
}

function AppearanceTab() {
  const user = useRequiredUser();
  const { save, pending } = useSavePreferences();
  return (
    <Card>
      <CardHeader title="Appearance" description="GhostWork uses a dark interface designed for long sessions." />
      <div className="flex flex-col gap-6 p-4 sm:p-5">
        <div className="flex flex-col gap-2 sm:flex-row sm:items-center sm:justify-between">
          <div>
            <p className="text-body font-medium">Density</p>
            <p className="text-meta text-fg-muted">Compact fits more rows in tables and lists.</p>
          </div>
          <SegmentedControl
            label="Density"
            value={user.density}
            onChange={(v) => !pending && save({ density: v })}
            options={[
              { value: "comfortable", label: "Comfortable" },
              { value: "compact", label: "Compact" },
            ]}
          />
        </div>
        <div className="flex flex-col gap-2 sm:flex-row sm:items-center sm:justify-between">
          <div>
            <p className="text-body font-medium">Motion</p>
            <p className="text-meta text-fg-muted">Reduce animations such as live-run indicators and panel transitions.</p>
          </div>
          <SegmentedControl
            label="Motion"
            value={user.reduce_motion}
            onChange={(v) => !pending && save({ reduce_motion: v })}
            options={[
              { value: "system", label: "System" },
              { value: "reduce", label: "Reduced" },
              { value: "full", label: "Full" },
            ]}
          />
        </div>
      </div>
    </Card>
  );
}

function ActivityTab() {
  const [page, setPage] = useState(1);
  const activity = useActivity(page);
  return (
    <Card>
      <CardHeader title="Account activity" description="Changes made in your account, newest first." />
      {activity.isPending ? (
        <div className="p-4"><LoadingBlock rows={4} /></div>
      ) : activity.isError ? (
        <ErrorState error={activity.error} onRetry={() => activity.refetch()} />
      ) : activity.data.items.length === 0 ? (
        <EmptyState title="No activity yet" />
      ) : (
        <>
          <ul className="divide-y divide-line-subtle">
            {activity.data.items.map((a) => (
              <li key={a.id} className="flex items-baseline justify-between gap-4 px-4 py-2.5 sm:px-5">
                <span className="text-body text-fg-secondary">{a.message}</span>
                <time className="shrink-0 text-micro text-fg-muted" dateTime={a.created_at} title={formatDateTime(a.created_at)}>
                  {timeAgo(a.created_at)}
                </time>
              </li>
            ))}
          </ul>
          <div className="border-t border-line-subtle">
            <Pagination page={page} pageSize={10} total={activity.data.total} onPage={setPage} />
          </div>
        </>
      )}
    </Card>
  );
}

export function SettingsView() {
  const params = useSearchParams();
  const router = useRouter();
  const pathname = usePathname();
  const raw = params.get("tab");
  const tab: Tab = TABS.some((t) => t.value === raw) ? (raw as Tab) : "profile";
  const setTab = (value: Tab) => router.replace(`${pathname}?tab=${value}`, { scroll: false });

  return (
    <>
      <div className="mb-5">
        <h1 className="text-title font-semibold">Settings</h1>
        <p className="mt-1 text-body text-fg-muted">Manage your profile, security and preferences.</p>
      </div>
      <div className="grid grid-cols-1 gap-5 lg:grid-cols-[200px_minmax(0,1fr)]">
        <Tabs label="Settings sections" value={tab} onChange={setTab} tabs={[...TABS]} className="lg:flex-col lg:overflow-visible" />
        <div id={`panel-${tab}`} role="tabpanel" aria-labelledby={`tab-${tab}`} className="min-w-0 max-w-3xl animate-fade-in" key={tab}>
          {tab === "profile" && <ProfileTab />}
          {tab === "security" && (
            <>
              <SecurityTab />
              <DangerZone />
            </>
          )}
          {tab === "sessions" && <SessionsTab />}
          {tab === "notifications" && <NotificationsTab />}
          {tab === "appearance" && <AppearanceTab />}
          {tab === "activity" && <ActivityTab />}
        </div>
      </div>
    </>
  );
}
