export function AuthHeading({ title, description }: { title: string; description?: React.ReactNode }) {
  return (
    <div className="mb-7">
      <h1 className="text-[1.625rem] leading-tight font-semibold tracking-[-0.02em]">{title}</h1>
      {description && <p className="mt-2 text-body text-fg-muted">{description}</p>}
    </div>
  );
}

/** Redirect target after sign-in; only same-site paths are allowed. */
export function safeNext(next: string | null | undefined): string {
  if (next && next.startsWith("/") && !next.startsWith("//") && !next.startsWith("/\\")) return next;
  return "/dashboard";
}
