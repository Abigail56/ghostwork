import type { Metadata } from "next";
import { NewWorkflowForm } from "./NewWorkflowForm";

export const metadata: Metadata = { title: "New workflow" };
export const instant = false;

export default function NewWorkflowPage() {
  return <NewWorkflowForm />;
}
