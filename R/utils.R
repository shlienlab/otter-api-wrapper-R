#' Local plots
#'
#' Use plotly to create local plots.
#'
#' @param plot_data Result from the plotting functions from otter.
#' @return Plots.
#' @export
otter_to_plot <- function (plot_data) {
  return(plotly_build(plot_data))
}
