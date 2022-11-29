using Base: Float64, @var, current_logger, Ordered
using Printf
import Base
using JSON: print
using Gurobi
using GZip
import Base: getindex, time
using DataStructures
import MathOptInterface
using LaTeXStrings
using LinearAlgebra
using .StorageProblem
using PyCall
import PyPlot as plt
using Plots
function plot_aggregate_solution(cvar_chr, cvar_dis, units, aggregate_solution, mean_prices, es_capacity, alpha)
    for u in units
        x = [i for i in 1:length(keys(aggregate_solution[u]["Net discharging power (MW)"]))]
        fig, ax1 = plt.subplots(figsize=(16.0, 6.0))
        ax2 = ax1.twinx()
        ax1.set_xlim([0, 49])
        xlab = [1]
        append!(xlab,[i for i in 6:6:48])
        ax1.set_xticks(xlab)
        ax1.set_xticklabels([L"%$i" for i in xlab], fontsize=30)
        ax1.step(x, [val for (key,val) in aggregate_solution[u]["Net discharging power (MW)"]], linewidth=1.5, color="#c7a577", label=L"\mathrm{net\,discharging\,power\,(MW)}")
        # ax1.plot(x, net_power, "o--", color="#c7a577", alpha=0.2)
        ax1.plot(x, [val for (key,val) in aggregate_solution[u]["Stored energy (MWh)"]], color="#fad8aa", alpha=1.0, label=L"\mathrm{stored\,energy\,(MWh)}")
        # ax1.plot(x, [val for (key,val) in aggregate_solution[u]["Stored energy (MWh)"]], "o--", color="lightskyblue", alpha=0.2)
        ax1.fill_between(x,[val for (key,val) in aggregate_solution[u]["Stored energy (MWh)"]], color="#fad8aa", alpha=0.3)
        ax2.step(x, mean_prices, "--", color="#48A1D5", alpha=1.0,linewidth=1.5, label = L"\mathrm{pre-dispatch\,price\,(A\$/MWh)}")
        ax1.set_xlabel(L"\mathrm{time\,period\,[k]}", fontsize=30)
        ax1.set_ylabel(L"\mathrm{MW/MWh}", color="#c7a577", fontsize=30)
        # ax2.set_ylabel(L"\mathrm{pre-dispatch\,price\,(A\$/MWh)}", color="#48A1D5", fontsize=30)
        ax2.set_ylabel(L"\mathrm{A\$/MWh}", color="#48A1D5", fontsize=30)
        for tick in ax1.get_yticklabels()
            tick.set_fontname("Times New Roman")
            tick.set_fontsize(30)
            tick.set_color("#c7a577")
        end
        for tick in ax2.get_yticklabels()
            tick.set_fontname("Times New Roman")
            tick.set_fontsize(30)
            tick.set_color("#48A1D5")
        end
        ax2.spines["left"].set_color("#c7a577")
        ax2.spines["right"].set_color("#48A1D5")
        ax1.legend(loc="upper left", fontsize=30)
        ax2.legend(loc="upper right", fontsize=30)
        # plt.show()
        plt.savefig("solution_files/$(cvar_chr)_$(cvar_dis)_$(es_capacity)_$(alpha)/aggregate_$(u).png", bbox_inches="tight",  dpi=600)
    end
    return
end
function plot_aggregate_solution_plots(cvar_chr, cvar_dis, units, aggregate_solution, mean_prices, es_capacity, alpha)
    
    # Set
    # x limits, x labels, font size, y label 
    for u in units
        T = length(keys(aggregate_solution[u]["Net discharging power (MW)"]))
        x = [i for i in 1:T]
        gr()
        plot_font = "Computer Modern"
        default(fontfamily=plot_font, legend=true, 
            legendfontsize = 14, grid=false)
        p = twinx()
        xticks = 1
        xticks = vcat(xticks, [i for i in 6:6:T])
        
        plot(x, [val for (key,val) in aggregate_solution[u]["Net discharging power (MW)"]],
            color="#c7a577", 
            label="net discharging power (MW)", 
            ylabel = "MW/MWh", legend = :topleft, fillalpha =1.0,
            y_foreground_color_axis = "#c7a577", y_guidefontcolor="#c7a577", 
            y_foreground_color_border="#c7a577", y_foreground_color_text = "#c7a577", 
            foreground_color_legend = nothing,
            xlims = (0, T+1), 
            ylims = (-320, 720),
            yticks=[-300, -150, 0, 150, 300, 450],
            xlabel = L"time period $[k]$",
            xticks = xticks,
            xguidefontsize=16,
            yguidefontsize=16,
            ytickfontsize=16,
            tickfontsize=16,
            linewidth = 2.0,
            linetype=:steppre, dpi=600)
        plot!(x, [val for (key,val) in aggregate_solution[u]["Stored energy (MWh)"]], 
            color="#fad8aa", 
            fillalpha =1.0, label="stored energy (MWh)", 
            linewidth = 2.0,
            foreground_color_legend = nothing,
            y_foreground_color_axis = "#c7a577", y_guidefontcolor="#c7a577", 
            y_foreground_color_border="#c7a577", y_foreground_color_text = "#c7a577",
            legend = :topleft, dpi=600)
        plot!(x, zeros(T), fillrange=[val for (key,val) in aggregate_solution[u]["Stored energy (MWh)"]], 
            color="#fad8aa", fillalpha =0.3,  dpi=600,
            label = "", 
            foreground_color_legend = nothing,
            y_foreground_color_axis = "#c7a577", y_guidefontcolor="#c7a577", 
            y_foreground_color_border="#c7a577", y_foreground_color_text = "#c7a577",
            linewidth = 2.0) # fill between
        plot!(p, x, mean_prices, color="#48A1D5", fillalpha=1.0, 
            label = "pre-dispatch price (A\$\$/MWh)",
            ylabel = "pre-dispatch price (A\$\$/MWh)",
            y_foreground_color_axis = "#48A1D5", y_guidefontcolor="#48A1D5", 
            y_foreground_color_border="#48A1D5", y_foreground_color_text="#48A1D5", 
            foreground_color_legend = nothing,
            linestyle=:dot,
            legend = :topright,
            linetype = :steppre,
            yguidefontsize=16,
            ytickfontsize=16,
            linewidth = 2.0,
            xlims = (0, T+1), 
            ylims = (0, 4600),
            dpi=600)
        plot!(size=(1000,400), right_margin = 6Plots.mm, left_margin =6Plots.mm, bottom_margin = 7Plots.mm) 
        savefig("solution_files/$(cvar_chr)_$(cvar_dis)_$(es_capacity)_$(alpha)/aggregate_$(u).png")
        close()
    end

    return
