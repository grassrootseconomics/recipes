import { spawn } from "node:child_process";
import { mkdir, readFile, writeFile } from "node:fs/promises";
import path from "node:path";
import { fileURLToPath } from "node:url";

type DisplayFactorKey = "last_ingredient" | "basket_thinness";

interface DisplayFactor {
  key: DisplayFactorKey;
  label: string;
  color: string;
  description: string;
  parameter: string;
}

interface RenderOptions {
  outputDir: string;
  summaryPath: string;
  maxX: number;
  factors: DisplayFactorKey[];
}

interface RawSummaryRow {
  factor: string;
  factorLabel: string;
  x: number;
  runs: number;
  successes: number;
  successRate: number;
  medianSuccessTurns: number;
  p25SuccessTurns: number;
  p75SuccessTurns: number;
  meanProductionTurns: number;
  meanSettlementTurns: number;
  meanInteractions: number;
  meanMaxHoardingIndex: number;
  meanScarcityEvents: number;
}

interface SummaryRow extends RawSummaryRow {
  factor: DisplayFactorKey;
  factorLabel: string;
}

interface LineChartPoint {
  x: number;
  y: number;
  low?: number;
  high?: number;
}

interface LineChartSeries {
  label: string;
  color: string;
  points: LineChartPoint[];
}

const DISPLAY_FACTORS: DisplayFactor[] = [
  {
    key: "last_ingredient",
    label: "Scarcity Hoarding",
    color: "#ca8a04",
    description:
      "Players withhold scarce own vouchers when another player requests them, when a basket copy is low-count, or when settlement would move a scarce promise card back toward clearance.",
    parameter: "scarce-voucher refusal probability = x; low-stock threshold = 1 + ceil(5 * x)"
  },
  {
    key: "basket_thinness",
    label: "Common Basket thinness",
    color: "#059669",
    description:
      "Players skip otherwise useful Common Basket swaps during production or settlement, forcing slower bilateral coordination.",
    parameter: "useful production/settlement basket-swap skip probability = x"
  }
];

const DISPLAY_FACTOR_BY_KEY = Object.fromEntries(DISPLAY_FACTORS.map((factor) => [factor.key, factor])) as Record<
  DisplayFactorKey,
  DisplayFactor
>;

const DEFAULT_MAX_X = 0.65;
const REPO_ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..", "..");
const EPSILON = 0.0000001;
const PLAYER_TURNS_PER_CYCLE = 8;

function parseOptions(args: string[]): RenderOptions {
  const getValue = (name: string, fallback: string) => {
    const prefix = `--${name}=`;
    return args.find((arg) => arg.startsWith(prefix))?.slice(prefix.length) ?? fallback;
  };
  const outputDir = path.resolve(REPO_ROOT, getValue("out", process.env.ECON_OUT ?? "analysis/economic-time/outputs/latest"));
  const summaryPath = path.resolve(outputDir, getValue("summary", process.env.ECON_SUMMARY ?? "summary_by_factor.csv"));
  const maxX = Number.parseFloat(getValue("max-x", process.env.ECON_RENDER_MAX_X ?? String(DEFAULT_MAX_X)));
  if (!Number.isFinite(maxX) || maxX < 0 || maxX > 1) {
    throw new Error("--max-x must be a number from 0 to 1.");
  }
  const factors = getValue("factors", process.env.ECON_RENDER_FACTORS ?? DISPLAY_FACTORS.map((factor) => factor.key).join(","))
    .split(",")
    .map((factor) => factor.trim())
    .filter(Boolean);
  if (factors.length === 0) {
    throw new Error("--factors must include at least one display factor.");
  }
  for (const factor of factors) {
    if (!isDisplayFactorKey(factor)) {
      throw new Error(`Unknown display factor '${factor}'. Expected one of: ${DISPLAY_FACTORS.map((item) => item.key).join(", ")}.`);
    }
  }
  return {
    outputDir,
    summaryPath,
    maxX,
    factors: factors as DisplayFactorKey[]
  };
}

