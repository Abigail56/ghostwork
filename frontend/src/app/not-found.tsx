import Link from "next/link";
import { LogoMark } from "@/components/brand/Logo";

export default function NotFound() {
  return (
    <main className="flex min-h-dvh flex-col items-center justify-center px-6 text-center">
      <LogoMark size={44} className="opacity-80" />
      <p className="mt-6 font-mono text-meta text-fg-muted">404</p>
      <h1 className="mt-1 text-title font-semibold">This page vanished</h1>
      <p className="mt-2 max-w-sm text-body text-fg-muted">The page you&apos;re looking for doesn&apos;t exist or has moved.</p>
      <div className="mt-6 flex gap-2">
        <Link href="/" className="inline-flex h-9 items-center rounded-md border border-line bg-elevated px-3.5 text-body font-medium hover:bg-hover">
          Home
        </Link>
        <Link href="/dashboard" className="inline-flex h-9 items-center rounded-md bg-violet px-3.5 text-body font-semibold text-canvas hover:bg-violet-hover">
          Dashboard
        </Link>
      </div>
    </main>
  );
}
