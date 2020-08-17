import pandas as pd
#import numpy as np
import pickle
import time



print("starting script")

print("loading pickles")
#load sim data, stored in python pickle format ()
python_sim_data = pickle.load( open( "py_sim_data.p", "rb" ) )

print("bulding functions")
def function_for_loop_dataframe(sim_data):
    #create empty dataframe
    average = pd.DataFrame(columns = ["Case", "Rep", 'var1','var2','var3'])
    for case in python_sim_data['case'].unique():
        print(case)
        for reps in python_sim_data['repitition'].unique():
            #print(reps)
            curr_case = python_sim_data[(python_sim_data['case']==case) & (python_sim_data['repitition']==reps)]
            curr_case = curr_case[['var1','var2','var3']]
            curr_base = python_sim_data[(python_sim_data['case']=='baseline') & (python_sim_data['repitition']==reps)]
            curr_base = curr_base[['var1','var2','var3']]
            base_diff = curr_case.subtract(curr_base.values)
            base_diff['Case'] = case
            base_diff['Rep'] = reps
            average = average.append(base_diff)
    aggregated_py_DF = average.groupby('Case')[['var1','var2','var3']].mean()
    baseline_diffs = aggregated_py_DF - aggregated_py_DF.loc['baseline'].values.squeeze()
    baseline_diffs = baseline_diffs.drop(labels='baseline')
    return(baseline_diffs)




def function_pandas_dataframe(sim_data):
    aggregated_py_DF = sim_data.groupby('case')[['var1','var2','var3']].mean()
    baseline_diffs = aggregated_py_DF - aggregated_py_DF.loc['baseline'].values.squeeze()
    baseline_diffs = baseline_diffs.drop(labels='baseline')
  
    return(baseline_diffs)



def function_dict_operations(sim_data):
    sim_data_list_of_dicts = sim_data.to_dict('records')
    #get baseline data
    baseline = [dict for dict in sim_data_list_of_dicts if 'baseline' in dict['case']]
    #get unique others names from list, execept baseline
    unique = list(set(val for dict in sim_data_list_of_dicts for val in dict['case'] if dict['case'] != 'baseline'))
    #search across list of dicts, to create seperated lists dynamically (from unique case names) - no hard coding
    sim_data_dict_of_case_dicts ={}
    for case in unique:
      sim_data_dict_of_case_dicts[case] = [dict for dict in sim_data_list_of_dicts if case in dict['case']]
    #create var list of interest
    var_list = ['var1','var2','var3']
    #add baseline name to unique list of cases 
    unique.append('baseline')
    #add baseline to sim_data_dict_of_case_dicts 
    sim_data_dict_of_case_dicts['baseline'] = baseline
    
    mean_dict = {}
    for case in unique:
        case_dict = {}
        for var in var_list:
            case_dict[var] = float(sum(d[var] for d in sim_data_dict_of_case_dicts[case])) / len(sim_data_dict_of_case_dicts[case])
        mean_dict[case] = case_dict
    
    case_diffs = {case: mean_dict[case].items() - mean_dict['baseline'].values() for case in mean_dict.keys()}
    case_diffs.pop('baseline')
    for case in case_diffs.keys():
        case_diffs[case] = {k:v for k,v in case_diffs[case]}
    case_diffs_df = pd.DataFrame.from_dict(case_diffs)
    return(case_diffs_df)


#benchmark in python
    

def test_my_stuff(iterations):
    dict_time = {}
    print("testing pandas dataframes")
    df_list = []
    for i in range(0,iterations):
        print(i)
        t4 = time.perf_counter()
        function_pandas_dataframe(python_sim_data)
        t5 = time.perf_counter()
        total_time3 = t5 - t4
        df_list.append(total_time3)
    #df_list = sum(df_list)/len(df_list)
    dict_time['pandasDF'] = df_list
    
    print("testing dict ops")
    dict_list = []
    for i in range(0,iterations):
        print(i)
        t0 = time.perf_counter()
        function_dict_operations(python_sim_data)
        t1 = time.perf_counter()
        total_time = t1 - t0
        dict_list.append(total_time)
    #dict_list = sum(dict_list)/len(dict_list)
    dict_time['dicts'] = dict_list
    
    print("testing dataframe for loops")
    loop_list = []
    for i in range(0,iterations):
        print(i)
        t2 = time.perf_counter()
        function_for_loop_dataframe(python_sim_data)
        t3 = time.perf_counter()
        total_time2 = t3 - t2
        loop_list.append(total_time2)
    #loop_list = sum(loop_list)/len(loop_list)
    dict_time['forLoop'] = loop_list
    

    return(dict_time)


#test_times = test_my_stuff(10)

#code to be able to run this function when script is sourced with import call
#import optimization
#optimization.test_my_stuff()
if __name__ == '__main__':
    # test1.py executed as script
    # do something
    test_my_stuff()


