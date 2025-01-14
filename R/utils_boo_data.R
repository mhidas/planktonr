#' Access data for timeseries and climatology plots
#'
#' @param Survey CPR or NRS, defaults to NRS
#' @param Type Phyto or zoo, defaults to phyto
#'
#' @return dataframe to use in pr_plot functions
#' @export
#'
#' @examples
#' df <- pr_get_tsdata("NRS", "Z")
pr_get_tsdata <- function(Survey = c("CPR", "NRS"), Type = c("P", "Z")){

  if(Type == "Z"){
    parameter1 <- "Biomass_mgm3"
    parameter2 <- "CopepodEvenness"
  }
  if(Type == "P" & Survey == "CPR")
  {
    parameter1 <- "PhytoBiomassCarbon_pgm3"
    parameter2 <- "DinoflagellateEvenness"
  }
  if(Type == "P" & Survey == "NRS"){
    parameter1 <- "PhytoBiomassCarbon_pgL"
    parameter2 <- "DinoflagellateEvenness"
  }

  if(Survey == 'CPR'){
    dat <- readr::read_csv(paste0(planktonr::pr_get_outputs(), "CPR_Indices.csv"), na = "NA", show_col_types = FALSE) %>%
      dplyr::select(.data$SampleDateUTC, .data$Year, .data$Month, .data$Day, .data$BioRegion, .data$Biomass_mgm3, .data[[parameter1]]:.data[[parameter2]]) %>%
      dplyr::mutate(Biomass_mgm3 = suppressWarnings(replace(.data$Biomass_mgm3, which(.data$Biomass_mgm3  < 0), 0)),
                    SampleDateUTC = lubridate::round_date(.data$SampleDateUTC, "month"),
                    YearMon = paste(.data$Year, .data$Month)) %>% # this step can be improved when nesting supports data pronouns
      tidyr::complete(.data$BioRegion, .data$YearMon) %>%
      dplyr::mutate(Year = as.numeric(stringr::str_sub(.data$YearMon, 1, 4)),
                    Month = as.numeric(stringr::str_sub(.data$YearMon, -2, -1))) %>%
      tidyr::pivot_longer(.data[[parameter1]]:.data[[parameter2]], values_to = "Values", names_to = 'parameters') %>%
      dplyr::group_by(.data$SampleDateUTC, .data$Year, .data$Month, .data$BioRegion, .data$parameters) %>%
      dplyr::summarise(Values = mean(.data$Values, na.rm = TRUE),
                       .groups = "drop") %>%
      pr_reorder() %>%
      dplyr::filter(!is.na(.data$BioRegion), !.data$BioRegion %in% c('North', 'North-west')) %>%
      droplevels()
    return(dat)
  } else
  {
   dat <- readr::read_csv(paste0(planktonr::pr_get_outputs(), "NRS_Indices.csv"), na = "NA", show_col_types = FALSE) %>%
      dplyr::mutate(Month = lubridate::month(.data$SampleDateLocal),
                    Year = lubridate::year(.data$SampleDateLocal),
                    StationCode = paste(.data$StationName, .data$StationCode),
                    SampleDateLocal = as.POSIXct(.data$SampleDateLocal, format = '%Y-%m-%d')) %>%
      #tidyr::complete(.data$Year, tidyr::nesting(Station, Code)) %>% # Nesting doesn't support data pronouns at this time
      tidyr::complete(.data$Year, .data$StationCode) %>%
      dplyr::mutate(StationName = stringr::str_sub(.data$StationCode, 1, -5),
                    StationCode = stringr::str_sub(.data$StationCode, -3, -1)) %>%
      dplyr::select(.data$Year, .data$Month, .data$SampleDateLocal, .data$StationName, .data$StationCode, .data[[parameter1]]:.data[[parameter2]]) %>%
      dplyr::select(-c(.data$Day, .data$Time_24hr)) %>%
      tidyr::pivot_longer(-c(.data$Year:.data$StationCode), values_to = 'Values', names_to = "parameters") %>%
      pr_reorder()
    return(dat)
  }
}

#' To produce the climatology for plotting
#'
#' @param df output of pr_get_tsdata
#' @param x Year, Month, Day, time period of climatology
#'
#' @return dataframe to use in pr_plot_climate functions
#' @export
#'
#' @examples
#' df <- data.frame(Month = rep(1:12,10), StationCode = 'NSI', Values = runif(120, min=0, max=10))
#' pr_make_climatology(df, Month)
#' @import dplyr
#' @importFrom stats sd
#' @importFrom magrittr "%>%"
#' @importFrom rlang .data
pr_make_climatology <- function(df, x){
  x <- dplyr::enquo(arg = x)
  df_climate <- df %>% dplyr::filter(!!x != 'NA') %>% # need to drop NA from month, added to dataset by complete(Year, StationCode)
    dplyr::group_by(!!x, .data$StationCode) %>%
    dplyr::summarise(mean = mean(.data$Values, na.rm = TRUE),
                     N = length(.data$Values),
                     sd = stats::sd(.data$Values, na.rm = TRUE),
                     se = sd / sqrt(.data$N),
                     .groups = "drop")
  return(df_climate)
}

