import type { Metadata } from "next";
import { PageIntro, Prose } from "@/components/marketing/Section";

export const metadata: Metadata = { title: "Terms" };

export default function TermsPage() {
  return (
    <>
      <PageIntro eyebrow="Legal" title="Terms of use" description="The ground rules for using GhostWork during early access." />
      <Prose>
        <p className="text-meta text-fg-muted">
          These terms are a plain-language starting point for the GhostWork software. Operators should adapt them with
          legal advice before offering GhostWork as a service.
        </p>
        <h2>Early access</h2>
        <p>
          GhostWork is in early access. Features may change, and the service is provided without uptime guarantees.
          Don&apos;t rely on it as the only copy of important data or for safety-critical processes.
        </p>
        <h2>Acceptable use</h2>
        <ul>
          <li>Only automate systems and accounts you are authorized to use.</li>
          <li>Don&apos;t use GhostWork to send spam, attack other services or bypass their limits.</li>
          <li>Don&apos;t attempt to reach internal networks or other users&apos; data through workflows.</li>
        </ul>
        <h2>Limits</h2>
        <p>
          Workflows are limited to 50 steps, schedules to one run every five minutes, and each account to five runs in
          progress at once. HTTP steps time out after at most 30 seconds.
        </p>
        <h2>Your content</h2>
        <p>You own your workflows and the data they process. You are responsible for the data you send through them.</p>
      </Prose>
    </>
  );
}
