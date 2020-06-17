#' This function reads in the 'long' TSV variant sheets generated by the makefile
#'
#' @param tsv_file A TSV-formatted file containing SNV data.
#'
#' @return filled.df A data frame containing filled SNV data
#' @export
read_filled_variant_tsv <- function(tsv_file) {
  filled.df <- readr::read_tsv(tsv_file,
                        col_names = c('chr', 'pos', 'ref', 'alt', 'sample', 'gene',
                                      'transcript', 'protein', 'genotype',
                                      'hq_depth', 'vaf')) %>%
                  # Calculate a numeric variant allele frequency
    dplyr::mutate(vaf_numeric = as.numeric(gsub('%', '', .data$vaf)),
                  # Calculate a 'variant key' - chr_pos_ref_alt
                  var_key = paste(.data$chr, .data$pos, .data$ref, .data$alt, sep = '_'),
                  # Paste together the HGVS names
                  var_hgvs = paste(.data$gene, .data$transcript, .data$protein, sep = ';'),
                  # Add a simple yes/no for 'was a variant called?'
                  # Note that we handle weird genotypes (0|1, 1|0, 1|1) here
                  bool_genotype = as.integer(dplyr::if_else(.data$genotype %in% c('0/1', '1/1', '0|1', '1|0', '1|1'),
                                                     1, 0)))
  return(filled.df)
}

#' This function takes the 'long, filled' data frames with variant observations, and converts them to 'wide' format
#'
#' @param df A data frame containing SNV data in the 'long, filled' format
#'
#' @return df A wide-format data frame containing simplified SNV data
#' @export
spread_filled_snv_df_to_wide <- function(df) {
  df %>%
    # Add a default concordance colour for plotting
    dplyr::mutate(concordance_col = 'black') %>%
    # Remove redundant columns
    dplyr::select(-genotype, -hq_depth, -vaf, -vaf_numeric) %>%
    # Spread to wide to compare samples by genotypes
    tidyr::spread(key = sample, value = bool_genotype) %>%
    as.data.frame() %>%
    return()
}

#' Add colour vector to concordance data frame
#'
#' This is a dummy function - this function is defined in the upstream analysis documents
add_colour_vector_to_concordance <- function() NULL

#' This function takes the long and wide data frames, and plots all variants by covearge, colouring them by concordance status
#'
#' @param wide.df A wide dataframe containing variant observations
#' @param long.df A long dataframe containing variant observations
#' @param sample_name Sample name
#'
#' @return A plot
#' @export
plot_vars_by_coverage <- function(wide.df, long.df, sample_name) {
  title <- paste0("Coverage Depth for ", sample_name, " Replicate SNVs")
  wide.df %>%
    add_colour_vector_to_concordance() %>%
    dplyr::select(.data$var_key, .data$concordance_col) %>%
    dplyr::left_join(long.df, by = "var_key") %>%
    ggplot2::ggplot(aes(x = factor(.data$var_key),
               y = .data$hq_depth,
               shape = .data$genotype,
               colour = .data$concordance_col)) +
    ggplot2::geom_point(size = 3) + ggplot2::scale_colour_identity() +
    ggplot2::scale_y_log10(breaks = c(1,2,5,10,20,50,100,200,500,1000, 2000)) +
    ggplot2::theme(axis.text.x = ggplot2::element_text(angle = 90, hjust = 0)) +
    ggplot2::coord_flip() +
    ggplot2::labs(title = title,
                  x = "Variant",
                  y = "High-quality Depth") %>%
    return()
}

#' Join to the plotting frame and re-plot for VAF
#'
#' @param wide.df A wide dataframe containing variant observations
#' @param long.df A long dataframe containing variant observations
#' @param sample_name Sample name
#'
#' @return A plot
#' @export
plot_vars_by_vaf <- function(wide.df, long.df, sample_name) {
  title <- paste0("Variant allele fraction for ", sample_name, " Replicate SNVs")
  wide.df %>%
    add_colour_vector_to_concordance() %>%
    dplyr::select(.data$var_key, .data$concordance_col) %>%
    dplyr::left_join(long.df, by = "var_key") %>%
    ggplot2::ggplot(aes(x = factor(.data$var_key),
               y = .data$vaf_numeric,
               shape = .data$genotype,
               colour = .data$concordance_col)) +
    ggplot2::geom_point(size = 3) + ggplot2::scale_colour_identity() +
    ggplot2::theme(axis.text.x = ggplot2::element_text(angle = 90, hjust = 0)) +
    ggplot2::coord_flip() +
    ggplot2::labs(title = title,
         x = "Variant",
         y = "Variant Allele Fraction") %>%
    return()
}

#' Split a FORMAT string from GATK-haplotype to get simpler statistics
#'
#' @param df A data frame containing GATK-formatted variant calls
#'
#' @return updated_df An augmented data frame.
#' @export
#'
#' @examples \dontrun{split_gatk_format_vals(df)}
split_gatk_format_vals <- function(df){

  df %>%
    dplyr::mutate(format_split = stringr::str_split(format_vals, ':'),
    genotype = map_chr(format_split, select_by_position, 1),
    allele_depth = map_chr(format_split, select_by_position, 2),
    depth_split = stringr::str_split(allele_depth, ','),
    ref_depth = as.integer(map_chr(depth_split, select_by_position, 1)),
    alt_depth = as.integer(map_chr(depth_split, select_by_position, 2)),
    vaf = alt_depth / (ref_depth + alt_depth) * 100.0,
    reported_depth = as.integer(map_chr(format_split, select_by_position, 3)),
    genotype_quality = as.integer(map_chr(format_split, select_by_position, 4)))
}