#' Get functional group data
#'
#' @param Survey CPR or NRS data
#' @param Type Zooplankton or phytoplankton data
#'
#' @return dataframe for plotting functional group time series info
#' @export
#'
#' @examples
#' df <- pr_get_fg('NRS', 'P')
pr_get_fg <- function(Survey = 'NRS', Type = "Z"){
  if(Survey == 'CPR' & Type == 'P'){
    df <- pr_get_CPRPhytoHTG()
  }
  else if(Survey == 'NRS' & Type == 'P'){
    df <- pr_get_NRSPhytoHTG()
  }
  else if(Survey == 'CPR' & Type == 'Z'){
    df <- pr_get_CPRZooHTG()
  }
  else {
    df <- pr_get_NRSZooHTG() %>% dplyr::filter(.data$StationName != 'Port Hacking 4')
  }

  if(Type == 'P'){
    parameter1 <- 'Centric diatom'
    parameter2 <- 'Silicoflagellate'
  } else {
    parameter1 <- 'Amphipod'
    parameter2 <- colnames(df[ ,ncol(df)])
  }

  if(Survey == 'CPR'){
    df <- df %>%
      dplyr::select(.data$BioRegion, .data$SampleDateUTC, .data$Month, .data$Year, .data[[parameter1]]:.data[[parameter2]]) %>%
      dplyr::filter(!is.na(.data$BioRegion), !.data$BioRegion %in% c('North', 'North-west')) %>%
      droplevels()
  }
  else {
    df <- df %>%
      dplyr::select(.data$StationName, .data$StationCode, .data$SampleDateLocal, .data$Month, .data$Year, .data[[parameter1]]:.data[[parameter2]])
  }

  df <- df %>%
    tidyr::pivot_longer(.data[[parameter1]]:.data[[parameter2]], values_to = "Values", names_to = 'parameters')  %>%
    dplyr::mutate(Values = .data$Values + min(.data$Values[.data$Values>0], na.rm = TRUE)) %>%
    dplyr::filter(.data$parameters != 'Flagellate') %>%
    pr_reorder()

  if(Type == 'P'){
    df <- df %>%
      dplyr::mutate(parameters = ifelse(.data$parameters %in% c('Ciliate','Foraminifera', 'Radiozoa', 'Silicoflagellate'), 'Other', .data$parameters),
                    parameters = factor(.data$parameters, levels = c('Centric diatom', 'Pennate diatom', 'Dinoflagellate', 'Cyanobacteria',
                                                                    'Other'))) %>%
      dplyr::group_by_at(1:6) %>%
      dplyr::summarise(Values = sum(.data$Values, na.rm = TRUE),
                       .groups = 'drop') %>%
      dplyr::mutate(Values = ifelse(.data$Values < 1, 1, .data$Values))
  }
  if(Type == 'Z'){
    df <- df %>%
      dplyr::mutate(parameters = ifelse(.data$parameters %in% c('Copepod', 'Appendicularian', 'Mollusc', 'Cladoceran', 'Chaetognath', 'Thaliacean'), .data$parameters, 'Other'),
             parameters = factor(.data$parameters, levels = c('Copepod', 'Appendicularian', 'Mollusc', 'Cladoceran', 'Chaetognath', 'Thaliacean',
                                                              'Other'))) %>%
      dplyr::group_by_at(1:6) %>%
      dplyr::summarise(Values = sum(.data$Values, na.rm = TRUE),
                       .groups = 'drop') %>%
      dplyr::mutate(Values = ifelse(.data$Values < 1, 1, .data$Values))
  }

  return(df)
}

#' Get picoplankton time series data
#'
#' @return Dataframe for plotting picoplankton time series
#' @export
#'
#' @examples
#' df <- pr_get_pico()
pr_get_pico <- function(){
  pico <- pr_get_NRSPico() %>%
    dplyr::select(.data$TripCode, .data$SampleDateLocal, .data$SampleDepth_m, .data[["Prochlorococcus_Cellsml"]]:.data[["Picoeukaryotes_Cellsml"]]) %>%
    dplyr::mutate(StationCode = stringr::str_sub(.data$TripCode, 1, 3),
                  Year = lubridate::year(.data$SampleDateLocal),
                  Month = lubridate::month(.data$SampleDateLocal)) %>%
    planktonr::pr_get_StationName() %>%
    tidyr::pivot_longer(.data[["Prochlorococcus_Cellsml"]]:.data[["Picoeukaryotes_Cellsml"]], values_to = "Values", names_to = 'parameters')  %>%
    dplyr::mutate(Values = .data$Values + min(.data$Values[.data$Values>0], na.rm = TRUE)) %>%
    pr_reorder()
}


