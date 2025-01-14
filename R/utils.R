## Functions for operating


#' Get location of raw plankton data
#'
#' Internal function to load the location of the raw plankton data files.
#' @return A string with location of raw plankton data
#' @export
#' @examples
#' file_loc <- pr_get_site()
#' @import dplyr
#' @importFrom magrittr "%>%"
#' @importFrom rlang .data
pr_get_site <- function(){
  raw <- "https://raw.githubusercontent.com/PlanktonTeam/IMOS_Toolbox/master/Plankton/RawData/"
}

#' Get location of output plankton data
#'
#' Internal function to load the location of the raw plankton data files.
#' @return A string with location of raw plankton data
#' @export
#' @examples
#' file_loc <- pr_get_outputs()
#' @import dplyr
#' @importFrom magrittr "%>%"
#' @importFrom rlang .data
pr_get_outputs <- function(){
  raw <- "https://raw.githubusercontent.com/PlanktonTeam/IMOS_Toolbox/master/Plankton/Output/"
}


#' Load copepod information table with sizes etc.
#'
#' @return A dataframe with NRS zooplankton information
#' @export
#'
#' @examples
#' df <- pr_get_ZooInfo()
#' @import dplyr
#' @importFrom magrittr "%>%"
#' @importFrom rlang .data
pr_get_ZooInfo <- function(){
  ZInfo <- readr::read_csv(paste0(pr_get_site(), "ZoopInfo.csv"), na = "", show_col_types = FALSE) %>%
    pr_rename()
}



#' Add StationName to data
#'
#' @param df A dataframe that contains `StationCode` but no `StationName`
#' @return A dataframe with StationName added
#' @export
#'
#' @examples
#' df <- pr_get_NRSStation() %>%
#'     pr_get_StationName()
#' @import dplyr
#' @importFrom magrittr "%>%"
#' @importFrom rlang .data
pr_get_StationName <- function(df){
  df <- df %>%
    mutate(StationName = case_when(
      StationCode == "DAR" ~ "Darwin",
      StationCode == "YON" ~ "Yongala",
      StationCode == "NSI" ~ "North Stradbroke Island",
      StationCode == "PHB" ~ "Port Hacking",
      StationCode == "MAI" ~ "Maria Island",
      StationCode == "KAI" ~ "Kangaroo Island",
      StationCode == "ESP" ~ "Esperance",
      StationCode == "ROT" ~ "Rottnest Island",
      StationCode == "NIN" ~ "Ningaloo"))
}

#' Order the Station or region in the df by latitude for consistent plotting
#'
#' @param df A dataframe that contains StationName, StationCode or BioRegion
#'
#' @return An ordered dataframe
#' @export
#'
#' @importFrom magrittr "%>%"
#' @examples
#' df <- data.frame(StationName = c('Port Hacking', 'Maria Island',
#' 'North Stradbroke Island','Esperance', 'Ningaloo', "Darwin",
#' 'Rottnest Island',  'Kangaroo Island', "Yongala"))
#' df <- pr_reorder(df)
pr_reorder <- function(df){
  if("StationName" %in% colnames(df)){
    df <- df %>% mutate(StationName = factor(.data$StationName, levels = c("Darwin", "Yongala", 'Ningaloo', 'North Stradbroke Island',
                                                               'Rottnest Island', 'Esperance', 'Port Hacking', 'Kangaroo Island',
                                                               'Maria Island')))
  }
  if("StationCode" %in% colnames(df) & !"StationName" %in% colnames(df)){
    df <- df %>% mutate(StationCode = factor(.data$StationCode, levels = c("DAR", "YON", 'NIN', 'NSI', 'ROT', 'ESP', 'PHB', 'KAI', 'MAI')))
  }
  if("BioRegion" %in% colnames(df)){
    df <- df %>% mutate(BioRegion = factor(.data$BioRegion, levels = c("North", "North-west", 'Coral Sea', 'Temperate East', 'South-east', 'South-west')))
  }
  return(df)
}


