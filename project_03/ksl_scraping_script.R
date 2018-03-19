library(RSelenium)
library(rvest)
library(tidyverse)
library(stringr)

pJS <- phantom()
remDr <- remoteDriver(browserName = "phantomjs")
remDr$open(silent = FALSE)

remDr$navigate("https://www.ksl.com/auto/search/index?p=&keyword=Minivan&make[]=Honda&model[]=Odyssey&miles=10000&page=0&perPage=96")
page0.html <- read_html(remDr$getPageSource()[[1]])
# Get number of pages there are of results so we can know how many times to loop
# Subtract 1 because pages are zero indexed
page.num <- page0.html %>% 
  html_node(css = ".link:nth-child(7)") %>% 
  html_text() %>% 
  as.numeric() - 1

# Create empty vector to collect all the links to all the results
links.vector <- vector("character", 0)

# Loop through all the pages and collect the links to all the returned results
for (i in 0:page.num) {
  site <- glue::glue("https://www.ksl.com/auto/search/index?p=&keyword=Minivan&make[]=Honda&model[]=Odyssey&miles=10000&page={i}&perPage=96")
  print(site)
  remDr$navigate(site)
  page.html <- read_html(remDr$getPageSource()[[1]])
  links.vector <- page.html %>%
    html_nodes(css = '.title .link , .featured-listing-title .link')%>% # //*[@id="specificationsTable"]
    html_attr("href") %>% 
    append(links.vector, .)
}

# Create empty vector to store individual car data
cars.vector <- vector("character", 0)

# Loop through all the links and collect the data that's in the
# the table for all pages
for(i in seq(1, length(links.vector))) {
  site <- glue::glue("https://www.ksl.com{links.vector[i]}")
  remDr$navigate(site)
  print(site)
  car.html <-  read_html(remDr$getPageSource()[[1]])
  
  # We need car name
  car.name <- car.html %>% 
    html_nodes(".title .cXenseParse") %>% 
    html_text() %>% 
    str_replace_all("\n| ","") %>% 
    paste0("Name:",.)
  
  # We also need car price
  car.price <- car.html %>% 
    html_nodes(xpath = '//*[(@id = "titleMain")]//*[contains(concat( " ", @class, " " ), concat( " ", "price", " " ))]') %>% 
    html_text() %>% 
    parse_number() %>% 
    paste0("Price:",.)
  
  # Here is where we collect the table data
  cars.vector <- car.html %>%
    html_nodes(xpath = '//*[@id="specificationsTable"]')%>%
    html_text() %>% 
    str_replace_all("\n| ","") %>% 
    str_split("\\s") %>% 
    unlist() %>% 
    append(., c(car.name, car.price)) %>% 
    append(cars.vector, .)
}

# Shut down the headless browser
remDr$close()
pJS$stop()

# We now need to clean up our data
dat <- cars.vector %>% 
  tibble(vec = .) %>% 
  separate(vec, into = c("var", "value"), sep = ":") %>% 
  na.omit() %>%
  group_by(var) %>% 
  do(tibble::rowid_to_column(.)) %>% 
  spread(var, value) %>% 
  filter(!Mileage %in% "notspecified",
         !ExteriorColor %in% c("NotSpecified", NA),
         !TitleType %in% "NotSpecified") %>% 
  mutate_at(c("Mileage", "Price", "Year"), parse_number) %>% 
  mutate_at(c("ExteriorColor","InteriorColor","TitleType","Trim"), factor) %>% 
  mutate(Trim = str_replace(Trim, "TOURING", "Touring")) %>% 
  select(Price, Mileage, everything(), 
         -c(DealerLicense, rowid, VIN, StockNumber, 
            Body, Cylinders, DriveType, FuelType, Liters,
            Make, Model, NumberofDoors, Transmission))

saveRDS(cars.vector, here::here("project_03/cars_vector.rds"))
saveRDS(dat, here::here("project_03/scrape_data.rds"))

cars.lm <- lm(Price ~ Mileage + TitleType, dat)
plot(cars.lm)
summary(cars.lm)
