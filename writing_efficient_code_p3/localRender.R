library(rmarkdown)
library(bookdown)

#PLEASE NOTE THAT THIS ONLY WORKS WITH SINGLE RMD DOCUMENTS FOR THIS TYPE OF BLOG POST TEMPLATE
bookdown::render_book(input = 'benchmark_testing.Rmd',
                      output_format = 'bookdown::markdown_document2',
                      output_dir = '.',
                      output_file = 'readme.md')