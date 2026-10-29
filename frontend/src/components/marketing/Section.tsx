import { cx } from "@/components/ui/cx";

export function Section({ id, eyebrow, title, description, children, className }: {
  id?: string;
  eyebrow?: string;
  title: React.ReactNode;
  description?: React.ReactNode;
  children?: React.ReactNode;
  className?: string;
}) {
  return (
    <section id={id} className={cx("mx-auto max-w-6xl px-4 py-16 sm:px-6 sm:py-24", className)}>
      <div className="max-w-2xl">
        {eyebrow && <p className="text-meta font-semibold text-violet">{eyebrow}</p>}
        <h2 className="mt-2 text-[1.75rem] leading-tight font-semibold tracking-[-0.02em] sm:text-headline">{title}</h2>
        {description && <p className="mt-3 text-[0.9375rem] leading-relaxed text-fg-secondary sm:text-base">{description}</p>}
      </div>
      {children && <div className="mt-10 sm:mt-12">{children}</div>}
    </section>
  );
}

export function PageIntro({ eyebrow, title, description }: { eyebrow: string; title: string; description: React.ReactNode }) {
  return (
    <div className="border-b border-line-subtle">
      <div className="mx-auto max-w-6xl px-4 pt-14 pb-12 sm:px-6 sm:pt-20 sm:pb-16">
        <p className="text-meta font-semibold text-violet">{eyebrow}</p>
        <h1 className="mt-2 max-w-3xl text-[2.125rem] leading-[1.1] font-semibold tracking-[-0.03em] sm:text-[2.75rem]">{title}</h1>
        <p className="mt-4 max-w-2xl text-base leading-relaxed text-fg-secondary">{description}</p>
      </div>
    </div>
  );
}

export function Prose({ children }: { children: React.ReactNode }) {
  return (
    <div className="mx-auto max-w-3xl px-4 py-12 text-[0.9375rem] leading-relaxed text-fg-secondary sm:px-6 [&_a]:text-violet [&_a:hover]:underline [&_code]:rounded [&_code]:bg-elevated [&_code]:px-1.5 [&_code]:py-0.5 [&_code]:font-mono [&_code]:text-[0.8125rem] [&_code]:text-fg [&_h2]:mt-10 [&_h2]:mb-3 [&_h2]:text-xl [&_h2]:font-semibold [&_h2]:text-fg [&_h3]:mt-6 [&_h3]:mb-2 [&_h3]:font-semibold [&_h3]:text-fg [&_li]:mt-1.5 [&_p]:mt-3 [&_pre]:mt-3 [&_pre]:overflow-x-auto [&_pre]:rounded-lg [&_pre]:border [&_pre]:border-line [&_pre]:bg-surface [&_pre]:p-4 [&_pre]:font-mono [&_pre]:text-[0.8125rem] [&_pre_code]:bg-transparent [&_pre_code]:p-0 [&_ul]:mt-3 [&_ul]:list-disc [&_ul]:pl-5">
      {children}
    </div>
  );
}
