
/*********************************************************************
 AIR POLLUTION DATA: EPA Air Quality Trends by City (CBSA), 2000-2023
 Purpose:
 - Convert wide-format EPA trend tables into long CBSA-year format
 - Standardize pollutant metrics
 - Produce one row per CBSA-year with pollutant summaries
*********************************************************************/

import delimited "/Users/victoryikpea/Downloads/Air Quality Trends by City 2000-2023.csv", clear
list in 1/2

import excel "/Users/victoryikpea/Downloads/airqualitytrendsbycity2000-2023 (4).xlsx", sheet("CBSA Trends 2000-2023") firstrow clear
describe
* Rename CBSA identifier for consistency across datasets
rename CBSA cbsa_code

* Rename year columns from Excel letters to explicit year variables
rename D  y2000
rename E  y2001
rename F  y2002
rename G  y2003
rename H  y2004
rename I  y2005
rename J  y2006
rename K  y2007
rename L  y2008
rename M  y2009
rename N  y2010
rename O  y2011
rename P  y2012
rename Q  y2013
rename R  y2014
rename S  y2015
rename T  y2016
rename U  y2017
rename V  y2018
rename W  y2019
rename X  y2020
rename Y  y2021
rename Z  y2022
rename AA y2023
describe y*


* Reshape from wide (one column per year) to long (one row per CBSA-year)
reshape long y, i(cbsa_code Pollutant TrendStatistic) j(year)
rename y value

* Create standardized pollutant metric names combining pollutant and statistic
gen pollutant_metric = ""

replace pollutant_metric = "co_2ndmax"                 if Pollutant=="CO"    & TrendStatistic=="2nd Max"
replace pollutant_metric = "no2_98thpercentile"       if Pollutant=="NO2"   & TrendStatistic=="98th Percentile"
replace pollutant_metric = "no2_annualmean"           if Pollutant=="NO2"   & TrendStatistic=="Annual Mean"
replace pollutant_metric = "o3_4thmax"                if Pollutant=="O3"    & TrendStatistic=="4th Max"
replace pollutant_metric = "pm10_2ndmax"              if Pollutant=="PM10"  & TrendStatistic=="2nd Max"
replace pollutant_metric = "pm25_98thpercentile"      if Pollutant=="PM2.5" & TrendStatistic=="98th Percentile"
replace pollutant_metric = "pm25_weightedannualmean"  if Pollutant=="PM2.5" & TrendStatistic=="Weighted Annual Mean"
replace pollutant_metric = "so2_99thpercentile"       if Pollutant=="SO2"   & TrendStatistic=="99th Percentile"

* Drop observations not used in analysis
drop if pollutant_metric==""
drop Pollutant TrendStatistic

* Reshape to wide so each pollutant metric is its own column
reshape wide value, i(cbsa_code year) j(pollutant_metric) string
rename value* *
list in 1/5

*export as CSV

/*********************************************************************
AQI DATA
Import, clean, and merge AQI summaries to CBSA-year air pollution data
*********************************************************************/

clear
use aqi_2001_2023.dta, clear
describe
codebook

* Rename variables for clarity and consistency
rename cbsacode cbsa_code
rename maxaqi max_aqi
rename thpercentileaqi th_percentile_aqi
rename medianaqi median_aqi

* Save cleaned AQI dataset
save newstab.dta, replace

* Re-import CSV version for compatibility checks
import delimited "/Users/victoryikpea/Downloads/newstab.csv", clear 

* Reload original AQI dataset and remove pollutant-specific day counts
use aqi_2001_2023.dta
drop daysco daysno2 daysozone dayspm25 dayspm10 

* Merge cleaned AQI summaries back into AQI dataset
use newstab.dta, clear
merge m:1 cbsa_code year using aqi_2001_2023.dta

* Inspect merge quality and drop merge indicator
tab _merge
drop _merge


*---------------------------------------------------------------------------------------
* TB CASE DATA: COUNTY TO CBSA AGGREGATION
*---------------------------------------------------------------------------------------

*Import cbsa lookup file csv*
* Save CBSA lookup structure
save cbsa_lookup.dta, replace

*Rename lookup columns to meaningful identifiers
rename v1 cbsa_code
rename v2 cbsa_code
rename v3 county
rename v4 state

* Merge county TB data to CBSA lookup
merge m:1 state county using cbsa_lookup.dta

* Aggregate TB cases and population from county to CBSA-year
collapse (sum) cases population rateper100000, by(cbsa_code cbsa year)

* Save intermediate TB and AQI datasets
save tb_cbsa.dta, replace
save con_aqi.dta, replace

* Merge TB CBSA data with AQI-consolidated dataset
use tb_cbsa.dta, clear
merge 1:1 cbsa_code year using con_aqi.dta
duplicates report cbsa_code year


*---------------------------------------------------------------------------------------
* COLLAPSING AQI AND POLLUTION METRICS TO FINAL CBSA-YEAR FORMAT
*---------------------------------------------------------------------------------------

use con_aqi.dta, clear
duplicates report cbsa_code year

