import type { Metadata } from "next";
import { CalendarClock, GitBranch, Globe, Hand, Mail, MessageSquare, Shuffle, Webhook } from "lucide-react";
import { PageIntro, Section } from "@/components/marketing/Section";
import { ButtonLink } from "@/components/ui/Button";

export const metadata: Metadata = { title: "Features" };

const TRIGGERS = [
  { icon: Hand, name: "Manual", body: "Start a run from the builder or workflow page, optionally with test data." },
  { icon: CalendarClock, name: "Schedule", body: "Repeat every N minutes, hours or days (minimum five minutes) while the workflow is active." },
  { icon: Webhook, name: "Webhook", body: "Each workflow gets a secret URL. POST JSON or form data to start a run; the body is available to every step." },
];

const ACTIONS = [
  { icon: Globe, name: "HTTP request", body: "GET, POST, PUT, PATCH or DELETE with templated URL, headers and body. Timeouts up to 30s, up to 3 retries for server errors." },
  { icon: Shuffle, name: "Transform data", body: "Build a new object from earlier values. A field that is exactly one reference keeps its original type." },
  { icon: GitBranch, name: "Condition", body: "Compare values with equals, contains, greater than, is empty and more. Continue down the true or false branch." },
  { icon: Mail, name: "Send email", body: "Deliver email through an SMTP server you connect. Recipients, subject and body support references." },
  { icon: MessageSquare, name: "Slack message", body: "Post to a channel through a Slack incoming webhook." },
];

const PLANNED = ["Google Workspace actions", "GitHub events", "Push notifications", "Team workspaces and shared workflows"];

export default function FeaturesPage() {
  return (
    <>
      <PageIntro
        eyebrow="Features"
        title="Everything GhostWork can do today"
        description="This page lists what is implemented and working now. Planned capabilities are listed separately at the bottom."
      />
      <Section eyebrow="Triggers" title="Start a workflow three ways">
        <div className="grid gap-4 md:grid-cols-3">
          {TRIGGERS.map(({ icon: Icon, name, body }) => (
            <div key={name} className="card p-5">
              <Icon size={18} className="text-violet" aria-hidden="true" />
              <h3 className="mt-3 text-section font-semibold">{name}</h3>
              <p className="mt-1 text-body leading-relaxed text-fg-muted">{body}</p>
            </div>
          ))}
        </div>
      </Section>
      <Section eyebrow="Steps" title="Actions and logic" className="pt-0 sm:pt-0">
        <div className="grid gap-4 md:grid-cols-2 lg:grid-cols-3">
          {ACTIONS.map(({ icon: Icon, name, body }) => (
            <div key={name} className="card p-5">
              <Icon size={18} className="text-cyan" aria-hidden="true" />
              <h3 className="mt-3 text-section font-semibold">{name}</h3>
              <p className="mt-1 text-body leading-relaxed text-fg-muted">{body}</p>
            </div>
          ))}
        </div>
      </Section>
      <Section eyebrow="Operations" title="Built for watching, not guessing" className="pt-0 sm:pt-0">
        <ul className="grid gap-3 text-body text-fg-secondary sm:grid-cols-2">
          {[
            "Visual builder with validation that points at the exact step to fix",
            "Live step-by-step progress while a run is executing",
            "Execution history with search, status, workflow and date filters",
            "Re-run any execution with the same trigger data",
            "Cancel queued or running executions",
            "Dashboard metrics computed from your real runs",
            "In-app notifications for failures (and optionally successes)",
            "Workflow templates for common jobs",
          ].map((item) => (
            <li key={item} className="flex gap-2.5 rounded-lg border border-line-subtle bg-surface px-4 py-3">
              <span className="mt-2 h-1.5 w-1.5 shrink-0 rounded-full bg-cyan" aria-hidden="true" />
              {item}
            </li>
          ))}
        </ul>
      </Section>
      <Section eyebrow="Planned" title="On the roadmap" description="These are not available yet." className="pt-0 sm:pt-0">
        <ul className="flex flex-wrap gap-2">
          {PLANNED.map((item) => (
            <li key={item} className="rounded-full border border-dashed border-line-strong px-3 py-1.5 text-meta text-fg-muted">
              {item}
            </li>
          ))}
        </ul>
        <div className="mt-10">
          <ButtonLink href="/register" variant="primary" size="lg">
            Start building
          </ButtonLink>
        </div>
      </Section>
    </>
  );
}
