% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/google_sheets.R
\name{readGS}
\alias{readGS}
\alias{readGS4}
\title{Google Sheets Reading (API v4)}
\usage{
readGS(
  title,
  sheet = "Hoja 1",
  range = NULL,
  drop_nas = TRUE,
  json = NULL,
  email = NULL,
  api_key = NULL,
  server = FALSE,
  ...
)
}
\arguments{
\item{title}{Character. Title of Google Drive file. Uses regular
expressions so you may fetch with patterns instead of names.}

\item{sheet}{Character. Working sheet to import}

\item{range}{Character. A cell range to read from}

\item{drop_nas}{Boolean. Remove columns and rows that contain only NAs?}

\item{json}{Character. JSON filename with service auth}

\item{email, api_key}{Character. If you have multiple pre-authorized
accounts in your machine, you may non-interactively select
which one you wish to use by email and/or api_key.}

\item{server}{Boolean. Force interacting auth process?}

\item{...}{Further read_sheet parameters}
}
\description{
Read data from Google Sheets knowing the file's title. You may read
a single value from a cell or a data.frame from a cell range.
}
\seealso{
Other Scrapper: 
\code{\link{filesGD}()},
\code{\link{geoStratum}()},
\code{\link{get_mp3}()},
\code{\link{holidays}()},
\code{\link{ip_country}()},
\code{\link{splot_etf}()},
\code{\link{stocks_hist}()},
\code{\link{stocks_quote}()},
\code{\link{trendsRelated}()},
\code{\link{writeGS}()}

Other Google: 
\code{\link{filesGD}()},
\code{\link{geoAddress}()},
\code{\link{queryGA}()},
\code{\link{trendsRelated}()},
\code{\link{trendsTime}()},
\code{\link{writeGS}()}
}
\concept{Google}
\concept{Scrapper}
