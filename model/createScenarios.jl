using Base: Float64
using DataStructures: push!
using Printf
using JSON
using DataStructures
using GZip
import Base: getindex, time
using Random, Distributions


function createScenarios(path::AbstractString, system_path::AbstractString, nscen::Int64, cvar_chr::Float64, cvar_dis::Float64)
    file = open(path)
    json = JSON.parse(file, dicttype = () -> DefaultOrderedDict(nothing))
    mean_vals = Float64[]
    covs = Array{Float64,1}[]
    for (time_key, dict) in json["Prices"]
        push!(mean_vals, dict["mean"])
        cov = Float64[]
        for(cov_time_key, val) in dict["covariance"]
            push!(cov, val)
        end
        push!(covs, cov)
    end
    close(file)
    covs = hcat(covs...)
    d = MvNormal(mean_vals, covs)
    Random.seed!(100)
    system_file = open(system_path)
    system_json = JSON.parse(system_file, dicttype = () -> DefaultOrderedDict(nothing))
    system_json = copy(system_json)
    push!(system_json, "CVaR chr constraint parameter"=>cvar_chr)
    push!(system_json, "CVaR dis constraint parameter"=>cvar_dis)
    price_dict = OrderedDict()
    for snum in range(1, length = nscen) 
        scen_price_dict = OrderedDict()
        push!(scen_price_dict, "Price (\$/MWh)" =>  rand(d))
        push!(scen_price_dict, "Probability" =>  1/nscen)
        push!(price_dict, "s$(snum)" =>  scen_price_dict)
    end
    push!(system_json, "Mean prices"=> mean_vals)
    push!(system_json, "Prices"=>price_dict)
    push!(system_json["Parameters"], "Scenario number"=>nscen)
    open("input_files/input_$(cvar_chr)_$(cvar_dis).json", "w") do f
        JSON.print(f, system_json, 4)
    end
    return
end