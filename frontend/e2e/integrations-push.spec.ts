import { expect, test } from "@playwright/test";
import { registerViaUi } from "./helpers";

test("GitHub and Google are available to connect, and nothing is labelled planned", async ({ page }) => {
  await registerViaUi(page);
  await page.goto("/integrations", { waitUntil: "networkidle" });
  const main = page.locator("main").filter({ visible: true });
  await expect(main.getByText("GitHub", { exact: true }).first()).toBeVisible();
  await expect(main.getByText("Google Sheets", { exact: true }).first()).toBeVisible();
  await expect(main.getByText("Planned", { exact: true })).toHaveCount(0);
});

test("the new templates are offered", async ({ page }) => {
  await registerViaUi(page);
  await page.goto("/templates", { waitUntil: "networkidle" });
  const main = page.locator("main").filter({ visible: true });
  await expect(main.getByText(/GitHub issue/i).first()).toBeVisible();
  await expect(main.getByText(/sheet/i).first()).toBeVisible();
});
