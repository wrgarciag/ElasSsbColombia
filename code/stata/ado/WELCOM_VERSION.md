# Pinned Stata dependencies

Project-local copy of the user-written Stata packages the pipeline needs. `code/stata/01_setup.do` points Stata's `PLUS` directory here and removes the machine-wide ado directories from the search path, so no other copy can be picked up. Nothing in this folder is modified, and nothing is installed or updated by the pipeline.

| Package | Version | Source recorded by Stata | Copied from | Files |
|---|---|---|---|---|
| WELCOM (`welcom_p1`–`welcom_p4`) | 3.60, 13 October 2021 (`_/_welcom_vers.ado`) | `http://dasp.ecn.ulaval.ca/welcom/Installer36`, installed 8 May 2023 | `c:/ado/plus` on the analysis machine, 2026-11-17 | see `ado_manifest.csv` |
| estout (`st0085_2`: `eststo`, `esttab`, `estout`, `estadd`, `estpost`) | Stata Journal 14-2 | `http://www.stata-journal.com/software/sj14-2`, installed 31 Oct 2022 | same | see `ado_manifest.csv` |

- `ado_manifest.csv` lists every file with its SHA-256 checksum.
- The estimator is `d/duvm.ado` (WELCOM's Deaton unit-value model). `duvm` calls `eststo`/`esttab` from estout.
- The Stata package record also lists WELCOM 2.30 (March 2019), installed on 5 March 2023 and overwritten by 3.60. The manuscript under revision reports version 2.1, which is not available. All results of this project are tied to 3.60.
- The same source is published by the World Bank at `https://github.com/worldbank/welcom-tool` (version 3.60). The original distribution URLs (`dasp.ecn.ulaval.ca/welcom/...`) no longer resolve (checked 2026-11-17).
- WELCOM is a World Bank product (Araar, Malásquez, Olivieri, Rodríguez-Castelán). Check its licence terms before redistributing this folder outside the project.
- To update deliberately: replace the files, regenerate `ado_manifest.csv`, record the new version here and in `docs/welcom_method.md`, and rerun the whole pipeline.
