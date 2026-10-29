import type { Metadata } from "next";
import { Suspense } from "react";
import { LoadingBlock } from "@/components/ui/Feedback";
import { SettingsView } from "./SettingsView";

export const metadata: Metadata = { title: "Settings" };
export const instant = false;

export default function SettingsPage() {
  return (
    <Suspense fallback={<LoadingBlock label="Loading settings" rows={5} />}>
      <SettingsView />
    </Suspense>
  );
}
