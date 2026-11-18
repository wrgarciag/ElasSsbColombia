*********************
******************
*
* Bloque3a. Estimacion del AIDS
*
******************
*********************

clear all
macro drop _all
set more off


*global path "C:\Users\William\OneDrive - ICESI\2Publicaciones\SSBElasticity\Data\Output"
global path "C:\Users\William\Documents\SSBElasticity\Data\Output"


use "$path\DataEstimates.dta",clear

tab xeduc,gen(xeduc_)
* Summary
summarize xsexo xedad xrural xtamanioh xuniper xninios xeduc_1 xeduc_2 xeduc_3 xeduc_4 IT ITPC IT ITPC 
summarize Gasto_SSB Gasto0_SSB Gasto1_SSB

** QUAIDS libreria
egen totalexp = rowtotal(Gasto_HotDrinks Gasto_MilkDerivatives Gasto_SSB Gasto_Water Gasto_Beer Gasto_Spirits Gasto_Wine)

local expe "Gasto_HotDrinks Gasto_MilkDerivatives Gasto_SSB Gasto_Water Gasto_Beer Gasto_Spirits Gasto_Wine"
 
foreach i of local expe {
        replace `i' =0 if mi(`i')
}

  
gen w1= Gasto_SSB/totalexp
gen w2= Gasto_HotDrinks/totalexp
gen w3= Gasto_MilkDerivatives/totalexp
gen w4= Gasto_Water/totalexp

gen w5= Gasto_Beer/totalexp
gen w6= Gasto_Spirits/totalexp
gen w7= Gasto_Wine/totalexp

rename Precio_SSB p1
rename Precio_HotDrinks p2
rename Precio_MilkDerivatives p3
rename Precio_Water p4

rename Precio_Beer p5
rename Precio_Spirits p6
rename Precio_Wine p7

order p1 p2 p3 p4 p5 p6 p7

* dummies de consumo
gen di1= (Gasto_SSB>0)
gen di2= (Gasto_HotDrinks>0)
gen di3= (Gasto_MilkDerivatives>0)
gen di4= (Gasto_Water>0)

gen di5= (Gasto_Beer>0)
gen di6= (Gasto_Spirits>0)
gen di7= (Gasto_Wine>0)

rename xsexo x1
rename xedad x2
rename xrural x3
rename xtamanioh x4
rename xuniper x5
rename xninios x6
rename xeduc_1 x7
rename xeduc_2 x8
rename xeduc_3 x9
rename xeduc_4 x10


* Logaritmos
* logaritmos de precios

forvalues i=1/7 {
gen lnp`i'=log(p`i')
}

*logaritmo gasto
gen lnexp=log(totalexp)


****************************
* Probit regressions
****************************

global X x1 x2  x4 x5 x6 x7 x8 x9
global P lnp1 lnp2 lnp3 lnp4 lnp5 lnp6 lnp7

* Se excluye el sexo para no sobreidentificar

*genera variables auxiliares

set more off
forvalues i=1/7 {
probit di`i' $X
predict f_d`i', xb
label var f_d`i' "Valor ajustado para el bien `i'"
generate pdf`i'=normalden(f_d`i')
generate cdf`i'=normal(f_d`i')
generate mills`i'=(di`i'*(pdf`i'/cdf`i'))+ ((1-di`i')*(pdf`i'/1-cdf`i'))
}


forvalues i=1/7 {
rename mills`i' xm`i'
}

save "$path\DataPaperTotal.dta",replace
set more on

set more off
aidsills w1-w7, prices(p1-p7) expenditure(totalexp) intercept(x1 x2 x4 x5 x6 x7 x8 x9 xm1 xm2 xm3 xm4 xm5 xm6 xm7) symmetry alpha_0(10)
aidsills_elas
set more on


set more off
aidsills w1-w7, prices(p1-p7) expenditure(totalexp) intercept(x1 x2 x4 x5 x6 x7 x8 x9) symmetry alpha_0(10)
aidsills_elas
set more on


*********************
******************
*
* Bloque3a. Estimacion del AIDS Gasto hogares unicamente
*
******************
*********************

clear all
macro drop _all
set more off


