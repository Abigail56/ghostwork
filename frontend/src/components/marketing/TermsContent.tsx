import { TERMS_EFFECTIVE, TERMS_SECTIONS, TERMS_SUMMARY, TERMS_VERSION } from "@/lib/terms";
import { cx } from "@/components/ui/cx";

/** The full Terms of Service. `compact` is used inside the sign-up form's scroll panel. */
export function TermsContent({ compact = false }: { compact?: boolean }) {
  const h = compact ? "text-body font-semibold text-fg" : "text-lg font-semibold text-fg";
  const p = compact ? "mt-1.5 text-meta leading-relaxed text-fg-secondary" : "mt-3 text-[0.9375rem] leading-relaxed text-fg-secondary";
  return (
    <div>
      <p className={cx(compact ? "text-micro" : "text-meta", "text-fg-muted")}>
        Version {TERMS_VERSION} · Effective {TERMS_EFFECTIVE}
      </p>
      <div className={cx("rounded-lg border border-violet/25 bg-violet-soft", compact ? "mt-3 p-3" : "mt-5 p-5")}>
        <p className={cx(compact ? "text-meta" : "text-body", "font-semibold text-fg")}>The short version</p>
        <ul className={cx("mt-2 flex flex-col gap-1.5", compact ? "text-meta" : "text-body", "text-fg-secondary")}>
          {TERMS_SUMMARY.map((item) => (
            <li key={item} className="flex gap-2">
              <span className="mt-[0.55em] h-1 w-1 shrink-0 rounded-full bg-violet" aria-hidden="true" />
              {item}
            </li>
          ))}
        </ul>
        <p className={cx("mt-2 text-fg-muted", compact ? "text-micro" : "text-meta")}>This summary is for convenience; the full terms below apply.</p>
      </div>
      {TERMS_SECTIONS.map((section) => (
        <section key={section.id} id={compact ? undefined : section.id} className={compact ? "mt-4" : "mt-9 scroll-mt-24"}>
          <h2 className={h}>{section.title}</h2>
          {section.paragraphs.map((text, i) => (
            <p key={i} className={p}>
              {text}
            </p>
          ))}
          {section.bullets && (
            <ul className={cx("list-disc pl-5", compact ? "mt-1.5 text-meta" : "mt-3 text-[0.9375rem]", "flex flex-col gap-1 leading-relaxed text-fg-secondary")}>
              {section.bullets.map((b) => (
                <li key={b}>{b}</li>
              ))}
            </ul>
          )}
        </section>
      ))}
    </div>
  );
}
