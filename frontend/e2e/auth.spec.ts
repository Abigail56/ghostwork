import { expect, test } from "@playwright/test";
import { PASSWORD, registerViaUi, uniqueEmail } from "./helpers";

test("register validates input before calling the API", async ({ page }) => {
  await page.goto("/register", { waitUntil: "networkidle" });
  await page.getByRole("button", { name: "Create account" }).click();
  await expect(page.getByText("Enter your name.")).toBeVisible();
  await expect(page.getByText("Enter a valid email address.")).toBeVisible();
  await page.getByLabel("Password", { exact: true }).filter({ visible: true }).fill("short1");
  await page.getByRole("button", { name: "Create account" }).click();
  await expect(page.getByText("Use at least 10 characters.")).toBeVisible();
});

test("register, sign out, sign in again", async ({ page }) => {
  const email = await registerViaUi(page);
  await expect(page.getByRole("heading", { name: /Grace/ })).toBeVisible();
  await expect(page.getByText("Create your first workflow").first()).toBeVisible();

  await page.getByRole("button", { name: "Account menu" }).click();
  await page.getByRole("menuitem", { name: "Log out" }).click();
  await expect(page).toHaveURL(/\/login/);

  await page.getByLabel("Email", { exact: true }).filter({ visible: true }).fill(email);
  await page.getByLabel("Password", { exact: true }).filter({ visible: true }).fill("wrong-password-9");
  await page.getByRole("button", { name: "Sign in" }).click();
  await expect(page.getByRole("alert").filter({ hasText: "Incorrect email or password." })).toBeVisible();

  await page.getByLabel("Password", { exact: true }).filter({ visible: true }).fill(PASSWORD);
  await page.getByRole("button", { name: "Sign in" }).click();
  await expect(page).toHaveURL(/\/dashboard$/);
});

test("session survives a reload via the refresh cookie", async ({ page }) => {
  await registerViaUi(page);
  await page.reload();
  await expect(page).toHaveURL(/\/dashboard$/);
  await expect(page.getByRole("heading", { name: /Grace/ })).toBeVisible();
});

test("protected routes redirect to sign in and back", async ({ page }) => {
  await page.goto("/executions");
  await expect(page).toHaveURL(/\/login\?next=%2Fexecutions/);
});

test("duplicate registration shows the server error", async ({ page }) => {
  const email = uniqueEmail();
  await registerViaUi(page, "First", email);
  await page.getByRole("button", { name: "Account menu" }).click();
  await page.getByRole("menuitem", { name: "Log out" }).click();
  await page.goto("/register", { waitUntil: "networkidle" });
  await page.getByLabel("Full name").fill("Second");
  await page.getByLabel("Work email").fill(email);
  await page.getByLabel("Password", { exact: true }).filter({ visible: true }).fill(PASSWORD);
  await page.getByRole("checkbox", { name: /I have read and agree/ }).check();
  await page.getByRole("button", { name: "Create account" }).click();
  await expect(page.getByText("An account with this email already exists.")).toBeVisible();
});

test("sign-up shows the terms and requires accepting them", async ({ page }) => {
  await page.goto("/register", { waitUntil: "networkidle" });
  const terms = page.getByRole("region", { name: "Terms of Service" });
  await expect(terms.getByText("The short version")).toBeVisible();
  await expect(terms.getByRole("heading", { name: "5. Acceptable use" })).toBeAttached();
  await page.getByLabel("Full name").fill("Terms Reader");
  await page.getByLabel("Work email").fill(uniqueEmail("terms"));
  await page.getByLabel("Password", { exact: true }).fill(PASSWORD);
  await page.getByRole("button", { name: "Create account" }).click();
  await expect(page.getByText("Please read and accept the Terms of Service to continue.")).toBeVisible();
  await expect(page).toHaveURL(/\/register$/);
  await page.getByRole("checkbox", { name: /I have read and agree/ }).check();
  await page.getByRole("button", { name: "Create account" }).click();
  await expect(page).toHaveURL(/\/dashboard$/);
  await page.goto("/settings?tab=activity");
  await expect(page.getByText(/Terms of Service \(2026-10-30\) accepted/)).toBeVisible();
});