function isDisplayFactorKey(value: string): value is DisplayFactorKey {
  return value === "last_ingredient" || value === "basket_thinness";
}

async function main(): Promise<void> {
  const options = parseOptions(process.argv.slice(2));
  const rawRows = await readSummaryRows(options.summaryPath);
  const rows = filterRows(rawRows, options);
  if (rows.length === 0) {
    throw new Error(`No display rows found in ${options.summaryPath}.`);
  }

  const figuresDir = path.join(options.outputDir, "figures");
  await mkdir(figuresDir, { recursive: true });
  const svgFiles = [
    { name: "time_to_success", content: renderTimeToClearanceSvg(rows, options) },
    { name: "production_vs_settlement", content: renderProductionSettlementSvg(rows, options) },
    { name: "success_rate", content: renderSuccessRateSvg(rows, options) }
  ];

  for (const svg of svgFiles) {
    const svgPath = path.join(figuresDir, `${svg.name}.svg`);
    await writeFile(svgPath, svg.content, "utf8");
    await convertSvgToPng(svgPath, path.join(figuresDir, `${svg.name}.png`));
  }
  await writeFile(path.join(options.outputDir, "REPORT.md"), renderReport(rows, options), "utf8");

  console.log(
    JSON.stringify(
      {
        ok: true,
        outputDir: options.outputDir,
        summaryCsv: options.summaryPath,
        displayRows: rows.length,
        displayFactors: options.factors.map((factor) => DISPLAY_FACTOR_BY_KEY[factor].label),
        maxX: options.maxX,
        files: [
          "REPORT.md",
          "figures/time_to_success.svg",
          "figures/time_to_success.png",
          "figures/production_vs_settlement.svg",
          "figures/production_vs_settlement.png",
          "figures/success_rate.svg",
          "figures/success_rate.png"
        ]
      },
      null,
      2
    )
  );
}

async function readSummaryRows(summaryPath: string): Promise<RawSummaryRow[]> {
  const text = await readFile(summaryPath, "utf8");
  const [header, ...records] = parseCsv(text);
  if (!header) {
    throw new Error(`${summaryPath} is empty.`);
  }
  const indexByColumn = new Map(header.map((column, index) => [column, index]));
  const requiredColumns: Array<keyof RawSummaryRow> = [
    "factor",
    "factorLabel",
    "x",
    "runs",
    "successes",
    "successRate",
    "medianSuccessTurns",
    "p25SuccessTurns",
    "p75SuccessTurns",
    "meanProductionTurns",
    "meanSettlementTurns",
    "meanInteractions",
    "meanMaxHoardingIndex",
    "meanScarcityEvents"
  ];
  for (const column of requiredColumns) {
    if (!indexByColumn.has(column)) {
      throw new Error(`${summaryPath} is missing required column '${column}'.`);
    }
  }
  return records
    .filter((record) => record.some((value) => value !== ""))
    .map((record) => {
      const value = (column: keyof RawSummaryRow) => record[indexByColumn.get(column) as number] ?? "";
      return {
        factor: value("factor"),
        factorLabel: value("factorLabel"),
        x: parseNumber(value("x"), "x"),
        runs: parseNumber(value("runs"), "runs"),
        successes: parseNumber(value("successes"), "successes"),
        successRate: parseNumber(value("successRate"), "successRate"),
        medianSuccessTurns: parseNumber(value("medianSuccessTurns"), "medianSuccessTurns"),
        p25SuccessTurns: parseNumber(value("p25SuccessTurns"), "p25SuccessTurns"),
        p75SuccessTurns: parseNumber(value("p75SuccessTurns"), "p75SuccessTurns"),
        meanProductionTurns: parseNumber(value("meanProductionTurns"), "meanProductionTurns"),
        meanSettlementTurns: parseNumber(value("meanSettlementTurns"), "meanSettlementTurns"),
        meanInteractions: parseNumber(value("meanInteractions"), "meanInteractions"),
        meanMaxHoardingIndex: parseNumber(value("meanMaxHoardingIndex"), "meanMaxHoardingIndex"),
        meanScarcityEvents: parseNumber(value("meanScarcityEvents"), "meanScarcityEvents")
      };
    });
}

