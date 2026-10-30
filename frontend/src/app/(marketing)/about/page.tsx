import type { Metadata } from "next";
import { PageIntro, Prose } from "@/components/marketing/Section";

export const metadata: Metadata = { title: "About" };

export default function AboutPage() {
  return (
    <>
      <PageIntro
        eyebrow="About"
        title="Automation should be visible"
        description="GhostWork exists to make repetitive work disappear — without making it mysterious."
      />
      <Prose>
        <p>
          Most automation tools are good at starting things and bad at explaining them. When something breaks you are
          left reading raw logs or guessing which step went wrong.
        </p>
        <p>
          GhostWork is built around the <strong className="text-fg">Living Workflow</strong>: the same diagram you use to
          design an automation shows you what it is doing while it runs and what it did afterwards. Every step records
          its input, output, timing and errors.
        </p>
        <h2>Principles</h2>
        <ul>
          <li>Show real state. Nothing animates unless something is actually running.</li>
          <li>Be honest about capabilities. Planned features are labelled as planned.</li>
          <li>Keep secrets secret. Credentials are encrypted and never sent back to the browser.</li>
          <li>Fail clearly. Errors say what failed and what to do next.</li>
        </ul>
        <h2>Technology</h2>
        <p>
          GhostWork is a Next.js web app and a Flutter mobile app backed by a FastAPI service, PostgreSQL for storage, and
          Redis with Celery for background execution. Both apps use the same API.
        </p>
      </Prose>
    </>
  );
}
