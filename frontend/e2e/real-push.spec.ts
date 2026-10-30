import { mkdtempSync, rmSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { chromium, expect, test } from "@playwright/test";
import { registerViaUi } from "./helpers";

// Needs installed Google Chrome and internet: bundled test browsers can't reach a push service.
// Run with E2E_REAL_PUSH=1. Uses a persistent profile because incognito contexts can't subscribe to push.
test.skip(!process.env.E2E_REAL_PUSH, "Set E2E_REAL_PUSH=1 to run against Google's push service");
test.setTimeout(180_000);

test("a notification reaches the browser through the push service", async ({ baseURL }) => {
  const profile = mkdtempSync(join(tmpdir(), "ghostwork-push-"));
  const context = await chromium.launchPersistentContext(profile, { channel: "chrome", baseURL });
  const page = context.pages()[0] ?? (await context.newPage());
  await context.grantPermissions(["notifications"]);
  await registerViaUi(page);
  await page.goto("/settings?tab=notifications", { waitUntil: "networkidle" });
  const toggle = page.getByRole("switch", { name: "Push notifications in this browser" }).filter({ visible: true });
  const posted = page.waitForResponse((r) => r.url().endsWith("/push/subscriptions") && r.request().method() === "POST", { timeout: 90_000 });
  await toggle.click();
  expect((await posted).status()).toBe(201);
  const send = page.waitForResponse((r) => r.url().endsWith("/push/test"));
  await page.getByRole("button", { name: "Send a test" }).filter({ visible: true }).click();
  expect((await send).status()).toBe(200);
  await expect
    .poll(
      () =>
        page.evaluate(async () => {
          const registration = await navigator.serviceWorker.getRegistration("/");
          return (await registration!.getNotifications()).map((n) => n.title);
        }),
      { timeout: 60_000 },
    )
    .toContain("GhostWork test notification");
  const removed = page.waitForResponse((r) => r.url().endsWith("/push/subscriptions") && r.request().method() === "DELETE");
  await toggle.click();
  expect((await removed).status()).toBe(200);
  await context.close();
  rmSync(profile, { recursive: true, force: true });
});
