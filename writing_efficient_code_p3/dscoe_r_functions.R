# This is our external R script called dscoe_r_functions.R
# It contains the functions from Part 1 to be sourced
# for the microbenchmark test

## @knitr load_data

#load('sim_data.RData')

## function_nestedList_mapping

function_nestedList_mapping <- function(input_data, seed=NULL){
  set.seed(seed)
  #group input data by case, summarise each variable with mean function and then turn into nested list
  input_data %>%
    group_by(case) %>% summarise_at(c('var1', 'var2', 'var3'), 
                                    mean, na.rm=TRUE) %>%
    group_by(case) %>% nest() -> DF_to_nested_list
  #set nested list names for data
  names(DF_to_nested_list$data)=DF_to_nested_list$case
  
  #purrr::map anonymous function to new nested list
  map(DF_to_nested_list$case, function(x) DF_to_nested_list$data[[x]] - DF_to_nested_list$data[['baseline']]) %>% bind_rows() %>% 
    cbind(.,DF_to_nested_list$case) %>% filter(DF_to_nested_list$case != 'baseline') -> baseline_diff
  
  #translate output to input names
  names(baseline_diff)[names(baseline_diff) ==  'DF_to_nested_list$case'] <- "case"
  
  return(baseline_diff)
  
}

## function_list_mapping

function_list_mapping <- function(input_data, seed=NULL){
  set.seed(seed)
  #transform results from Df to names list of data
  #list has two elements, case (case names) and data (the data)
  input_data %>% 
    dplyr::group_by(case) %>% dplyr::summarise_at(c('var1', 'var2', 'var3'), mean, na.rm=TRUE) %>% 
    dplyr::group_by(case) %>% tidyr::nest() %>% purrr::map(~ ., as.list) -> DF_to_list_of_lists
  
  #name the individual elements of the data, to correspond with the case
  names(DF_to_list_of_lists$data)=DF_to_list_of_lists$case
  
  #use purrr:map to apply the anonymous function defined here to find the difference from baseline
  purrr::map(DF_to_list_of_lists$case, function(x) DF_to_list_of_lists$data[[x]] - DF_to_list_of_lists$data[['baseline']]) -> case_base_diffs
  
  #rename the new list to correspond with each case for output
  names(case_base_diffs)=DF_to_list_of_lists$case
  
  case_base_diffs %>% bind_rows() %>% cbind(.,DF_to_list_of_lists$case) %>% filter(DF_to_list_of_lists$case != 'baseline') -> baseline_diffs
  
  names(baseline_diffs)[names(baseline_diffs) ==  'DF_to_nested_list$case'] <- "case"
  
  return(baseline_diffs)
}

## function_loop_through_dataframe

function_loop_through_dataframe <- function(input_data,
                                            seed=NULL){
  
  # Set the seed
  set.seed(seed)
  
  averages <- data.frame(matrix(nrow = 0, ncol = 5, dimnames = list(NULL, c("Case", "Rep", "var1", "var2", "var3"))))
  
  for (case in unique(input_data$case)){
    for (reps in unique(input_data$repitition)){
      
      input_data[input_data$case == case &
                   input_data$repitition == reps,][3:5] -> curr_case
      
      input_data[input_data$case == 'baseline' &
                   input_data$repitition == reps,][3:5] -> curr_base
      base_diff <- curr_case - curr_base
      new_row <- data.frame('Case' = as.factor(case), 
                            'repitition' = reps, 'diff_from_baseline' = base_diff)
      rbind(averages, new_row) -> averages
    } # close rep for loop
  } # close case for loop
  
  averages %>%  group_by(Case) %>% summarise_all(mean, na.rm=TRUE) %>% 
    mutate_at(c('diff_from_baseline.var1', 'diff_from_baseline.var2', 'diff_from_baseline.var3'),ceiling)-> averages
  
  # create output df
  return(averages)
  
}

## function_loop_through_lists

function_loop_through_lists <- function(input_data,
                                        seed=NULL){
  
  # Set the seed
  set.seed(seed)
  
  input_data %>% 
    group_by(case) %>% summarise_at(c('var1', 'var2', 'var3'), mean, na.rm=TRUE) %>%
    group_by(case) %>% tidyr::nest() -> DF_to_nested_list
  
  names(DF_to_nested_list$data)=DF_to_nested_list$case
  
  for (cases in unique(DF_to_nested_list$case)){ 
    
    DF_to_nested_list$data[[cases]] <- ceiling(DF_to_nested_list$data[[cases]] - DF_to_nested_list$data[['baseline']])
    
  }
  
  DF_to_nested_list$data %>% bind_rows() %>% 
    cbind(.,DF_to_nested_list$case) %>% filter(DF_to_nested_list$case != 'baseline') -> baseline_diff2
  
  names(baseline_diff2)[names(baseline_diff2) ==  'DF_to_nested_list$case'] <- "case"
  baseline_diff2 <- baseline_diff2[,c(4,3,2,1)]
  
  # create output df
  return(baseline_diff2)
  
}

## function_data.table_manipulation

function_data.table_manipulation <- function(input_data, seed=NULL){
  set.seed(seed)
  
  #transform dataframe to datatable
  sim_data_DT <- data.table(input_data)
  #select all data, calculate mean on specified columns, group by case
  sim_data_DT[,.(var1 = mean(var1), var2 = mean(var2), var3 = mean(var3)), by = .(case)] -> sim_data_DT
  # sim_data_DT[,lapply(.SD, mean), by = .(case), .SDcols = c('var1', 'var2', 'var3')]
  
  #set the key on case, so you can filter on case easily
  setkey(sim_data_DT, case)
  #apply function to difference all cases - baseline for iterator case list
  lapply(sim_data_DT[,case], function(x){sim_data_DT[x][,2:4] - sim_data_DT['baseline'][,2:4]}) -> baseline_diffs
  #transform list to DF for output sake
  do.call(rbind.data.frame, baseline_diffs) -> baseline_diffs
  #add case names back
  cbind(baseline_diffs, case = sim_data_DT[,case]) -> baseline_diffs
  #remove baseline
  baseline_diffs[case != 'baseline'] -> baseline_diffs
  
  return(baseline_diffs)
}