* Collapse all numeric AQI and pollutant variables to CBSA-year means
collapse (mean) _all, by(cbsa_code year cbsa)

collapse (mean) co_2ndmax no2_98thperce~e no2_annualmean o3_4thmax pm10_2ndmax ///
    pm25_98thperc~e pm25_weighted~n pb_max3montha~e so2_99thperce~e ///
    dayswithaqi gooddays moderatedays unhealthyfors~s unhealthydays ///
    veryunhealthy~s hazardousdays maxaqi thpercentileaqi medianaqi, ///
    by(cbsa_code year cbsa)

save con_aqi_collapsed.dta, replace
destring year, replace
save tb_cbsa.dta, replace

* Merge collapsed AQI/pollution data with TB CBSA data
use con_aqi_collapsed.dta, clear
merge 1:1 cbsa_code year using tb_cbsa.dta
tab _merge
duplicates list cbsa_code year, sepby(cbsa_code)

*---------------------------------------------------------------------------------------
* EMISSIONS DATA 
*---------------------------------------------------------------------------------------

ddescribe
list in 1/6

* Drop facility-level identifiers and metadata not used in analysis
drop tribalname eisfacilityid programsystem~e agencyfacilit~d trifacilityid companyname ///
     sitename primarynaicsc~e primarynaicsd~n facilitysourc~e address city zipcode ///
     postalabbrevi~n reportingperiod emissionsoper~e pollutanttypes haptype dataset ///
     outlierminimum outliermaximum outlier

tab pollutantdesc
save em2021.dta, replace
save em2020.dta, replace

* Merge emissions datasets by pollutant
merge m:m pollutantcode using "em2021.dta"
tab _merge
drop _merge
save emfull.dta, replace

* Assign year values to emissions datasets
use em2021.dta, clear
gen year= 2021

use em2020.dta, clear
gen year =2020
save em2020.dta, replace
gen year = 2019
save em2019.dta, replace

merge m:m pollutantcode using "emfull.dta"
gen year = 2018

use emfull.dta, clear
gen year = 2017
gen year = 2016
gen year = 2015
gen year = 2014
gen year = 2013
gen year = 2012

* Remove remaining facility metadata
drop eis_facility_~d program_syste~d alt_agency_id region_cd tribal_name ///
     facility_site~e naics_cd facility_sour~n facility_site~d ///
     location_addr~t locality address_posta~e emissions_op_~e

tab description
gen year = 2011

* Standardize emissions variable names
rename addr_state_cd state
rename county_name county
rename state_and_county_fips fipscode
rename latitude_msr sitelatitude
rename longitude_msr sitelongitude
rename pollutant_cd pollutantcode
rename description pollutantdesc
rename total_emissions totalemissions
rename uom emissionsuom
gen year = 2008

* Merge emissions datasets by spatial coordinates
merge m:m sitelatitude sitelongitude using "emfull.dta"
drop state
tab year

*merge emission*

describe

import delimited "/Users/victoryikpea/Downloads/emi2020-2021.csv", stringcols(2 3 8) clear

save emi20_21.dta, replace
import delimited "/Users/victoryikpea/Downloads/emi2022.csv", stringcols(6) clear 

save emi22.dta, replace

describe
list in 50/100

use emi20_21.dta, clear

* Collapse total emissions by county and pollutant
collapse (sum) total_emissions, by(st_usps_cd county_name pollutantdesc year)

* Save the collapsed dataset
save "emi2020-2021_collapsed.dta", replace


* Merge the two datasets by state_code county year
merge m:m state_code county year using tbdataallset.dta

* Check merge results
tab _merge

* Keep only matched observations if needed
keep if _merge == 3

* Drop the merge indicator if not needed
drop _merge

* Save the merged dataset
save tb_em_merged_by_state_county_year.dta, replace

describe
codebook



/****************************************************************************************
 TUBERCULOSIS CASE DATA PROCESSING
 Purpose:
 - Convert county-level TB case data from wide to long format
 - Aggregate TB cases from counties to CBSA-year
 - Merge TB data with environmental, emissions, and demographic datasets
****************************************************************************************/
* Import county-level TB case data (wide format by year)
import delimited "tbcases2000-2011.csv", clear

* Clean up variable names (remove spaces and special chars)
rename healthdistrictwhenapplicable health_district
rename avgcases06_10 avg_cases_06_10
rename tbrate0610 tbrate_06_10

* Check variable names
describe

* Reshape from wide to long
reshape long y, i(fips county state health_district) j(year)

* Rename reshaped variables for clarity
rename y tb_cases

* Convert year from string (like "1994") to numeric if needed
replace year = real(year)

* Save the long dataset
save tbcases2000_2011_long.dta, replace
tab year

summarize

*---------------------------------------------------------------------------------------
* AGGREGATE COUNTY TB DATA TO CBSA LEVEL
*---------------------------------------------------------------------------------------
* Merge county TB data with county-to-CBSA crosswalk
merge m:1 state_fips county_fips using cbsa_county_rel_2023.dta

