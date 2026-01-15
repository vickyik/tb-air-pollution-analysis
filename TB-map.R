gc()
# List of required packages
required_packages <- c("readr", "dplyr", "tidyr", "janitor", 
                       "ggplot2", "sf", "tigris", "patchwork")

# Check for missing packages and install them
missing_packages <- required_packages[!required_packages %in% installed.packages()[,"Package"]]
if(length(missing_packages)) {
  message("Installing missing packages: ", paste(missing_packages, collapse = ", "))
  install.packages(missing_packages)
}
install.packages("sf") # For handling spatial data
install.packages("ggpattern")
# Load all libraries

library(readr)
library(dplyr)
library(tidyr)
library(janitor)
library(ggplot2)
library(sf)
options(tigris_use_cache = TRUE)
library(tigris)
library(patchwork)
library(sf)
library(ggpattern)

#-------------------------------
# 1) Read Data with Error Handling
#-------------------------------
setwd("/Users/victoryikpea/Documents/My research/nov")

tbdemofullfix <- read_csv("tbdemofullfix.csv")
#-------------------------------
# 2) Prepare Analysis Dataset
#-------------------------------

project_data <- tbdemofullfix |>
  # Rename FIRST, before clean_names()
  rename(
    tb_rate_100k = `tb_rate/100000`,
    american_indian_alaska_native = aian,
    native_hawaiian_and_other_pacific_islander = nhopi,
    two_or_more_races = two_plus
  ) |>
  clean_names() |>
  filter(year %in% c(2003, 2004, 2005, 2006, 2007, 2008, 2009, 2010, 2011)) |>
  mutate(
    cbsa_code      = as.character(cbsa_code),
    year           = factor(year),
    tb_cases       = as.numeric(tb_cases),
    tb_rate_100k   = as.numeric(tb_rate_100k),
    median_aqi     = as.numeric(median_aqi),
    no2_annualmean = as.numeric(no2_annualmean)
  )
message(paste("Analysis dataset prepared:", nrow(project_data), "rows"))

# Data quality check
data_summary <- project_data |> 
  summarise(
    n_tb_rate_na = sum(is.na(tb_rate_100k)),
    n_aqi_na     = sum(is.na(median_aqi)),
    n_no2_na     = sum(is.na(no2_annualmean))
  )

message("Missing values:")
print(data_summary)
message("")

#-------------------------------
# 3) Download Geographic Boundaries
#-------------------------------

cbsa_sf <- core_based_statistical_areas(cb = TRUE, year = 2020) |>
  mutate(CBSAFP = as.character(CBSAFP)) |>
  st_make_valid() |>
  st_transform(4326)  # WGS84 coordinate system

states_sf_raw <- states(cb = TRUE, year = 2020) |>
  st_make_valid() |>
  st_transform(4326)

# Filter to continental US only (exclude Alaska, Hawaii, and territories)
# This improves rendering speed and focuses the visualization
continental_states <- c(
  "Alabama", "Arizona", "Arkansas", "California", "Colorado",
  "Connecticut", "Delaware", "Florida", "Georgia", "Idaho",
  "Illinois", "Indiana", "Iowa", "Kansas", "Kentucky",
  "Louisiana", "Maine", "Maryland", "Massachusetts",
  "Michigan", "Minnesota", "Mississippi", "Missouri",
  "Montana", "Nebraska", "Nevada", "New Hampshire",
  "New Jersey", "New Mexico", "New York", "North Carolina",
  "North Dakota", "Ohio", "Oklahoma", "Oregon",
  "Pennsylvania", "Rhode Island", "South Carolina",
  "South Dakota", "Tennessee", "Texas", "Utah", "Vermont",
  "Virginia", "Washington", "West Virginia", "Wisconsin", "Wyoming",
  "District of Columbia"
)

states_sf <- states_sf_raw |> 
  filter(NAME %in% continental_states)