function parseCsv(text: string): string[][] {
  const rows: string[][] = [];
  let row: string[] = [];
  let field = "";
  let inQuotes = false;

  for (let index = 0; index < text.length; index += 1) {
    const char = text[index] as string;
    if (inQuotes) {
      if (char === '"' && text[index + 1] === '"') {
        field += '"';
        index += 1;
      } else if (char === '"') {
        inQuotes = false;
      } else {
        field += char;
      }
      continue;
    }

    if (char === '"') {
      inQuotes = true;
    } else if (char === ",") {
      row.push(field);
      field = "";
    } else if (char === "\n") {
      row.push(field);
      rows.push(row);
      row = [];
      field = "";
    } else if (char !== "\r") {
      field += char;
    }
  }

  if (field !== "" || row.length > 0) {
    row.push(field);
    rows.push(row);
  }
  return rows;
}

function parseNumber(value: string, label: string): number {
  const parsed = Number.parseFloat(value);
  if (!Number.isFinite(parsed)) {
    throw new Error(`Invalid numeric value for ${label}: '${value}'.`);
  }
  return parsed;
}

function filterRows(rawRows: RawSummaryRow[], options: RenderOptions): SummaryRow[] {
  const factorSet = new Set<string>(options.factors);
  return rawRows
    .filter((row) => isDisplayFactorKey(row.factor) && factorSet.has(row.factor) && row.x <= options.maxX + EPSILON)
    .map((row) => ({
      ...row,
      factor: row.factor as DisplayFactorKey,
      factorLabel: DISPLAY_FACTOR_BY_KEY[row.factor as DisplayFactorKey].label
    }))
    .sort((left, right) => factorOrder(left.factor) - factorOrder(right.factor) || left.x - right.x);
}

function factorOrder(factor: DisplayFactorKey): number {
  return DISPLAY_FACTORS.findIndex((item) => item.key === factor);
}

function renderReport(rows: SummaryRow[], options: RenderOptions): string {
  const factors = displayFactors(options);
  const xValues = uniqueXValues(rows);
  const xMin = Math.min(...xValues);
  const xMax = Math.max(...xValues);
  const finalRows = rows.filter((row) => approximatelyEqual(row.x, xMax));
  const sampled = (mapper: (x: number) => number | string) => xValues.map((level) => mapper(level)).join(", ");
  const resultLines = finalRows
    .map(
      (row) =>
        `- ${row.factorLabel}: median time to clearance ${round(row.medianSuccessTurns)} turns, clearance rate ${round(
          row.successRate * 100
        )}%, mean production ${round(row.meanProductionTurns)}, mean settlement ${round(row.meanSettlementTurns)}.`
    )
    .join("\n");

  return `# Economic Time To Clearance Monte Carlo

This report and the figures in \`figures/\` are a filtered presentation view generated by \`npm run analyze:economics:render\`. The underlying CSV files still contain the complete Monte Carlo scenario grid for later analysis and animation.

The primary term is **production-to-clearance cycle**. The metric is **time to clearance**: turns from start until all products are produced and all obligations are cleared back to the starting settlement condition. The simulator measures clearance at the first eating event, then continues through eating to verify that the table reaches \`complete\`; consumption turns are not counted as part of time to clearance.

## Displayed Scenario Definitions

Scenario intensity \`x\` is the independent variable on the charts. This presentation displays \`${xValues
    .map(formatParameter)
    .join(", ")}\`, so the displayed x range is \`${formatParameter(xMin)}\` to \`${formatParameter(xMax)}\`. Each displayed scenario changes one friction parameter at a time while the other friction parameters remain at zero. Each can affect both production and settlement in the production-to-clearance cycle.

${factors.map((factor) => `- **${factor.label}:** ${factor.description}`).join("\n")}

## Parameter Values Used

| Scenario | Parameter changed by \`x\` | Values at displayed \`x\` levels |
| --- | --- | --- |
| Scarcity Hoarding | ${DISPLAY_FACTOR_BY_KEY.last_ingredient.parameter} | probability: \`${sampled(formatParameter)}\`; threshold: \`${sampled((x) => 1 + Math.ceil(5 * x))}\` |
| Common Basket thinness | ${DISPLAY_FACTOR_BY_KEY.basket_thinness.parameter} | \`${sampled(formatParameter)}\` |

## Highest Displayed x Results

${resultLines}

## Files

- \`simulation_runs.csv\`: preserved full-grid run data.
- \`summary_by_factor.csv\`: preserved full-grid factor/x quantiles and means.
- \`turn_timeline.csv\`: preserved full-grid per-event state snapshots for later animation.
- \`figures/time_to_success.svg\`: filtered median time to settlement, in 8-player-turn cycles.
- \`figures/production_vs_settlement.svg\`: filtered mean production and settlement components of the production-to-clearance cycle.
- \`figures/success_rate.svg\`: filtered clearance rate by x.
`;
}

