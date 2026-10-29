"use client";

import { Copy, MoreHorizontal, Pause, PencilRuler, Play, Trash2, Eye } from "lucide-react";
import { useRouter } from "next/navigation";
import { useState } from "react";
import { ApiError } from "@/lib/api";
import { useDeleteWorkflow, useDuplicateWorkflow, useSetWorkflowStatus } from "@/lib/queries";
import type { WorkflowSummary } from "@/lib/types";
import { Button } from "@/components/ui/Button";
import { ConfirmDialog, Menu, type MenuItem } from "@/components/ui/Overlay";
import { useToast } from "@/components/ui/Toast";

function describe(error: unknown) {
  if (error instanceof ApiError && error.issues.length) {
    return `${error.message} ${error.issues.slice(0, 3).map((i) => i.message).join(" ")}`;
  }
  return (error as Error).message;
}

/** Row/overflow menu for a workflow: open, duplicate, pause/activate, delete (confirmed). */
export function WorkflowActions({
  workflow,
  showView = true,
  onDeleted,
}: {
  workflow: WorkflowSummary;
  showView?: boolean;
  onDeleted?: () => void;
}) {
  const router = useRouter();
  const toast = useToast();
  const duplicate = useDuplicateWorkflow();
  const setStatus = useSetWorkflowStatus();
  const remove = useDeleteWorkflow();
  const [confirm, setConfirm] = useState<"delete" | "activate" | null>(null);
  const [error, setError] = useState<string | null>(null);

  const items: (MenuItem | "separator")[] = [
    ...(showView ? [{ label: "View details", icon: Eye, onSelect: () => router.push(`/workflows/${workflow.id}`) }] : []),
    { label: "Open builder", icon: PencilRuler, onSelect: () => router.push(`/workflows/${workflow.id}/builder`) },
    {
      label: "Duplicate",
      icon: Copy,
      onSelect: () =>
        duplicate.mutate(workflow.id, {
          onSuccess: (copy) => toast({ tone: "success", title: "Workflow duplicated", description: copy.name }),
          onError: (e) => toast({ tone: "error", title: "Couldn't duplicate", description: describe(e) }),
        }),
    },
    workflow.status === "active"
      ? {
          label: "Pause",
          icon: Pause,
          onSelect: () =>
            setStatus.mutate(
              { id: workflow.id, status: "paused" },
              {
                onSuccess: () => toast({ tone: "success", title: `${workflow.name} paused` }),
                onError: (e) => toast({ tone: "error", title: "Couldn't pause", description: describe(e) }),
              },
            ),
        }
      : { label: "Activate", icon: Play, onSelect: () => (setError(null), setConfirm("activate")) },
    "separator",
    { label: "Delete", icon: Trash2, tone: "danger", onSelect: () => (setError(null), setConfirm("delete")) },
  ];

  return (
    <>
      <Menu
        label={`Actions for ${workflow.name}`}
        items={items}
        trigger={(props) => (
          <Button variant="ghost" size="icon-sm" aria-label={`Actions for ${workflow.name}`} {...props}>
            <MoreHorizontal size={16} />
          </Button>
        )}
      />
      <ConfirmDialog
        open={confirm === "delete"}
        onClose={() => setConfirm(null)}
        title="Delete workflow?"
        description={
          <>
            <strong className="text-fg">{workflow.name}</strong> and its entire execution history will be permanently deleted.
            This can&apos;t be undone.
          </>
        }
        confirmLabel="Delete workflow"
        tone="danger"
        loading={remove.isPending}
        error={error}
        onConfirm={() =>
          remove.mutate(workflow.id, {
            onSuccess: () => {
              setConfirm(null);
              toast({ tone: "success", title: "Workflow deleted" });
              onDeleted?.();
            },
            onError: (e) => setError(describe(e)),
          })
        }
      />
      <ConfirmDialog
        open={confirm === "activate"}
        onClose={() => setConfirm(null)}
        title="Activate workflow?"
        description="Once active, its schedule or webhook will start runs automatically. You can pause it at any time."
        confirmLabel="Activate"
        loading={setStatus.isPending}
        error={error}
        onConfirm={() =>
          setStatus.mutate(
            { id: workflow.id, status: "active" },
            {
              onSuccess: () => {
                setConfirm(null);
                toast({ tone: "success", title: `${workflow.name} is active` });
              },
              onError: (e) => setError(describe(e)),
            },
          )
        }
      />
    </>
  );
}