#' Get NRS nutrient timeseries data
#'
#' @return dataframe for plotting nutrient time series info
#' @export
#'
#' @examples
#' df <- pr_get_nuts()
pr_get_nuts <-  function(){
  Nuts <- readr::read_csv(paste0(planktonr::pr_get_site(), "BGC_Chemistry.csv"),
                          col_types = list(SAMPLEDATELOCAL = readr::col_datetime())) %>%
    dplyr::select_if(!grepl('FLAG', names(.)) & !grepl('COMMENTS', names(.)) & !grepl('MICROB', names(.))) %>%
    dplyr::filter(.data$PROJECTNAME == 'NRS') %>%
    pr_rename() %>%
    dplyr::mutate(StationCode = stringr::str_sub(.data$TripCode, 1, 3),
                  Month = lubridate::month(.data$SampleDateLocal)) %>%
    dplyr::select(-.data$TripCode) %>%
    tidyr::pivot_longer(.data$Salinity_psu:.data$Oxygen_umolL, values_to = "Values", names_to = 'parameters') %>%
    pr_get_StationName() %>%
    pr_reorder()
}

#' Get NRS long term nutrient timeseries data
#'
#' @return dataframe for plotting long term nutrient time series info
#' @export
#'
#' @examples
#' df <- pr_get_LTnuts()
pr_get_LTnuts <-  function(){
  NutsLT <- readr::read_csv(paste0(planktonr::pr_get_outputs(), "nuts_longterm_clean2.csv")) %>%
    tidyr::pivot_longer(-c(.data$StationCode:.data$SampleDepth_m), values_to = "Values", names_to = 'parameters') %>%
    dplyr::mutate(ProjectName = 'LTM',
                  SampleDateLocal = strptime(as.POSIXct(.data$SampleDateLocal), "%Y-%m-%d")) %>%
    pr_get_StationName() %>%
    pr_reorder()

  Nuts <- planktonr::pr_get_nuts() %>%
    dplyr::mutate(SampleDateLocal = strptime(.data$SampleDateLocal, "%Y-%m-%d")) %>%
    dplyr::filter(StationCode %in% c('MAI', 'ROT', 'PHB'))

  Temp <- planktonr::pr_get_CTD() %>%
    dplyr::mutate(StationCode = stringr::str_sub(.data$TripCode, 1, 3)) %>%
    dplyr::select(.data$StationCode, .data$StationName, .data$SampleDateLocal, .data$SampleDepth_m, .data$Temperature_degC) %>%
    dplyr::filter(StationCode %in% c('MAI', 'ROT', 'PHB')) %>%
      tidyr::pivot_longer(-c(.data$StationCode:.data$SampleDepth_m), values_to = "Values", names_to = 'parameters') %>%
      dplyr::mutate(ProjectName = 'NRS',
                    SampleDateLocal = strptime(as.POSIXct(.data$SampleDateLocal), "%Y-%m-%d"))

  LTnuts <- dplyr::bind_rows(NutsLT, Nuts, Temp) %>%
    dplyr::mutate(Year = lubridate::year(.data$SampleDateLocal),
                  Month = lubridate::month(.data$SampleDateLocal))

  means <- LTnuts %>%
    dplyr::select(.data$StationName, .data$parameters, .data$Values) %>%
    dplyr::group_by(.data$StationName, .data$parameters) %>%
    dplyr::summarise(means = mean(Values, na.rm = TRUE),
                     sd = stats::sd(Values, na.rm = TRUE),
                     .groups = 'drop')

  Pol <- LTnuts %>% dplyr::left_join(means, by = c("StationName", "parameters")) %>%
    dplyr::mutate(anomaly = (Values - means)/sd)

   }


