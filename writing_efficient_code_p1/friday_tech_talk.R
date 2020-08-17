#install all required packages
list.of.packages <- c("microbenchmark", "magrittr", "purrr", "tidyr", "dplyr", "ggplot2", "data.table")
new.packages <- list.of.packages[!(list.of.packages %in% installed.packages()[,"Package"])]
if(length(new.packages)) install.packages(new.packages)
remove(list = ls())

#load packages
library(microbenchmark)
library(magrittr)
library(purrr)
library(tidyr)
library(dplyr)
library(ggplot2)
library(data.table)

#load data
load('sim_data.RData')

## For Loop across a dataframe ----
averages <- data.frame(matrix(nrow = 0, ncol = 5, dimnames = list(NULL, c("Case", "Rep", "var1", "var2", "var3"))))

for (case in unique(sim_data$case)){
  for (reps in unique(sim_data$repitition)){
    
    sim_data[sim_data$case == case &
               sim_data$repitition == reps,][3:5] -> curr_case
    
    sim_data[sim_data$case == 'baseline' &
               sim_data$repitition == reps,][3:5] -> curr_base
    base_diff <- curr_case - curr_base
    new_row <- data.frame('Case' = as.factor(case), 
                          'repitition' = reps, 'diff_from_baseline' = base_diff)
    rbind(averages, new_row) -> averages
  } # close rep for loop
} # close case for loop

averages %>%  group_by(Case) %>% summarise_all(mean, na.rm=TRUE) %>% 
  mutate_at(c('diff_from_baseline.var1', 'diff_from_baseline.var2', 'diff_from_baseline.var3'),ceiling)-> averages

averages %>% select(-'repitition') %>% filter(Case != 'baseline') -> averages




## List Mapping ----
sim_data %>% 
  dplyr::group_by(case) %>% dplyr::summarise_at(c('var1', 'var2', 'var3'), mean, na.rm=TRUE) %>% 
  dplyr::group_by(case) %>% tidyr::nest() %>% purrr::map(~ ., as.list) -> DF_to_list_of_lists

#name the individual elements of the data, to correspond with the case
names(DF_to_list_of_lists$data)=DF_to_list_of_lists$case

#use purrr:map to apply the anonymous function defined here to find the difference from baseline
purrr::map(DF_to_list_of_lists$case, function(x) DF_to_list_of_lists$data[[x]] - DF_to_list_of_lists$data[['baseline']]) -> case_base_diffs

#rename the new list to correspond with each case for output
names(case_base_diffs)=DF_to_list_of_lists$case

case_base_diffs %>% bind_rows() %>% cbind(.,DF_to_list_of_lists$case) %>% filter(DF_to_list_of_lists$case != 'baseline') -> baseline_diff1

names(baseline_diff1)[names(baseline_diff1) ==  'DF_to_list_of_lists$case'] <- "case"
baseline_diff1 <- baseline_diff1[,c(4,3,2,1)]


## Nested List Mapping ----
#group input data by case, summarise each variable with mean function and then turn into nested list
sim_data %>%
  group_by(case) %>% summarise_at(c('var1', 'var2', 'var3'), 
                                  mean, na.rm=TRUE) %>%
  group_by(case) %>% nest() -> DF_to_nested_list

#set nested list names for data
names(DF_to_nested_list$data)=DF_to_nested_list$case

#purrr::map anonymous function to new nested list
map(DF_to_nested_list$case, function(x) DF_to_nested_list$data[[x]] - DF_to_nested_list$data[['baseline']]) %>% bind_rows() %>% 
  cbind(.,DF_to_nested_list$case) %>% filter(DF_to_nested_list$case != 'baseline') -> baseline_diff2

#translate output to input names
names(baseline_diff2)[names(baseline_diff2) ==  'DF_to_nested_list$case'] <- "case"
baseline_diff2 <- baseline_diff2[,c(4,3,2,1)]


## For loop across lists ----
sim_data %>% 
  group_by(case) %>% summarise_at(c('var1', 'var2', 'var3'), mean, na.rm=TRUE) %>%
  group_by(case) %>% tidyr::nest() -> DF_to_nested_list

names(DF_to_nested_list$data)=DF_to_nested_list$case

for (cases in unique(DF_to_nested_list$case)){ 
  DF_to_nested_list$data[[cases]] <- ceiling(DF_to_nested_list$data[[cases]] - 
                                               DF_to_nested_list$data[['baseline']])
}

DF_to_nested_list$data %>% bind_rows() %>% 
  cbind(.,DF_to_nested_list$case) %>% filter(DF_to_nested_list$case != 'baseline') -> baseline_diff3

names(baseline_diff2)[names(baseline_diff2) ==  'DF_to_nested_list$case'] <- "case"
baseline_diff3 <- baseline_diff3[,c(4,3,2,1)]



## Data.Table manipulation ----

  #transform dataframe to datatable
  sim_data_DT <- data.table(sim_data)
  #select all data, calculate mean on specified columns, group by case
  sim_data_DT[,.(var1 = mean(var1), var2 = mean(var2), var3 = mean(var3)), by = .(case)] -> sim_data_DT
  # sim_data_DT[,lapply(.SD, mean), by = .(case), .SDcols = c('var1', 'var2', 'var3')]
  
  #set the key on case, so you can filter on case easily
  setkey(sim_data_DT, case)
  #apply function to difference all cases - baseline for iterator case list
  lapply(sim_data_DT[,case], function(x){sim_data_DT[x][,2:4] - sim_data_DT['baseline'][,2:4]}) -> baseline_diff4
  #transform list to DF for output sake
  do.call(rbind.data.frame, baseline_diff4) -> baseline_diff4
  #add case names back
  cbind(baseline_diff4, case = sim_data_DT[,case]) -> baseline_diff4
  #remove baseline
  baseline_diff4[case != 'baseline'] -> baseline_diff4


  
## Benchmark testing ----
  mbm <- microbenchmark::microbenchmark(
    
    "ListOfLists" = {function_list_mapping(sim_data)},
    
    "NestedLists" = {function_nestedList_mapping(sim_data)},
    
    "DFLoops" = {function_loop_through_dataframe(sim_data)},
    
    "ListLoops" = {function_loop_through_lists(sim_data)},
    
    "data_table" = {function_data.table_manipulation(sim_data)},
    
    times = 100
    
  )
  
autoplot(mbm)
