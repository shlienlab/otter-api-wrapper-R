# Special thanks to Matthew Cannon from Nationwide for developing a lot of the functions you'll find in this package

# Some useful keyboard shortcuts for package authoring:
#
#   Install Package:           'Cmd + Shift + B'
#   Check Package:             'Cmd + Shift + E'
#   Test Package:              'Cmd + Shift + T'

library("rjson")
library(plotly)

otter_api <- function(
  api_token,
  base_api_url="https://otter.ccm.sickkids.ca/api",
  base_app_url="https://otter.ccm.sickkids.ca/app"
) {
  return(list(
    api_token=api_token,
    base_api_url=base_api_url,
    base_app_url=base_app_url
  ))
}

otter_run_sample_path <- function(
  otter_obj,
  file_path,
  model_name,
  atlas_version=NULL,
  sample_name=NULL
) {
  if (is.null(sample_name)) {
    sample_name <- tail(strsplit(file_path, "/")[[1]], n=1)
  }

  df <- read.csv(file_path, sep='\t')

  otter_run_sample_res <- otter_run_sample(otter_obj, df, model_name, atlas_version, sample_name)
  return_data <- NULL
  return_data$df_result <- otter_run_sample_res$df_result
  return_data$inference_id <- otter_run_sample_res$inference_id
  return (return_data)
}

otter_run_sample <- function(
  otter_obj,
  df,
  model_name,
  atlas_version,
  sample_name
) {
  post_data <-
    list(
      version = model_name,
      data = list(
        TPM = df$TPM,
        gene_name = df$gene_name
      ),
      name = sample_name
    )

  form <- httr2::request(sprintf(
    "%s/inference",
    otter_obj$base_api_url
  ))

  form <-
    form |>
    httr2::req_headers(
      Authorization = sprintf(
        "Bearer %s",
        otter_obj$api_token
      )
    ) |>
    httr2::req_body_json(post_data)


    tryCatch({
      # Perform the request
      submitted <- httr2::req_perform(form)

      httr2::resp_check_status(submitted)

      if (submitted$status == 200) {
        resp <- httr2::resp_body_json(submitted)
        task_id <- resp$task_id
        inference_id <- resp$inference_id

        return_data <- NULL
        return_data$inference_id <- inference_id
        return_data$df_result <- otter_wait_for_sample(otter_obj, task_id)
        return(return_data)
      }
      else {
        stop("Error in submitting inference job")
      }

    }, error = function(e) {
      print(httr2::resp_body_json(e$resp))
      stop("Error in submitting inference job")

    })

}

otter_wait_for_sample <- function(
  otter_obj,
  task_id
) {
  url <-
    sprintf(
      "%s/inference_check?task_id=%s",
      otter_obj$base_api_url,
      task_id
  )

  done <- FALSE
  while (!done) {
    Sys.sleep(1)
    check <-
      httr2::request(url) |>
      httr2::req_headers(
        Authorization = paste0(
          "Bearer ",
          otter_obj$api_token
        )
      ) |>
      httr2::req_perform()

    if (inherits(httr2::resp_body_json(check)$result, "list")) {
      done <- TRUE
    }
  }

  results <- httr2::resp_body_json(check)$result
  otter_output <- unlist(results) |> tibble::enframe()
  return (otter_output)
}


otter_plot_sample <- function(
  otter_obj,
  df_result,
  width=800,
  height=800
) {

  post_data <-
    list(
      result=toJSON(setNames(lapply(df_result$value, function(x) list(x)), df_result$name)),
      width = width,
      height = height
    )

  form <- httr2::request(sprintf(
    "%s/plot_result",
    otter_obj$base_app_url
  ))

  form <-
    form |>
    httr2::req_headers(
      Authorization = sprintf(
        "Bearer %s",
        otter_obj$api_token
      )
    ) |>
    httr2::req_body_json(post_data)
    form_resp <- httr2::req_perform(form)

    results <- httr2::resp_body_json(form_resp)
    #otter_output <- unlist(results) |> tibble::enframe()
    return(fromJSON(results))
}

otter_explore_plots <- function(
  otter_obj,
  class_name=""
) {

  form <- httr2::request(sprintf(
    "%s/get_explore_plots?label=%s",
    otter_obj$base_app_url,
    gsub("#", "%23", gsub(" ", "+", class_name))
  ))

  form <-
    form |>
    httr2::req_headers(
      Authorization = sprintf(
        "Bearer %s",
        otter_obj$api_token
      )
    )
  form_resp <- httr2::req_perform(form)
  results <- httr2::resp_body_json(form_resp)

  return(fromJSON(results))

}

otter_download_pdf_report <- function(
    otter_obj,
    inference_id,
    output_path
) {

  form <- httr2::request(sprintf(
    "%s/download_pdf_result?inference_id=%s",
    otter_obj$base_api_url,
    inference_id
  ))

  form <-
    form |>
    httr2::req_headers(
      Authorization = sprintf(
        "Bearer %s",
        otter_obj$api_token
      )
    )
  form_resp <- httr2::req_perform(form)
  writeBin(httr2::resp_body_raw(form_resp), output_path)

  return(TRUE)

}