#' Get NRS pigment timeseries data
#'
#' @return dataframe for plotting pigment time series info
#' @export
#'
#' @examples
#' df <- pr_get_pigs()
pr_get_pigs <-  function(){
  Pigs  <- readr::read_csv(paste0(planktonr::pr_get_site(), "BGC_Pigments.csv"),
                           col_types = list(PROJECTNAME = readr::col_character(),
                                            TRIP_CODE = readr::col_character(),
                                            SAMPLEDATELOCAL = readr::col_datetime(),
                                            SAMPLEDEPTH_M = readr::col_character(),
                                            .default = readr::col_double())) %>%
    dplyr::select_if(!grepl('FLAG', names(.)) & !grepl('COMMENTS', names(.))) %>%
    pr_rename() %>%
    dplyr::filter(.data$ProjectName == 'NRS', .data$SampleDepth_m != 'WC') %>%
    dplyr::rowwise() %>%
    dplyr::mutate(SampleDepth_m = as.numeric(.data$SampleDepth_m),
                  TotalChla = sum(.data$CPHLIDE_A, .data$DV_CPHL_A, .data$CPHL_A, na.rm = TRUE),
                  TotalChl = sum(.data$CPHLIDE_A, .data$DV_CPHL_A, .data$CPHL_A, .data$DV_CPHL_B, .data$CPHL_B, .data$CPHL_C3, .data$CPHL_C2, .data$CPHL_C1, na.rm = TRUE),
                  PPC = sum(.data$ALLO, .data$DIADCHR, .data$DIADINO, .data$DIATO, .data$ZEA,  na.rm = TRUE),#+ CARO, #Photoprotective Carotenoids
                  PSC = sum(.data$BUT_FUCO, .data$HEX_FUCO, .data$PERID,  na.rm = TRUE),#Photosynthetic Carotenoids
                  PSP = sum(.data$PSC, .data$TotalChl,  na.rm = TRUE),#Photosynthetic pigments
                  TCaro = sum(.data$PSC, .data$PSP,  na.rm = TRUE),#Total Carotenoids
                  TAcc = sum(.data$TCaro, .data$DV_CPHL_B, .data$CPHL_B, .data$CPHL_C3, .data$CPHL_C2, .data$CPHL_C1,  na.rm = TRUE),#Total Accessory pigments
                  TPig = sum(.data$TAcc, .data$TotalChla,  na.rm = TRUE),#Total pigments
                  TDP = sum(.data$PSC, .data$ALLO, .data$ZEA, .data$DV_CPHL_B, .data$CPHL_B,  na.rm = TRUE),#Total Diagnostic pigments
                  StationCode = stringr::str_sub(.data$TripCode, 1, 3),
                  Month = lubridate::month(.data$SampleDateLocal)) %>%
    dplyr::filter(.data$TotalChla != 0) %>%
    dplyr::select(.data$ProjectName:.data$SampleDepth_m, .data$TotalChla:.data$Month, -.data$TripCode)  %>%
    tidyr::pivot_longer(.data$TotalChla:.data$TDP, values_to = "Values", names_to = 'parameters') %>%
    pr_get_StationName() %>%
    pr_reorder()
}


