# Economic Time Analysis

This directory contains headless Monte Carlo analysis for the
production-to-clearance cycle. It is not gameplay code. The simulator uses the
authoritative TypeScript server rules directly, then varies behavioral/economic
friction parameters around those rules.

Run from the repo root:

```bash
npm run analyze:economics
```

To recreate the filtered presentation figures and report from the existing
latest summary CSV without rerunning the Monte Carlo:

```bash
npm run analyze:economics:render
```

For a prose introduction to the game and the analysis discussion topics, see
[`ARTICLE.md`](ARTICLE.md).

Useful options:

```bash
npm run analyze:economics -- --runs=40 --levels=0,0.1,0.2,0.4,0.6,0.8
npm run analyze:economics -- --factors=hoarding,last_ingredient --runs=60
```

Outputs are written to `analysis/economic-time/outputs/latest/`:

- `simulation_runs.csv`: one row per Monte Carlo run.
- `summary_by_factor.csv`: chart-ready quantiles and means by factor and x.
- `turn_timeline.csv`: per-event state snapshots for later animation.
- `figures/time_to_success.svg`: median time to clearance.
- `figures/production_vs_settlement.svg`: mean production and settlement
  components of the production-to-clearance cycle.
- `figures/success_rate.svg`: clearance rate under each scenario.

The main y-axis is time to clearance: turns from start until all products are
produced and all obligations are cleared back to the starting settlement
condition. The script measures clearance at the first eating event, then
continues through eating to verify the run reaches `complete`; consumption
turns are not counted as part of time to clearance.
