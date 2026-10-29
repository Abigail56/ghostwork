import type { Metadata } from "next";
import { PageIntro, Prose } from "@/components/marketing/Section";
import { API_BASE_URL } from "@/lib/api";

export const metadata: Metadata = { title: "Documentation" };

const TOC = [
  ["quickstart", "Quickstart"],
  ["triggers", "Triggers"],
  ["steps", "Steps"],
  ["references", "References"],
  ["conditions", "Conditions"],
  ["webhooks", "Webhooks"],
  ["credentials", "Credentials"],
  ["runs", "Runs and history"],
  ["limits", "Limits"],
  ["api", "API"],
];

export default function DocsPage() {
  return (
    <>
      <PageIntro
        eyebrow="Documentation"
        title="Build your first workflow"
        description="Everything you need to design, run and debug GhostWork workflows."
      />
      <div className="mx-auto flex max-w-6xl gap-10 px-0 sm:px-2">
        <nav aria-label="On this page" className="sticky top-20 hidden h-fit w-48 shrink-0 py-12 pl-4 lg:block">
          <p className="eyebrow">On this page</p>
          <ul className="mt-3 flex flex-col gap-1.5 text-body">
            {TOC.map(([id, label]) => (
              <li key={id}>
                <a href={`#${id}`} className="text-fg-muted hover:text-fg">
                  {label}
                </a>
              </li>
            ))}
          </ul>
        </nav>
        <div className="min-w-0 flex-1">
          <Prose>
            <h2 id="quickstart">Quickstart</h2>
            <ul>
              <li>Create an account and open <strong className="text-fg">Workflows → New workflow</strong>.</li>
              <li>Pick a trigger (manual, schedule or webhook), or start from a template.</li>
              <li>In the builder, add steps from the left panel and connect them by dragging from a step&apos;s bottom handle to the next step&apos;s top handle.</li>
              <li>Select a step to configure it in the right panel. The toolbar shows whether the workflow is valid.</li>
              <li>Press <strong className="text-fg">Test run</strong> to execute it now and watch each step complete, then <strong className="text-fg">Activate</strong> to turn on its schedule or webhook.</li>
            </ul>

            <h2 id="triggers">Triggers</h2>
            <p>Every workflow has exactly one trigger, and it can&apos;t have incoming connections.</p>
            <ul>
              <li><code>Manual</code> — runs when you press Run. You can pass test data, available as <code>trigger.payload</code>.</li>
              <li><code>Schedule</code> — runs every N minutes, hours or days while active. The shortest interval is 5 minutes.</li>
              <li><code>Webhook</code> — runs when its secret URL receives a POST while the workflow is active.</li>
            </ul>
            <p>Manual test runs are always allowed, even for draft or paused workflows, as long as the workflow is valid.</p>

            <h2 id="steps">Steps</h2>
            <h3>HTTP request</h3>
            <p>
              Calls an external API. The response is available as <code>steps.&lt;id&gt;.status_code</code>,{" "}
              <code>steps.&lt;id&gt;.headers</code> and <code>steps.&lt;id&gt;.body</code> (parsed when the response is JSON).
              Responses with status 400 or above fail the step unless you turn off <em>Fail on error status</em>.
              Server errors (5xx) and 429 are retried with backoff up to the retry count you set.
            </p>
            <h3>Transform data</h3>
            <p>
              Builds an object from named fields. If a field&apos;s value is exactly one reference, such as{" "}
              <code>{"{{ steps.fetch.body.items }}"}</code>, it keeps its original type (list, number, object). Otherwise
              the result is text.
            </p>
            <h3>Send email</h3>
            <p>Sends a plain-text email through an SMTP integration. Requires a connected Email (SMTP) integration.</p>
            <h3>Slack message</h3>
            <p>Posts text to Slack through an incoming webhook. Requires a connected Slack integration.</p>

            <h2 id="references">References</h2>
            <p>Text fields can include references in double braces. Only plain lookups are supported — no code or expressions.</p>
            <pre>
              <code>{`{{ trigger.payload.body.email }}     webhook JSON body
{{ trigger.payload.user }}           manual test data
{{ steps.fetch.body.items.0.id }}    list items by index
{{ steps.shape.total }}              transform output
{{ execution.id }}  {{ execution.started_at }}
{{ workflow.name }}`}</code>
            </pre>
            <p>A step can only reference steps that run before it. Validation points out references that can&apos;t resolve.</p>

            <h2 id="conditions">Conditions</h2>
            <p>
              A condition compares a value with <code>equals</code>, <code>not_equals</code>, <code>contains</code>,{" "}
              <code>not_contains</code>, <code>greater_than</code>, <code>less_than</code>, <code>is_empty</code> or{" "}
              <code>is_not_empty</code>. Connect its <span className="text-success">True</span> and/or False outputs.
              Steps on the branch that wasn&apos;t taken are marked as skipped.
            </p>

            <h2 id="webhooks">Webhooks</h2>
            <p>After you save a workflow with a webhook trigger, its URL appears in the trigger settings and on the workflow page.</p>
            <pre>
              <code>{`curl -X POST "$WEBHOOK_URL" \\
  -H "Content-Type: application/json" \\
  -d '{"event": "signup", "priority": "high"}'`}</code>
            </pre>
            <p>
              The request body, query string and a safe subset of headers (content type, user agent and a few event
              headers) are passed to the run. Authorization and cookie headers are never stored. Payloads are limited to
              256 KB. Regenerate the URL at any time if it leaks.
            </p>

            <h2 id="credentials">Credentials</h2>
            <p>
              Never paste API keys into plain headers — validation rejects headers such as <code>Authorization</code>.
              Instead, create an <strong className="text-fg">HTTP credential</strong> on the Integrations page and select it in the HTTP step.
              Credentials are encrypted at rest and never shown again after you save them.
            </p>

            <h2 id="runs">Runs and history</h2>
            <p>
              Runs move through <code>queued</code> → <code>running</code> → <code>succeeded</code> or <code>failed</code>{" "}
              (or <code>cancelled</code>). Each step records its status, attempts, duration, output and error. When a
              step fails, the run stops and later steps are skipped. From the execution page you can cancel an active run
              or run the workflow again with the same trigger data.
            </p>

            <h2 id="limits">Limits</h2>
            <ul>
              <li>50 steps per workflow.</li>
              <li>5 runs in progress per account at once.</li>
              <li>HTTP steps: 30 second timeout, 1 MB response, 3 redirects, no private or internal network addresses.</li>
              <li>Runs are stopped after 120 seconds.</li>
              <li>Stored step outputs are truncated at 64 KB.</li>
            </ul>

            <h2 id="api">API</h2>
            <p>
              GhostWork is API-first. The interactive OpenAPI reference is served by the backend at{" "}
              <a href={`${API_BASE_URL}/docs`} target="_blank" rel="noreferrer">
                {API_BASE_URL}/docs
              </a>
              .
            </p>
          </Prose>
        </div>
      </div>
    </>
  );
}