#' Remove flagged data in df
#'
#' @param df A dataframe containing data with associated flags
#' @return A dataframe with flagged data removed
#' @export
#'
#' @examples
#' df <- data.frame(SST = c(27.4, 28.9, 45), SST_Flag = c(1, 1, 4))
#' df <- pr_apply_flags(df)
#' @import dplyr
#' @importFrom magrittr "%>%"
#' @importFrom data.table ":="
#' @importFrom rlang .data
pr_apply_flags <- function(df){

  # qc_scheme_short_name,flag_value,flag_meaning,flag_description
  # IMOS IODE,0,No QC performed,The level at which all data enter the working archive. They have not yet been quality controlled
  # IMOS IODE,1,Good data,Top quality data in which no malfunctions have been identified and all real features have been verified during the quality control process
  # IMOS IODE,2,Probably good data,Good data in which some features (probably real) are present but these are unconfirmed. Code 2 data are also data in which minor malfunctions may be present but these errors are small and/or can be successfully corrected without seriously affecting the overall quality of the data.
  # IMOS IODE,3,Bad data that are potentially correctable,Suspect data in which unusual,, and probably erroneous features are observed
  # IMOS IODE,4,Bad data,Obviously erroneous values are observed
  # IMOS IODE,5,Value changed,Altered by a QC Centre,, with original values (before the change) preserved in the history record of the profile. eMII discourage the use of this flag. Where data values must be changed (e.g. smoothing of data sets) we strongly prefer that the original data be retained and an additional variable be added to accommodate the interpolated/corrected data values.
  # IMOS IODE,6,Not used,Flag 6 is reserved for future use
  # IMOS IODE,7,Not used,Flag 7 is reserved for future use
  # IMOS IODE,8,Interpolated value,Indicates that data values are interpolated
  # IMOS IODE,9,Missing value,Indicates that the element is missing

  bad_flags <- c(3, 4, 6, 9)

  var_names <- stringr::str_remove(stringr::str_subset(colnames(df),"_Flag"), "_Flag") # Get all the variables from the df that contain a flag (*_Flag)

  for(v in 1:length(var_names)){ # Loop through and apply the flag to all

    out <- colnames(df)[stringr::str_detect(colnames(df), var_names[v])]
    var_units <- stringr::str_subset(stringr::str_subset(out, "_Flag", negate = TRUE), "_Comments", negate = TRUE) # Find the full variable variable name
    var_flags <- stringr::str_subset(out,"_Flag") # Find the flag

    df <- df %>%
      mutate(!!var_units := if_else(eval(rlang::sym(var_flags)) %in% bad_flags, NA_real_, eval(rlang::sym(var_units))))
    rm(out, var_units, var_flags)
  }
  return(df)
}



#' Remove flagged data in df
#'
#' @param df A dataframe containing time column
#' @return A dataframe with extra date columns
#' @export
#'
#' @examples
#' df <- data.frame(SampleDateLocal = lubridate::now(), Latitude = -32, Longitude = 160)
#' df <- pr_apply_time(df)
#' @import dplyr
#' @importFrom magrittr "%>%"
#' @importFrom data.table ":="
#' @importFrom rlang .data
pr_apply_time <- function(df){

  df <- df %>%
    mutate(Year = lubridate::year(.data$SampleDateLocal),
           Month = lubridate::month(.data$SampleDateLocal),
           Day = lubridate::day(.data$SampleDateLocal),
           Time_24hr = stringr::str_sub(.data$SampleDateLocal, -8, -1), # hms doesn"t seem to work on 00:00:00 times
           tz = lutz::tz_lookup_coords(.data$Latitude, .data$Longitude, method = "fast", warn = FALSE),
           SampleDateUTC = lubridate::with_tz(lubridate::force_tzs(.data$SampleDateLocal, .data$tz, roll = TRUE), "UTC"))

}


#' Remove incorrect species names from dataframe
#'
#' @param df A dataframe with species names
#'
#' @return A dataframe with all correct species names
#' @export
#'
#' @examples
#' df <- tibble(Species = c("IncorrectSpecies cf.", "CorrectSpcies1", NA,
#'               "CorrectSpecies2", "Incorrect spp., Incorrect/Species"))
#' df <- pr_filter_species(df)
#' @import dplyr
#' @importFrom magrittr "%>%"
#' @importFrom rlang .data
pr_filter_species <- function(df){
  pat <- c("spp.", "cf.", "/", "grp", "complex", "type")
  df <- df %>%
    filter(stringr::str_detect(.data$Species, paste(pat, collapse = "|"), negate = TRUE))
}


