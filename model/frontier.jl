using Base: Order
# UnitCommitmentSTO.jl: Optimization Package for Security-Constrained Unit Commitment
# Copyright (C) 2020, UChicago Argonne, LLC. All rights reserved.
# Released under the modified BSD license. See COPYING.md for more details.

using Printf
using JSON
using DataStructures
using GZip
import Base: getindex, tim


function construct_frontier(cvar_chr_params::Vector{Float64}, cvar_dis_params::Vector{Float64})
    file = open("solution_files/solution_$(cvar_chr_params[1])_$(cvar_dis_params[1]).json")
    json=JSON.parse(file, dicttype = () -> DefaultOrderedDict(nothing))
    units = keys(json)
    close(file)
    revenue = OrderedDict()
    for c in cvar_chr_params
        for d in cvar_dis_params
            file = open("solution_files/solution_$(c)_$(d).json")
            json=JSON.parse(file, dicttype = () -> DefaultOrderedDict(nothing))
            for u in units
                revenue["$(c) $(d) $(u)"] = json[u]["Average total profit (\$)"]
            end
            close(file)
        end
    end
    unit_profits = OrderedDict()
    profits = OrderedDict()
    for u in units
        temp = OrderedDict()
        for c in cvar_chr_params
            for d in cvar_dis_params
                temp["CVaR chr $(c) CVaR dis $(d)"] = revenue["$(c) $(d) $(u)"] 
            end
        end
        unit_profits[u] = temp
    end
    profits["Average total profits"]=unit_profits
    write("solution_files/frontier.json", profits)
    return 
end
