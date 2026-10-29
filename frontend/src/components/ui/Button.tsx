import Link from "next/link";
import { forwardRef } from "react";
import { cx } from "./cx";
import { Spinner } from "./Feedback";

type Variant = "primary" | "secondary" | "ghost" | "danger" | "subtle";
type Size = "sm" | "md" | "lg" | "icon" | "icon-sm";

const base =
  "inline-flex shrink-0 items-center justify-center gap-2 whitespace-nowrap rounded-md font-medium transition-[background-color,border-color,color,opacity] duration-150 select-none disabled:pointer-events-none disabled:opacity-45 focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-focus";

const variants: Record<Variant, string> = {
  primary: "bg-violet text-canvas hover:bg-violet-hover active:bg-[#7676f0] font-semibold",
  secondary: "border border-line bg-elevated text-fg hover:bg-hover hover:border-line-strong active:bg-pressed",
  ghost: "text-fg-secondary hover:bg-hover hover:text-fg active:bg-pressed",
  subtle: "bg-violet-soft text-violet hover:bg-[rgb(133_133_255/0.18)]",
  danger: "bg-danger text-canvas hover:bg-[#f47a82] font-semibold",
};

const sizes: Record<Size, string> = {
  sm: "h-8 px-3 text-meta",
  md: "h-9 px-3.5 text-body",
  lg: "h-11 px-5 text-[0.9375rem]",
  icon: "h-9 w-9",
  "icon-sm": "h-8 w-8",
};

export interface ButtonProps extends React.ButtonHTMLAttributes<HTMLButtonElement> {
  variant?: Variant;
  size?: Size;
  loading?: boolean;
}

export const Button = forwardRef<HTMLButtonElement, ButtonProps>(function Button(
  { variant = "secondary", size = "md", loading, className, children, disabled, type = "button", ...props },
  ref,
) {
  return (
    <button
      ref={ref}
      type={type}
      className={cx(base, variants[variant], sizes[size], className)}
      disabled={disabled || loading}
      aria-busy={loading || undefined}
      {...props}
    >
      {loading && <Spinner size={14} />}
      {children}
    </button>
  );
});

export function ButtonLink({
  href,
  variant = "secondary",
  size = "md",
  className,
  children,
  ...props
}: { href: string; variant?: Variant; size?: Size; className?: string; children: React.ReactNode } & Omit<
  React.AnchorHTMLAttributes<HTMLAnchorElement>,
  "href"
>) {
  return (
    <Link href={href} className={cx(base, variants[variant], sizes[size], className)} {...props}>
      {children}
    </Link>
  );
}
