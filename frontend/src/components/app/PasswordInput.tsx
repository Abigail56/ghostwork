"use client";

import { Eye, EyeOff } from "lucide-react";
import { forwardRef, useState } from "react";
import { Input } from "@/components/ui/Form";

export const PasswordInput = forwardRef<HTMLInputElement, React.InputHTMLAttributes<HTMLInputElement>>(
  function PasswordInput(props, ref) {
    const [visible, setVisible] = useState(false);
    return (
      <div className="relative">
        <Input ref={ref} type={visible ? "text" : "password"} className="pr-10" {...props} />
        <button
          type="button"
          onClick={() => setVisible((v) => !v)}
          className="absolute top-1/2 right-1.5 flex h-7 w-7 -translate-y-1/2 items-center justify-center rounded text-fg-muted hover:text-fg"
          aria-label={visible ? "Hide password" : "Show password"}
          aria-pressed={visible}
        >
          {visible ? <EyeOff size={15} /> : <Eye size={15} />}
        </button>
      </div>
    );
  },
);

export function passwordProblems(value: string): string | null {
  if (value.length < 10) return "Use at least 10 characters.";
  if (value.length > 128) return "Use at most 128 characters.";
  if (!/[A-Za-z]/.test(value) || !/\d/.test(value)) return "Include at least one letter and one number.";
  if (new Set(value).size < 5) return "This password is too repetitive.";
  return null;
}

export function PasswordStrength({ value }: { value: string }) {
  const checks = [value.length >= 10, /[A-Za-z]/.test(value) && /\d/.test(value), new Set(value).size >= 5, value.length >= 14];
  const score = checks.filter(Boolean).length;
  const colors = ["bg-danger", "bg-danger", "bg-warning", "bg-success", "bg-success"];
  return (
    <div className="mt-1 flex gap-1" aria-hidden="true">
      {[0, 1, 2, 3].map((i) => (
        <span key={i} className={`h-1 flex-1 rounded-full ${i < score ? colors[score] : "bg-elevated"}`} />
      ))}
    </div>
  );
}