#' Get data for frequency map plots
#' @param Type Phyto or zoo, defaults to phyto
#'
#' @return dataframe for plotting wiht pr_plot_fmap
#' @export
#'
#' @examples
#' df <- pr_get_fMap_data("P")
pr_get_fMap_data <-  function(Type = "Z"){
  if(Type == "P"){
    PhytoCountNRS <- planktonr::pr_get_NRSPhytoData() %>%
      dplyr::rename(Sample = .data$TripCode, Counts = .data$TaxonCount) %>%
      dplyr::filter(!is.na(.data$Species) & !grepl("cf.|spp.|grp", .data$Species) & .data$Genus != '') %>%
      dplyr::mutate(Taxon = paste0(stringr::word(.data$Genus,1), " ", stringr::word(.data$Species,1)),
                    Survey = 'NRS',
                    SampVol_m3 = .data$SampVol_L/1000) %>%
      dplyr::group_by(.data$Sample, .data$Survey, .data$Taxon, .data$SampVol_m3) %>%
      dplyr::summarise(Counts = sum(.data$Counts, na.rm = TRUE), .groups = "drop")

    PhytoCountCPR <- planktonr::pr_get_CPRPhytoData("Count") %>% # nned to think about FOV versus counts
      dplyr::rename(Counts = .data$FovCount) %>%
      dplyr::filter(!is.na(.data$Species) & !grepl("cf.|spp.|grp", .data$Species) & .data$Genus != '') %>%
      dplyr::mutate(Taxon = paste0(stringr::word(.data$Genus,1), " ", stringr::word(.data$Species,1)),
                    Survey = 'CPR') %>%
      dplyr::group_by(.data$Sample, .data$Survey, .data$Taxon, .data$SampVol_m3) %>%
      dplyr::summarise(Counts = sum(.data$Counts, na.rm = TRUE), .groups = "drop")

    obs <- dplyr::bind_rows(PhytoCountCPR, PhytoCountNRS) %>% dplyr::arrange(.data$Taxon)
  } else {
    ZooCountNRS <- planktonr::pr_get_NRSZooData() %>%
      dplyr::rename(Sample = .data$TripCode, Counts = .data$TaxonCount) %>%
      dplyr::filter(!is.na(.data$Species) & !grepl("cf.|spp.|grp", .data$Species) & .data$Genus != '') %>%
      dplyr::mutate(Taxon = paste0(stringr::word(.data$Genus,1), " ", stringr::word(.data$Species,1)),
                    Survey = 'NRS') %>%
      dplyr::group_by(.data$Sample, .data$Survey, .data$Taxon, .data$SampVol_m3) %>%
      dplyr::summarise(Counts = sum(.data$Counts, na.rm = TRUE), .groups = "drop")

    ZooCountCPR <- planktonr::pr_get_CPRZooData("Count") %>%
      dplyr::rename(Counts = .data$TaxonCount) %>%
      dplyr::filter(!is.na(.data$Species) & !grepl("cf.|spp.|grp", .data$Species) & .data$Genus != '') %>%
      dplyr::mutate(Taxon = paste0(stringr::word(.data$Genus,1), " ", stringr::word(.data$Species,1)),
                    Survey = 'CPR') %>%
      dplyr::group_by(.data$Sample, .data$Survey, .data$Taxon, .data$SampVol_m3) %>%
      dplyr::summarise(Counts = sum(.data$Counts, na.rm = TRUE), .groups = "drop")

    obs <- dplyr::bind_rows(ZooCountCPR, ZooCountNRS) %>% dplyr::arrange(.data$Taxon)
  }

  NRSSamp <- planktonr::pr_get_NRSTrips(Type) %>%
    dplyr::rename(Sample = .data$TripCode, Date = .data$SampleDateLocal) %>%
    dplyr::mutate(DOY = lubridate::yday(.data$Date),
                  Start = as.Date(paste0(min(lubridate::year(.data$Date))-1, "-12-31")),
                  days = difftime(as.Date(.data$Date), .data$Start, units = "days") %>% as.numeric(),
                  thetadoy = (.data$days %% 365.25)/365.25 * 2 * base::pi, ## leap years...
                  Survey = 'NRS')  %>%
    dplyr::select(.data$Sample, .data$Survey, .data$Date, .data$DOY, .data$Latitude, .data$Longitude, .data$thetadoy)

  CPRSamp <- planktonr::pr_get_CPRSamps(Type) %>%
    dplyr::rename(Date = .data$SampleDateUTC) %>%
    dplyr::mutate(DOY = lubridate::yday(.data$Date),
                  Start = as.Date(paste0(min(lubridate::year(.data$Date))-1, "-12-31")),
                  days = difftime(as.Date(.data$Date), .data$Start, units = "days") %>% as.numeric(),
                  thetadoy = (.data$days %% 365.25)/365.25 * 2 * base::pi, ## leap years...
                  Survey = 'CPR')  %>%
    dplyr::select(.data$Sample, .data$Survey, .data$Date, .data$DOY, .data$Latitude, .data$Longitude, .data$thetadoy)

  SampLocs <- dplyr::bind_rows(CPRSamp, NRSSamp) %>%
    dplyr::mutate(Lat = round(.data$Latitude), #/0.5, 0)*0.5,
                  Long = round(.data$Longitude), #/0.5, 0)*0.5,
                  Month = lubridate::month(.data$Date),
                  Season = ifelse(.data$Month >2 & .data$Month < 6, "March - May",
                                  ifelse(.data$Month >5 & .data$Month < 9, "June - August",
                                         ifelse(.data$Month > 8 & .data$Month < 12, "September - November", "December - February")))) %>%
    dplyr::select(.data$Sample, .data$Survey, .data$Lat, .data$Long, .data$Season)

  mapdata <- obs %>%
    dplyr::select(.data$Sample, .data$Taxon, .data$Counts) %>%
    dplyr::left_join(SampLocs, by="Sample") %>%
    tidyr::drop_na() %>%
    dplyr::group_by(.data$Season, .data$Taxon, .data$Lat, .data$Long) %>%
    dplyr::summarise(freq = dplyr::n(), .groups = "drop") %>%
    dplyr::left_join(SampLocs %>%  dplyr::group_by(.data$Lat, .data$Long, .data$Season) %>% dplyr::summarise(samples = dplyr::n(), .groups = "drop"), by=c("Lat", "Long", "Season")) %>%
    dplyr::ungroup() %>%
    dplyr::mutate(freqsamp = .data$freq/.data$samples,
                  freqfac = as.factor(ifelse(.data$freqsamp<0.375, "Seen in 25%",
                                             ifelse(.data$freqsamp>0.875, "100 % of Samples",
                                                    ifelse(.data$freqsamp>0.375 & .data$freqsamp<0.625, '50%', '75%')))),
                  Season = factor(.data$Season, levels = c("December - February","March - May","June - August","September - November")),
                  Taxon = as.factor(.data$Taxon)) %>%
    dplyr::select(.data$Season, .data$Lat, .data$Long, .data$Taxon, .data$freqsamp, .data$freqfac)

  absences <-  SampLocs %>%  dplyr::distinct(.data$Lat, .data$Long, .data$Season) %>%
    dplyr::mutate(Taxon = "Taxon",
                  freqsamp = 0,
                  freqfac = as.factor("Absent"))
  freqMapData <- dplyr::bind_rows(mapdata, absences)

  return(freqMapData)

}

