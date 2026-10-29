import { Suspense } from "react";
import { LoadingBlock } from "@/components/ui/Feedback";
import { BuilderLoader } from "./BuilderLoader";

export const instant = false;

export default function BuilderPage({ params }: PageProps<"/workflows/[id]/builder">) {
  return (
    <Suspense fallback={<div className="p-6"><LoadingBlock label="Loading builder" rows={4} /></div>}>
      <BuilderLoader params={params} />
    </Suspense>
  );
}
