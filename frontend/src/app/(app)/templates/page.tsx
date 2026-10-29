import type { Metadata } from "next";
import { TemplatesView } from "./TemplatesView";

export const metadata: Metadata = { title: "Templates" };
export const instant = false;

export default function TemplatesPage() {
  return <TemplatesView />;
}
