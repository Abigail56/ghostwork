"use client";

import { ExternalLink } from "lucide-react";
import Link from "next/link";
import { useId } from "react";
import type { UseFormRegisterReturn } from "react-hook-form";
import { TermsContent } from "@/components/marketing/TermsContent";
import { cx } from "@/components/ui/cx";

/** Scrollable Terms of Service plus the required acceptance checkbox. */
export function TermsAgreement({ error, registerProps }: { error?: string; registerProps: UseFormRegisterReturn }) {
  const id = useId();
  return (
    <div className="flex flex-col gap-2.5">
      <div className="flex items-center justify-between">
        <p id={`${id}-title`} className="text-meta font-medium text-fg-secondary">
          Terms of Service
        </p>
        <Link href="/terms" target="_blank" className="inline-flex items-center gap-1 text-micro text-violet hover:underline">
          Open full page <ExternalLink size={11} aria-hidden="true" />
        </Link>
      </div>
      <div
        role="region"
        aria-labelledby={`${id}-title`}
        tabIndex={0}
        className="h-52 overflow-y-auto rounded-md border border-line bg-canvas px-3.5 py-3 focus-visible:outline-2 focus-visible:outline-focus"
      >
        <TermsContent compact />
      </div>
      <label htmlFor={`${id}-accept`} className={cx("flex cursor-pointer items-start gap-2.5 rounded-md border px-3 py-2.5", error ? "border-danger/60" : "border-line-subtle")}>
        <input
          id={`${id}-accept`}
          type="checkbox"
          className="mt-0.5 h-4 w-4 shrink-0 cursor-pointer accent-[#8585ff]"
          aria-invalid={error ? true : undefined}
          aria-describedby={error ? `${id}-error` : undefined}
          {...registerProps}
        />
        <span className="text-meta leading-relaxed text-fg-secondary">
          I have read and agree to the{" "}
          <Link href="/terms" target="_blank" className="text-fg underline-offset-2 hover:underline">
            Terms of Service
          </Link>{" "}
          and the{" "}
          <Link href="/privacy" target="_blank" className="text-fg underline-offset-2 hover:underline">
            Privacy Policy
          </Link>
          .
        </span>
      </label>
      {error && (
        <p id={`${id}-error`} role="alert" className="text-meta text-danger">
          {error}
        </p>
      )}
    </div>
  );
}
