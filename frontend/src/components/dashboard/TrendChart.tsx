"use client";

import { Bar, BarChart, CartesianGrid, ResponsiveContainer, Tooltip, XAxis, YAxis } from "recharts";
import { useState } from "react";
import type { DashboardSummary } from "@/lib/types";

const SERIES = [
  { key: "succeeded", label: "Succeeded", color: "#3dd68c" },
  { key: "failed", label: "Failed", color: "#f2616b" },
  { key: "other", label: "Other", color: "#6b7385" },
] as const;

function dayLabel(iso: string) {
  return new Date(`${iso}T00:00:00`).toLocaleDateString(undefined, { month: "short", day: "numeric" });
}

function ChartTooltip({ active, payload, label }: { active?: boolean; payload?: { dataKey: string; value: number }[]; label?: string }) {
  if (!active || !payload?.length || !label) return null;
  const total = payload.reduce((sum, p) => sum + p.value, 0);
  return (
    <div className="rounded-md border border-line bg-elevated px-3 py-2 text-meta shadow-pop">
      <p className="mb-1 font-medium text-fg">{dayLabel(label)}</p>
      {SERIES.map((s) => {
        const value = payload.find((p) => p.dataKey === s.key)?.value ?? 0;
        return (
          <p key={s.key} className="flex items-center gap-2 text-fg-secondary">
            <span className="h-2 w-2 rounded-sm" style={{ background: s.color }} aria-hidden="true" />
            {s.label}
            <span className="ml-auto pl-4 tabular-nums text-fg">{value}</span>
          </p>
        );
      })}
      <p className="mt-1 border-t border-line-subtle pt-1 text-fg-muted">
        Total <span className="float-right tabular-nums text-fg">{total}</span>
      </p>
    </div>
  );
}

export function TrendChart({ trend }: { trend: DashboardSummary["trend"] }) {
  const [showTable, setShowTable] = useState(false);
  const total = trend.reduce((sum, d) => sum + d.succeeded + d.failed + d.other, 0);
  return (
    <div>
      <div className="mb-3 flex flex-wrap items-center gap-x-4 gap-y-2">
        <ul className="flex flex-wrap gap-x-4 gap-y-1 text-meta text-fg-secondary" aria-label="Legend">
          {SERIES.map((s) => (
            <li key={s.key} className="flex items-center gap-1.5">
              <span className="h-2.5 w-2.5 rounded-sm" style={{ background: s.color }} aria-hidden="true" />
              {s.label}
            </li>
          ))}
        </ul>
        <button
          type="button"
          onClick={() => setShowTable((v) => !v)}
          className="ml-auto text-meta text-fg-muted underline-offset-2 hover:text-fg hover:underline"
          aria-pressed={showTable}
        >
          {showTable ? "Show chart" : "Show as table"}
        </button>
      </div>
      {showTable ? (
        <div className="max-h-[220px] overflow-auto rounded-md border border-line-subtle">
          <table className="w-full text-meta">
            <caption className="sr-only">Executions per day for the last 14 days</caption>
            <thead className="sticky top-0 bg-elevated text-left text-fg-muted">
              <tr>
                <th className="px-3 py-1.5 font-medium">Day</th>
                {SERIES.map((s) => (
                  <th key={s.key} className="px-3 py-1.5 text-right font-medium">
                    {s.label}
                  </th>
                ))}
              </tr>
            </thead>
            <tbody className="divide-y divide-line-subtle">
              {trend.map((d) => (
                <tr key={d.date}>
                  <td className="px-3 py-1.5 text-fg-secondary">{dayLabel(d.date)}</td>
                  {SERIES.map((s) => (
                    <td key={s.key} className="px-3 py-1.5 text-right tabular-nums">
                      {d[s.key]}
                    </td>
                  ))}
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      ) : (
        <div className="relative h-[220px]" role="img" aria-label={`Bar chart of ${total} executions over the last 14 days`}>
          {total === 0 && (
            <p className="absolute inset-0 z-10 flex items-center justify-center text-body text-fg-muted">
              No runs in the last 14 days
            </p>
          )}
          <ResponsiveContainer width="100%" height="100%">
            <BarChart data={trend} margin={{ top: 4, right: 4, bottom: 0, left: -24 }} barCategoryGap="28%">
              <CartesianGrid vertical={false} stroke="#1e2330" />
              <XAxis
                dataKey="date"
                tickFormatter={dayLabel}
                tick={{ fill: "#7d8597", fontSize: 11 }}
                axisLine={{ stroke: "#282e3b" }}
                tickLine={false}
                interval="preserveStartEnd"
                minTickGap={16}
              />
              <YAxis allowDecimals={false} tick={{ fill: "#7d8597", fontSize: 11 }} axisLine={false} tickLine={false} width={48} />
              <Tooltip cursor={{ fill: "rgb(160 168 184 / 0.06)" }} content={<ChartTooltip />} isAnimationActive={false} />
              {SERIES.map((s, i) => (
                <Bar
                  key={s.key}
                  dataKey={s.key}
                  stackId="runs"
                  fill={s.color}
                  stroke="#151923"
                  strokeWidth={2}
                  radius={i === SERIES.length - 1 ? [4, 4, 0, 0] : 0}
                  isAnimationActive={false}
                  maxBarSize={28}
                />
              ))}
            </BarChart>
          </ResponsiveContainer>
        </div>
      )}
    </div>
  );
}
