import * as React from "react";
import * as RechartsPrimitive from "recharts";
import { cn } from "@/lib/utils";

const FORMATTING_STYLES: Record<string, any> = {
  scientific: "scientific", decimal: "decimal", currency: "currency", percent: "percent",
};

const ChartContainer = React.forwardRef<HTMLDivElement, React.ComponentProps<"div"> & {
  config: Record<string, { label?: string; color?: string; icon?: React.ComponentType<{ className?: string }>; formatter?: (value: number | string) => string }>;
  accessibilityLayer?: boolean;
}>(({ className, children, config }, ref) => {
  void config;
  return (
    <div ref={ref} className={cn("flex aspect-video justify-center text-xs [&_.recharts-cartesian-axis-tick_text]:fill-muted-foreground [&_.recharts-line_path]:stroke-card [&_.recharts-bar-rectangle_path]:hover:fill-card", className)}>
      {children}
    </div>
  );
});
ChartContainer.displayName = "Chart";

const ChartTooltip = RechartsPrimitive.Tooltip;

const ChartLegendContent = ({ payload }: any) => (
  <ul className="flex flex-wrap items-center gap-4 text-sm">
    {(payload ?? []).map((item: any) => (
      <li key={item.dataKey} className="flex items-center gap-2">
        <span style={{ background: item.color }} className="h-2 w-2 rounded-full" />{item.name}
      </li>
    ))}
  </ul>
);

const ChartLegend = RechartsPrimitive.Legend;

function ChartTooltipContent(props: any) {
  const { label, payload } = props;
  if (!payload?.length) return null;
  return (
    <div className={cn("rounded-lg border bg-background p-2 shadow-sm")}>
      {label != null && <div className="mb-1 font-medium">{String(label)}</div>}
      <ul className="grid gap-1">
        {payload.map((p: any, i: number) => (
          <li key={i} className="flex items-center gap-2 text-xs">
            <span style={{ background: p.color }} className="h-2 w-2 rounded-full" />
            <span>{p.name}</span><b className="ml-auto num">{typeof p.value === "number" ? p.value.toLocaleString("id-ID") : String(p.value)}</b>
          </li>
        ))}
      </ul>
    </div>
  );
}

export { ChartContainer, ChartTooltip, ChartTooltipContent, ChartLegend, ChartLegendContent, FORMATTING_STYLES };