* Aggregate TB cases and other variables to CBSA-year level
collapse (sum) tb_cases tb_deaths total_emissions ///
         (mean) median_income male_pct ///
         [aw=population], by(cbsa_code year)

*---------------------------------------------------------------------------------------
* MERGE TB CASE DATA WITH AIR POLLUTION DATA
*--------------------------------------------------------

describe
* Save CBSA-level TB dataset
save tbcasecbsa.dta, replace
* Save corresponding CBSA environmental dataset
save cbsacon.dta, replace
* Merge TB cases with environmental data using CBSA and year
merge 1:1 cbsa_code year cbsatitle using tbcasecbsa.dta
rename cbsa cbsatitle
codebook

* Collapse AQI day counts and pollutant concentrations to CBSA-year
collapse ///
    (sum) dayswith_aqi gooddays_aqi moderatedays_aqi ///
          unhealthyforsensitivegroupsdays_ unhealthydays_aqi ///
          veryunhealthydays_aqi hazardousdays_aqi ///
    (mean) co_2ndmax no2_98thpercentile no2_annualmean o3_4thmax ///
           pm10_2ndmax pm25_98thpercentile pm25_weightedannualmean ///
           pb_max3monthaverage so2_99thpercentile maxaqi_aqi ///
           thpercentile_aqi median_aqi ///
    (firstnm) cbsatitle, by(cbsa_code year)

*---------------------------------------------------------------------------------------
* RE-COLLAPSE TB DATA TO ENSURE ONE ROW PER CBSA-YEAR
*---------------------------------------------------------------------------------------
use tbcasecbsa.dta, clear
* Force TB case counts to numeric and treat non-numeric as missing
destring tb_cases, replace force   // "." will become missing
* Collapse TB cases to CBSA-year and count contributing counties
collapse (sum) tb_cases ///
         (firstnm) cbsatitle ///
         (count) n_counties = county_fips, ///
         by(cbsa_code year)

		 
*---------------------------------------------------------------------------------------
* MERGE TB AND ENVIRONMENTAL DATASETS
*---------------------------------------------------------------------------------------

use cbsacon.dta, clear
merge m:1 

merge m:m cbsa_code year cbsatitle using tbcasecbsa.dta

*---------------------------------------------------------------------------------------
* MERGE EMISSIONS DATA BY STATE AND YEAR
*---------------------------------------------------------------------------------------

save tbcon.dta

save emi.dta, replace
* Merge emissions data using state FIPS and year
merge m:1 state_fips year using emi.dta
use tbcon.dta, clear

*---------------------------------------------------------------------------------------
* MERGE STATE-LEVEL TB DEATH DATA
*---------------------------------------------------------------------------------------

describe
save tbfull.dta, replace

save detah.dta, replace

* Merge TB deaths by state and year
use tbfull.dta, clear
merge m:m state_fips year using detah.dta

tab year
use detah.dta, clear
summarize

*---------------------------------------------------------------------------------------
* MERGE POPULATION ESTIMATES AND FINAL DATA REDUCTION
*-----------------------------------------------------------------------

save popcbsa.dta, replace
save fullset.dta, replace
* Merge population estimates to full CBSA-year dataset
use fullset.dta, clear
merge m:1 cbsa_code year using popcbsa.dta

rename cbsatitle cbsa_title
* Check observation count before reduction
count   // shows 996896 now

* reduce the data
keep if !missing(somevar)
drop if year < 2003
duplicates drop cbsa_code year, force

count   // new smaller count

export delimited using "big_reduced.csv", replace


/****************************************************************************************
 FIXING DEMOGRAPHIC (POPULATION) DATA
 Purpose:
 - Clean Census county-level population estimates for 2003–2011
 - Create sex, race, and ethnicity population counts
 - Aggregate county-level demographics to CBSA-year
 - Merge demographics into final TB analytic dataset
****************************************************************************************/
*import 2003-2010*
import delimited "/Users/victoryikpea/Downloads/coest2003-2010.csv", clear 
describe


* Reshape population estimates from wide year format to long county-year format
reshape long popestimate, i(state county stname ctyname sex origin race) j(year)
* Note: reshape error occurred previously; drop incomplete identifier rows
drop if state == . | county == . | sex == . | origin == . | race == .

* Rename population variable for clarity
rename popestimate pop
* Create sex-specific population counts
gen male   = pop if sex == 1
gen female = pop if sex == 2
* Create Hispanic and non-Hispanic population counts
gen hispanic     = pop if origin == 2
gen not_hispanic = pop if origin == 1
* Create race-specific population counts using Census race codes
gen white    = pop if race == 1
gen black    = pop if race == 2
gen aian     = pop if race == 3
gen asian    = pop if race == 4
gen nhopi    = pop if race == 5
gen two_plus = pop if race == 6

list in 200/210
* Collapse to one observation per county-year by summing demographic counts
collapse (sum) male female hispanic not_hispanic white black aian asian nhopi two_plus pop, ///
    by(state county stname ctyname year)

* Save final dataset
save "coest_clean.dta", replace

