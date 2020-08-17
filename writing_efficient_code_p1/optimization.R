#install all required packages
list.of.packages <- c("microbenchmark", "magrittr", "purrr", "tidyr", "dplyr")
new.packages <- list.of.packages[!(list.of.packages %in% installed.packages()[,"Package"])]
if(length(new.packages)) install.packages(new.packages)
remove(list = ls())
#load packages

library(microbenchmark)
library(magrittr)
library(purrr)
library(tidyr)
#library(ggplot2)
library(dplyr)

#load data
load('sim_data.RData')

{ # list of lists script ----
  
  function_list_mapping <- function(input_data, seed=NULL){
    #transform results from Df to names list of data
    #list has two elements, case (case names) and data (the data)
    sim_data %>% #df_sim_rep_hospDeceased %>% 
      dplyr::group_by(case) %>% dplyr::summarise_at(c('var1', 'var2', 'var3'), mean, na.rm=TRUE) %>% 
      dplyr::group_by(case) %>% tidyr::nest() %>% purrr::map(~ ., as.list) -> DF_to_nested_list
    
    #name the individual elements of the data, to correspond with the case
    names(DF_to_nested_list$data)=DF_to_nested_list$case
    
    #use purrr:map to apply the anonymous function defined here to find the difference from baseline
    purrr::map(DF_to_nested_list$case, function(x) DF_to_nested_list$data[[x]] - DF_to_nested_list$data[['baseline']]) -> case_base_diffs
    
    #rename the new list to correspond with each case for output
    names(case_base_diffs)=DF_to_nested_list$case
    
    case_base_diffs %>% bind_rows() %>% cbind(.,DF_to_nested_list$case) %>% filter(DF_to_nested_list$case != 'baseline') -> baseline_diffs
    
    names(baseline_diffs)[names(baseline_diffs) ==  'DF_to_nested_list$case'] <- "case"
    
    return(baseline_diffs)
  }
  
} #end list of list scripts

{ #nested DF with lists script ----
  
  function_nestedList_mapping <- function(sim_data, seed=NULL){
    
    sim_data %>%
      group_by(case) %>% summarise_at(c('totalEvacuated', 'hospitalized', 'deceased'), mean, na.rm=TRUE) %>%
      group_by(case) %>% nest() -> nested_death
    
    names(nested_death$data)=nested_death$case
    
    map(nested_death$case, function(x) nested_death$data[[x]] - nested_death$data[['baseline']]) %>% bind_rows() %>% 
      cbind(.,nested_death$case) %>% filter(nested_death$case != 'baseline') -> baseline_diff
    
    names(baseline_diff)[names(baseline_diff) ==  'nested_death$case'] <- "case"
    
    return(baseline_diff)
    
  } # end low_function_compareHospDeaths_nestedList
  
} #end nested DF with lists

{ # for loop DF section ----
  
  function_loop_through_dataframe <- function(sim_data,
                                              seed=NULL){
    
    # Set the seed
    set.seed(seed)
    
    averageDeaths <- data.frame(matrix(nrow = 0, ncol = 5, dimnames = list(NULL, c("Case", "Rep", "totalEvacuated", "hospitalized", "deceased"))))
    
    for (case in unique(sim_data$case)){
      
      for (reps in unique(sim_data$rep)){
        
        sim_data[sim_data$case == case &
                   sim_data$rep == reps,][3:5] -> curr_case
        
        sim_data[sim_data$case == 'baseline' &
                   sim_data$rep == reps,][3:5] -> curr_base
        
        dead_diff <- curr_case - curr_base
        
        new_row <- data.frame('Case' = as.factor(case), 'Rep' = reps, 'diff_from_baseline' = dead_diff)
        
        rbind(averageDeaths, new_row) -> averageDeaths
      } # close rep for loop
    } # close case for loop
    
    averageDeaths %>%  group_by(Case) %>% summarise_all(mean, na.rm=TRUE) %>% 
      mutate_at(c('diff_from_baseline.totalEvacuated', 'diff_from_baseline.hospitalized', 'diff_from_baseline.deceased'),ceiling)-> averageDeaths
    
    # create output df
    return(averageDeaths)
    
  }# close the lowFunction_compareHospDeaths function itself
  
}# close for loop section

{ # for loop lists section ----
  
  function_loop_through_lists <- function(sim_data,
                                          seed=NULL){
    
    # Set the seed
    set.seed(seed)
    
    sim_data %>%
      group_by(case) %>% summarise_at(c('totalEvacuated', 'hospitalized', 'deceased'), mean, na.rm=TRUE) %>%
      group_by(case) %>% tidyr::nest() -> nested_death2
    
    names(nested_death2$data)=nested_death2$case
    
    for (cases in unique(nested_death2$case)){ 
      #print(nested_death2$data[[cases]])
      
      nested_death2$data[[cases]] <- ceiling(nested_death2$data[[cases]] - nested_death2$data[['baseline']])
      
    }
    
    nested_death2$data %>% bind_rows() %>% 
      cbind(.,nested_death2$case) %>% filter(nested_death2$case != 'baseline') -> baseline_diff2
    
    names(baseline_diff2)[names(baseline_diff2) ==  'nested_death2$case'] <- "case"
    baseline_diff2 <- baseline_diff2[,c(4,3,2,1)]
    
    # create output df
    return(baseline_diff2)
    
  }# close the lowFunction_compareHospDeaths_listLoop function itself
  
}# close for loop lists section

{ #data.table manipulation
  
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
  } #close function_data.table_manipulation
  
} #close data.table manipulation section

## testing ----

mbm <- microbenchmark::microbenchmark(
  
"ListOfLists" = {function_listOfLists(sim_data)},

"NestedLists" = {function_nestedList(sim_data)},

"DFLoops" = {function_loop_through_dataframe(sim_data)},

"ListLoops" = {function_loop_through_lists(sim_data)},

"data_table" = {function_data.table_manipulation(sim_data)}

times = 1000

) #close microbenchmark test

mbm
autoplot(mbm)
plot(mbm)

## close testing




