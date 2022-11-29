using Printf
using JSON
using DataStructures
using GZip
import Base: getindex, time



function read(path::AbstractString)::StorageProblemInstance
    file = open(path)
    return _from_json(
        JSON.parse(file, dicttype = () -> DefaultOrderedDict(nothing)),
    )
end



function _from_json(json; repair = true)
    function scalar(x; default = nothing)
        x !== nothing || return default
        return x
    end
    function timeseries(x; default = nothing)
        x !== nothing || return default
        x isa Array || return [x for t in 1:T]
        return x
    end
    units = Unit[]
    prices=PriceScenario[]
    problem_horizon = json["Parameters"]["Problem horizon (min)"]
    time_step = scalar(json["Parameters"]["Time step (min)"], default = 60)
    (60 % time_step == 0) ||
        error("Time step $time_step is not a divisor of 60")
    T = problem_horizon ÷ time_step
    scenario_number = json["Parameters"]["Scenario number"]
    scenario_number !== nothing || error("Missing parameter: Scenario number")
    time_step = scalar(json["Parameters"]["Time step (min)"], default = 60)
    (60 % time_step == 0) ||
        error("Time step $time_step is not a divisor of 60")
    time_multiplier = time_step / 60
    alpha_chr = timeseries(
        json["Parameters"]["Alpha chr parameter"],
        default = [.95 for t in 1:T],
    )
    alpha_dis = timeseries(
        json["Parameters"]["Alpha dis parameter"],
        default = [.95 for t in 1:T],
    )
    cvar_dis_parameters = timeseries(
        json["CVaR dis constraint parameter"],
        default = [1.0 for t in 1:T],
    )
    cvar_chr_parameters = timeseries(
        json["CVaR chr constraint parameter"],
        default = [1.0 for t in 1:T],
    )
    cvar_dis_parameters = timeseries(
        json["CVaR dis constraint parameter"],
        default = [1.0 for t in 1:T],
    )
    mean_prices = timeseries(
        json["Mean prices"],
        default = [1.0 for t in 1:T],
    )
    name_to_unit = Dict{String,Unit}()
    name_to_scenario= Dict{String,PriceScenario}()
    # Read price scenarios
    
    for (scenario_name, dict) in json["Prices"]
        price_scenario=PriceScenario(scenario_name, dict["Price (\$/MWh)"], dict["Probability"])
        name_to_scenario[scenario_name]=price_scenario
        push!(prices, price_scenario)
    end
    
    # Read units
    for (unit_name, dict) in json["Units"]
 
        unit = Unit(
            unit_name,
            scalar(dict["Initial energy (MWh)"], default = 0) ,
            scalar(dict["Minimum energy (MWh)"], default = 0) ,
            scalar(dict["Maximum energy (MWh)"], default = 100) ,
            scalar(dict["Minimum final energy (MWh)"], default = 0) ,
            scalar(dict["Maximum final energy (MWh)"], default = 100) ,
            scalar(dict["Minimum discharging power (MW)"], default = 0) ,
            scalar(dict["Maximum discharging power (MW)"], default = 100) ,
            scalar(dict["Minimum charging power (MW)"], default = 0) ,
            scalar(dict["Maximum charging power (MW)"], default = 100) ,
            scalar(dict["Ramp up limit (MW)"], default = 1e6),
            scalar(dict["Ramp down limit (MW)"], default = 1e6),
            scalar(dict["Efficiency"], default = 1),
        )
        name_to_unit[unit_name] = unit
        push!(units, unit)
    end

   
    instance = StorageProblemInstance(
        nscenarios = scenario_number,
        price_scenarios_by_name = Dict(p.name => p for p in prices),
        prices = prices,
        mean_prices = mean_prices,
        time = T,
        time_multiplier = time_multiplier,
        units_by_name = Dict(g.name => g for g in units),
        units = units,
        alpha_chr = alpha_chr,
        alpha_dis = alpha_dis,
        cvar_chr_parameters = cvar_chr_parameters,
        cvar_dis_parameters = cvar_dis_parameters
    )
    return instance
end