*---------------------------------------------------------------------------------------
* POST-CENSAL DEMOGRAPHIC DATA: 2011
*---------------------------------------------------------------------------------------

* Import 2011 county population estimates with sex, race, and Hispanic origin
import delimited "/Users/victoryikpea/Documents/My research/nov/2011_sexracehisp.csv", clear 
describe

* Assign year value
gen year = 2011
* Retain only variables needed to reconstruct demographic groups
keep year state county stname ctyname ///
     tot_male tot_female ///
     nh_male nh_female h_male h_female ///
     wa_male wa_female ba_male ba_female ///
     ia_male ia_female aa_male aa_female ///
     na_male na_female tom_male tom_female
	 
* Create total male and female counts
gen male   = tot_male
gen female = tot_female
*reshape sex*

* Create Hispanic and non-Hispanic population counts
gen hispanic     = h_male + h_female
gen not_hispanic = nh_male + nh_female


* Create race-specific population counts
gen white   = wa_male  + wa_female
gen black   = ba_male  + ba_female
gen aian    = ia_male  + ia_female
gen asian   = aa_male  + aa_female
gen nhopi   = na_male  + na_female
gen two_plus = tom_male + tom_female

* Calculate total population
gen total_pop = male + female
* Drop intermediate Census variables no longer needed
drop tot_* h_* nh_* wa_* ba_* ia_* aa_* na_* tom_*
* Order variables for readability and consistency
order state county year stname ctyname ///
      male female ///
      hispanic not_hispanic ///
      white black aian asian nhopi two_plus ///
      total_pop


list in 1/10
* Save cleaned 2011 county-level demographic dataset
save final2011, replace

*---------------------------------------------------------------------------------------
* COUNTY TO CBSA CROSSWALK AND AGGREGATION
*---------------------------------------------------------------------------------------

* Import county-to-CBSA crosswalk
import delimited "/Users/victoryikpea/Downloads/full_fips.csv", clear
describe
keep county_fips cbsa_code cbsatitle state_fips
save crosswalk.dta, replace

* Import combined demographic file and construct county FIPS codes
import delimited "/Users/victoryikpea/Downloads/Demo fix/clean_2003_2011.csv", clear 
describe
gen county_fips = string(state,"%02.0f") + string(county,"%03.0f")
* Verify FIPS construction
list in 1/1
save final2003_2011.dta, replace

* Standardize FIPS formatting in crosswalk
use crosswalk.dta, clear
tostring county_fips, gen(county_fips_str) format(%05.0f)
drop county_fips
rename county_fips_str county_fips
save crosswalk.dta, replace

* Merge demographic data with CBSA crosswalk
use final2003_2011.dta, clear
merge m:m county_fips using crosswalk.dta
keep if _merge==3
drop _merge
save finals2003_2011.dta, replace

*---------------------------------------------------------------------------------------
* AGGREGATE DEMOGRAPHICS TO CBSA-YEAR
*---------------------------------------------------------------------------------------

* After merging county_fips to cbsa_code:
use finals2003_2011.dta, clear

* Collapse to CBSA-year
collapse (sum) male female hispanic not_hispanic white black aian asian nhopi two_plus pop, ///
    by(cbsa_code year)

save demo_cbsa_2003_2011, replace

*---------------------------------------------------------------------------------------
* MERGE DEMOGRAPHICS INTO TB DATASET
*-----------------------------------------------
use tbfull2003_2011clean.dta, clear
* Merge CBSA-level demographics with TB dataset
merge 1:1 cbsa_code year using demo_cbsa_2003_2011
keep if _merge == 3
drop _merge
* Save TB dataset with demographics
save tb_demo_merged.dta, replace


*---------------------------------------------------------------------------------------
* DESCRIPTIVE STATISTICS TABLE
*---------------------------------------------------------------------------------------
* Install asdoc for formatted summary tables
ssc install asdoc
* Generate descriptive statistics table for TB, demographics, and environmental exposures

asdoc sum tb_cases tb_ra~100000 tb_deaths_~e   male  female hispanic not_hispanic white black ///
aian asian nhopi two_plus dayswith_aqi  maxaqi_aqi  median_aqi thpercenti~i co_2ndmax no2_98thpe~e no2_annual~n o3_4thmax pm10_2ndmax pm25_98thp~e pm25_weigh~n so2_99thpe~e, dec(2) save(tbdemosumtable) title(Tuberculosis Descriptive Statistics by Race, Gender and Enviromental Exposures) append


*---------------------------------------------------------------------------------------
* ADD STATE ABBREVIATIONS TO TB DEATH DATA
*---------------------------------------------------------------------------------------

* Import state-level TB death dataset
import delimited "tb Death, 2003-2011(2).csv", clear

describe
* Create empty state abbreviation variable
gen str2 state_abbrev = ""

