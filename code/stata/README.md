# Stata code

Stata estimates with WELCOM's `duvm` and computes inference. It does not merge survey modules, classify purchases or convert units.

| File | Purpose |
|---|---|
| `00_master.do` | Entry point: `StataMP-64.exe /e do code/stata/00_master.do "<root>" <run_id> <point|boot|inference|all> [worker] [nworkers]` |
| `01_setup.do` | Pins the ado path to `ado/`, defines folders, loads `config/stata_params.do` |
| `10_programs.do` | `elas_prepare`, `elas_validate` (WELCOM input contract), `elas_duvm`, `elas_post` |
| `20_point_estimates.do` | One `duvm` call per model in `config/models.csv`; exports estimates, model metadata, sample identifiers, WELCOM's own bootstrap output |
| `30_bootstrap_worker.do` | External cluster bootstrap around `duvm`; parallel and resumable |
| `40_inference.do` | Standard errors, percentile intervals, covariance matrices, specification differences |
| `ado/` | Pinned WELCOM 3.60 and estout (`WELCOM_VERSION.md`, `ado_manifest.csv`) |

Use `run_pipeline.ps1` to launch the stages; it starts the parallel bootstrap workers and checks the marker files that each stage writes on success.
