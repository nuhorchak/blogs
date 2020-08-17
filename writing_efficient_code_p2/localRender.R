library(rmarkdown)
library(bookdown)

bookdown::render_book(input = 'data_constructs_in_python.Rmd',
                      output_format = 'bookdown::markdown_document2',
                      output_dir = '.',
                      output_file = 'readme.md')

