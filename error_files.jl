using Base: concatenate_setindex!
using CSV, Tables
using DataFrames
using DataStructures
using Random, Distributions, LinearAlgebra


error_values = DataFrame(CSV.File("input_files/price_params/error_time_series.csv", header=1, drop=[1,2]))
colnames = names(error_values)
error_values[!, :id] = 1:size(error_values, 1)
dfl = stack(error_values, colnames)
error_values_new = unstack(dfl, :variable, :id, :value)
error_values_new_removed = select!(error_values_new, Not(1))
CSV.write("input_files/price_params/error_time_series_transposed_removed.csv", error_values_new_removed, writeheader=false)

error_values_new_removed = DataFrame(CSV.File("input_files/price_params/error_time_series_transposed_removed.csv", header = 0))
col_names = names(error_values_new_removed)
red_col_names = []
for i in 1:length(col_names) 
    if minimum(error_values_new_removed[!, col_names[i]])>-300
        append!(red_col_names, i)
    end
end
CSV.write("input_files/price_params/error_time_series_transposed_removed_filtered.csv", error_values_new_removed[!, red_col_names], writeheader=false)

