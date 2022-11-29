using JuMP, MathOptInterface, DataStructures
import JuMP: value, fix, set_name
using JSON: print

function solution(model::JuMP.Model)::OrderedDict
    instance, T, tm = model[:instance], model[:instance].time, model[:instance].time_multiplier
    function chr_power(g)
        return OrderedDict("time period $(t)" => value(model[:chr_power][g.name, t]) for t in 1:T)
    end
    function dis_power(g)
        return OrderedDict("time period $(t)" => value(model[:dis_power][g.name, t]) for t in 1:T)
    end
    function net_dis_power(g)
        return OrderedDict("time period $(t)" => (value(model[:dis_power][g.name, t])-value(model[:chr_power][g.name, t])) for t in 1:T)
    end
    function stored_energy(g)
        return OrderedDict("time period $(t)" => value(model[:stored_energy][g.name, t]) for t in 1:T)
    end
    function average_hourly_cost(g)
        return OrderedDict("time period $(t)" => value(model[:chr_power][g.name, t]) * 
            sum(sc.price[t] * sc.probability for sc in model[:instance].prices) for t in 1:T)
    end

    function average_hourly_revenue(g)
        return OrderedDict("time period $(t)" => value(model[:dis_power][g.name, t]) * 
            sum(sc.price[t] * sc.probability for sc in model[:instance].prices) for t in 1:T)
    end

    function average_total_cost(g)
        return sum(value(model[:chr_power][g.name, t]) * 
            sum(sc.price[t] * sc.probability for sc in model[:instance].prices) for t in 1:T)
        
    end

    function average_total_revenue(g)
        return sum(value(model[:dis_power][g.name, t]) * 
            sum(sc.price[t] * sc.probability for sc in model[:instance].prices) for t in 1:T)
        
    end

    function average_total_profit(g)
        return average_total_revenue(g)-average_total_cost(g)
    end

    function final_energy(g)
        return value(model[:stored_energy][g.name, T])
    end
    sol = OrderedDict()
    for g in instance.units
        sol[g.name] = OrderedDict(
            "Discharging power (MW)" => dis_power(g),
            "Charging power (MW)" => chr_power(g),
            "Net discharging power (MW)" => net_dis_power(g),
            "Stored energy (MWh)" => stored_energy(g),
            "Final energy (MWh)" => final_energy(g),
            "Hourly average cost (\$)" => average_hourly_cost(g), 
            "Hourly average revenue (\$)" => average_hourly_revenue(g),
            "Total average cost (\$)" => average_total_cost(g), 
            "Total average revenue (\$)" => average_total_revenue(g),
            "Total average profit (\$)" => average_total_profit(g),
        )
    end
    return sol
end

function write(filename::AbstractString, solution::AbstractDict)::Nothing
    open(filename, "w") do file
        return JSON.print(file, solution, 2)
    end
    return
end