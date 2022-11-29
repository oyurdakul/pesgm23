using JuMP, MathOptInterface, DataStructures
import JuMP: value, fix, set_name

function _add_injection_withdrawal_vars!(model::JuMP.Model, g::Unit)::Nothing
    bin_var = _init(model, :bin_var)
    dis_power = _init(model, :dis_power)
    chr_power = _init(model, :chr_power)
    stored_energy = _init(model, :stored_energy)
    T = model[:instance].time

    for t in 1:model[:instance].time
        bin_var[g.name, t] = @variable(model, binary=true)
        dis_power[g.name, t] = @variable(model, lower_bound = 0)
        chr_power[g.name, t] = @variable(model, lower_bound = 0)
        stored_energy[g.name, t] = @variable(model, lower_bound = 0)
    end 
    return
end

function _add_costs_revs!(model::JuMP.Model, g::Unit)::Nothing
    instance = model[:instance]
    T = instance.time
    tm = instance.time_multiplier
    dis_power = model[:dis_power]
    chr_power = model[:chr_power]
    for sc in instance.prices
        for t in 1:T
            add_to_expression!(
                model[:obj],
                tm*sc.probability*sc.price[t],
                chr_power[g.name, t],
            )
            add_to_expression!(
                model[:obj],
                -tm*sc.probability*sc.price[t],
                dis_power[g.name, t],
            )
        end
    end
    return
end

function _add_operational_constraints!(model::JuMP.Model, g::Unit)::Nothing
    instance = model[:instance]
    T = instance.time
    tm = instance.time_multiplier
    dis_power = model[:dis_power]
    chr_power = model[:chr_power]
    bin_var = model[:bin_var]
    stored_energy = model[:stored_energy]
    gn = g.name

    ini_energy = _init(model, :ini_energy)
    ener_stor = _init(model, :ener_stor)
    dis_power_min=_init(model,:dis_power_min)
    dis_power_max=_init(model,:dis_power_max)
    chr_power_min=_init(model,:chr_power_min)
    chr_power_max=_init(model,:chr_power_max)
    ener_min=_init(model,:ener_min)
    ener_max=_init(model,:ener_max)
    ener_min_end=_init(model,:ener_min_end)
    ener_max_end=_init(model,:ener_max_end)


    ener_stor[gn, 1] = @constraint(
        model,
        stored_energy[gn, 1] == g.initial_energy + (chr_power[gn, 1] * tm * g.efficiency) - (dis_power[gn, 1] * tm / g.efficiency)
        )
    
    for t in 2:T
        ener_stor[gn, t] = @constraint(
            model,
            stored_energy[gn, t] == stored_energy[gn, t-1] + (chr_power[gn, t] * tm * g.efficiency) - (dis_power[gn, t] * tm / g.efficiency)
            )
    end

    for t in 1:T
        dis_power_min[gn, t] = @constraint(
            model,
            dis_power[gn, t] >= g.min_discharging_power
        )
        dis_power_max[gn, t] = @constraint(
            model,
            dis_power[gn, t] <= g.max_discharging_power * bin_var[gn, t]
        )
        chr_power_min[gn, t] = @constraint(
            model,
            chr_power[gn, t] >= g.min_charging_power
        )
        chr_power_max[gn, t] = @constraint(
            model,
            chr_power[gn, t] <= g.max_charging_power * (1-bin_var[gn, t])
        )
        ener_min[gn, t] = @constraint(
            model,
            stored_energy[gn, t] >= g.min_energy
            )
        ener_max[gn, t] = @constraint(
            model,
            stored_energy[gn, t] <= g.max_energy
            )
    end

    ener_min_end[gn] = @constraint(
            model,
            stored_energy[gn, T] + (chr_power[gn, T] * tm * g.efficiency) - (dis_power[gn, T] * tm / g.efficiency) >= g.min_final_energy
            )
    
    ener_max_end[gn] = @constraint(
        model,
        stored_energy[gn, T] + (chr_power[gn, T] * tm * g.efficiency) - (dis_power[gn, T] * tm / g.efficiency) <= g.max_final_energy
        )

    return
end
function _add_cvar_vars!(model::JuMP.Model, g::Unit)::Nothing
    chr_z = _init(model, :chr_z)
    chr_VaR = _init(model, :chr_VaR)
    dis_z = _init(model, :dis_z)
    dis_VaR = _init(model, :dis_VaR)
    instance = model[:instance]
    gn = g.name
    T = instance.time
    for t in 1:T
        chr_VaR[gn, t] = @variable(model)
        dis_VaR[gn, t] = @variable(model)
        for sc in instance.prices
            chr_z[gn, sc.name, t] = @variable(model, lower_bound = 0)
            dis_z[gn, sc.name, t] = @variable(model, lower_bound = 0)
        end
    end 
    return
