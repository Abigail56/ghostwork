import type { Metadata } from "next";
import { PageIntro } from "@/components/marketing/Section";
import { TermsContent } from "@/components/marketing/TermsContent";
import { TERMS_SECTIONS } from "@/lib/terms";

export const metadata: Metadata = { title: "Terms of Service" };

export default function TermsPage() {
  return (
    <>
      <PageIntro eyebrow="Legal" title="Terms of Service" description="The agreement that applies when you use GhostWork, written to be read." />
      <div className="mx-auto flex max-w-6xl gap-10 px-4 py-12 sm:px-6">
        <nav aria-label="Sections" className="sticky top-20 hidden h-fit w-56 shrink-0 lg:block">
          <p className="eyebrow">Sections</p>
          <ol className="mt-3 flex flex-col gap-1.5 text-meta">
            {TERMS_SECTIONS.map((s) => (
              <li key={s.id}>
                <a href={`#${s.id}`} className="text-fg-muted hover:text-fg">
                  {s.title}
                </a>
              </li>
            ))}
          </ol>
        </nav>
        <div className="min-w-0 max-w-3xl flex-1">
          <TermsContent />
        </div>
      </div>
    </>
  );
}