*global path "C:\Users\William\OneDrive - ICESI\2Publicaciones\SSBElasticity\Data\Output"
global path "C:\Users\William\Documents\SSBElasticity\Data\Output"

use "$path\DataEstimates.dta",clear

tab xeduc,gen(xeduc_)
* Summary
summarize xsexo xedad xrural xtamanioh xuniper xninios xeduc_1 xeduc_2 xeduc_3 xeduc_4 IT ITPC IT ITPC 
summarize Gasto_SSB Gasto0_SSB Gasto1_SSB

drop Gasto_HotDrinks Gasto_MilkDerivatives Gasto_SSB Gasto_Water Gasto_Beer Gasto_Spirits Gasto_Wine


rename Gasto1_HotDrinks Gasto_HotDrinks 
rename Gasto1_MilkDerivatives Gasto_MilkDerivatives 
rename Gasto1_SSB Gasto_SSB
rename Gasto1_Water Gasto_Water 
rename Gasto1_Beer Gasto_Beer 
rename Gasto1_Spirits Gasto_Spirits 
rename Gasto1_Wine Gasto_Wine


** QUAIDS libreria
egen totalexp = rowtotal(Gasto_HotDrinks Gasto_MilkDerivatives Gasto_SSB Gasto_Water Gasto_Beer Gasto_Spirits Gasto_Wine)

local expe "Gasto_HotDrinks Gasto_MilkDerivatives Gasto_SSB Gasto_Water Gasto_Beer Gasto_Spirits Gasto_Wine"
 
foreach i of local expe {
        replace `i' =0 if mi(`i')
}

  
gen w1= Gasto_SSB/totalexp
gen w2= Gasto_HotDrinks/totalexp
gen w3= Gasto_MilkDerivatives/totalexp
gen w4= Gasto_Water/totalexp

gen w5= Gasto_Beer/totalexp
gen w6= Gasto_Spirits/totalexp
gen w7= Gasto_Wine/totalexp

rename Precio_SSB p1
rename Precio_HotDrinks p2
rename Precio_MilkDerivatives p3
rename Precio_Water p4

rename Precio_Beer p5
rename Precio_Spirits p6
rename Precio_Wine p7

order p1 p2 p3 p4 p5 p6 p7

* dummies de consumo
gen di1= (Gasto_SSB>0)
gen di2= (Gasto_HotDrinks>0)
gen di3= (Gasto_MilkDerivatives>0)
gen di4= (Gasto_Water>0)

gen di5= (Gasto_Beer>0)
gen di6= (Gasto_Spirits>0)
gen di7= (Gasto_Wine>0)

rename xsexo x1
rename xedad x2
rename xrural x3
rename xtamanioh x4
rename xuniper x5
rename xninios x6
rename xeduc_1 x7
rename xeduc_2 x8
rename xeduc_3 x9
rename xeduc_4 x10


* Logaritmos
* logaritmos de precios

forvalues i=1/7 {
gen lnp`i'=log(p`i')
}

*logaritmo gasto
gen lnexp=log(totalexp)


****************************
* Probit regressions
****************************

global X x1 x2  x4 x5 x6 x7 x8 x9
global P lnp1 lnp2 lnp3 lnp4 lnp5 lnp6 lnp7

* Se excluye el sexo para no sobreidentificar

*genera variables auxiliares

set more off
forvalues i=1/7 {
probit di`i' $X
predict f_d`i', xb
label var f_d`i' "Valor ajustado para el bien `i'"
generate pdf`i'=normalden(f_d`i')
generate cdf`i'=normal(f_d`i')
generate mills`i'=(di`i'*(pdf`i'/cdf`i'))+ ((1-di`i')*(pdf`i'/1-cdf`i'))
}


forvalues i=1/7 {
rename mills`i' xm`i'
}


set more off
aidsills w1-w7, prices(p1-p7) expenditure(totalexp) intercept(x1 x2 x4 x5 x6 x7 x8 x9 xm1 xm2 xm3 xm4 xm5 xm6 xm7) quadratic symmetry alpha_0(10)
aidsills_elas
set more on


set more off
aidsills w1-w7, prices(p1-p7) expenditure(totalexp) intercept(x1 x2 x4 x5 x6 x7 x8 x9) symmetry alpha_0(10)
aidsills_elas
set more on
