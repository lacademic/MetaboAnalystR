% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/peaks_to_function.R
\name{PerformPSEA}
\alias{PerformPSEA}
\title{Function to perform peak set enrichment analysis}
\usage{
PerformPSEA(mSetObj=NA, lib, permNum = 100)
}
\arguments{
\item{mSetObj}{Input the name of the created mSetObj object}

\item{lib}{Input the name of the organism library, default is hsa}

\item{permNum}{Numeric, the number of permutations to perform}
}
\description{
This is the main function that performs either the mummichog
algorithm, GSEA, or both for peak set enrichment analysis.
}
\author{
Jasmine Chong, Jeff Xia \email{jeff.xia@mcgill.ca}
McGill University, Canada
License: GNU GPL (>= 2)
}
