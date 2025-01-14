% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/utils_boo_plot.R
\name{pr_get_PlotCols}
\alias{pr_get_PlotCols}
\title{Setting the colours for plots using cmocean}
\usage{
pr_get_PlotCols(pal = "matter", n)
}
\arguments{
\item{pal}{is the palette name}

\item{n}{is the number of colours required}
}
\value{
is a list of colours of length n from palette pal
}
\description{
Setting the colours for plots using cmocean
}
\examples{
plotCols <- pr_get_PlotCols('matter', 5)
}
