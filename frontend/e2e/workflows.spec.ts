import { expect, test } from "@playwright/test";
import { registerViaUi } from "./helpers";

test("create a workflow, build it, run it, and delete it", async ({ page }) => {
  await registerViaUi(page);
  await page.goto("/workflows/new", { waitUntil: "networkidle" });
  await page.getByLabel("Name").fill("E2E greeting");
  await page.getByRole("button", { name: "Create and open builder" }).click();
  await expect(page).toHaveURL(/\/builder$/);

  // Validation reflects the saved state: a lone trigger isn't runnable yet.
  await expect(page.getByText(/1 issue/)).toBeVisible();

  // Add a transform step (click-to-add connects it to the trigger) and configure it.
  await page.getByRole("button", { name: /Add Transform data/ }).click();
  await expect(page.getByText("Unsaved changes")).toBeVisible();
  await page.getByRole("button", { name: "Add field" }).click();
  await page.getByLabel("Field name 1", { exact: true }).fill("greeting");
  await page.getByLabel("Field value 1", { exact: true }).fill("Hello {{ trigger.payload.name }}");
  await page.keyboard.press("Control+s");
  await expect(page.getByText("Saved · valid")).toBeVisible();

  await page.getByRole("button", { name: "Test run" }).click();
  await page.getByLabel(/Test data/).fill('{"name": "Ada"}');
  await page.getByRole("button", { name: "Run now" }).click();
  const run = page.getByRole("region", { name: "Test run" });
  await expect(run.getByText("Succeeded").first()).toBeVisible({ timeout: 20_000 });
  await run.getByRole("button", { name: /Transform data/ }).click();
  await expect(run.getByText('"greeting": "Hello Ada"')).toBeVisible();

  // The run is recorded in history.
  await page.goto("/executions");
  await expect(page.getByRole("cell", { name: "E2E greeting" })).toBeVisible();

  // Search, then delete with confirmation (cancel first).
  await page.goto("/workflows?q=E2E");
  const row = page.getByRole("row", { name: /E2E greeting/ });
  await row.getByRole("button", { name: "Actions for E2E greeting" }).click();
  await page.getByRole("menuitem", { name: "Delete" }).click();
  await expect(page.getByRole("dialog", { name: "Delete workflow?" })).toBeVisible();
  await page.getByRole("button", { name: "Cancel" }).click();
  await expect(row).toBeVisible();
  await row.getByRole("button", { name: "Actions for E2E greeting" }).click();
  await page.getByRole("menuitem", { name: "Delete" }).click();
  await page.getByRole("button", { name: "Delete workflow" }).click();
  await expect(page.getByText("No matching workflows")).toBeVisible();
});

test("activation is blocked until the workflow is valid", async ({ page }) => {
  await registerViaUi(page);
  await page.goto("/workflows/new", { waitUntil: "networkidle" });
  await page.getByLabel("Name").fill("Incomplete");
  await page.getByRole("button", { name: "Create and open builder" }).click();
  await expect(page).toHaveURL(/\/builder$/);
  await page.getByRole("button", { name: "Activate" }).click();
  const dialog = page.getByRole("dialog", { name: "Activate this workflow?" });
  await dialog.getByRole("button", { name: "Activate" }).click();
  await expect(dialog.getByText("Add at least one action after the trigger.")).toBeVisible();
});

test("API failures show an error state with retry", async ({ page }) => {
  await registerViaUi(page);
  await page.route("**/api/v1/dashboard/summary", (route) => route.fulfill({ status: 500, body: '{"detail":"Something went wrong on our side. Please try again."}', contentType: "application/json" }));
  await page.reload();
  await expect(page.getByText("Couldn't load your dashboard")).toBeVisible({ timeout: 20_000 });
  await page.unroute("**/api/v1/dashboard/summary");
  await page.getByRole("button", { name: "Try again" }).click();
  await expect(page.getByText("Total workflows")).toBeVisible();
});

test("templates create valid workflows", async ({ page }) => {
  await registerViaUi(page);
  await page.goto("/templates");
  const card = page.locator(".card", { hasText: "Scheduled data retrieval" });
  await card.getByRole("button", { name: "Preview" }).click();
  await expect(page.getByRole("dialog", { name: "Scheduled data retrieval" })).toBeVisible();
  await page.getByRole("dialog").getByRole("button", { name: /Use template/ }).click();
  await expect(page).toHaveURL(/\/builder$/);
  await expect(page.getByText("Saved · valid")).toBeVisible();
});

test("webhook signing secret is shown once", async ({ page }) => {
  await registerViaUi(page);
  await page.goto("/workflows/new", { waitUntil: "networkidle" });
  await page.getByLabel("Name").fill("Signed hook");
  await page.getByRole("radio", { name: /Webhook/ }).click();
  await page.getByRole("button", { name: "Create and open builder" }).click();
  await expect(page).toHaveURL(/\/builder$/);
  await page.getByRole("button", { name: "Signed hook" }).click(); // breadcrumb -> detail page
  await expect(page.getByText("Signed requests off")).toBeVisible();
  await page.getByRole("button", { name: "Require signature" }).click();
  await page.getByRole("dialog", { name: "Require signed webhooks?" }).getByRole("button", { name: "Create secret" }).click();
  const secretDialog = page.getByRole("dialog", { name: "Signing secret" });
  await expect(secretDialog.getByText("won't be shown again")).toBeVisible();
  await secretDialog.getByRole("button", { name: "Done" }).click();
  await expect(page.getByText("Signed requests required")).toBeVisible();
  await expect(page.getByRole("button", { name: "Export" })).toBeVisible();
});
