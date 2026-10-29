import { History, LayoutDashboard, LayoutTemplate, LifeBuoy, Plug, Settings, Workflow } from "lucide-react";

export const APP_NAV = [
  { href: "/dashboard", label: "Dashboard", icon: LayoutDashboard },
  { href: "/workflows", label: "Workflows", icon: Workflow },
  { href: "/executions", label: "Executions", icon: History },
  { href: "/integrations", label: "Integrations", icon: Plug },
  { href: "/templates", label: "Templates", icon: LayoutTemplate },
  { href: "/settings", label: "Settings", icon: Settings },
];

export const HELP_NAV = { href: "/help", label: "Help", icon: LifeBuoy };

export function isActive(pathname: string, href: string) {
  return pathname === href || pathname.startsWith(`${href}/`);
}

export function pageTitle(pathname: string): string {
  if (pathname.endsWith("/builder")) return "Builder";
  if (pathname === "/workflows/new") return "New workflow";
  const match = [...APP_NAV, HELP_NAV].find((item) => isActive(pathname, item.href));
  return match?.label ?? "GhostWork";
}