message(paste("Filtered to", nrow(states_sf), "continental states\n"))

#-------------------------------
# 4) Join Data to Boundaries
#-------------------------------

message("Joining data to CBSA boundaries...")
merged_data <- cbsa_sf |>
  left_join(project_data, by = c("CBSAFP" = "cbsa_code"))

message(paste("Joined dataset contains", nrow(merged_data), "rows"))

# Check join success
n_matched <- merged_data |> filter(!is.na(year)) |> nrow()
message(paste("Successfully matched", n_matched, "CBSA-year combinations\n"))

#-------------------------------
# 5) Prepare Map-Specific Datasets
#-------------------------------
# Create separate datasets for each map to handle missing values appropriately

message("Preparing map-specific datasets...")

# Map 1: AQI only (polygons with AQI data)
map_aqi <- merged_data |> 
  drop_na(median_aqi)

# Map 2: TB rate only (points with TB data)
map_tb_pts <- cbsa_points |> 
  drop_na(tb_rate_100k)

# Map 3: AQI + TB combo (need both variables)
map_aqi_tb_poly <- merged_data |> 
  drop_na(median_aqi, tb_rate_100k)
map_aqi_tb_pts <- cbsa_points |> 
  drop_na(median_aqi, tb_rate_100k)

#-------------------------------
# 7) Define Theme and Coordinate System
#-------------------------------

# Custom theme for clean, journal-ready maps
theme_map_journal <- function() {
  theme_bw(base_size = 11) +
    theme(
      panel.grid.major = element_blank(),
      panel.grid.minor = element_blank(),
      panel.background = element_blank(),
      axis.title       = element_blank(),
      axis.text        = element_blank(),
      axis.ticks       = element_blank(),
      plot.title       = element_text(size = 14, face = "bold"),
      strip.background = element_rect(fill = "grey90", color = NA),
      strip.text       = element_text(size = 11, face = "bold"),
      legend.title     = element_text(size = 10),
      legend.text      = element_text(size = 9),
      legend.position  = "right",
      panel.spacing    = unit(0.7, "lines")
    )
}


# Coordinate system focused on continental US
coord_us <- coord_sf(
  xlim   = c(-125, -66),  # Longitude: West to East
  ylim   = c(24, 50),     # Latitude: South to North
  expand = FALSE
)


#-------------------------------
# FIGURE 1 — TB Rate with Gray Background CBSAs
#-------------------------------

# Create categorical TB levels
tb_summary <- merged_data |>
  filter(!is.na(tb_rate_100k)) |>
  st_drop_geometry() |>
  summarise(
    min_tb  = min(tb_rate_100k, na.rm = TRUE),
    max_tb  = max(tb_rate_100k, na.rm = TRUE),
    mean_tb = mean(tb_rate_100k, na.rm = TRUE),
    p90_tb  = quantile(tb_rate_100k, 0.90, na.rm = TRUE),
    p95_tb  = quantile(tb_rate_100k, 0.95, na.rm = TRUE)
  )

print(tb_summary)
map_tb_pts <- map_tb_pts |>
  mutate(
    tb_level = case_when(
      tb_rate_100k < 5 ~ "Low (<5)",
      tb_rate_100k < 10 ~ "Medium (5-10)",
      tb_rate_100k < 20 ~ "High (10-20)",
      TRUE ~ "Very High (20+)"
    ) |> factor(levels = c("Low (<5)", "Medium (5-10)", 
                           "High (10-20)", "Very High (20+)"))
  )

# Create background: ALL CBSAs (including those without AQI data)
cbsa_background <- merged_data |>
  filter(!is.na(year))  # Keep all CBSAs that have ANY data for each year

# Separate data layers
no_data_cbsas <- merged_data |>
  filter(!is.na(year), is.na(tb_rate_100k))