#' Get data for plots of species abundance by day and night using CPR data
#' @param Type Phyto or zoo, defaults to phyto
#'
#' @return df to be sued with pr_plot_daynight
#' @export
#'
#' @examples
#' df <- pr_get_daynight("Z")
pr_get_daynight <- function(Type = c("P", "Z")){
  if(Type == "Z"){
    cprzdat <-  planktonr::pr_get_CPRZooCopepod()
  } else {
    cprzdat <-  planktonr::pr_get_CPRPhytoSpecies()
  }

  dates <- cprzdat %>%
    dplyr::select(.data$SampleDateUTC, .data$Latitude, .data$Longitude) %>%
    dplyr::rename(date = .data$SampleDateUTC, lat = .data$Latitude, lon = .data$Longitude) %>%
    dplyr::mutate(date = lubridate::as_date(.data$date))

  daynight <- suncalc::getSunlightTimes(data = dates,
                                        keep = c("sunrise", "sunset"),
                                        tz = 'UTC') %>%
    dplyr::bind_cols(cprzdat["SampleDateUTC"]) %>%
    dplyr::mutate(daynight = ifelse(.data$SampleDateUTC > .data$sunrise & .data$SampleDateUTC < .data$sunset, 'Day', 'Night'))

  cprzmon <- cprzdat %>% dplyr::bind_cols(daynight["daynight"]) %>%
    dplyr::select(.data[["Latitude"]]:.data[["Time_24hr"]], .data$daynight, everything()) %>%
    tidyr::pivot_longer(-c(.data[["Latitude"]]:.data[["daynight"]]), values_to = "Species_m3", names_to = 'Species') %>%
    dplyr::group_by(.data$Month, .data$daynight, .data$Species) %>%
    dplyr::summarise(Species_m3 = mean(.data$Species_m3, na.rm = TRUE),
                     .groups = 'drop')
}

#' Get data for STI plots of species abundance
#' @param Type Phyto or zoo, defaults to phyto
#'
#' @return df to be sued with pr_plot_sti
#' @export
#'
#' @examples
#' df <- pr_get_sti("P")
pr_get_sti <-  function(Type = c("P", "Z")){

  if(Type == "Z"){
     cprzdat <-  planktonr::pr_get_CPRZooCopepod()
     nrszdat <- planktonr::pr_get_NRSZooSpeciesCopepod()
     parameter <- "CopeAbundance_m3"
  } else {
    cprzdat <-  planktonr::pr_get_CPRPhytoSpecies()
    nrszdat <- planktonr::pr_get_NRSPhytoSpecies()
    parameter <- "PhytoAbundance_m3"
  }


  ## These will be replace with proper satelite data from extractions in time
  nrssat <- readr::read_csv("https://raw.githubusercontent.com/PlanktonTeam/IMOS_Toolbox/master/Plankton/RawData/NRS_SatData.csv",
                     show_col_types = FALSE) %>%
    rename(Latitude = .data$LATITUDE, Longitude = .data$LONGITUDE, SampleDateLocal = .data$SAMPLEDATE_LOCAL)
  cprsat <- readr::read_csv("https://raw.githubusercontent.com/PlanktonTeam/IMOS_Toolbox/master/Plankton/RawData/CPR_SatData.csv",
                     show_col_types = FALSE) %>%
    rename(Latitude = .data$LATITUDE, Longitude = .data$LONGITUDE, SampleDateUTC = .data$SAMPLEDATE_UTC)

  cpr <- cprzdat %>%
    tidyr::pivot_longer(-c(.data[["Latitude"]]:.data[["Time_24hr"]]), names_to = 'Species', values_to = parameter) %>%
    dplyr::left_join(cprsat, by = c("Latitude", "Longitude", "SampleDateUTC")) %>%
    dplyr::select(.data$Species, .data$SST, .data[[parameter]]) %>%
    dplyr::filter(!is.na(.data$SST) & .data[[parameter]] > 0) %>%
    dplyr::mutate(Project = 'cpr',
                  Species_m3 = .data[[parameter]] + min(.data[[parameter]][.data[[parameter]]>0], na.rm = TRUE))

  nrs <- nrszdat %>%
    tidyr::pivot_longer(-c(.data[["TripCode"]]:.data[["Time_24hr"]]), names_to = 'Species', values_to = parameter) %>%
    dplyr::left_join(nrssat, by = c("Latitude", "Longitude", "SampleDateLocal")) %>%
    dplyr::select(.data$Species, .data$SST, .data[[parameter]]) %>%
    dplyr::filter(!is.na(.data$SST) & .data[[parameter]] > 0) %>%
    dplyr::mutate(Project = 'nrs',
                  Species_m3 = .data[[parameter]] + min(.data[[parameter]][.data[[parameter]]>0], na.rm = TRUE))

  comball <- cpr %>% dplyr::bind_rows(nrs) %>%
    dplyr:: mutate(sst = round(.data$SST/0.5) * 0.5) %>%
    dplyr::arrange(.data$Species)
}


