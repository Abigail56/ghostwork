import type { Metadata } from "next";
import { Check } from "lucide-react";
import { PageIntro } from "@/components/marketing/Section";
import { ButtonLink } from "@/components/ui/Button";

export const metadata: Metadata = { title: "Pricing" };

export default function PricingPage() {
  return (
    <>
      <PageIntro
        eyebrow="Pricing"
        title="Free while GhostWork is in early access"
        description="There is no billing in GhostWork today. Every account gets the full feature set, with limits that keep the shared queue healthy."
      />
      <div className="mx-auto grid max-w-6xl gap-5 px-4 py-14 sm:px-6 md:grid-cols-2">
        <div className="card relative overflow-hidden p-6 sm:p-8">
          <div className="absolute inset-x-0 top-0 h-px bg-gradient-to-r from-transparent via-violet to-transparent" aria-hidden="true" />
          <p className="text-meta font-semibold text-violet">Early access</p>
          <p className="mt-3 text-[2.5rem] font-semibold tracking-tight">
            $0 <span className="text-base font-normal text-fg-muted">/ month</span>
          </p>
          <p className="mt-1 text-body text-fg-muted">Everything that is available today.</p>
          <ul className="mt-6 flex flex-col gap-2.5 text-body text-fg-secondary">
            {[
              "Unlimited workflows",
              "Up to 50 steps per workflow",
              "Up to 5 runs in progress at once",
              "Schedules, webhooks and manual runs",
              "HTTP, transform, condition, email and Slack steps",
              "Full execution history",
            ].map((item) => (
              <li key={item} className="flex gap-2.5">
                <Check size={16} className="mt-0.5 shrink-0 text-success" aria-hidden="true" />
                {item}
              </li>
            ))}
          </ul>
          <ButtonLink href="/register" variant="primary" size="lg" className="mt-8 w-full">
            Create your account
          </ButtonLink>
        </div>
        <div className="card p-6 sm:p-8">
          <p className="text-meta font-semibold text-fg-muted">Teams</p>
          <p className="mt-3 text-[2.5rem] font-semibold tracking-tight text-fg-muted">Planned</p>
          <p className="mt-1 text-body text-fg-muted">Not available yet. Pricing will be published before launch.</p>
          <ul className="mt-6 flex flex-col gap-2.5 text-body text-fg-muted">
            {["Shared workspaces", "Roles and permissions", "Higher concurrency limits", "Audit log export"].map((item) => (
              <li key={item} className="flex gap-2.5">
                <span className="mt-2 h-1 w-1 shrink-0 rounded-full bg-fg-muted" aria-hidden="true" />
                {item}
              </li>
            ))}
          </ul>
        </div>
      </div>
    </>
  );
}
