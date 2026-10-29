"use client";

import { X } from "lucide-react";
import { useEffect, useId, useRef, useState } from "react";
import { Button } from "./Button";
import { cx } from "./cx";
import { InlineAlert } from "./Feedback";

/** Modal dialog built on <dialog>: native focus trapping, Escape to close, inert background. */
export function Dialog({
  open,
  onClose,
  title,
  description,
  children,
  footer,
  size = "md",
}: {
  open: boolean;
  onClose: () => void;
  title: string;
  description?: React.ReactNode;
  children?: React.ReactNode;
  footer?: React.ReactNode;
  size?: "sm" | "md" | "lg";
}) {
  const ref = useRef<HTMLDialogElement>(null);
  const titleId = useId();
  useEffect(() => {
    const dialog = ref.current;
    if (!dialog) return;
    if (open && !dialog.open) dialog.showModal();
    if (!open && dialog.open) dialog.close();
  }, [open]);

  return (
    <dialog
      ref={ref}
      aria-labelledby={titleId}
      onClose={onClose}
      onCancel={(e) => {
        e.preventDefault();
        onClose();
      }}
      onClick={(e) => {
        if (e.target === ref.current) onClose();
      }}
      className={cx(
        "m-auto w-[calc(100vw-2rem)] max-h-[calc(100dvh-2rem)] overflow-hidden rounded-xl border border-line bg-surface p-0 text-fg shadow-pop open:animate-pop-in",
        size === "sm" ? "max-w-md" : size === "md" ? "max-w-lg" : "max-w-2xl",
      )}
    >
      {open && (
        <div className="flex max-h-[calc(100dvh-2rem)] flex-col">
          <div className="flex items-start justify-between gap-4 border-b border-line-subtle px-5 pt-4 pb-3.5">
            <div>
              <h2 id={titleId} className="text-section font-semibold">
                {title}
              </h2>
              {description && <div className="mt-1 text-body text-fg-muted">{description}</div>}
            </div>
            <Button variant="ghost" size="icon-sm" aria-label="Close" onClick={onClose} className="-mr-1.5 -mt-0.5">
              <X size={16} />
            </Button>
          </div>
          {children && <div className="overflow-y-auto px-5 py-4">{children}</div>}
          {footer && (
            <div className="flex flex-col-reverse gap-2 border-t border-line-subtle bg-sidebar/60 px-5 py-3 sm:flex-row sm:justify-end">
              {footer}
            </div>
          )}
        </div>
      )}
    </dialog>
  );
}

export function ConfirmDialog({
  open,
  onClose,
  onConfirm,
  title,
  description,
  confirmLabel = "Confirm",
  tone = "primary",
  loading,
  error,
}: {
  open: boolean;
  onClose: () => void;
  onConfirm: () => void;
  title: string;
  description: React.ReactNode;
  confirmLabel?: string;
  tone?: "primary" | "danger";
  loading?: boolean;
  error?: string | null;
}) {
  return (
    <Dialog
      open={open}
      onClose={onClose}
      title={title}
      size="sm"
      footer={
        <>
          <Button onClick={onClose} disabled={loading}>
            Cancel
          </Button>
          <Button variant={tone === "danger" ? "danger" : "primary"} onClick={onConfirm} loading={loading}>
            {confirmLabel}
          </Button>
        </>
      }
    >
      <div className="text-body text-fg-secondary">{description}</div>
      {error && <InlineAlert className="mt-3">{error}</InlineAlert>}
    </Dialog>
  );
}

/** Side sheet. Used for mobile navigation and builder panels on small screens. */
export function Drawer({
  open,
  onClose,
  title,
  side = "right",
  children,
  width = "w-[min(22rem,calc(100vw-2.5rem))]",
}: {
  open: boolean;
  onClose: () => void;
  title: string;
  side?: "left" | "right";
  children: React.ReactNode;
  width?: string;
}) {
  const ref = useRef<HTMLDialogElement>(null);
  const titleId = useId();
  useEffect(() => {
    const dialog = ref.current;
    if (!dialog) return;
    if (open && !dialog.open) dialog.showModal();
    if (!open && dialog.open) dialog.close();
  }, [open]);
  return (
    <dialog
      ref={ref}
      aria-labelledby={titleId}
      onCancel={(e) => {
        e.preventDefault();
        onClose();
      }}
      onClose={onClose}
      onClick={(e) => {
        if (e.target === ref.current) onClose();
      }}
      className={cx(
        "fixed inset-y-0 m-0 h-dvh max-h-dvh border-line bg-sidebar p-0 text-fg shadow-pop",
        width,
        side === "left"
          ? "left-0 right-auto border-r open:animate-slide-in-left"
          : "right-0 left-auto border-l open:animate-slide-in-right",
      )}
    >
      {open && (
        <div className="flex h-full flex-col">
          <div className="flex h-14 shrink-0 items-center justify-between border-b border-line-subtle px-4">
            <h2 id={titleId} className="text-section font-semibold">
              {title}
            </h2>
            <Button variant="ghost" size="icon-sm" aria-label="Close" onClick={onClose}>
              <X size={16} />
            </Button>
          </div>
          <div className="min-h-0 flex-1 overflow-y-auto">{children}</div>
        </div>
      )}
    </dialog>
  );
}

