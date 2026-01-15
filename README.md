
# Tuberculosis and Air Pollution Analysis

Analysis examining the relationship between air quality, environmental exposures, and tuberculosis incidence across US Core-Based Statistical Areas (CBSAs) from 2003-2023.

## Overview

This repository contains code and documentation for integrating multi-source public health and environmental datasets to analyze tuberculosis epidemiology. The analysis links county-level TB case data with air quality indicators, pollutant concentrations, and demographic characteristics at the CBSA-year level.

## Data Sources

- **TB Case Data**: County-level tuberculosis cases and deaths (2003-2011)
- **Air Quality Index (AQI)**: EPA daily AQI summaries by CBSA (2000-2023)
- **Air Pollutants**: EPA concentration trends for CO, NO₂, O₃, PM2.5, PM10, SO₂, Pb (2000-2023)
- **Emissions**: Facility-level emissions data (2008-2022)
- **Demographics**: Census county population estimates by sex, race, and ethnicity (2003-2023)
- **Geographic Crosswalks**: County-to-CBSA mapping files

## Methodology

### Data Processing Pipeline

1. **Air Quality Integration**
   - Reshape EPA pollutant trends from wide to long format (CBSA-year)
   - Merge AQI summaries with pollutant concentrations
   - Standardize pollutant metrics (2nd max, 98th percentile, annual mean, etc.)

2. **TB Case Aggregation**
   - Convert county-level TB cases from wide to long format
   - Map counties to CBSAs using FIPS code crosswalks
   - Aggregate cases and deaths to CBSA-year level
   - Special handling for Connecticut planning region transitions

3. **Demographic Integration**
   - Process Census population estimates (2003-2023)
   - Calculate sex, race, and ethnicity distributions
   - Aggregate county demographics to CBSA-year

4. **Emissions Processing**
   - Collapse facility-level emissions to county totals
   - Standardize pollutant codes across years
   - Link emissions to TB data via state/county identifiers

5. **Final Dataset Construction**
   - Merge TB, air quality, demographics, and emissions
   - Create analytical variables and derived metrics
   - Handle missing data and duplicates
   - Produce final CBSA-year panel dataset

### Key Challenges Addressed

- **Connecticut FIPS Transition**: Mapped legacy county FIPS codes to new planning region codes (2003-2011)
- **Multi-level Geographic Aggregation**: County → CBSA conversion with population-weighted metrics
- **Temporal Alignment**: Standardized data across 2000-2023 with varying source coverage
- **Data Quality**: Duplicate removal, missing value handling, crosswalk validation

## Repository Structure
```
.
├── README.md
├── code/
│   ├── 01_air_quality_processing.do      # EPA AQI and pollutant data
│   ├── 02_tb_case_aggregation.do         # TB case county-to-CBSA
│   ├── 03_demographics_cleaning.do       # Census population estimates
│   ├── 04_emissions_processing.do        # Facility emissions data
│   ├── 05_connecticut_realignment.do     # CT FIPS code fixes
│   ├── 06_final_merge.do                 # Master merge script
│   └── 07_descriptive_analysis.do        # Summary statistics
├── data/
│   ├── raw/                              # Original source files (not tracked)
│   ├── intermediate/                     # Processed intermediates
│   └── final/                            # Analytical datasets
├── documentation/
│   ├── codebook.md                       # Variable definitions
│   ├── data_dictionary.xlsx             # Detailed variable metadata
│   └── cbsa_crosswalk_notes.md          # Geographic mapping documentation
└── output/
    ├── tables/                           # Descriptive statistics tables
    └── figures/                          # Data quality visualizations
```

## Software Requirements

- **Stata** 15.0 or higher
- Required Stata packages:
  - `asdoc` (for formatted summary tables)
  - Standard Stata commands (reshape, merge, collapse)
## Visualization Scripts

In addition to Stata data processing, this repository includes R scripts for creating publication-quality maps and visualizations.

### R Requirements