* Assign abbreviations
replace state_abbrev = "AL" if state == "Alabama"
replace state_abbrev = "AK" if state == "Alaska"
replace state_abbrev = "AZ" if state == "Arizona"
replace state_abbrev = "AR" if state == "Arkansas"
replace state_abbrev = "CA" if state == "California"
replace state_abbrev = "CO" if state == "Colorado"
replace state_abbrev = "CT" if state == "Connecticut"
replace state_abbrev = "DE" if state == "Delaware"
replace state_abbrev = "DC" if state == "District of Columbia"
replace state_abbrev = "FL" if state == "Florida"
replace state_abbrev = "GA" if state == "Georgia"
replace state_abbrev = "HI" if state == "Hawaii"
replace state_abbrev = "ID" if state == "Idaho"
replace state_abbrev = "IL" if state == "Illinois"
replace state_abbrev = "IN" if state == "Indiana"
replace state_abbrev = "IA" if state == "Iowa"
replace state_abbrev = "KS" if state == "Kansas"
replace state_abbrev = "KY" if state == "Kentucky"
replace state_abbrev = "LA" if state == "Louisiana"
replace state_abbrev = "ME" if state == "Maine"
replace state_abbrev = "MD" if state == "Maryland"
replace state_abbrev = "MA" if state == "Massachusetts"
replace state_abbrev = "MI" if state == "Michigan"
replace state_abbrev = "MN" if state == "Minnesota"
replace state_abbrev = "MS" if state == "Mississippi"
replace state_abbrev = "MO" if state == "Missouri"
replace state_abbrev = "MT" if state == "Montana"
replace state_abbrev = "NE" if state == "Nebraska"
replace state_abbrev = "NV" if state == "Nevada"
replace state_abbrev = "NH" if state == "New Hampshire"
replace state_abbrev = "NJ" if state == "New Jersey"
replace state_abbrev = "NM" if state == "New Mexico"
replace state_abbrev = "NY" if state == "New York"
replace state_abbrev = "NC" if state == "North Carolina"
replace state_abbrev = "ND" if state == "North Dakota"
replace state_abbrev = "OH" if state == "Ohio"
replace state_abbrev = "OK" if state == "Oklahoma"
replace state_abbrev = "OR" if state == "Oregon"
replace state_abbrev = "PA" if state == "Pennsylvania"
replace state_abbrev = "RI" if state == "Rhode Island"
replace state_abbrev = "SC" if state == "South Carolina"
replace state_abbrev = "SD" if state == "South Dakota"
replace state_abbrev = "TN" if state == "Tennessee"
replace state_abbrev = "TX" if state == "Texas"
replace state_abbrev = "UT" if state == "Utah"
replace state_abbrev = "VT" if state == "Vermont"
replace state_abbrev = "VA" if state == "Virginia"
replace state_abbrev = "WA" if state == "Washington"
replace state_abbrev = "WV" if state == "West Virginia"
replace state_abbrev = "WI" if state == "Wisconsin"
replace state_abbrev = "WY" if state == "Wyoming"

* Check
tab state_abbrev

/****************************************************************************************
 CONNECTICUT-SPECIFIC DATA REINTEGRATION
 Purpose:
 - Reincorporate Connecticut TB data excluded due to CBSA/FIPS changes
 - Reassign legacy county FIPS codes to Connecticut planning regions
 - Align CT TB, AQI, air pollution, and demographic data to CBSA-year
****************************************************************************************/

*---------------------------------------------------------------------------------------
* IMPORT CONNECTICUT TB DATA
*---------------------------------------------------------------------------------------

* Import Connecticut-specific TB case file
import delimited "/Users/victoryikpea/Documents/My research/nov/ctfix.csv", clear
describe

* Save raw Connecticut TB dataset
save cttb.dta, replace

*---------------------------------------------------------------------------------------
* CONNECTICUT FIPS CODE REALIGNMENT
* Connecticut transitioned from county FIPS to planning region codes
* This mapping translates old county FIPS to new planning-region FIPS
*---------------------------------------------------------------------------------------

clear
input str5 old_fips str5 plan_fips
"09001" "09120"   // Fairfield → Greater Bridgeport
"09001" "09190"   // Fairfield → Western CT
"09003" "09110"   // Hartford → Capitol
"09005" "09160"   // Litchfield → Northwest Hills
"09007" "09130"   // Middlesex → Lower CT River Valley
"09009" "09170"   // New Haven → South Central CT
"09011" "09180"   // New London → Southeastern CT
"09013" "09110"   // Tolland → Capitol
"09013" "09150"   // Tolland → Northeastern
"09015" "09150"   // Windham → Northeastern
end

* Save Connecticut county-to-planning-region crosswalk
save ct_county_to_plan.dta, replace

* Reload Connecticut TB dataset
use cttb.dta, clear

*---------------------------------------------------------------------------------------
* RESHAPE CONNECTICUT TB DATA TO LONG FORMAT
*---------------------------------------------------------------------------------------

* Ensure county identifier is named consistently
rename fips county_fips

