mutable struct PriceScenario
    name::String
    price::Vector{Float64}
    probability::Float64
end

mutable struct Unit
    name::String
    initial_energy::Float64
    min_energy::Float64
    max_energy::Float64
    min_final_energy::Float64
    max_final_energy::Float64
    min_discharging_power::Float64
    max_discharging_power::Float64
    min_charging_power::Float64
    max_charging_power::Float64
    ramp_up_limit::Float64
    ramp_down_limit::Float64
    efficiency::Float64
end

Base.@kwdef mutable struct StorageProblemInstance
    nscenarios::Int
    price_scenarios_by_name::Dict{AbstractString, PriceScenario}
    prices::Vector{PriceScenario}
    mean_prices::Vector{Float64}
    time::Int
    time_multiplier::Float64
    units_by_name::Dict{AbstractString,Unit}
    units::Vector{Unit}
    alpha_chr::Vector{Float64}
    alpha_dis::Vector{Float64}
    cvar_chr_parameters::Vector{Float64}
    cvar_dis_parameters::Vector{Float64}
end

function Base.show(io::IO, instance::StorageProblemInstance)
    print(io, "StorageProblemInstance(")
    print(io, "$(length(instance.units)) units, ")
    print(io, "$(length(instance.nscenarios)) scenarios, ")
    print(io, "$(instance.time) time steps")
    print(io, ")")
    return
end

export StorageProblemInstance