#' Add Carbon concentration to phytoplankton dataframe
#'
#' This is where you write the description
#' @param df Input dataframe with BioVolume
#' @param meth Method for data collection
#'
#' @return Dataframe with Carbon included
#' @export
#'
#' @examples
#' df <- tibble(TaxonGroup = c("Dinoflagellate", "Cyanobacteria"),
#'                           Biovolume_um3L = c(100, 150), Cells_L = c(10, 8))
#' df <- pr_add_Carbon(df, "NRS")
#' df <- tibble(TaxonGroup = c("Dinoflagellate", "Cyanobacteria"),
#'                           BioVolume_um3m3 = c(100, 150), PhytoAbund_m3 = c(10, 8))
#' df <- pr_add_Carbon(df, "CPR")
pr_add_Carbon <- function(df, meth){

  if (meth %in% "CPR"){
    df <- df %>%
      mutate(BV_Cell = .data$BioVolume_um3m3 / .data$PhytoAbund_m3, # biovolume of one cell
             Carbon = ifelse(.data$TaxonGroup == "Dinoflagellate", 0.76*(.data$BV_Cell)^0.819, # conversion to Carbon based on taxongroup and biovolume of cell
                             ifelse(.data$TaxonGroup == 'Ciliate', 0.22*(.data$BV_Cell)^0.939,
                                    ifelse(.data$TaxonGroup == 'Cyanobacteria', 0.2, 0.288*(.data$BV_Cell)^0.811 ))),
             Carbon_m3 = .data$PhytoAbund_m3 * .data$Carbon) # Carbon per m3
    return(df)
  }


  if (meth %in% "NRS"){
    df <- df %>%
      mutate(BV_Cell = .data$Biovolume_um3L / .data$Cells_L, # biovolume of one cell
             Carbon = case_when(.data$TaxonGroup == "Dinoflagellate" ~ 0.76*(.data$BV_Cell)^0.819, # conversion to Carbon based on taxongroup and biovolume of cell
                                .data$TaxonGroup == "Ciliate" ~ 0.22*(.data$BV_Cell)^0.939,
                                .data$TaxonGroup == "Cyanobacteria" ~ 0.2,
                                TRUE ~ 0.288*(.data$BV_Cell)^0.811),
             Carbon_L = .data$Cells_L * .data$Carbon) # Carbon per litre
    return(df)
  }

}



#' Add local Time
#'
#' This function adds the local time based on timezone.
#' @param df Dataframe with UTC Time
#'
#' @return A datafrane with local time added
#' @export
#'
#' @examples
#' df <- tibble(tz = c("Australia/Perth", "Australia/Brisbane"),
#'                SampleDateUTC = c(lubridate::now(), lubridate::now()))
#' df <- pr_add_LocalTime(df)
pr_add_LocalTime <- function(df){

  df <- purrr::map2(df$SampleDateUTC, df$tz, function(x,y) lubridate::with_tz(x, tzone = y))

}

#' For use in models to create a circular predictor
#'
#' This function i for use in models to create a circular predictor
#' @param theta Paramter to model in radians
#' @param k degrees of freedom
#'
#' @return A harmonic function
#' @export
#'
#' @examples
#' theta = 2
#' k = 1
#' df <- pr_harmonic(theta, k)

pr_harmonic <- function (theta, k = 4) {
  X <- matrix(0, length(theta), 2 * k)
  nam <- as.vector(outer(c("c", "s"), 1:k, paste, sep = ""))
  dimnames(X) <- list(names(theta), nam)
  m <- 0
  for (j in 1:k) {
    X[, (m <- m + 1)] <- cos(j * theta)
    X[, (m <- m + 1)] <- sin(j * theta)
  }
  X
}

#' Get coefficients from linear model
#'
#' @param df datafram containing Year, Month, parameters, values
#'
#' @return coefficients from linear model
#' @export
#'
#' @examples
#' df <- data.frame(Year = runif(10, 2000, 2003), Month = runif(10, 1, 6), parameters = c('Biomasss_mgm3', 'Diversity'),
#' Values = runif(10, 1, 5))
#' pr <- pr_get_coeffs(df)
pr_get_coeffs <-  function(df){

  params <- df %>% dplyr::select(.data$parameters) %>% unique()
  params <- params$parameters

  coeffs <- function(params){
    lmdat <-  df %>% dplyr::filter(parameters == params) %>%
      tidyr::drop_na()
    m <- lm(Values ~ Year + planktonr::pr_harmonic(Month, k = 1), data = lmdat)
    lmdat <- data.frame(lmdat %>% dplyr::bind_cols(fv = m$fitted.values))
    ms <- summary(m)
    slope <- ifelse(ms$coefficients[2,1] < 0, 'decreasing', 'increasing')
    p <-  ifelse(ms$coefficients[2,4] < 0.005, 'significantly', 'but not significantly')
    df <-  data.frame(slope = slope, p = p, parameters = params)
    df <- lmdat %>% dplyr::inner_join(df, by = 'parameters')
  }

  outputs <- purrr::map_dfr(params, coeffs)

}