- **R** 4.0.0 or higher
- Required R packages:
  - `readr` - Data import
  - `dplyr` - Data manipulation
  - `tidyr` - Data reshaping
  - `janitor` - Variable name cleaning
  - `ggplot2` - Graphics
  - `sf` - Spatial data handling
  - `tigris` - Census geographic boundaries
  - `patchwork` - Multi-panel figures

### R Installation
```r
# Install required packages
required_packages <- c("readr", "dplyr", "tidyr", "janitor", 
                       "ggplot2", "sf", "tigris", "patchwork")

install.packages(required_packages)
```

### Visualization Outputs

**Figure 1: Median Air Quality Index by CBSA (2003-2011)**
- Continuous gradient using EPA official AQI colors
- Shows median AQI values across all CBSAs
- Gray areas indicate missing AQI data

**Figure 2: Tuberculosis Incidence Rates by CBSA (2003-2011)**
- Categorical TB rate levels (Low, Medium, High, Very High)
- Color-coded based on rates per 100,000 population
- Highlights geographic disparities in TB burden

**Figure 3: Annual Mean NO₂ Concentrations by CBSA (2003-2011)**
- Continuous gradient showing nitrogen dioxide levels
- Uses same color scale as AQI for visual consistency
- Identifies areas with elevated air pollution

### Running Visualization Scripts
```r
# Set working directory to repository
setwd("/path/to/tb-air-pollution-analysis")

# Run visualization script
source("code/08_create_maps.R")

# Maps will be saved to output/figures/
```

### Map Features

- **Continental US focus**: Excludes Alaska, Hawaii, and territories for clarity
- **Dashed borders**: Indicate CBSAs with missing data
- **State boundaries**: Overlaid for geographic reference
- **Faceted by year**: Shows temporal trends 2003-2011
- **High resolution**: 300 DPI PNG output suitable for publication

### Coordinate System

All maps use:
- **Projection**: WGS84 (EPSG:4326)
- **Extent**: Continental US (longitude: -125 to -66, latitude: 24 to 50)
- **Boundary Source**: US Census TIGER/Line shapefiles (2020 vintage)
## Installation & Usage
```stata
* Set working directory
cd "/path/to/repository"
```

## Key Variables

### Outcome Variables
- `tb_cases`: Total TB cases per CBSA-year
- `tb_rate_per100000`: TB incidence rate per 100,000 population
- `tb_deaths`: TB deaths per CBSA-year

### Air Quality Exposures
- `co_2ndmax`: Carbon monoxide 2nd maximum (ppm)
- `no2_98thpercentile`: Nitrogen dioxide 98th percentile (ppb)
- `o3_4thmax`: Ozone 4th maximum (ppm)
- `pm25_weightedannualmean`: PM2.5 weighted annual mean (μg/m³)
- `maxaqi_aqi`: Maximum AQI value
- `gooddays_aqi`: Number of days with good AQI

### Demographics
- `pop`: Total CBSA population
- `male`, `female`: Sex distribution
- `white`, `black`, `asian`, `hispanic`: Race/ethnicity counts

## Data Quality Notes

- **Coverage**: 189 CBSAs with complete TB and air quality data (2003-2011)
- **Missing Data**: Some pollutants have incomplete temporal coverage
- **Connecticut**: Special FIPS realignment required for 2003-2011 data
- **Population Denominators**: Multiple Census sources merged to cover 2000-2023

## Citation

If you use this code or data, please cite:
```
Victory Ikpea. (2025). Tuberculosis and Air Pollution Analysis.
GitHub repository: https://github.com/vickyik/tb-air-pollution-analysis
```

## Contact

Victory Ikpea
Ikpeavictory@gmail.com
University of Massachusetts Lowell

## Acknowledgments

Data sources:
- EPA Air Quality System (AQS)
- CDC National Tuberculosis Surveillance System
- US Census Bureau Population Estimates Program
- EPA National Emissions Inventory (NEI)
```

---
