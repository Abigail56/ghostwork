import { CheckCircle2, GitBranch, Globe, Webhook } from "lucide-react";
import Link from "next/link";
import { Logo } from "@/components/brand/Logo";

function MiniFlow() {
  const steps = [
    { icon: Webhook, label: "Webhook received", tone: "text-violet bg-violet-soft" },
    { icon: GitBranch, label: "Priority is high", tone: "text-warning bg-warning-soft" },
    { icon: Globe, label: "POST to incident API", tone: "text-cyan bg-cyan-soft" },
  ];
  return (
    <div className="relative" aria-hidden="true">
      {steps.map(({ icon: Icon, label, tone }, i) => (
        <div key={label} className="relative">
          <div className="flex items-center gap-3 rounded-lg border border-line bg-surface/90 px-3 py-2.5 shadow-node">
            <span className={`flex h-7 w-7 items-center justify-center rounded-md ${tone}`}>
              <Icon size={14} />
            </span>
            <span className="text-meta font-medium text-fg">{label}</span>
            <CheckCircle2 size={14} className="ml-auto text-success" />
          </div>
          {i < steps.length - 1 && <div className="ml-[26px] h-5 w-px bg-cyan/60" />}
        </div>
      ))}
    </div>
  );
}

export default function AuthLayout({ children }: LayoutProps<"/">) {
  return (
    <div className="grid min-h-dvh lg:grid-cols-[minmax(0,1fr)_minmax(0,1.05fr)]">
      <aside className="relative hidden overflow-hidden border-r border-line-subtle bg-sidebar lg:flex lg:flex-col">
        <div className="grid-canvas absolute inset-0 opacity-70" aria-hidden="true" />
        <div
          className="absolute -top-32 -left-32 h-[480px] w-[480px] rounded-full bg-[radial-gradient(circle,rgb(133_133_255/0.18),transparent_65%)]"
          aria-hidden="true"
        />
        <div className="relative flex h-full flex-col p-10 xl:p-14">
          <Link href="/" aria-label="GhostWork home" className="w-fit">
            <Logo size={28} />
          </Link>
          <div className="my-auto max-w-md py-12">
            <h2 className="text-[2rem] leading-[1.12] font-semibold tracking-[-0.03em]">
              Your workflows.
              <br />
              <span className="text-violet">On autopilot.</span>
            </h2>
            <p className="mt-4 text-[0.9375rem] leading-relaxed text-fg-secondary">
              Connect your tools, orchestrate your work, and see every automation come to life in one connected workspace.
            </p>
            <div className="mt-10 max-w-sm">
              <MiniFlow />
            </div>
          </div>
          <p className="text-meta text-fg-muted">Let the repetitive work disappear.</p>
        </div>
      </aside>
      <main className="flex flex-col px-4 py-8 sm:px-8">
        <Link href="/" aria-label="GhostWork home" className="mx-auto mb-8 w-fit lg:hidden">
          <Logo size={28} />
        </Link>
        <div className="mx-auto my-auto w-full max-w-[400px]">{children}</div>
      </main>
    </div>
  );
}
