# Loading packages (install if not yet installed)
if (!require("pacman")) install.packages("pacman")
pacman::p_load(tidyverse, hrbrthemes, lubridate, ggpubr, sf, rgdal)

# Clear environment to start from a white page
remove(list = ls())

# Data preparation ######################################################

# Get files
temp = list.files(path = "2_data/2_csv/", pattern="*.csv")
myfiles = lapply(paste0("2_data/2_csv/", temp), read.csv) 
data <- do.call(rbind, myfiles)

# Specify type
data <- data %>%
  select(date, station, simscab, temp, preci) %>%
  mutate(type = "scab")

# Generate date variable
data$new_date <- as.Date(data$date, "%d.%m.%Y")
data$week <- strftime(data$new_date, format = "%Y%V")
data$year <- strftime(data$new_date, format = "%Y")
data$q <- quarter(data$new_date)

# Reformat variables
data$simscab <- as.numeric(data$simscab)

data$temp_new <- NA
for (i in 1:nrow(data)) {
  if (str_detect(data$temp[i], "\n") == TRUE) {
    data$temp_new[i] <- substring(data$temp[i], as.numeric(gregexpr(pattern = "\n", data$temp[i])) + 1, nchar(data$temp[i]))
  } else {
    data$temp_new[i] <- data$temp[i]
  }
}

data$temp_new <- as.numeric(data$temp_new)
data$preci <- as.numeric(data$preci)

## Station level
station_data <- data %>%
  group_by(station) %>%
  summarise(avg_simscab = mean(simscab), 
            sum_simscab = sum(simscab),
            avg_temp = mean(temp_new, na.rm = TRUE),
            avg_preci = mean(preci))
  
save(station_data, file = "2_data/station_data.RData")

# Combine station level data
load("2_data/stations.RData")
df$name <- tolower(df$name)
df <- df %>%
  select(name, lat_ch, lon_ch, lat, lon)
df$name <- gsub("-","_",df$name)
df$name[df$name == "bad ragaz"] <- "bad_ragaz"

station_data <- merge(station_data, df, by.x = "station", by.y = "name")

save(station_data, file = "2_data/merged_station_data.RData")

# Plotting ###############################################################

## Regional
station_data$lat <- as.numeric(station_data$lat)
station_data$lon <- as.numeric(station_data$lon)

# Convert coordinates from WGS 84 to LV95  
coordinates(station_data) <- c("lon", "lat")
proj4string(station_data) <- CRS("+init=epsg:4326") # WGS 84
CRS.new <- CRS("+proj=somerc +lat_0=46.95240555555556
+lon_0=7.439583333333333 +k_0=1 +x_0=600000 +y_0=200000
+ellps=bessel +towgs84=674.374,15.056,405.346,0,0,0,0 +units=m +no_defs")
station_data <- spTransform(station_data, CRS.new)
station_data <- as.data.frame(station_data)

# Auxilliary data
canton_data <- st_read("2_data/swissBOUNDARIES3D_1_3_TLM_KANTONSGEBIET.shp")
canton_data <- st_transform(canton_data, CRS.new)
country_data <- st_read("2_data/swissBOUNDARIES3D_1_3_TLM_LANDESGEBIET.shp")
country_data <- st_transform(country_data, CRS.new)

# Lakes
lakes <- readOGR(dsn = "2_data/22_DKM500_GEWAESSER_PLY.shp", stringsAsFactors = F)
lakes <- spTransform(lakes, CRS.new)

lakes@data$seq_id <- seq(1:nrow(lakes@data))
lakes@data$id <- rownames(lakes@data)
lakes_data <- fortify(lakes, region = "id")
lakes_df <- merge(lakes_data, lakes@data, by = "id")

qq = quantile(lakes_df$SHP_AREA, probs = seq(0, 1, .25))

lakes_df <- subset(lakes_df, lakes_df$SHP_AREA >= qq[3])
lakes_df <- subset(lakes_df, NAMN1 != "Lago di Garda" & NAMN1 != "Lac d'Annecy" & NAMN1 != "Lago di Como / Lario" & 
                     NAMN1 != "Schluchsee" & NAMN1 != "Forggensee" & NAMN1 != "Lago d'Iseo" & NAMN1 != "Lago di Varese" &
                     NAMN1 != "Lago d'Orta" & NAMN1 != "Lago di Comabbio" & NAMN1 != "Lago di Pusiano" & NAMN1 != "Lago di Annone" & 
                     NAMN1 != "Lago Didro" & NAMN1 != "Lac de Saint-Point" & NAMN1 != "Lago di Mezzola")

lakes_df <- subset(lakes_df, long < 834119.5)

# Spatial plot
station_data <- station_data %>%
  filter(avg_simscab < 10)

spatial_plot <- ggplot() +
  geom_sf(data = canton_data, alpha = 0.9, color = "darkgrey") +
  geom_sf(data = subset(country_data, NAME == "Schweiz"), alpha = 0.5, fill = NA, color = "black", size = 0.75) +
  geom_polygon(data = lakes_df,
               aes(long, lat, group = group), color = 'skyblue', fill = 'skyblue', size = 0.025, alpha = 1, show.legend = FALSE) +
  geom_point(data = station_data, aes(x = lon, y = lat, fill = avg_simscab), shape = 21, color = "black", size = 3.25) +
  scale_fill_gradient(name = "Average simulated apple scab infection risk", low = "lightgreen", high = "darkred") +
  theme_minimal() + 
  theme(legend.position = "bottom") +
  labs(x = NULL, 
       y = NULL) 

ggsave(plot = spatial_plot, 
       width = 300, 
       height = 200, 
       units = "mm", 
       dpi = 300, 
       bg = "white",
       filename = "3_output/spatial_plot.png")

## Time series
time_series <- data %>%
  filter(simscab < 500) %>%
  group_by(new_date) %>%
  summarise(avg_simscab = mean(simscab))

time_series_plot <- ggplot(data = time_series) + 
  geom_area(mapping = aes(x = new_date, y = avg_simscab), fill= "grey", alpha = 0.5) +
  geom_line(mapping = aes(x = new_date, y = avg_simscab), color= "black", size = 1) + 
  xlab("") +
  scale_x_date(date_breaks = "2 month", date_labels = "%B %Y") +
  theme_ipsum() +
  theme(axis.text.x = element_text(angle = 45, hjust=1),
        axis.title.y = element_text(size = 15),
        axis.title.y.right = element_text(color = "white"),
        axis.text.y.right = element_text(color = "white")) +
  scale_y_continuous("Simulated apple scab infection risk") 

ggsave(plot = time_series_plot, 
       width = 300, 
       height = 200, 
       units = "mm", 
       dpi = 300, 
       bg = "white",
       filename = "3_output/time_series_plot.png")

