import type { Metadata } from "next";
import { PageIntro, Prose } from "@/components/marketing/Section";

export const metadata: Metadata = { title: "Privacy" };

export default function PrivacyPage() {
  return (
    <>
      <PageIntro eyebrow="Legal" title="Privacy" description="What GhostWork stores, why, and how it is protected." />
      <Prose>
        <p className="text-meta text-fg-muted">
          This document describes how the GhostWork software handles data. Operators who host GhostWork for others
          should review it with their own legal counsel before relying on it.
        </p>
        <h2>Data we store</h2>
        <ul>
          <li>Account details: your name, email address and an Argon2 hash of your password.</li>
          <li>Sign-in sessions: browser user agent, IP address and timestamps, so you can review and revoke devices.</li>
          <li>Workflows you create, and the record of each execution, including step outputs (truncated to 64 KB).</li>
          <li>Integration credentials, encrypted at rest. They are decrypted only by the worker when a step needs them.</li>
          <li>Notifications and an activity log of actions taken in your account.</li>
        </ul>
        <h2>What we don&apos;t do</h2>
        <ul>
          <li>We don&apos;t sell or share your data with advertisers.</li>
          <li>We don&apos;t use third-party analytics or tracking scripts.</li>
          <li>We don&apos;t return stored secrets to the browser or write them to execution logs.</li>
        </ul>
        <h2>Cookies</h2>
        <p>
          GhostWork uses one essential cookie: an HttpOnly refresh-session cookie that keeps you signed in. It is not
          readable by page scripts and is only sent to the authentication endpoints.
        </p>
        <h2>Retention and deletion</h2>
        <ul>
          <li>Finished executions are deleted automatically after 90 days.</li>
          <li>Deleting a workflow deletes its execution history.</li>
          <li>Disconnecting an integration deletes its stored credentials.</li>
          <li>
            Deleting your account (Settings → Security) permanently deletes your profile, sessions, workflows, run
            history, integrations and notifications.
          </li>
        </ul>
        <h2>Terms</h2>
        <p>
          Using GhostWork is also subject to the <a href="/terms">Terms of Service</a>, which you accept when you
          create an account. We record which version you accepted and when.
        </p>
      </Prose>
    </>
  );
}
