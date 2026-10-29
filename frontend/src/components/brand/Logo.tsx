import { useId } from "react";

/**
 * The GhostWork mark: a geometric ghost whose eyes are two connected workflow nodes.
 * Pure SVG so it scales from favicon to hero.
 */
export function LogoMark({ size = 28, className = "" }: { size?: number; className?: string }) {
  const id = useId();
  return (
    <svg width={size} height={size} viewBox="0 0 32 32" fill="none" className={className} aria-hidden="true">
      <defs>
        <linearGradient id={`${id}-g`} x1="6" y1="4" x2="26" y2="28" gradientUnits="userSpaceOnUse">
          <stop stopColor="#9B9BFF" />
          <stop offset="1" stopColor="#6E6EF0" />
        </linearGradient>
      </defs>
      <path
        d="M5.5 15.5C5.5 9.70101 10.201 5 16 5C21.799 5 26.5 9.70101 26.5 15.5V26.2C26.5 27.03 25.55 27.5 24.89 27L22.5 25.2L19.83 27.2C19.48 27.47 18.99 27.47 18.63 27.2L16 25.2L13.37 27.2C13.01 27.47 12.52 27.47 12.17 27.2L9.5 25.2L7.11 27C6.45 27.5 5.5 27.03 5.5 26.2V15.5Z"
        fill={`url(#${id}-g)`}
      />
      <path d="M12.6 15.2H19.4" stroke="#0B0D12" strokeWidth="1.4" strokeLinecap="round" />
      <circle cx="12" cy="15.2" r="2.3" fill="#0B0D12" />
      <circle cx="20" cy="15.2" r="2.3" fill="#0B0D12" />
      <circle cx="20" cy="15.2" r="1" fill="#55C5F2" />
    </svg>
  );
}

export function Logo({ size = 28, className = "", showWordmark = true }: { size?: number; className?: string; showWordmark?: boolean }) {
  return (
    <span className={`inline-flex items-center gap-2.5 ${className}`}>
      <LogoMark size={size} />
      {showWordmark && (
        <span className="text-[1.05rem] font-semibold tracking-[-0.02em] text-fg">
          Ghost<span className="text-fg-secondary">Work</span>
        </span>
      )}
    </span>
  );
}
