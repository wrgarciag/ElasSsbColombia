* Wrapper: runs the UNMODIFIED legacy do-file; only sets path, seed, working dir and log.
version 17
clear all
set more off
cd "C:/Users/wrgar/AppData/Local/Temp/claude/b23658276da87ad8/710aa0c7-f7c9-49cb-997a-5f1cdd64596c/scratchpad/legacy_run/stata"
global path "C:/Users/wrgar/AppData/Local/Temp/claude/b23658276da87ad8/710aa0c7-f7c9-49cb-997a-5f1cdd64596c/scratchpad/legacy_run/out"
set seed 20261117
log using "C:/Users/wrgar/AppData/Local/Temp/claude/b23658276da87ad8/710aa0c7-f7c9-49cb-997a-5f1cdd64596c/scratchpad/legacy_run/stata/duvm_hogar.log", text replace
which duvm
do "C:/Users/wrgar/OneDrive - UW/02Work/Miscellaneous/ssb-colombia/ElasSsbColombia/code/legacy/SSBElasticityPaperRevised_hogar_duvm.do"