#' Summarise the plankton observations
#'
#' Summarise the plankton observations from the NRS and CPR.
#' @return a dataframe with a species summary
#' @export
#'
#' @examples
#' df <- pr_export_SppCount()
pr_export_SppCount <- function(){

  # First do Phytoplankton
  nrsP <- pr_get_NRSPhytoData() %>%
    mutate(TaxonName = stringr::str_c(.data$Genus, " ", .data$Species)) %>%  # Overwrite Taxon Name to remove the fluff
    select(.data$TaxonName, .data$SPCode, .data$TaxonCount) %>%
    tidyr::drop_na()

  cprP <- pr_get_CPRPhytoData("Count") %>%
    mutate(TaxonName = stringr::str_c(.data$Genus, " ", .data$Species)) %>%  # Overwrite Taxon Name to remove the fluff
    rename(TaxonCount = .data$FovCount) %>%
    select(.data$TaxonName, .data$SPCode, .data$TaxonCount) %>%
    tidyr::drop_na()

  outP <- bind_rows(nrsP, cprP) %>%
    group_by(.data$TaxonName, .data$SPCode) %>%
    summarise(n = n(), .groups = "drop") %>%
    arrange(desc(.data$n)) %>%
    dplyr::filter(stringr::str_detect(.data$TaxonName, 'spp', negate = TRUE)) %>%
    mutate(Group = "Phytoplankton")

  # Now do Zooplankton
  nrsZ <- pr_get_NRSZooData() %>%
    mutate(TaxonName = stringr::str_c(.data$Genus, " ", .data$Species)) %>%  # Overwrite Taxon Name to remove f/m/j etc
    select(.data$TaxonName, .data$SPCode, .data$TaxonCount) %>%
    tidyr::drop_na()

  cprZ <- pr_get_CPRZooData("Count") %>%
    mutate(TaxonName = stringr::str_c(.data$Genus, " ", .data$Species)) %>%  # Overwrite Taxon Name to remove f/m/j etc
    select(.data$TaxonName, .data$SPCode, .data$TaxonCount) %>%
    tidyr::drop_na()

  outZ <- bind_rows(nrsZ, cprZ) %>%
    group_by(.data$TaxonName, .data$SPCode) %>%
    summarise(n = n(), .groups = "drop") %>%
    arrange(desc(.data$n)) %>%
    dplyr::filter(stringr::str_detect(.data$TaxonName, 'spp', negate = TRUE)) %>%
    mutate(Group = "Zooplankton")

  # Now combine them
  out <- bind_rows(outP, outZ)
  return(out)

}


#' Get the summary plankton observations
#'
#' Get the summary plankton observations from the NRS and CPR.
#' @return a dataframe with a species summary
#'
#' @param gp The group of plankton requested. Either "Zooplankton" or "Phytoplankton"
#'
#' @export
#'
#' @examples
#' df <- pr_get_SppCount("Zooplankton")
pr_get_SppCount <- function(gp){

  out <- sppSummary %>%
    filter(.data$Group == gp)

}


#' Random facts about plankton
#'
#' This function randomly returns a fun fact about plankton.
#'
#' @return
#' @export
#'
#' @examples
#' pr_get_facts()
pr_get_facts <- function(){

  facts <- list("Phytoplankton generate > 50 % of the worlds oxygen (reference)",
                "Phytoplankton generate > 50 % of the worlds oxygen (reference)",
                "Phytoplankton generate > 50 % of the worlds oxygen (reference)")

  r <- round(stats::runif(1, min = 1, max = length(facts)))

  out <- facts[[r]]

}




