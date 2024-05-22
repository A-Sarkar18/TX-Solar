# Texas Solar Potential Analysis

# Script Name: TX_solar_data.R
# Purpose: Perform exploratory data analysis on Texas solar MW 
# production, solar facility location, and potential PV productivity
# Author: Ayan Sarkar
# Date: May 23, 2024

#Load in relevant libraries
library(ggplot2)
library(dplyr)
library(readr)
library(tidyr)
library(knitr)
library(lubridate)
library(stringr)
library(scales)
library(sf)

#Set Working Directory
setwd('/Users/ayansarkar/Desktop/Solar')

#Read in SEIA Solar Capacity Data for the US
solar_df <- read.csv('SEIA_solar_state.csv')

#Load US Shape file
usa <- sf::st_read("States_shapefile.shp")

#Subset to just Contiguous USA
usa <- usa %>% 
  filter(!(State_Name %in% c("ALASKA", "HAWAII"))) %>% 
  rename(NAME = State_Name)
solar_df <- solar_df %>% 
  filter(!(NAME %in% c("Alaska", "Hawaii")))

#Prepare for merge 
usa <- usa %>% 
  mutate(NAME = str_to_title(NAME))

#Merge to attach geo data on SEIA Capacity data
solar_usa <- merge(solar_df, usa, by = "NAME", all = TRUE)
solar_usa <- solar_usa[!is.na(solar_usa$Solar_Jobs), ]
rownames(solar_usa) <- NULL

# Convert to sf object if necessary
if (!inherits(solar_usa, "sf")) {
  solar_usa <- st_as_sf(solar_usa)
}

# Ensure that the geometry column is set
if (is.null(st_geometry(solar_usa))) {
  st_geometry(solar_usa) <- solar_usa$geometry
}

# Check the CRS and align if necessary
if (st_crs(usa) != st_crs(solar_usa)) {
  solar_usa <- st_transform(solar_usa, st_crs(usa))
}

# Example code to create the US MW Solar Capacity Map with a logarithmic scale for the map values and original numbers for the legend
ggplot() +
  geom_sf(data = usa, color = alpha("black", 1), fill = "white", alpha = 0) +
  geom_sf(data = solar_usa, aes(fill = MW_Installed), color = alpha("white", 0)) + 
  scale_fill_continuous(trans = "log10", 
                        breaks = c(1, 10, 100, 1000, 10000), # Adjust breaks as needed
                        labels = scales::comma,
                        low = alpha("white", 1), # Set low color to white
                        high = alpha("darkgreen", 1)) + # Set high color to dark green
  labs(title = "A. U.S. Solar MW Capacity Installed") +
  theme_minimal() +
  theme(panel.grid.major = element_blank(), 
        panel.grid.minor = element_blank(),
        axis.text = element_blank(),
        axis.title = element_blank(),
        axis.ticks = element_blank(),
        panel.border = element_blank(),
        plot.title = element_text(hjust = 0.5, family = 'Helvetica', face = 'bold')) +
  guides(fill = guide_colorbar(title = "MW Installed", barwidth = 1, barheight = 10, label.position = "right"))

#Read in shape file of US Solar facilities geopoints from US. Phototvoltaic Database (uspvdb)
sol_loc <- sf::st_read("uspvdb_v1_0_20231108.shp")

#Subset for just TX
sol_loc <- sol_loc[sol_loc$p_state == "TX", ]

#Load in Texas County-level & state outline shape files
tex_out <- sf::st_read("State.shp")
tex <-sf::st_read("Tx_CntyBndry_Detail_TIGER500k.shp")

#Ensure matching CRS
if (!identical(st_crs(sol_loc), st_crs(tex))) {
  sol_loc <- st_transform(sol_loc, st_crs(tex))
}
sol_loc <- st_make_valid(sol_loc)
sol_loc <- st_intersection(sol_loc, tex)

#Read in solar potential data from Global Solar Atlas (GSA) processed in Python via Google Earth Engine
sopot <- read.csv('solar_potential_mean.csv')

#Prepare for merge
sopot <- sopot %>%
  rename(NAME = ADM2_NAME)
tex <- tex %>%
  mutate(NAME = gsub(" County", "", NAME))

#Attach geo data onto the GSA solar potential data
sopot <- merge(sopot, tex, by = "NAME", all = TRUE)

#Esnure geometries are present & set as sf objects
ensure_sf <- function(obj, crs = 4326) {
  if (!inherits(obj, "sf")) {
    if ("geometry" %in% colnames(obj)) {
      obj <- st_as_sf(obj)
    } else {
      stop("Object does not have geometry information.")
    }
  }
  obj <- st_transform(obj, crs)
  return(obj)
}
tex <- ensure_sf(tex)
sopot <- ensure_sf(sopot)
tex_out <- ensure_sf(tex_out)

#Prep legend gradient bar for aesthetics
min_val <- min(sopot$mean, na.rm = TRUE)
max_val <- max(sopot$mean, na.rm = TRUE)

# Create the plot with the color gradient showing only the lowest and highest values
ggplot() +
  geom_sf(data = tex, color = alpha("white", 0), fill = "black", alpha = 0) +
  geom_sf(data = sopot, aes(fill = mean), color = alpha("white", 0)) +
  scale_fill_gradient(low = alpha("yellow", 0.5), high = alpha("red", 1), name = "kWh/kWp",
                      limits = c(min_val, max_val),
                      breaks = c(min_val, max_val),
                      labels = c(round(min_val, 2), round(max_val, 1))) +
#  geom_point(data = sol_loc, aes(x = xlong, y = ylat), 
#             color = "black", shape = 16, size = 2, alpha = 0.5) +  # Adjust color and size
  geom_sf(data = tex_out, color = alpha("black", 1), fill = "white", alpha = 0) +
  labs(title = "B. Texas Daily Average PV Power Potential 1999 - 2018") +
  theme_minimal() +
  theme(panel.grid.major = element_blank(), 
        panel.grid.minor = element_blank(),
        axis.text = element_blank(),
        axis.title = element_blank(),
        axis.ticks = element_blank(),
        panel.border = element_blank(),
        plot.title = element_text(hjust = 0.25, family = "Helvetica", face = "bold")) +
  guides(fill = guide_colorbar(title = "kWh/kWp", title.theme = element_text(family = "Helvetica"), barwidth = 1, barheight = 10, size = 10, label.position = "right"))

#Plot locations and capacities of solar facilities in TX from U.S PV Database
ggplot() +
  geom_sf(data = tex, color = alpha("white", 0), fill = "#EEECDF", alpha = 1) +
  geom_point(data = sol_loc, aes(x = xlong, y = ylat, color = p_cap_ac, size = p_cap_ac), 
             shape = 16, alpha = 0.8) +  # Adjust alpha if needed
  scale_color_gradient(name = "Capacity (MW)", low = "yellow", high = "red") +
  scale_size_continuous(name = "Capacity (MW)", range = c(2, 12)) +
  geom_sf(data = tex_out, color = alpha("black", 1), fill = "white", alpha = 0) +
  labs(title = "C. Texas Solar Facility Total Rated Capacity")  +
  theme_minimal() +
  theme(panel.grid.major = element_blank(), 
        panel.grid.minor = element_blank(),
        axis.text = element_blank(),
        axis.title = element_blank(),
        axis.ticks = element_blank(),
        panel.border = element_blank(),
        plot.title = element_text(hjust = 0.5, family="Helvetica", face = "bold"),
        legend.text = element_text(size = 10, family="Helvetica")) +
  guides(color = guide_legend(), size = guide_legend()) +
  theme(legend.position = "right")