export interface MenuItem {
  label: string;
  icon?: React.ElementType;
  onSelect: () => void;
  tone?: "danger";
  disabled?: boolean;
}

/** Dropdown menu with arrow-key navigation and Escape/outside-click dismissal. */
export function Menu({
  trigger,
  items,
  align = "end",
  label,
}: {
  trigger: (props: { onClick: () => void; "aria-expanded": boolean; "aria-haspopup": "menu"; "aria-controls": string }) => React.ReactNode;
  items: (MenuItem | "separator")[];
  align?: "start" | "end";
  label: string;
}) {
  const [open, setOpen] = useState(false);
  const id = useId();
  const container = useRef<HTMLDivElement>(null);
  const list = useRef<HTMLDivElement>(null);

  useEffect(() => {
    if (!open) return;
    const onDown = (e: PointerEvent) => {
      if (!container.current?.contains(e.target as Node)) setOpen(false);
    };
    document.addEventListener("pointerdown", onDown);
    list.current?.querySelector<HTMLButtonElement>("[role=menuitem]:not([disabled])")?.focus();
    return () => document.removeEventListener("pointerdown", onDown);
  }, [open]);

  const onKeyDown = (e: React.KeyboardEvent) => {
    const buttons = Array.from(list.current?.querySelectorAll<HTMLButtonElement>("[role=menuitem]:not([disabled])") ?? []);
    const index = buttons.indexOf(document.activeElement as HTMLButtonElement);
    if (e.key === "ArrowDown") {
      e.preventDefault();
      buttons[(index + 1) % buttons.length]?.focus();
    } else if (e.key === "ArrowUp") {
      e.preventDefault();
      buttons[(index - 1 + buttons.length) % buttons.length]?.focus();
    } else if (e.key === "Escape") {
      setOpen(false);
      (container.current?.querySelector("[aria-haspopup]") as HTMLElement | null)?.focus();
    } else if (e.key === "Tab") {
      setOpen(false);
    }
  };

  return (
    <div ref={container} className="relative inline-flex">
      {trigger({ onClick: () => setOpen((v) => !v), "aria-expanded": open, "aria-haspopup": "menu", "aria-controls": id })}
      {open && (
        <div
          ref={list}
          id={id}
          role="menu"
          aria-label={label}
          onKeyDown={onKeyDown}
          className={cx(
            "absolute top-full z-50 mt-1.5 min-w-48 animate-pop-in rounded-lg border border-line bg-elevated p-1 shadow-pop",
            align === "end" ? "right-0" : "left-0",
          )}
        >
          {items.map((item, i) =>
            item === "separator" ? (
              <div key={`sep-${i}`} role="separator" className="my-1 h-px bg-line-subtle" />
            ) : (
              <button
                key={item.label}
                type="button"
                role="menuitem"
                disabled={item.disabled}
                onClick={() => {
                  setOpen(false);
                  item.onSelect();
                }}
                className={cx(
                  "flex w-full items-center gap-2.5 rounded-md px-2.5 py-2 text-left text-body outline-none transition-colors disabled:opacity-40",
                  item.tone === "danger"
                    ? "text-danger hover:bg-danger-soft focus:bg-danger-soft"
                    : "text-fg-secondary hover:bg-hover hover:text-fg focus:bg-hover focus:text-fg",
                )}
              >
                {item.icon && <item.icon size={15} aria-hidden="true" />}
                {item.label}
              </button>
            ),
          )}
        </div>
      )}
    </div>
  );
}

/** Lightweight tooltip shown on hover and keyboard focus. */
export function Tooltip({ label, children, side = "top" }: { label: string; children: React.ReactElement; side?: "top" | "bottom" }) {
  const id = useId();
  return (
    <span className="group/tip relative inline-flex" aria-describedby={id}>
      {children}
      <span
        id={id}
        role="tooltip"
        className={cx(
          "pointer-events-none absolute left-1/2 z-50 -translate-x-1/2 whitespace-nowrap rounded-md border border-line bg-elevated px-2 py-1 text-micro font-medium text-fg opacity-0 shadow-pop transition-opacity delay-150 group-hover/tip:opacity-100 group-focus-within/tip:opacity-100",
          side === "top" ? "bottom-full mb-1.5" : "top-full mt-1.5",
        )}
      >
        {label}
      </span>
    </span>
  );
}