has_data_cbsas <- merged_data |>
  filter(!is.na(year), !is.na(tb_rate_100k)) |>
  mutate(
    tb_category = case_when(
      tb_rate_100k < 5 ~ "Low (<5)",
      tb_rate_100k < 10 ~ "Medium (5-10)",
      tb_rate_100k < 20 ~ "High (10-20)",
      TRUE ~ "Very High (20+)"
    ) |> factor(levels = c("Low (<5)", "Medium (5-10)", 
                           "High (10-20)", "Very High (20+)"))
  )

p_tb_final <- ggplot() +
  # Layer 1: No data areas with dashed borders
  geom_sf(data = no_data_cbsas, fill = "gray92", color = "gray50", 
          linewidth = 0.35, linetype = "dashed") +
  # Layer 2: Areas with TB data
  geom_sf(data = has_data_cbsas, aes(fill = tb_category), 
          color = "white", linewidth = 0.12) +
  # Layer 3: State boundaries
  geom_sf(data = states_sf, fill = NA, color = "gray20", linewidth = 0.5) +
  scale_fill_manual(
    name = "TB Rate\n(per 100,000)",
    values = c("Low (<5)" = "#00e400",
               "Medium (5-10)" = "#ffff00",
               "High (10-20)" = "#ff4800",
               "Very High (20+)" = "#ff0000"),
    labels = c("Low (<5)", "Medium (5-10)", "High (10-20)", "Very High (≥20)")
  ) +
  facet_wrap(~ year, ncol = 3) +
  labs(
    title = "Tuberculosis Incidence Rates by Core-Based Statistical Area, 2003-2011",
  ) +
  theme_map_journal() +
  theme(
    plot.title = element_text(size = 16, face = "bold", hjust = 0, margin = margin(b = 10)),
    plot.caption = element_text(hjust = 0, color = "gray40", size = 9, margin = margin(t = 8)),
    legend.key.size = unit(0.8, "cm"),  # Larger legend boxes
    strip.text = element_text(size = 12, face = "bold")  # Bigger year labels
  ) +
  coord_us

ggsave("TB_Rate_Final_2003_2011.png", p_tb_final, 
       width = 22, height = 15, dpi = 300, bg = "white")

#-------------------------------
# FIGURE 2 — Median AQI with Official Colors
#-------------------------------

# Separate data layers for AQI
no_aqi_data <- merged_data |>
  filter(!is.na(year), is.na(median_aqi))

has_aqi_data <- merged_data |>
  filter(!is.na(year), !is.na(median_aqi)) |>
  mutate(
    # Create AQI categories based on official EPA breakpoints
    aqi_category = case_when(
      median_aqi <= 50 ~ "Good - (0-50)",
      median_aqi <= 100 ~ "Moderate (51-100)",
      median_aqi <= 150 ~ "Unhealthy for Sensitive Groups (101-150)",
      median_aqi <= 200 ~ "Unhealthy (151-200)",
      median_aqi <= 300 ~ "Very Unhealthy (201-300)",
      TRUE ~ "Hazardous (301+)"
    ) |> factor(levels = c("Good (0-50)", 
                           "Moderate (51-100)", 
                           "Unhealthy for Sensitive Groups (101-150)",
                           "Unhealthy (151-200)",
                           "Very Unhealthy (201-300)",
                           "Hazardous (301+)"))
  )

# Check what AQI range you actually have
aqi_summary <- has_aqi_data |> 
  st_drop_geometry() |>
  summarise(
    min_aqi = min(median_aqi, na.rm = TRUE),
    max_aqi = max(median_aqi, na.rm = TRUE),
    mean_aqi = mean(median_aqi, na.rm = TRUE)
  )
print(aqi_summary)