function renderTimeToClearanceSvg(rows: SummaryRow[], options: RenderOptions): string {
  return renderLineChart({
    title: "Time To Settlement",
    subtitle: "Median 8-player-turn cycles in the production-to-clearance cycle; bands show p25-p75 across cleared runs",
    yLabel: "cycles (8 player turns)",
    xMinOverride: 0.1,
    maxX: options.maxX,
    yMinOverride: 150 / PLAYER_TURNS_PER_CYCLE,
    yMaxOverride: 600 / PLAYER_TURNS_PER_CYCLE,
    yFormat: formatParameter,
    series: displayFactors(options).map((factor) => ({
      label: factor.label,
      color: factor.color,
      points: rows
        .filter((row) => row.factor === factor.key)
        .map((row) => ({
          x: row.x,
          y: row.medianSuccessTurns / PLAYER_TURNS_PER_CYCLE,
          low: row.p25SuccessTurns / PLAYER_TURNS_PER_CYCLE,
          high: row.p75SuccessTurns / PLAYER_TURNS_PER_CYCLE
        }))
    }))
  });
}

function renderSuccessRateSvg(rows: SummaryRow[], options: RenderOptions): string {
  return renderLineChart({
    title: "Clearance Rate Under Economic Friction",
    subtitle: "Share of runs that cleared all products and obligations within the turn cap",
    yLabel: "clearance rate",
    maxX: options.maxX,
    yMaxOverride: 1,
    yFormat: (value) => `${Math.round(value * 100)}%`,
    series: displayFactors(options).map((factor) => ({
      label: factor.label,
      color: factor.color,
      points: rows.filter((row) => row.factor === factor.key).map((row) => ({ x: row.x, y: row.successRate }))
    }))
  });
}

