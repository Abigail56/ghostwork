import type { Metadata } from "next";
import { DashboardView } from "./DashboardView";

export const metadata: Metadata = { title: "Dashboard" };
// Rendered after the client restores the session; see (app)/layout.tsx.
export const instant = false;

export default function DashboardPage() {
  return <DashboardView />;
}
