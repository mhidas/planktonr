% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/utils_boo_plot.R
\name{pr_plot_climate}
\alias{pr_plot_climate}
\title{Plot single climatology}
\usage{
pr_plot_climate(df, Survey = "NRS", x, pal = "matter", Scale = "identity")
}
\arguments{
\item{df}{dataframe with specified time period, station code and parameter}

\item{Survey}{CPR or NRS data}

\item{x}{specified time period}

\item{pal}{is the palette name from cmocean}

\item{Scale}{scale of y axis on plot, whatever scale_y_continuous trans accepts}
}
\value{
a plotly climatology plot
}
\description{
Plot single climatology
}
\examples{
df <- data.frame(Month = rep(1:12,10), StationCode = c('NSI', 'NSI', 'PHB', 'PHB'),
parameters = 'Biomass_mgm3', Values = runif(120, min=0, max=10))
monthly <- pr_plot_climate(df, "NRS", Month, 'matter')
}
