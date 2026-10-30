import {
  ArrowRight,
  CalendarClock,
  Eye,
  FileSpreadsheet,
  GitBranch,
  Globe,
  History,
  KeyRound,
  Lock,
  Mail,
  MessageSquare,
  RefreshCcw,
  ShieldCheck,
  Shuffle,
  Timer,
  Webhook,
} from "lucide-react";
import { HeroPreview } from "@/components/marketing/HeroPreview";
import { Section } from "@/components/marketing/Section";
import { ButtonLink } from "@/components/ui/Button";

const INTEGRATIONS = [
  { icon: Webhook, name: "Webhooks", note: "Trigger from any service", available: true },
  { icon: Globe, name: "HTTP APIs", note: "Call any REST endpoint", available: true },
  { icon: Mail, name: "Email (SMTP)", note: "Send through your server", available: true },
  { icon: MessageSquare, name: "Slack", note: "Incoming webhooks", available: true },
  { icon: CalendarClock, name: "Schedules", note: "Minutes to days", available: true },
  { icon: FileSpreadsheet, name: "Google Sheets", note: "Read and append rows", available: true },
  { icon: GitBranch, name: "GitHub", note: "Create issues", available: true },
];

const FEATURES = [
  {
    icon: Eye,
    title: "See every step",
    body: "Each run records what happened at every step — inputs, outputs, timing and errors — so you never have to guess.",
  },
  {
    icon: GitBranch,
    title: "Branch on real data",
    body: "Route a run down a true or false path based on values from the trigger or any earlier step.",
  },
  {
    icon: Shuffle,
    title: "Reshape data without code",
    body: "Build new objects from earlier results with simple references like {{ steps.fetch.body.id }}.",
  },
  {
    icon: RefreshCcw,
    title: "Retries that make sense",
    body: "HTTP steps retry server errors with backoff. Client errors fail fast with a clear message.",
  },
  {
    icon: Timer,
    title: "Schedules and webhooks",
    body: "Run on an interval, from a unique webhook URL, or on demand. Pause any workflow in one click.",
  },
  {
    icon: History,
    title: "Searchable history",
    body: "Filter runs by workflow, status and date. Re-run a failed execution with the same input.",
  },
];

const SECURITY = [
  { icon: Lock, title: "Argon2 password hashing", body: "Passwords are hashed with Argon2id and never stored or logged in plain text." },
  { icon: RefreshCcw, title: "Rotating, revocable sessions", body: "Short-lived access tokens, HttpOnly refresh cookies, reuse detection and per-device sign-out." },
  { icon: KeyRound, title: "Encrypted credentials", body: "Integration secrets are encrypted at rest and never returned to the browser or written to run logs." },
  { icon: ShieldCheck, title: "Guarded outbound requests", body: "HTTP steps can't reach private or internal network addresses, including through redirects." },
];

const FAQ = [
  {
    q: "What can GhostWork automate today?",
    a: "Workflows start from a manual run, a schedule or a webhook, and can call HTTP APIs, transform data, branch on conditions, send email through your SMTP server, post to Slack, create GitHub issues and update Google Sheets.",
  },
  {
    q: "Does GhostWork use AI to make decisions?",
    a: "No. Workflows do exactly what you configure. Conditions compare values you choose; nothing is decided by a model.",
  },
  {
    q: "What happens when a step fails?",
    a: "The run stops at that step, later steps are marked as skipped, and you get a notification with the error. You can fix the workflow and re-run with the same input.",
  },
  {
    q: "Where are my credentials stored?",
    a: "Secrets such as SMTP passwords, Slack webhook URLs and API tokens are encrypted in the database. They're only decrypted by the worker when a step needs them.",
  },
  {
    q: "Is there a mobile app?",
    a: "Yes — GhostWork runs on Android and iOS with the same features as the web app, including the workflow builder.",
  },
];