function renderProductionSettlementSvg(rows: SummaryRow[], options: RenderOptions): string {
  const width = 1200;
  const height = 760;
  const factors = displayFactors(options);
  const margin = { left: 76, right: 190, top: 82, bottom: 88 };
  const plotWidth = width - margin.left - margin.right;
  const plotHeight = height - margin.top - margin.bottom;
  const maxY = niceMax(Math.max(...rows.map((row) => row.meanProductionTurns + row.meanSettlementTurns), 1));
  const xValues = uniqueXValues(rows);
  const groupWidth = plotWidth / factors.length;
  const barGap = 5;
  const barWidth = Math.max(8, (groupWidth - 42) / xValues.length - barGap);
  const scaleY = (value: number) => margin.top + plotHeight - (value / maxY) * plotHeight;
  const bars: string[] = [];

  factors.forEach((factor, factorIndex) => {
    const factorRows = rows.filter((row) => row.factor === factor.key).sort((left, right) => left.x - right.x);
    const groupX = margin.left + factorIndex * groupWidth + 20;
    factorRows.forEach((row, xIndex) => {
      const x = groupX + xIndex * (barWidth + barGap);
      const showXLabel = xIndex % 2 === 0 || xIndex === factorRows.length - 1;
      const productionY = scaleY(row.meanProductionTurns);
      const settlementY = scaleY(row.meanProductionTurns + row.meanSettlementTurns);
      const totalHeight = margin.top + plotHeight - settlementY;
      const productionHeight = margin.top + plotHeight - productionY;
      const settlementHeight = Math.max(0, productionY - settlementY);
      bars.push(
        `<rect x="${roundSvg(x)}" y="${roundSvg(settlementY)}" width="${roundSvg(barWidth)}" height="${roundSvg(totalHeight)}" fill="#d8dee9"/>`,
        `<rect x="${roundSvg(x)}" y="${roundSvg(productionY)}" width="${roundSvg(barWidth)}" height="${roundSvg(productionHeight)}" fill="${factor.color}"/>`,
        `<rect x="${roundSvg(x)}" y="${roundSvg(settlementY)}" width="${roundSvg(barWidth)}" height="${roundSvg(settlementHeight)}" fill="#111827" opacity="0.82"/>`,
        showXLabel
          ? `<text x="${roundSvg(x + barWidth / 2)}" y="${height - 50}" text-anchor="middle" font-size="10" fill="#4b5563">${formatParameter(
              row.x
            )}</text>`
          : ""
      );
    });
    bars.push(
      `<text x="${roundSvg(groupX + groupWidth / 2 - 18)}" y="${height - 22}" text-anchor="middle" font-size="13" fill="#111827">${escapeXml(
        factor.label
      )}</text>`
    );
  });

  return svgFrame(
    width,
    height,
    [
      chartTitle("Production-To-Clearance Cycle Components", "Mean player turns by displayed scenario and x; dark segment is settlement"),
      ...axisGrid(width, height, margin, 0, maxY, (value) => String(Math.round(value)), 0, options.maxX),
      `<text x="${roundSvg(margin.left + plotWidth / 2)}" y="${height - 8}" text-anchor="middle" font-size="13" fill="#374151">x: scenario intensity, grouped by scenario</text>`,
      `<text x="20" y="${roundSvg(margin.top + plotHeight / 2)}" transform="rotate(-90 20 ${roundSvg(
        margin.top + plotHeight / 2
      )})" text-anchor="middle" font-size="13" fill="#374151">mean player turns</text>`,
      ...bars,
      `<rect x="${width - 168}" y="126" width="14" height="14" fill="#111827" opacity="0.82"/><text x="${width - 146}" y="138" font-size="13" fill="#111827">settlement turns</text>`,
      `${factors
        .map((factor, index) => `<rect x="${width - 168 + index * 8}" y="150" width="8" height="14" fill="${factor.color}"/>`)
        .join("")}<text x="${width - 146}" y="162" font-size="13" fill="#111827">production turns</text>`
    ].join("\n")
  );
}

