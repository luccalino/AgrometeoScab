# Load need library
library(utils)

# Save all pdfs for specific year to download folder
year = "2020"

for (i in 1:400) {
  browseURL(paste0("https://api.agrometeo.ch/venturia/stations/",i,"/report?year=",year), 
            browser = getOption("browser"),
            encodeIfNeeded = FALSE)
}

# Move all pdfs from download folder to data/pdf folder
files <- list.files(path = "C:/Users/zlucca/Downloads", 
                    pattern = paste0("-",year,".pdf"), 
                    full.names = TRUE, 
                    recursive = TRUE)

n <- length(files) # newest files
selected_files <- files[tail(order(file.mtime(files)), n)]

file.copy(from = selected_files, to = "2_data/1_pdf/", 
          overwrite = TRUE, 
          recursive = FALSE, 
          copy.mode = TRUE)

# Deleting corrupted files
ldir <-  normalizePath("2_data/1_pdf/")
file_inf <- file.info(dir(path = ldir, full.names = TRUE), extra_cols = FALSE)
files2remove <- subset(file_inf, size < 300)
file.remove(row.names(files2remove))

# Deleting files in download folder
file.remove(selected_files)


