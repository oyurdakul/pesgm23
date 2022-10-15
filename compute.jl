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
using .StorageProblem

price_parameter_file = "input_files/price_params.json"
system_parameter_file = "input_files/system_params.json"
n_scen = 100
cvar_chr_params = [0.0, 0.25, 0.50, 0.75, 1.0, 1.25, 1.5, 2.0, 5.0]
cvar_dis_params = [0.0, 0.25, 0.50, 0.75, 1.0, 1.25, 1.5, 2.0, 5.0]
# StorageProblem.createPriceParamsFile(system_parameter_file)
for cvar_chr in cvar_chr_params
    for cvar_dis in cvar_dis_params
    StorageProblem.createScenarios(price_parameter_file, system_parameter_file, n_scen, cvar_chr, cvar_dis)
    instance = StorageProblem.read("input_files/input_$(cvar_chr)_$(cvar_dis).json")
    model = StorageProblem.build_model(
        instance = instance,
        optimizer = Gurobi.Optimizer,
    )
    JuMP.optimize!(model)
    solution = StorageProblem.solution(model)
    StorageProblem.write("solution_files/solution_$(cvar_chr)_$(cvar_dis).json", solution)
    end
end
StorageProblem.construct_frontier(cvar_chr_params, cvar_dis_params)