* Convert yearly TB columns to numeric prior to reshaping
foreach var of varlist y2003-y2011 {
    destring `var', replace force
}

* Reshape TB data to county-year format
reshape long y, i(county_fips) j(year)
tab year

* Rename TB case variable
rename y tb_cases

*---------------------------------------------------------------------------------------
* MERGE UPDATED CONNECTICUT FIPS CODES
*---------------------------------------------------------------------------------------

* Preserve original FIPS for mapping
rename county_fips old_fips
tostring old_fips, replace format(%05.0f)

* Merge old county FIPS with new planning-region FIPS
merge m:m old_fips using ct_county_to_plan.dta
rename plan_fips county_fips
drop _merge

* Save updated Connecticut TB dataset
save cttb.dta, replace

*---------------------------------------------------------------------------------------
* ASSIGN CBSA CODES USING CROSSWALK
*---------------------------------------------------------------------------------------

* Import full county-to-CBSA crosswalk
import excel "/Users/victoryikpea/Documents/My research/nov/full_fips.xlsx", sheet("List 1") firstrow clear
describe
save fullfips.dta, replace

* Merge Connecticut TB data with CBSA identifiers
use cttb.dta, clear
rename state StateName
merge m:1 county_fips StateName using fullfips.dta
drop if _merge != 3
drop _merge

* Inspect merged Connecticut TB records
list in 1/10

*---------------------------------------------------------------------------------------
* MERGE CONNECTICUT AQI AND AIR QUALITY DATA
*---------------------------------------------------------------------------------------

* Import full AQI dataset
import delimited "/Users/victoryikpea/Documents/My research/nov/con_aqi_allset.csv", clear
save aqifull.tba, replace

* Import Connecticut-specific AQI and pollution file
import delimited "/Users/victoryikpea/Documents/My research/nov/ctfilefix.csv", clear
describe
save ctalmost.dta, replace

* Rename CBSA title for merge consistency
rename cbsatitle cbsa

* Merge AQI data to Connecticut TB records
merge m:1 cbsa_code year cbsa using aqifull.tba
drop if _merge==2
drop _merge

* Save Connecticut TB + AQI dataset
save ctalmost.dta, replace

*---------------------------------------------------------------------------------------
* ADD DEMOGRAPHIC DATA FOR CONNECTICUT
*---------------------------------------------------------------------------------------

* Load cleaned national demographic dataset
use finals2003_2011.dta, clear

* Import Connecticut demographic file
import delimited "/Users/victoryikpea/Documents/My research/nov/ctdemo.csv", clear
describe

* Aggregate demographic variables to CBSA-year
collapse (sum) male female hispanic not_hispanic white black aian asian nhopi two_plus pop, ///
    by(cbsa_code year)

* Check for duplicate CBSA-year entries
duplicates report cbsa_code year

* Restrict dataset to Connecticut observations
drop if !inlist(state,9)
save ctdemo.dta, replace

*---------------------------------------------------------------------------------------
* REAPPLY CONNECTICUT FIPS AND CBSA MAPPING TO DEMOGRAPHICS
*---------------------------------------------------------------------------------------

list in 1/1
save ctdemo.dta, replace

rename county_fips old_fips
tostring old_fips, replace format(%05.0f)

* Merge planning-region FIPS
merge m:m old_fips using ct_county_to_plan.dta
rename plan_fips county_fips
drop _merge
save ctdemofullfips.dta

* Merge demographics with CBSA crosswalk
merge m:m county_fips using crosswalk.dta
keep if _merge==3
drop _merge
save ctdemowthcbsa.dta, replace

* Check for duplicate CBSA-year records
duplicates report cbsa_code year

*---------------------------------------------------------------------------------------
* FINAL CONNECTICUT CBSA-YEAR DEMOGRAPHIC AGGREGATION
*---------------------------------------------------------------------------------------

use ctdemowthcbsa.dta
collapse (sum) male female hispanic not_hispanic white black aian asian nhopi two_plus pop, ///
    by(cbsa_code year)

save ctdemowthcbsa.dta, replace

*---------------------------------------------------------------------------------------
* MERGE CONNECTICUT TB, DEMOGRAPHICS, AND ENVIRONMENTAL DATA
*---------------------------------------------------------------------------------------

* Import Connecticut TB and AQI file
import delimited "/Users/victoryikpea/Documents/My research/nov/ctfilefix.csv", clear 

* Collapse duplicate CBSA-year entries
collapse ///
    (sum) tb_cases population ///
    (mean) ///
        dayswith_aqi gooddays_aqi moderatedays_aqi ///
        maxaqi_aqi median_aqi thpercentile_aqi ///
        unhealthyforsensitivegroupsdays_ unhealthydays_aqi ///
        veryunhealthydays_aqi hazardousdays_aqi ///
        co_2ndmax no2_98thpercentile no2_annualmean ///
        o3_4thmax pm10_2ndmax pm25_98thpercentile ///
        pm25_weightedannualmean so2_99thpercentile ///
    (firstnm) cbsatitle states_in_cbsa counties_in_cbsa ///
    , by(cbsa_code year)

* Save collapsed Connecticut dataset
save ctfile.dta, replace
use ctfile.dta, clear	

* Merge Connecticut demographics into CT dataset
use ctdemowthcbsa.dta, clear
drop if !inlist(cbsa_code, 14860, 25540, 35300, 35980)
merge m:1 cbsa_code year using ctfile.dta
drop _merge

*---------------------------------------------------------------------------------------
* RE-IMPORT AIR POLLUTION AND AQI DATA (CT-ALIGNED)
*---------------------------------------------------------------------------------------

* Import EPA air pollution trends
import excel "/Users/victoryikpea/Downloads/airqualitytrendsbycity2000-2023 (4).xlsx", sheet("CBSA Trends 2000-2023") firstrow clear
describe

* Rename CBSA and year columns
rename CBSA cbsa_code
rename D  y2000
rename E  y2001
rename F  y2002
rename G  y2003
rename H  y2004
rename I  y2005
rename J  y2006
rename K  y2007
rename L  y2008
rename M  y2009
rename N  y2010
rename O  y2011
rename P  y2012
rename Q  y2013
rename R  y2014
rename S  y2015
rename T  y2016
rename U  y2017
rename V  y2018
rename W  y2019
rename X  y2020
rename Y  y2021
rename Z  y2022
rename AA y2023
describe y*

* Reshape air pollution data to CBSA-year
reshape long y, i(cbsa_code Pollutant TrendStatistic) j(year)
rename y value

* Create standardized pollutant metric names
gen pollutant_metric = ""
replace pollutant_metric = "co_2ndmax" if Pollutant=="CO"  & TrendStatistic=="2nd Max"
replace pollutant_metric = "no2_98thpercentile" if Pollutant=="NO2"  & TrendStatistic=="98th Percentile"
replace pollutant_metric = "no2_annualmean" if Pollutant=="NO2"  & TrendStatistic=="Annual Mean"
replace pollutant_metric = "o3_4thmax" if Pollutant=="O3"   & TrendStatistic=="4th Max"
replace pollutant_metric = "pm10_2ndmax"  if Pollutant=="PM10" & TrendStatistic=="2nd Max"
replace pollutant_metric = "pm25_98thpercentile" if Pollutant=="PM2.5"& TrendStatistic=="98th Percentile"
replace pollutant_metric = "pm25_weightedannualmean" if Pollutant=="PM2.5"& TrendStatistic=="Weighted Annual Mean"
replace pollutant_metric = "so2_99thpercentile" if Pollutant=="SO2"  & TrendStatistic=="99th Percentile"

* Retain only required pollutant metrics
drop if pollutant_metric==""
drop Pollutant TrendStatistic

* Reshape pollutants to wide CBSA-year format
reshape wide value, i(cbsa_code year) j(pollutant_metric) string
rename value* *
list in 1/5

* Save air pollution dataset
save airpollu2023, replace

*---------------------------------------------------------------------------------------
* MERGE AQI DATA AND FINALIZE CONNECTICUT DATASET
*---------------------------------------------------------------------------------------

* Import AQI data
import delimited "/Users/victoryikpea/Documents/My research/nov/aqi2000-23.csv", clear 
save aqi_2000_2023.dta, replace

describe
codebook

* Standardize AQI variable names
rename cbsacode cbsa_code
rename maxaqi max_aqi
rename thpercentileaqi th_percentile_aqi
rename medianaqi median_aqi

* Merge AQI with air pollution dataset
use airpollu2023, clear
destring cbsa_code, replace
merge m:1 cbsa_code year using aqi_2000_2023.dta

* Retain matched CBSA-year observations
drop if _merge!=3
drop _merge
save fullairpollu.dta, replace

*---------------------------------------------------------------------------------------
* CREATE STATE ABBREVIATIONS FROM CBSA TITLES
*---------------------------------------------------------------------------------------

use fullairpollu.dta, clear
use crosswalk.dta, clear

* Drop unneeded identifiers
drop state_fips county_fips

* Standardize CBSA title variable
rename cbsatitle cbsa

* Merge CBSA titles into final dataset
merge m:m cbsa_code cbsa using fullairpollu.dta
drop if _merge !=3
drop _merge

* Extract state abbreviations from CBSA titles
gen state_abbrev = ""
replace state_abbrev = substr(cbsa, strpos(cbsa, ",") + 2, .)

* Inspect final records
list in 1/5

* Save final TB analytic dataset
save fulltb.dta, replace

*---------------------------------------------------------------------------------------
* ADD POPULATION TO CBSA AIR-POLLUTANT ONLY DATASET (2000-2023)
*---------------------------------------------------------------------------------------
use airpollu2023, clear
describe
save airpollu2023, replace

* Import and save the 2000-2002, 2012-2020, 2021-2023 pop data*
*2000-2002*
import delimited "/Users/victoryikpea/Documents/My research/nov/pop2000-2002.csv", clear 
describe
* Add standard county_fips variable*
gen county_fips = string(state,"%02.0f") + string(county,"%03.0f")
save pop2000_2002.dta, replace
*2012-2020*
import delimited "/Users/victoryikpea/Documents/My research/nov/pop2012-2020.csv", clear 
gen county_fips = string(state,"%02.0f") + string(county,"%03.0f")
save pop2012_2020.dta, replace
*2021-2023*
import delimited "/Users/victoryikpea/Documents/My research/nov/pop2021-2023.csv", clear 
gen county_fips = string(state,"%02.0f") + string(county,"%03.0f")
save pop2021_2023.dta, replace
* Fix Connecticut county FIPS and county names to legacy county system
use pop2000_2002.dta, clear

* Greater Bridgeport Planning Region
replace county_fips = "09120" if state == 9 & county_fips == "09001"
replace ctyname     = "Greater Bridgeport Planning Region" if county_fips == "09120"

* Capitol Planning Region
replace county_fips = "09110" if state== 9 & inlist(county_fips,"09003","09013")
replace ctyname      = "Capitol Planning Region" if county_fips=="09110"

* Lower Connecticut River Valley Planning Region
replace county_fips = "09130" if state==9 & county_fips=="09007"
replace ctyname      = "Lower Connecticut River Valley Planning Region" if county_fips=="09130"

* Northwest Hills Planning Region
replace county_fips = "09160" if state==9 & county_fips=="09005"
replace ctyname      = "Northwest Hills Planning Region" if county_fips=="09160"

* South Central Connecticut Planning Region
replace county_fips = "09170" if state==9 & county_fips=="09009"
replace ctyname      = "South Central Connecticut Planning Region" if county_fips=="09170"

* Southeastern Connecticut Planning Region
replace county_fips = "09180" if state==9 & county_fips=="09011"
replace ctyname      = "Southeastern Connecticut Planning Region" if county_fips=="09180"

* Northeastern Connecticut Planning Region
replace county_fips = "09150" if state==9 & county_fips=="09015"
replace ctyname      = "Northeastern Connecticut Planning Region" if county_fips=="09150"

* Western Connecticut Planning Region
replace county_fips = "09190" if state==9 & county_fips=="09001"
replace ctyname      = "Western Connecticut Planning Region" if county_fips=="09190"

save pop2000_2002.dta, replace
*Do this for the corresponding years* 
use pop2012_2020.dta, clear
save pop2012_2020.dta, replace

* Merge them all*
merge m:m county_fips state using pop2000_2002.dta
merge m:m county_fips state using pop2021_2023.dta
drop _merge
save pop2000_2023.dta, replace
* Convert to long formatted
describe
rename popestimate2000 y2000
rename popestimate2001 y2001
rename popestimate2002 y2002
rename popestimate2012 y2012
rename popestimate2013 y2013
rename popestimate2014 y2014
rename popestimate2015 y2015
rename popestimate2016 y2016
rename popestimate2017 y2017
rename popestimate2018 y2018
rename popestimate2019 y2019
rename popestimate2020 y2020
rename popestimate2021 y2021
rename popestimate2022 y2022
rename popestimate2023 y2023
reshape long y, i(state county county_fips stname ctyname) j(year)
rename y population
destring year, replace
tab year
summarize population
save pop2000_2023.dta, replace

* Add in cbsa_code via crosswork*
use pop2000_2023.dta, clear
merge m:1 county_fips using crosswalk.dta
*/Result                      Number of obs
* -----------------------------------------
*    Not matched                        19,560
*        from master                    19,560  (_merge==1)
*       from using                          0  (_merge==2)
    *Matched                            27,746  (_merge==3) */
drop if _merge !=3
drop _merge
save pop2000_2023.dta, replace
* Collapse population to CBSA-year
collapse (sum) population, by(cbsa_code year)
duplicates report
save pop2000_2023.dta, replace
* Export to csv
use pop2000_2023.dta, clear
export delimited using "/Users/victoryikpea/Documents/My research/nov/popa.csv", replace

* Import main tb dataset to get pop for 2003-2011*
 
import delimited "/Users/victoryikpea/Documents/My research/nov/tbdemofullfix.csv", clear 
save tbmerge.dta, replace

* Drop unneccessary variables for merge*
keep cbsa_code year population
describe
save tbmerge.dta, replace
*export 
 export delimited using "/Users/victoryikpea/Documents/My research/nov/pop2003.csv"
*merged with excel externally to get all years*


*merge population into aqipollupop2000_2023 table*
import delimited "/Users/victoryikpea/Documents/My research/nov/aqipollutant2000-2023.csv", clear 

describe
isid cbsa_code year
save aqipollutant2000_2023.dta, replace
import delimited "/Users/victoryikpea/Documents/My research/nov/popa.csv", clear 
isid cbsa_code year
save popa.dta, replace

use aqipollutant2000_2023.dta, clear
merge 1:1 cbsa_code year using popa.dta
*    Result                      Number of obs
 *   -----------------------------------------
*    Not matched                        15,570
 *       from master                         0  (_merge==1)
 *       from using                     15,570  (_merge==2)
*    Matched                             6,621  (_merge==3)

drop if _merge !=3
drop _merge
save aqipollutant2000_2023.dta, replace