end
function _add_cvar_objective!(model::JuMP.Model, g::Unit)::Nothing
    instance = model[:instance]
    T = instance.time
    chr_z = model[:chr_z]
    chr_VaR = model[:chr_VaR]  
    dis_z = model[:dis_z]
    dis_VaR = model[:dis_VaR]                   
    chr_power = model[:chr_power]
    dis_power = model[:dis_power]
    cvar_chr_parameters = instance.cvar_chr_parameters
    cvar_dis_parameters = instance.cvar_dis_parameters
    chr_CVaR_lin_constraint = _init(model, :chr_CVaR_lin_constraint)
    dis_CVaR_lin_constraint = _init(model, :dis_CVaR_lin_constraint)
    gn = g.name
    
    for t in 1:T
        add_to_expression!(
                model[:obj],
                cvar_chr_parameters[t],
                chr_VaR[gn, t] + ((1/(1-instance.alpha_chr[t]))  * sum(sc.probability * chr_z[gn, sc.name, t] for sc in instance.prices)) 
                )
        add_to_expression!(
                model[:obj],
                cvar_dis_parameters[t],
                dis_VaR[gn, t] + ((1/(1-instance.alpha_dis[t]))  * sum(sc.probability * dis_z[gn, sc.name, t] for sc in instance.prices)) 
                )
        for sc in instance.prices
            chr_CVaR_lin_constraint[gn, sc.name, t] = @constraint(
                model,
                chr_z[gn, sc.name, t] >=  (sc.price[t] * chr_power[gn, t]) - chr_VaR[gn, t]
                )
            dis_CVaR_lin_constraint[gn, sc.name, t] = @constraint(
                model,
                dis_z[gn, sc.name, t] >=  (dis_power[gn, t] * exp(-sc.price[t]/1000)) - dis_VaR[gn, t]
                )
        end
    end
    return
end

function _add_cvar_constraints!(model::JuMP.Model, g::Unit)::Nothing
    instance = model[:instance]
    T = instance.time
    chr_z = model[:chr_z]
    chr_VaR = model[:chr_VaR]  
    dis_z = model[:dis_z]
    dis_VaR = model[:dis_VaR]                   
    chr_power = model[:chr_power]
    dis_power = model[:dis_power]
    chr_CVaR_constraint = _init(model, :chr_CVaR_constraint)
    chr_CVaR_lin_constraint = _init(model, :chr_CVaR_lin_constraint)
    dis_CVaR_constraint = _init(model, :dis_CVaR_constraint)
    dis_CVaR_lin_constraint = _init(model, :dis_CVaR_lin_constraint)
    gn = g.name
    daily_mean = sum(instance.mean_prices[t] for t in 1:T)/T
    
    for t in 1:T
        chr_CVaR_constraint[gn, t] = @constraint(
                model,
                chr_VaR[gn, t] + ((1/(1-instance.alpha))  * sum(sc.probability * chr_z[gn, sc.name, t] for sc in instance.prices))  <= 
                instance.cvar_chr_parameters[t] * daily_mean * g.max_charging_power
                )
        dis_CVaR_constraint[gn, t] = @constraint(
            model,
            dis_VaR[gn, t] + ((1/(1-instance.alpha))  * sum(sc.probability * dis_z[gn, sc.name, t] for sc in instance.prices))  <= 
            instance.cvar_dis_parameters[t] / daily_mean * g.max_charging_power
            )
        for sc in instance.prices
            chr_CVaR_lin_constraint[gn, sc.name, t] = @constraint(
                model,
                chr_z[gn, sc.name, t] >=  (sc.price[t] * chr_power[gn, t]) - chr_VaR[gn, t]
                )
            dis_CVaR_lin_constraint[gn, sc.name, t] = @constraint(
                model,
                dis_z[gn, sc.name, t] >=  (dis_power[gn, t] / sc.price[t]) - dis_VaR[gn, t]
                )
        end
    end
    return
end

function _add_unit!(model::JuMP.Model, g::Unit)
    _add_injection_withdrawal_vars!(model, g)
    _add_costs_revs!(model, g)
    _add_operational_constraints!(model, g)
    _add_cvar_vars!(model, g)
    _add_cvar_objective!(model, g)
end