import Link from "next/link";
import { Logo } from "@/components/brand/Logo";
import { API_BASE_URL } from "@/lib/api";

const COLUMNS = [
  {
    title: "Product",
    links: [
      { href: "/features", label: "Features" },
      { href: "/pricing", label: "Pricing" },
      { href: "/register", label: "Get started" },
    ],
  },
  {
    title: "Resources",
    links: [
      { href: "/docs", label: "Documentation" },
      { href: `${API_BASE_URL}/docs`, label: "API reference", external: true },
    ],
  },
  {
    title: "Company",
    links: [
      { href: "/about", label: "About" },
      { href: "/privacy", label: "Privacy" },
      { href: "/terms", label: "Terms" },
    ],
  },
];

async function currentYear() {
  "use cache";
  return new Date().getFullYear();
}

export async function SiteFooter() {
  return (
    <footer className="border-t border-line-subtle bg-sidebar">
      <div className="mx-auto grid max-w-6xl gap-10 px-4 py-12 sm:px-6 md:grid-cols-[1.4fr_repeat(3,1fr)]">
        <div>
          <Logo size={24} />
          <p className="mt-3 max-w-xs text-body text-fg-muted">Let the repetitive work disappear.</p>
        </div>
        {COLUMNS.map((column) => (
          <div key={column.title}>
            <h2 className="eyebrow">{column.title}</h2>
            <ul className="mt-3 flex flex-col gap-2">
              {column.links.map((link) => (
                <li key={link.href}>
                  {"external" in link ? (
                    <a href={link.href} className="text-body text-fg-secondary hover:text-fg" target="_blank" rel="noreferrer">
                      {link.label}
                    </a>
                  ) : (
                    <Link href={link.href} className="text-body text-fg-secondary hover:text-fg">
                      {link.label}
                    </Link>
                  )}
                </li>
              ))}
            </ul>
          </div>
        ))}
      </div>
      <div className="border-t border-line-subtle">
        <div className="mx-auto flex max-w-6xl flex-col gap-2 px-4 py-5 text-meta text-fg-muted sm:flex-row sm:justify-between sm:px-6">
          <span>© {await currentYear()} GhostWork</span>
          <span>Built with FastAPI, PostgreSQL, Redis and Next.js.</span>
        </div>
      </div>
    </footer>
  );
}
