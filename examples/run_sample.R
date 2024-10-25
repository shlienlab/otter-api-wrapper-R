library(otterapiwrapperR)

otter_obj <- otter_api(api_token="<your API token>")

result <- otter_run_sample_path(
  otter_obj, file_path="examples/data/rhabdomyosarcoma.genes.hugo.results", model_name = 'otter',
  wait_for_result=TRUE, timeout=300, share_with = list('<email to share results with>')
)
df_result <- result$df_result
inference_id <- result$inference_id

plot_result = otter_plot_sample(otter_obj, df_result)
print(plot_result$top_path)
plotly_fig <- otter_to_plot(plot_result$sunburst_plot)
plotly_fig

plot_result <- otter_explore_plots(otter_obj)
plotly_fig <- otter_to_plot(plot_result$age_plot)
plotly_fig

plotly_fig <- otter_to_plot(plot_result$diagnosis_plot)
plotly_fig

plotly_fig <- otter_to_plot(plot_result$sex_plot)
plotly_fig

otter_download_pdf_report(otter_obj, inference_id, "output.pdf")
