<img src="docs/images/otter_logo.png" width="300" padding="100">

<!-- --- -->
[OTTER: Oncologic TranscripTome Expression Recognition](https://www.nature.com/articles/s41591-023-02221-x#Sec37)

Otter is a series of deep learning models aimed at classifying RNA TPM counts against an atlas of cancer types and subtypes. The original code for running Otter is available at https://github.com/shlienlab/otter.

<br>

<img src="docs/images/otter-api-wrapper.jpeg" width="100" padding="50">

# Otter API Wrapper 

This is an R wrapper for the Otter API. This wrapper helps you run the API available at https://otter.ccm.sickkids.ca/.


![CRAN/METACRAN Version](https://img.shields.io/cran/v/otterapiwrapperR)

## Installation 

```R
install.packages("rjson")
install.packages("plotly")
install.packages("otterapiwrapperR")
```

## Quickstart
You can check out the examples folder for more details. The simplest usage of the API is:
```R
library(otterapiwrapperR)

otter_obj <- otter_api(api_token="<your API token>")
df_result <- otter_run_sample_path(otter_obj, file_path="examples/data/rhabdomyosarcoma.genes.hugo.results")
```

## Short Docs
Usually you want to start with creating an OtterAPI object:

```R
library(otterapiwrapperR)

otter_obj <- otter_api(api_token="<your API token>")
```

Then, running a sample is the next step. This sends the sample to our servers and runs our models. The sample is only stored in the server during runtime and is deleted shortly after:

```R
df_result <- otter_run_sample_path(
  otter_obj,
  file_path="examples/data/rhabdomyosarcoma.genes.hugo.results",
  model_name='<otter, hierarchical>', # check http://localhost:3000/app/inference for details
  sample_name='<custom name for the sample>'
)
```

Details on the classes of the resulting dataframe can be found as an [Excel file](https://static-content.springer.com/esm/art%3A10.1038%2Fs41591-023-02221-x/MediaObjects/41591_2023_2221_MOESM3_ESM.xlsx) or if that link fails, as a supplementary table on the [paper](https://www.nature.com/articles/s41591-023-02221-x#Sec36).

From the dataframe, you can now generate all of the plots available on the webapp using the [Plotly](https://plotly.com/) library:

```R
# Returns a dictionary with top_path and sunburst_plot
plot_result = otter_plot_sample(otter_obj, df_result)
plotly_fig <- otter_to_plot(plot_result$sunburst_plot)
plotly_fig
```

The *top_path* key allows you to get the top path of subclasses based on the model classification. This is the same as you will find on the [results page](https://otter.ccm.sickkids.ca/app/results). The *sunburst_plot* key gives you access to the sunburst plot, also available on the results page.

If you want to retrieve plots from the explore page, you can do so by calling

```R
# returns age_plot, diagnosis_plot, and sex_plot
plot_result <- otter_explore_plots(otter_obj)

# or 

plot_result <- otter_explore_plots(otter_obj, tail(plot_result$top_path$names, n=1)) # where class_name is the name of any class you are interested in

# then
plotly_fig <- otter_to_plot(plot_result$age_plot)
plotly_fig

plotly_fig <- otter_to_plot(plot_result$diagnosis_plot)
plotly_fig

plotly_fig <- otter_to_plot(plot_result$sex_plot)
plotly_fig
```

## Citation
When using this library, please cite:

> Comitani, Federico, et al. "Diagnostic classification of childhood cancer using multiscale transcriptomics." Nature medicine 29.3 (2023): 656-666.

## Questions
If you have any questions about the API or the methods behind OTTER, please send an email to pedro.lemosballester@sickkids.ca or adam.shlien@sickkids.ca.
