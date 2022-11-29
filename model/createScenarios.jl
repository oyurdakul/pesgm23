using Base: Float64
using DataStructures: push!
using Printf
using JSON
using DataStructures
using GZip
import Base: getindex, time
using Random, Distributions
using CSV, Tables
using DataFrames


function createScenarios(price_file_path::AbstractString, error_file_path::AbstractString, 
    system_parameters_file_path::AbstractString, nscen::Int64, cvar_chr::Float64, 
    cvar_dis::Float64, es_capacity::Float64, alpha::Float64)
    
    system_file = open(system_parameters_file_path)
    system_json = JSON.parse(system_file, dicttype = () -> DefaultOrderedDict(nothing))
    simulation_horizon = system_json["Parameters"]["Simulation horizon (min)"]
    time_step = scalar(system_json["Parameters"]["Time step (min)"], default = 60)
    (60 % time_step == 0) ||
        error("Time step $time_step is not a divisor of 60")
    T = simulation_horizon ÷ time_step
    close(system_file)


    mkpath("input_files/scenarios/$(cvar_chr)_$(cvar_dis)_$(es_capacity)_$(alpha)/")
    mean_prices = DataFrame(CSV.File(price_file_path, header=0))
    error_values_new_removed = DataFrame(CSV.File(error_file_path, header = 0))
    number_of_samples = length(names(error_values_new_removed))
    sample_index = []
    i=0
    Random.seed!(3)
    while(true)
        new_num = convert(Int32,trunc(number_of_samples * (1-rand()))) + 1
        if i == nscen
            break
        elseif new_num ∉ sample_index
            append!(sample_index, new_num)
            i += 1
        end
    end
    error_values = select!(error_values_new_removed, sample_index)
    for s in 1:T
        scen_json = copy(system_json)
        delete!(scen_json["Parameters"], "Simulation horizon (min)")
        push!(scen_json["Parameters"], "Problem horizon (min)"=>(T-s+1)*time_step)
        push!(scen_json["Parameters"], "Alpha chr parameter"=>alpha)
        push!(scen_json, "CVaR chr constraint parameter"=>cvar_chr)
        push!(scen_json, "CVaR dis constraint parameter"=>cvar_dis)
        for (unit, dict) in scen_json["Units"]
            dict["Maximum energy (MWh)"] = es_capacity
            dict["Maximum final energy (MWh)"] = es_capacity
        end

        price_dict = OrderedDict()
        price_scenarios = cat(mean_prices[s:T,1] + convert(Vector{Float64}, error_values[1:T-s+1,1]), dims =(2,2))
        for i in 2:nscen
            price_scenarios = cat(price_scenarios, mean_prices[s:T,1] + convert(Vector{Float64}, error_values[1:T-s+1,i]), dims =(2,2))
        end
        for snum in 1:nscen 
            scen_price_dict = OrderedDict()
            push!(scen_price_dict, "Price (\$/MWh)" =>  price_scenarios[:, snum])
            push!(scen_price_dict, "Probability" =>  1/nscen)
            push!(price_dict, "s$(snum)" =>  scen_price_dict)
        end
        push!(scen_json, "Prices"=>price_dict)
        push!(scen_json["Parameters"], "Scenario number"=>nscen)
        open("input_files/scenarios/$(cvar_chr)_$(cvar_dis)_$(es_capacity)_$(alpha)/$(s).json", "w") do f
            JSON.print(f, scen_json, 4)
        end
    end
    return T, mean_prices[:,1]
end