end

function aggregateSolution(cvar_chr::Float64, cvar_dis::Float64, T::Int64, mean_prices::Vector{Float64}, es_capacity::Float64, alpha::Float64)
    path = "solution_files/$(cvar_chr)_$(cvar_dis)_$(es_capacity)_$(alpha)/hourly/1.json"
    file=open(path)
    json=JSON.parse(file, dicttype = () -> DefaultOrderedDict(nothing))
    units = keys(json)
    close(file)
    aggregate_solution = OrderedDict()
    for u in units
        aggregate_solution[u]=OrderedDict()
        aggregate_solution[u]["Discharging power (MW)"]=OrderedDict()
        aggregate_solution[u]["Charging power (MW)"]=OrderedDict()
        aggregate_solution[u]["Net discharging power (MW)"]=OrderedDict()
        aggregate_solution[u]["Stored energy (MWh)"]=OrderedDict()
        aggregate_solution[u]["Hourly average cost (\$)"]=OrderedDict()
        aggregate_solution[u]["Hourly average revenue (\$)"]=OrderedDict()
        for s in 1:T
            path = "solution_files/$(cvar_chr)_$(cvar_dis)_$(es_capacity)_$(alpha)/hourly/$(s).json"
            file=open(path)
            json=JSON.parse(file, dicttype = () -> DefaultOrderedDict(nothing))
            close(file)
            aggregate_solution[u]["Discharging power (MW)"]["time period $(s)"]=json[u]["Discharging power (MW)"]["time period 1"]
            aggregate_solution[u]["Charging power (MW)"]["time period $(s)"]=json[u]["Charging power (MW)"]["time period 1"]
            aggregate_solution[u]["Net discharging power (MW)"]["time period $(s)"]=json[u]["Net discharging power (MW)"]["time period 1"]
            aggregate_solution[u]["Stored energy (MWh)"]["time period $(s)"]=json[u]["Stored energy (MWh)"]["time period 1"]
            aggregate_solution[u]["Hourly average cost (\$)"]["time period $(s)"]=json[u]["Hourly average cost (\$)"]["time period 1"]
            aggregate_solution[u]["Hourly average revenue (\$)"]["time period $(s)"]=json[u]["Hourly average revenue (\$)"]["time period 1"]
            if s==T
                aggregate_solution[u]["Final energy (MWh)"]=json[u]["Final energy (MWh)"]
            end
        end
        aggregate_solution[u]["Total average revenue"]=sum(values(aggregate_solution[u]["Hourly average revenue (\$)"]))
        aggregate_solution[u]["Total average cost"]=sum(values(aggregate_solution[u]["Hourly average cost (\$)"]))
        aggregate_solution[u]["Total average profit"]=aggregate_solution[u]["Total average revenue"]-aggregate_solution[u]["Total average cost"]
    end
    # plot_aggregate_solution_plots(cvar_chr, cvar_dis, units, aggregate_solution, mean_prices, es_capacity, alpha)
    open("solution_files/$(cvar_chr)_$(cvar_dis)_$(es_capacity)_$(alpha)/aggregate.json", "w") do file
        return JSON.print(file, aggregate_solution, 4)
    end
    return
end

function solveHorizon(cvar_chr::Float64, cvar_dis::Float64, T::Int64, mean_prices::Vector{Float64},  es_capacity::Float64, alpha::Float64)
    mkpath("solution_files/$(cvar_chr)_$(cvar_dis)_$(es_capacity)_$(alpha)/hourly/")
    for s in 1:T
        instance = StorageProblem.read("input_files/scenarios/$(cvar_chr)_$(cvar_dis)_$(es_capacity)_$(alpha)/$(s).json")
        model = StorageProblem.build_model(
            instance = instance,
            optimizer = Gurobi.Optimizer,
        )
        JuMP.optimize!(model)
        solution = StorageProblem.solution(model)
        StorageProblem.write("solution_files/$(cvar_chr)_$(cvar_dis)_$(es_capacity)_$(alpha)/hourly/$(s).json", solution)
        if s!=T
            path = "input_files/scenarios/$(cvar_chr)_$(cvar_dis)_$(es_capacity)_$(alpha)/$(s+1).json"
            file = open(path)
            json=JSON.parse(file, dicttype = () -> DefaultOrderedDict(nothing))
            close(file)
            for key in keys(solution)
                json["Units"][key]["Initial energy (MWh)"] = solution[key]["Stored energy (MWh)"]["time period 1"]
            end
            open("input_files/scenarios/$(cvar_chr)_$(cvar_dis)_$(es_capacity)_$(alpha)/$(s+1).json", "w") do file
                return JSON.print(file, json, 4)
            end
        end
    end
    StorageProblem.aggregateSolution(cvar_chr, cvar_dis, T, mean_prices, es_capacity, alpha)
end