# AQI map with official EPA colors
p_aqi_continuous <- ggplot() +
  geom_sf(data = no_aqi_data, fill = "gray92", color = "gray50", 
          linewidth = 0.35, linetype = "dashed") +
  geom_sf(data = has_aqi_data, aes(fill = median_aqi), 
          color = "white", linewidth = 0.12) +
  geom_sf(data = states_sf, fill = NA, color = "gray20", linewidth = 0.5) +
  # Continuous gradient using AQI colors
  scale_fill_gradientn(
    name = "Median AQI",
    colors = c("#00E400", "#FFFF00", "#FF7E00", "#FF0000", "#8F3F97"),
    values = scales::rescale(c(0, 50, 100, 150, 200)),  # Normalized breakpoints
    limits = c(0, 200),
    na.value = "gray80"
  ) +
  facet_wrap(~ year, ncol = 3) +
  labs(
    title = "Median Air Quality Index by Core-Based Statistical Area, 2003-2011",
    caption = "Note: Gray areas with dashed borders indicate CBSAs without available AQI data"
  ) +
  theme_map_journal() +
  theme(
    plot.title = element_text(size = 16, face = "bold", hjust = 0),
    plot.caption = element_text(hjust = 0, color = "gray40", size = 9),
    legend.key.height = unit(1.5, "cm"),
    legend.key.width = unit(0.5, "cm")
  ) +
  coord_us

ggsave("AQI_Continuous_Gradient.png", p_aqi_continuous, 
       width = 22, height = 15, dpi = 300, bg = "white")
#--------------------------------------------------
# FIGURE 3 - NO2 with Official Colors
#-------------------------------


no2_summary <- merged_data |>
  filter(!is.na(no2_annualmean)) |>
  st_drop_geometry() |>
  summarise(
    min_no2  = min(no2_annualmean, na.rm = TRUE),
    max_no2  = max(no2_annualmean, na.rm = TRUE),
    mean_no2 = mean(no2_annualmean, na.rm = TRUE)
  )

print(no2_summary)

#Separate data layers

no_no2_data <- merged_data |>
  filter(!is.na(year), is.na(no2_annualmean))

has_no2_data <- merged_data |>
  filter(!is.na(year), !is.na(no2_annualmean))

#NO2 map
p_no2_continuous <- ggplot() +
  # Layer 1: No NO2 data
  geom_sf(
    data = no_no2_data,
    fill = "gray92",
    color = "gray50",
    linewidth = 0.35,
    linetype = "dashed"
  ) +
  # Layer 2: CBSAs with NO2 data
  geom_sf(
    data = has_no2_data,
    aes(fill = no2_annualmean),
    color = "white",
    linewidth = 0.12
  ) +
  # Layer 3: State boundaries
  geom_sf(
    data = states_sf,
    fill = NA,
    color = "gray20",
    linewidth = 0.5
  ) +
  # SAME color ramp as AQI
  scale_fill_gradientn(
    name = expression(paste("Annual Mean NO"[2], " (ppb)")),
    colors = c("#00E400", "#FFFF00", "#FF7E00", "#FF0000"),
    values = scales::rescale(c(0, 10, 20, 30)),
    breaks = c(0, 5, 10, 15, 20, 25, 30),
    limits = c(0, 30),
    na.value = "gray80"
  ) +
  facet_wrap(~ year, ncol = 3) +
  labs(
    title = expression(
      paste("Annual Mean NO"[2], " by Core-Based Statistical Area, 2003-2011")
    ),
    caption = "Note: Gray areas indicate CBSAs without available NO₂ data"
  ) +
  theme_map_journal() +
  theme(
    plot.title = element_text(size = 16, face = "bold", hjust = 0),
    plot.caption = element_text(hjust = 0, color = "gray40", size = 9),
    legend.key.height = unit(1.5, "cm"),
    legend.key.width  = unit(0.5, "cm"),
    strip.text = element_text(size = 12, face = "bold")
  ) +
  coord_us

#save
ggsave(
  "NO2_Continuous_AQI_ColorScale_2003_2011.png",
  p_no2_continuous,
  width = 22, height = 15, dpi = 300, bg = "white"
)