export default function LandingPage() {
  return (
    <>
      {/* Hero */}
      <section className="relative overflow-hidden">
        <div
          aria-hidden="true"
          className="pointer-events-none absolute inset-x-0 -top-40 h-[520px] bg-[radial-gradient(ellipse_at_center,rgb(133_133_255/0.16),transparent_62%)]"
        />
        <div className="relative mx-auto max-w-6xl px-4 pt-16 pb-10 sm:px-6 sm:pt-24">
          <div className="mx-auto max-w-3xl text-center">
            <p className="inline-flex items-center gap-2 rounded-full border border-line bg-surface px-3 py-1 text-meta text-fg-secondary">
              <span className="h-1.5 w-1.5 rounded-full bg-cyan" aria-hidden="true" />
              Let the repetitive work disappear
            </p>
            <h1 className="mt-6 text-[2.5rem] leading-[1.04] font-semibold tracking-[-0.04em] text-balance sm:text-display md:text-[4rem]">
              Your workflows. <span className="text-violet">On autopilot.</span>
            </h1>
            <p className="mx-auto mt-5 max-w-xl text-base leading-relaxed text-pretty text-fg-secondary sm:text-[1.0625rem]">
              Connect your tools, automate repetitive work, and see every workflow clearly — from the first trigger to the
              final result.
            </p>
            <div className="mt-8 flex flex-col justify-center gap-3 sm:flex-row">
              <ButtonLink href="/register" variant="primary" size="lg">
                Get started free <ArrowRight size={16} />
              </ButtonLink>
              <ButtonLink href="/features" size="lg">
                See how it works
              </ButtonLink>
            </div>
          </div>
          <div className="mt-14 sm:mt-16">
            <HeroPreview />
          </div>
        </div>
      </section>

      {/* Integrations */}
      <section aria-labelledby="integrations-title" className="border-y border-line-subtle bg-sidebar/60">
        <div className="mx-auto max-w-6xl px-4 py-10 sm:px-6">
          <h2 id="integrations-title" className="text-center text-meta text-fg-muted">
            Works with the tools you already use
          </h2>
          <ul className="mt-6 grid grid-cols-2 gap-2 sm:flex sm:flex-wrap sm:justify-center">
            {INTEGRATIONS.map(({ icon: Icon, name, note, available }) => (
              <li key={name} className="flex min-w-0 items-center gap-2.5 rounded-lg border border-line-subtle bg-surface px-3 py-2.5 sm:min-w-[9.5rem]">
                <Icon size={17} className={available ? "text-fg-secondary" : "text-fg-disabled"} aria-hidden="true" />
                <div className="min-w-0">
                  <p className={`truncate text-meta font-medium ${available ? "text-fg" : "text-fg-muted"}`}>{name}</p>
                  <p className="truncate text-micro text-fg-muted">{note}</p>
                </div>
              </li>
            ))}
          </ul>
        </div>
      </section>

      {/* Features */}
      <Section
        eyebrow="The Living Workflow"
        title="Automation you can actually see"
        description="Every GhostWork workflow is a map of what starts it, what it does and where data flows. When it runs, the same map shows you exactly where it is and what happened."
      >
        <div className="grid gap-px overflow-hidden rounded-xl border border-line bg-line sm:grid-cols-2 lg:grid-cols-3">
          {FEATURES.map(({ icon: Icon, title, body }) => (
            <div key={title} className="bg-surface p-6">
              <span className="flex h-9 w-9 items-center justify-center rounded-lg border border-line bg-elevated text-violet">
                <Icon size={17} aria-hidden="true" />
              </span>
              <h3 className="mt-4 text-section font-semibold">{title}</h3>
              <p className="mt-1.5 text-body leading-relaxed text-fg-muted">{body}</p>
            </div>
          ))}
        </div>
      </Section>

      {/* How it works */}
      <section className="border-y border-line-subtle bg-sidebar/60">
        <div className="mx-auto max-w-6xl px-4 py-16 sm:px-6 sm:py-24">
          <p className="text-meta font-semibold text-violet">How it works</p>
          <h2 className="mt-2 max-w-xl text-[1.75rem] leading-tight font-semibold tracking-[-0.02em] sm:text-headline">
            From busywork to background work in three steps
          </h2>
          <ol className="mt-12 grid gap-8 md:grid-cols-3 md:gap-6">
            {[
              ["Choose a trigger", "Start on a schedule, from a webhook URL, or whenever you press Run."],
              ["Connect the steps", "Drag in HTTP calls, transforms, conditions, email and Slack. Wire them together on the canvas."],
              ["Activate and watch", "GhostWork runs it in the background. Every execution is recorded step by step."],
            ].map(([title, body], index) => (
              <li key={title} className="relative pl-12 md:pl-0">
                <span className="absolute top-0 left-0 flex h-8 w-8 items-center justify-center rounded-full border border-violet/40 bg-violet-soft font-mono text-meta text-violet md:static">
                  {index + 1}
                </span>
                <h3 className="text-section font-semibold md:mt-4">{title}</h3>
                <p className="mt-1.5 text-body leading-relaxed text-fg-muted">{body}</p>
              </li>
            ))}
          </ol>
        </div>
      </section>

      {/* Security */}
      <Section
        eyebrow="Security and reliability"
        title="Built to be trusted with your work"
        description="GhostWork runs your automations in a background queue with time limits, retries and a full record of every step."
      >
        <div className="grid gap-4 sm:grid-cols-2">
          {SECURITY.map(({ icon: Icon, title, body }) => (
            <div key={title} className="card flex gap-4 p-5">
              <Icon size={19} className="mt-0.5 shrink-0 text-cyan" aria-hidden="true" />
              <div>
                <h3 className="text-section font-semibold">{title}</h3>
                <p className="mt-1 text-body leading-relaxed text-fg-muted">{body}</p>
              </div>
            </div>
          ))}
        </div>
      </Section>

      {/* FAQ */}
      <section className="border-t border-line-subtle">
        <div className="mx-auto grid max-w-6xl gap-10 px-4 py-16 sm:px-6 sm:py-24 lg:grid-cols-[1fr_1.6fr]">
          <div>
            <p className="text-meta font-semibold text-violet">FAQ</p>
            <h2 className="mt-2 text-[1.75rem] leading-tight font-semibold tracking-[-0.02em] sm:text-headline">Questions, answered</h2>
          </div>
          <div className="divide-y divide-line-subtle border-y border-line-subtle">
            {FAQ.map(({ q, a }) => (
              <details key={q} className="group py-4">
                <summary className="flex cursor-pointer list-none items-center justify-between gap-4 rounded-md text-[0.9375rem] font-medium text-fg [&::-webkit-details-marker]:hidden">
                  {q}
                  <span className="text-fg-muted transition-transform group-open:rotate-45" aria-hidden="true">
                    +
                  </span>
                </summary>
                <p className="mt-2 pr-8 text-body leading-relaxed text-fg-muted">{a}</p>
              </details>
            ))}
          </div>
        </div>
      </section>

      {/* Final CTA */}
      <section className="px-4 pb-20 sm:px-6">
        <div className="relative mx-auto max-w-6xl overflow-hidden rounded-2xl border border-line bg-surface px-6 py-14 text-center sm:py-16">
          <div
            aria-hidden="true"
            className="pointer-events-none absolute inset-0 bg-[radial-gradient(ellipse_at_top,rgb(85_197_242/0.10),transparent_60%)]"
          />
          <h2 className="relative text-[1.75rem] leading-tight font-semibold tracking-[-0.02em] sm:text-headline">
            Automate the busywork.
            <br className="hidden sm:block" /> Focus on what moves you forward.
          </h2>
          <div className="relative mt-8 flex flex-col justify-center gap-3 sm:flex-row">
            <ButtonLink href="/register" variant="primary" size="lg">
              Create your account
            </ButtonLink>
            <ButtonLink href="/docs" size="lg">
              Read the docs
            </ButtonLink>
          </div>
        </div>
      </section>
    </>
  );
}
