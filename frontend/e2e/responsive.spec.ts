import { expect, test } from "@playwright/test";
import { registerViaUi } from "./helpers";

test("mobile navigation drawer opens, navigates and closes", async ({ page }) => {
  await registerViaUi(page);
  await page.getByRole("button", { name: "Open navigation" }).click();
  const drawer = page.getByRole("dialog", { name: "Navigation" });
  await expect(drawer).toBeVisible();
  await drawer.getByRole("link", { name: "Executions" }).click();
  await expect(page).toHaveURL(/\/executions$/);
  await expect(drawer).toBeHidden();

  await page.getByRole("button", { name: "Open navigation" }).click();
  await page.keyboard.press("Escape");
  await expect(page.getByRole("dialog", { name: "Navigation" })).toBeHidden();
});

test("pages don't scroll horizontally on a phone", async ({ page }) => {
  await registerViaUi(page);
  for (const path of ["/dashboard", "/workflows", "/executions", "/integrations", "/templates", "/settings", "/"]) {
    await page.goto(path);
    await page.waitForLoadState("networkidle");
    const overflow = await page.evaluate(() => document.documentElement.scrollWidth - window.innerWidth);
    expect(overflow, path).toBeLessThanOrEqual(0);
  }
});

test("keyboard: skip link and settings tabs", async ({ page }) => {
  await registerViaUi(page);
  await page.goto("/settings");
  await expect(page.getByRole("heading", { name: "Settings" })).toBeVisible();
  // The skip link is the first tab stop in the page (the Next.js dev-tools button may
  // precede it in development, so allow one extra Tab).
  const skip = page.getByRole("link", { name: "Skip to content" });
  await page.keyboard.press("Tab");
  if (!(await skip.evaluate((el) => el === document.activeElement))) await page.keyboard.press("Tab");
  await expect(skip).toBeFocused();
  await page.keyboard.press("Enter");
  await expect(page).toHaveURL(/#app-main$/);
  await page.getByRole("tab", { name: "Profile" }).focus();
  await page.keyboard.press("ArrowRight");
  await expect(page.getByRole("tab", { name: "Security" })).toHaveAttribute("aria-selected", "true");
  await expect(page.getByRole("heading", { name: "Password" })).toBeVisible();
});
