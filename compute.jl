include("StorageProblem.jl")

using Base: Float64, @var, current_logger, Ordered
using Gurobi
using Cbc
using Clp
using JuMP
using JSON
using PyCall
using Printf
import Base
using JSON: print
using GZip
import Base: getindex, time
using DataStructures
import MathOptInterface
using LinearAlgebra
using LaTeXStrings
using PyCall
import PyPlot as plt
using .StorageProblem

price_file_path = "input_files/price_params/SA12June22_VIC.csv"
error_file_path = "input_files/price_params/error_time_series_transposed_removed_filtered.csv"
system_parameters_file_path = "input_files/storage_params/Victorian_big_battery.json"
n_scen = 100
cvar_chr_params = [i for i in range(0.0, step=0.1, length=5)]
cvar_dis_params = [0.0]
energy_storage_capacity = [450.0]
# energy_storage_capacity = [i for i in range(4.0, step=4.0, length=6)]
# energy_storage_capacity = [i for i in range(250, step = 50.0, stop = 650.0)]
# alpha_params = vcat([i for i in range(0.0, step = 0.2, stop=0.8)], 0.99)
alpha_params = [0.95]
mean_prices = Vector{Float64}
for cvar_chr in cvar_chr_params
    for cvar_dis in cvar_dis_params
        for es_capacity in energy_storage_capacity
            for alpha in alpha_params
                T, mean_prices = StorageProblem.createScenarios(price_file_path, error_file_path, system_parameters_file_path, n_scen, cvar_chr, cvar_dis, es_capacity, alpha)
                StorageProblem.solveHorizon(cvar_chr, cvar_dis, T, mean_prices, es_capacity, alpha)
            end
        end
    end
end
StorageProblem.construct_frontier(cvar_chr_params, cvar_dis_params, mean_prices, energy_storage_capacity, alpha_params)