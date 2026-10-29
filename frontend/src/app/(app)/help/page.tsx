import type { Metadata } from "next";
import { HelpView } from "./HelpView";

export const metadata: Metadata = { title: "Help" };
export const instant = false;

export default function HelpPage() {
  return <HelpView />;
}
