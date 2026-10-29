import { expect, type Page } from "@playwright/test";

export const PASSWORD = "e2e-password-123";

export function uniqueEmail(prefix = "e2e") {
  return `${prefix}-${Date.now()}-${Math.floor(Math.random() * 1e6)}@example.com`;
}

export async function registerViaUi(page: Page, name = "Grace Hopper", email = uniqueEmail()) {
  await page.goto("/register");
  await page.getByLabel("Full name").fill(name);
  await page.getByLabel("Work email").fill(email);
  await page.getByLabel("Password", { exact: true }).fill(PASSWORD);
  await page.getByRole("button", { name: "Create account" }).click();
  await expect(page).toHaveURL(/\/dashboard$/);
  return email;
}