function renderLineChart(config: {
  title: string;
  subtitle: string;
  yLabel: string;
  xMinOverride?: number;
  maxX: number;
  yMinOverride?: number;
  yMaxOverride?: number;
  yFormat?: (value: number) => string;
  series: LineChartSeries[];
}): string {
  const width = 1200;
  const height = 760;
  const margin = { left: 76, right: 250, top: 88, bottom: 74 };
  const plotWidth = width - margin.left - margin.right;
  const plotHeight = height - margin.top - margin.bottom;
  const minX = config.xMinOverride ?? 0;
  if (config.maxX <= minX) {
    throw new Error(`Invalid x-axis range for chart '${config.title}': ${minX} to ${config.maxX}.`);
  }
  const series = config.series.map((item) => ({
    ...item,
    points: item.points.filter((point) => point.x >= minX - EPSILON && point.x <= config.maxX + EPSILON)
  }));
  const allPoints = series.flatMap((item) => item.points);
  if (allPoints.length === 0) {
    throw new Error(`No points available for chart '${config.title}'.`);
  }
  const maxY = config.yMaxOverride ?? niceMax(Math.max(...allPoints.flatMap((point) => [point.y, point.high ?? point.y]), 1));
  const minY = config.yMinOverride ?? 0;
  if (maxY <= minY) {
    throw new Error(`Invalid y-axis range for chart '${config.title}': ${minY} to ${maxY}.`);
  }
  const yFormat = config.yFormat ?? ((value: number) => String(Math.round(value)));
  const scaleX = (value: number) => margin.left + ((value - minX) / (config.maxX - minX)) * plotWidth;
  const scaleY = (value: number) => {
    const bounded = Math.min(maxY, Math.max(minY, value));
    return margin.top + plotHeight - ((bounded - minY) / (maxY - minY)) * plotHeight;
  };
  const parts: string[] = [
    chartTitle(config.title, config.subtitle),
    ...axisGrid(width, height, margin, minY, maxY, yFormat, minX, config.maxX)
  ];

  for (const item of series) {
    const points = [...item.points].sort((left, right) => left.x - right.x);
    const bandPoints = points.filter((point) => point.low !== undefined && point.high !== undefined);
    if (bandPoints.length > 0) {
      const upper = bandPoints.map((point) => `${roundSvg(scaleX(point.x))},${roundSvg(scaleY(point.high as number))}`).join(" ");
      const lower = [...bandPoints]
        .reverse()
        .map((point) => `${roundSvg(scaleX(point.x))},${roundSvg(scaleY(point.low as number))}`)
        .join(" ");
      parts.push(`<polygon points="${upper} ${lower}" fill="${item.color}" opacity="0.14"/>`);
    }
    const path = points
      .map((point, index) => `${index === 0 ? "M" : "L"} ${roundSvg(scaleX(point.x))} ${roundSvg(scaleY(point.y))}`)
      .join(" ");
    parts.push(`<path d="${path}" fill="none" stroke="${item.color}" stroke-width="3" stroke-linejoin="round"/>`);
    for (const point of points) {
      parts.push(
        `<circle cx="${roundSvg(scaleX(point.x))}" cy="${roundSvg(scaleY(point.y))}" r="4.5" fill="${item.color}" stroke="#ffffff" stroke-width="1.5"/>`
      );
    }
  }

  parts.push(
    `<text x="${roundSvg(margin.left + plotWidth / 2)}" y="${height - 20}" text-anchor="middle" font-size="13" fill="#374151">x: scenario intensity</text>`,
    `<text x="20" y="${roundSvg(margin.top + plotHeight / 2)}" transform="rotate(-90 20 ${roundSvg(
      margin.top + plotHeight / 2
    )})" text-anchor="middle" font-size="13" fill="#374151">${escapeXml(config.yLabel)}</text>`,
    ...legend(series, width - margin.right + 34, margin.top + 4)
  );
  return svgFrame(width, height, parts.join("\n"));
}

function axisGrid(
  width: number,
  height: number,
  margin: { left: number; right: number; top: number; bottom: number },
  minY: number,
  maxY: number,
  yFormat: (value: number) => string,
  minX: number,
  maxX: number
): string[] {
  const plotWidth = width - margin.left - margin.right;
  const plotHeight = height - margin.top - margin.bottom;
  const parts: string[] = [
    `<rect x="${margin.left}" y="${margin.top}" width="${plotWidth}" height="${plotHeight}" fill="#ffffff"/>`,
    `<line x1="${margin.left}" y1="${margin.top + plotHeight}" x2="${margin.left + plotWidth}" y2="${margin.top + plotHeight}" stroke="#111827" stroke-width="1"/>`,
    `<line x1="${margin.left}" y1="${margin.top}" x2="${margin.left}" y2="${margin.top + plotHeight}" stroke="#111827" stroke-width="1"/>`
  ];
  for (let index = 0; index <= 5; index += 1) {
    const value = minY + ((maxY - minY) / 5) * index;
    const y = margin.top + plotHeight - ((value - minY) / (maxY - minY)) * plotHeight;
    parts.push(
      `<line x1="${margin.left}" y1="${roundSvg(y)}" x2="${margin.left + plotWidth}" y2="${roundSvg(y)}" stroke="#e5e7eb" stroke-width="1"/>`,
      `<text x="${margin.left - 10}" y="${roundSvg(y + 4)}" text-anchor="end" font-size="12" fill="#4b5563">${escapeXml(yFormat(value))}</text>`
    );
  }
  for (const value of xTicks(minX, maxX)) {
    const x = margin.left + ((value - minX) / (maxX - minX)) * plotWidth;
    parts.push(
      `<line x1="${roundSvg(x)}" y1="${margin.top}" x2="${roundSvg(x)}" y2="${margin.top + plotHeight}" stroke="#f3f4f6" stroke-width="1"/>`,
      `<text x="${roundSvg(x)}" y="${margin.top + plotHeight + 22}" text-anchor="middle" font-size="12" fill="#4b5563">${formatParameter(value)}</text>`
    );
  }
  return parts;
}