#' Random scientific papers using IMOS data
#'
#' This function randomly returns a publication that uses the IMOS plankton data
#'
#' @return
#' @export
#'
#' @examples
#' pr_get_papers()
pr_get_papers <- function(){

  papers <- list(
    "Campbell MD, Schoeman DS, Venables W, Abu-Alhaija R, Batten SD, Chiba S, et al. Testing Bergmann\'s rule in marine copepods. Ecography. 2021;n/a(n/a). doi: https://doi.org/10.1111/ecog.05545.",
    "Ajani P, Davies C, Eriksen R, Richardson A. Global Warming Impacts Micro-Phytoplankton at a Long-Term Pacific Ocean Coastal Station. Frontiers in Marine Science. 2020;7. doi:  https:// doi.org/10.3389/fmars.2020.576011 . PubMed PMID: WOS:000580605700001.",
    "Hallegraeff G, Eriksen R, Davies C, Slotwinski A, McEnnulty F, Coman F, et al. The marine planktonic dinoflagellate Tripos: 60 years of species-level distributions in Australian waters. Australian Systematic Botany. 2020;33(4):392-411. doi: https:// doi.org/10.1071/SB19043. PubMed PMID: WOS:000548434100004.",
    "Landry MR, Hood RR, Davies CH. Mesozooplankton biomass and temperature-enhanced grazing along a 110\U00B0E transect in the eastern Indian Ocean. Marine Ecology Progress Series. 2020;649:1-19. DOI: https://doi.org/10.3354/meps13444",
    "McCosker E, Davies C, Beckley L. Oceanographic influence on coastal zooplankton assemblages at three IMOS National Reference Stations in Western Australia. Marine and Freshwater Research. 2020;71(12):1672-85. doi: https:// doi.org/10.1071/MF19397. PubMed PMID: WOS:000556426000001.",
    "McEnnulty F, Davies C, Armstrong A, Atkins N, Coman F, Clementson L, et al. A database of zooplankton biomass in Australian marine waters. Scientific Data. 2020;7(1). doi: https://doi.org/10.1038/s41597-020-00625-9. PubMed PMID: WOS:000571812600010.",
    "Robson B, Skerratt J, Baird M, Davies C, Herzfeld M, Jones E, et al. Enhanced assessment of the eReefs biogeochemical model for the Great Barrier Reef using the Concept/State/Process/System model evaluation framework. Environmental Modelling & Software. 2020;129. doi: https:// doi.org/10.1016/j.envsoft.2020.104707. PubMed PMID: WOS:000540077900007.",
    "Bailey K, Steinberg C, Davies C, Galibert G, Hidas M, McManus M, et al. Coastal Mooring Observing Networks and Their Data Products: Recommendations for the Next Decade. Frontiers in Marine Science. 2019;6. doi: https:// doi.org/10.3389/fmars.2019.00180. PubMed PMID: WOS:000464606500001.",
    "Berry T, Saunders B, Coghlan M, Stat M, Jarman S, Richardson A, et al. Marine environmental DNA biomonitoring reveals seasonal patterns in biodiversity and identifies ecosystem responses to anomalous climatic events. Plos Genetics. 2019;15(2). doi: https://doi.org/10.1371/journal.pgen.1007943. PubMed PMID: WOS:000459970100030.",
    "Eriksen R, Davies C, Bonham P, Coman F, Edgar S, McEnnulty F, et al. Australia\'s Long-Term Plankton Observations: The Integrated Marine Observing System National Reference Station Network. Frontiers in Marine Science. 2019;6. doi: https:// doi.org/10.3389/fmars.2019.00161. PubMed PMID: WOS:000465444800001.",
    "Skerratt J, Mongin M, Baird M, Wild-Allen K, Robson B, Schaffelke B, et al. Simulated nutrient and plankton dynamics in the Great Barrier Reef (2011-2016). Journal of Marine Systems. 2019;192:51-74. doi: https:// doi.org/10.1016/j.jmarsys.2018.12.006. PubMed PMID: WOS:000459523000005.",
    "Brown MV, van de Kamp J, Ostrowski M, Seymour JR, Ingleton T, Messer LF, et al. Systematic, continental scale temporal monitoring of marine pelagic microbiota by the Australian Marine Microbial Biodiversity Initiative. Scientific Data. 2018;5(1):180130. doi: https:// doi.org/10.1038/sdata.2018.130.",
    "Davies C, Ajani P, Armbrecht L, Atkins N, Baird M, Beard J, et al. A database of chlorophyll a in Australian waters. Scientific Data. 2018;5. doi: https:// doi.org/10.1038/sdata.2018.18. PubMed PMID: WOS:000425502700003.",
    "Dornelas M, Antao L, Moyes F, Bates A, Magurran A, Adam D, et al. BioTIME: A database of biodiversity time series for the Anthropocene. Global Ecology and Biogeography. 2018;27(7):760-86. doi: https:// doi.org/10.1111/geb.12729. PubMed PMID: WOS:000439785700001.",
    "Everett J, Baird M, Buchanan P, Bulman C, Davies C, Downie R, et al. Modeling What We Sample and Sampling What We Model: Challenges for Zooplankton Model Assessment. Frontiers in Marine Science. 2017;4. doi: https:// doi.org/10.3389/fmars.2017.00077. PubMed PMID: WOS:000457690600077.",
    "Kelly P, Clementson L, Davies C, Corney S, Swadling K. Zooplankton responses to increasing sea surface temperatures in the southeastern Australia global marine hotspot. Estuarine Coastal and Shelf Science. 2016;180:242-57. doi: https:// doi.org/10.1016/j.ecss.2016.07.019. PubMed PMID: WOS:000384866900024.",
    "Davies CH, Armstrong AJ, Baird M, Coman F, Edgar S, Gaughan D, et al. Over 75 years of zooplankton data from Australia. Ecology. 2014;95(11):3229-. doi: https:// doi.org/10.1890/14-0697.1.",
    "Hallegraeff G, Coman F, Davies C, Hayashi A, McLeod D, Slotwinski A, et al. Australian Dust Storm Associated with Extensive Aspergillus sydowii Fungal Bloom in Coastal Waters. Applied and Environmental Microbiology. 2014;80(11):3315-20. doi: https:// doi.org/10.1128/AEM.04118-13. PubMed PMID: WOS:000336035200004."
  )

  r <- round(stats::runif(1, min = 1, max = length(papers)))

  out <- papers[[r]]

}
