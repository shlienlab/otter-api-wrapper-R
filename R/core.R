# Special thanks to Matthew Cannon from Nationwide for developing a lot of the functions you'll find in this package

# Some useful keyboard shortcuts for package authoring:
#
#   Install Package:           'Cmd + Shift + B'
#   Check Package:             'Cmd + Shift + E'
#   Test Package:              'Cmd + Shift + T'

library("rjson")
library(plotly)

#' Otter API starting point
#'
#' This function initializes the Otter API.
#'
#' @param api_token Your API token from https://otter.ccm.sickkids.ca/app/api_docs.
#' @param base_api_url API link.
#' @param base_app_url App link.
#' @return An object to be passed to other functions.
#' @export
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

#' Run sample through the API
#'
#' Runs a sample from a path to their TPMs.
#'
#' @param otter_obj Your API object.
#' @param file_path path to TPM counts file.
#' @param model_name otter or hierarchical.
#' @param atlas_version not used for now, but kept here for compatibility with future versions of the atlas.
#' @param sample_name Name of the sample.
#' @param share_with List of emails to share the sample with.
#' @param save Checking this to TRUE allows us to save the files sent to the server for later research.
#' @param wait_for_result Whether to submit the job and move on or wait for the results.
#' @param timeout When waiting, time to timeout.
#' @return Dataframe of prediction or task id and inference id.
#' @export
otter_run_sample_path <- function(
    otter_obj,
    file_path,
    model_name,
    atlas_version=NULL,
    sample_name=NULL,
    share_with=NULL,
    save=FALSE,
    wait_for_result=TRUE,
    timeout=300
) {
  if (is.null(sample_name)) {
    sample_name <- utils::tail(strsplit(file_path, "/")[[1]], n=1)
  }

  df <- utils::read.csv(file_path, sep='\t')

  otter_run_sample_res <- otter_run_sample(
    otter_obj, df, model_name, atlas_version, sample_name,
    share_with, save, wait_for_result, timeout
  )
  return_data <- NULL
  return_data$df_result <- otter_run_sample_res$df_result
  return_data$inference_id <- otter_run_sample_res$inference_id
  return_data$task_id <- otter_run_sample_res$task_id
  return (return_data)
}

#' Run sample through the API
#'
#' Runs a sample from their TPM counts.
#'
#' @param otter_obj Your API object.
#' @param df TPM counts.
#' @param model_name otter or hierarchical.
#' @param atlas_version not used for now, but kept here for compatibility with future versions of the atlas.
#' @param sample_name Name of the sample.
#' @param share_with List of emails to share the sample with.
#' @param save Checking this to TRUE allows us to save the files sent to the server for later research.
#' @param wait_for_result Whether to submit the job and move on or wait for the results.
#' @param timeout When waiting, time to timeout.
#' @return Dataframe of prediction or task id and inference id.
#' @export
otter_run_sample <- function(
    otter_obj,
    df,
    model_name,
    atlas_version,
    sample_name,
    share_with,
    save,
    wait_for_result,
    timeout
) {
  post_data <-
    list(
      version = model_name,
      data = list(
        TPM = df$TPM,
        gene_name = df$gene_name
      ),
      name = sample_name,
      save = save
    )
  if (!is.null(share_with)) {
    post_data = append(post_data, list(share_with=share_with))
  }

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
      if (wait_for_result) {
        return_data$df_result <- otter_wait_for_sample(otter_obj, task_id, timeout)
      }
      else {
        return_data <- NULL
        return_data$task_id = task_id
        return_data$inference_id = inference_id
      }

      return(return_data)
    }
    else {
      stop("Error in submitting inference job")
    }

  }, error = function(e) {
    print('This is likely an error of API limit reached.')
    print(httr2::resp_body_json(e$resp))
    stop("Error in submitting inference job")

  })

}

#' Waits for the API
#'
#' Waits for the results to be available in the API
#'
#' @param otter_obj Your API object.
#' @param task_id The id of the API run.
#' @param timeout Time to timeout.
#' @return Prediction dataframe
#' @export
otter_wait_for_sample <- function(
    otter_obj,
    task_id,
    timeout
) {
  url <-
    sprintf(
      "%s/inference_check?task_id=%s",
      otter_obj$base_api_url,
      task_id
    )

  done <- FALSE
  start.time <- Sys.time()

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

    time.taken <- Sys.time() - start.time
    if (time.taken > timeout) {
      return ('Timeout while waiting for the sample. Check the website for a detailed log.')
    }


  }

  results <- httr2::resp_body_json(check)$result
  otter_output <- unlist(results) |> tibble::enframe()
  return (otter_output)
}

#' Main plot
#'
#' Sunburst plot and other plots and info.
#'
#' @param otter_obj Your API object.
#' @param df_result Dataframe of prediction.
#' @param width Plot width.
#' @param height Plot height.
#' @return Plotly plot.
#' @export
otter_plot_sample <- function(
    otter_obj,
    df_result,
    width=800,
    height=800
) {

  post_data <-
    list(
      result=rjson::toJSON(stats::setNames(lapply(df_result$value, function(x) list(x)), df_result$name)),
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
  return(rjson::fromJSON(results))
}

#' Explore plots
#'
#' Plots available in the explore page.
#'
#' @param otter_obj Your API object.
#' @param class_name Optional parameter to get the explore plots of an specific class.
#' @return Plotly plot.
#' @export
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

  return(rjson::fromJSON(results))

}

#' PDF report
#'
#' PDF report of the sample.
#'
#' @param otter_obj Your API object.
#' @param inference_id Inference ID of the sample.
#' @param output_path Path to save the pdf.
#' @return PDF file.
#' @export
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