function xTicks(minX: number, maxX: number): number[] {
  const ticks = [0, 0.1, 0.15, 0.3, 0.45, 0.6].filter((value) => value >= minX - EPSILON && value <= maxX + EPSILON);
  if (!ticks.some((value) => approximatelyEqual(value, minX))) {
    ticks.unshift(minX);
  }
  if (!ticks.some((value) => approximatelyEqual(value, maxX))) {
    ticks.push(maxX);
  }
  return [...new Set(ticks)].sort((left, right) => left - right);
}

function chartTitle(title: string, subtitle: string): string {
  return `<text x="76" y="38" font-size="25" font-weight="700" fill="#111827">${escapeXml(title)}</text>
<text x="76" y="62" font-size="14" fill="#4b5563">${escapeXml(subtitle)}</text>`;
}

function legend(series: LineChartSeries[], x: number, y: number): string[] {
  return series.flatMap((item, index) => {
    const itemY = y + index * 28;
    return [
      `<line x1="${x}" y1="${itemY}" x2="${x + 22}" y2="${itemY}" stroke="${item.color}" stroke-width="4"/>`,
      `<circle cx="${x + 11}" cy="${itemY}" r="4" fill="${item.color}" stroke="#ffffff" stroke-width="1"/>`,
      `<text x="${x + 32}" y="${itemY + 5}" font-size="13" fill="#111827">${escapeXml(item.label)}</text>`
    ];
  });
}

function svgFrame(width: number, height: number, body: string): string {
  return `<svg xmlns="http://www.w3.org/2000/svg" width="${width}" height="${height}" viewBox="0 0 ${width} ${height}" role="img">
<rect width="${width}" height="${height}" fill="#f8fafc"/>
${body}
</svg>
`;
}

function displayFactors(options: RenderOptions): DisplayFactor[] {
  return options.factors.map((factor) => DISPLAY_FACTOR_BY_KEY[factor]);
}

function uniqueXValues(rows: SummaryRow[]): number[] {
  return [...new Set(rows.map((row) => row.x))].sort((left, right) => left - right);
}

function round(value: number): number {
  return Math.round(value * 10) / 10;
}

function roundSvg(value: number): string {
  return value.toFixed(1);
}

function formatParameter(value: number): string {
  return value.toFixed(4).replace(/0+$/u, "").replace(/\.$/u, "");
}

function niceMax(value: number): number {
  const magnitude = 10 ** Math.floor(Math.log10(value));
  const normalized = value / magnitude;
  const nice = normalized <= 1 ? 1 : normalized <= 2 ? 2 : normalized <= 5 ? 5 : 10;
  return nice * magnitude;
}

function approximatelyEqual(left: number, right: number): boolean {
  return Math.abs(left - right) <= EPSILON;
}

function escapeXml(value: string): string {
  return value.replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;").replace(/"/g, "&quot;");
}

async function convertSvgToPng(svgPath: string, pngPath: string): Promise<void> {
  await new Promise<void>((resolve, reject) => {
    const child = spawn("convert", [svgPath, pngPath], { stdio: ["ignore", "ignore", "pipe"] });
    let stderr = "";
    child.stderr.setEncoding("utf8");
    child.stderr.on("data", (chunk: string) => {
      stderr += chunk;
    });
    child.on("error", reject);
    child.on("close", (code) => {
      if (code === 0) {
        resolve();
      } else {
        reject(new Error(`convert failed for ${svgPath} with exit code ${code}: ${stderr}`));
      }
    });
  });
}

void main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
