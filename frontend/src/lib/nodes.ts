import {
  CalendarClock,
  GitBranch,
  Globe,
  Hand,
  KeyRound,
  Mail,
  MessageSquare,
  Shuffle,
  Webhook,
  type LucideIcon,
} from "lucide-react";
import type { NodeDefinition } from "./types";

export type NodeKind = "trigger" | "action" | "condition";

export const KIND_STYLE: Record<NodeKind, { label: string; text: string; bg: string; border: string; dot: string }> = {
  trigger: { label: "Trigger", text: "text-violet", bg: "bg-violet-soft", border: "border-violet/40", dot: "bg-violet" },
  action: { label: "Action", text: "text-cyan", bg: "bg-cyan-soft", border: "border-cyan/35", dot: "bg-cyan" },
  condition: { label: "Condition", text: "text-warning", bg: "bg-warning-soft", border: "border-warning/35", dot: "bg-warning" },
};

export const NODE_ICONS: Record<string, LucideIcon> = {
  "trigger.manual": Hand,
  "trigger.schedule": CalendarClock,
  "trigger.webhook": Webhook,
  "action.http_request": Globe,
  "action.transform": Shuffle,
  "action.email": Mail,
  "action.slack": MessageSquare,
  "condition.if": GitBranch,
};

export const PROVIDER_ICONS: Record<string, LucideIcon> = {
  smtp: Mail,
  slack: MessageSquare,
  http_auth: KeyRound,
};

export function kindOf(type: string): NodeKind {
  if (type.startsWith("trigger.")) return "trigger";
  if (type.startsWith("condition.")) return "condition";
  return "action";
}

const OPERATOR_LABEL: Record<string, string> = {
  equals: "=",
  not_equals: "≠",
  contains: "contains",
  not_contains: "doesn't contain",
  greater_than: ">",
  less_than: "<",
  is_empty: "is empty",
  is_not_empty: "is not empty",
};

/** One line describing what a configured node will do. */
export function summarize(node: Pick<NodeDefinition, "type" | "config">): string {
  const c = node.config as Record<string, unknown>;
  switch (node.type) {
    case "trigger.manual":
      return "Runs when you start it";
    case "trigger.schedule":
      return `Every ${c.every ?? 1} ${String(c.unit ?? "hours").replace(/s$/, Number(c.every) === 1 ? "" : "s")}`;
    case "trigger.webhook":
      return "Runs on incoming HTTP POST";
    case "action.http_request": {
      const url = String(c.url ?? "");
      if (!url) return "URL not set";
      try {
        const parsed = new URL(url.replace(/\{\{.*?\}\}/g, "x"));
        return `${c.method ?? "GET"} ${parsed.host}${parsed.pathname === "/" ? "" : parsed.pathname}`;
      } catch {
        return `${c.method ?? "GET"} ${url}`;
      }
    }
    case "action.transform": {
      const fields = (c.fields as { key: string }[] | undefined) ?? [];
      return fields.length ? `Builds ${fields.map((f) => f.key).join(", ")}` : "No fields yet";
    }
    case "action.email": {
      const to = (c.to as string[] | undefined) ?? [];
      return to.length ? `To ${to.join(", ")}` : "Recipients not set";
    }
    case "action.slack":
      return c.text ? String(c.text).slice(0, 60) : "Message not set";
    case "condition.if":
      return c.left
        ? `${String(c.left).replace(/\{\{\s*|\s*\}\}/g, "")} ${OPERATOR_LABEL[String(c.operator)] ?? ""} ${
            ["is_empty", "is_not_empty"].includes(String(c.operator)) ? "" : String(c.right ?? "")
          }`.trim()
        : "Condition not set";
    default:
      return "";
  }
}
