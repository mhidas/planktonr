% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/pr_add_bioregions.R
\name{pr_add_bioregions}
\alias{pr_add_bioregions}
\title{Add bioregions data to existing df}
\usage{
pr_add_bioregions(df)
}
\arguments{
\item{df}{A dataframe with columns \code{.data$Longitude} and \code{.data$Latitude}}
}
\value{
A dataframe with Marine Bioregions added
}
\description{
Add bioregions data to existing df
}
\examples{
df <- pr_get_NRSStation() \%>\%
pr_add_bioregions
}
