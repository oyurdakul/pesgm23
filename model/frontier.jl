using Base: Order
using Printf
using JSON
using DataStructures
using GZip
using LaTeXStrings
import Base: getindex, time
using LaTeXStrings
using PyCall
import PyPlot as plt
using Plots
function plot_profit_frontier(unit_profits, cvar_chr_params, yaxis, yaxis_string)
    gr()
    plot_font = "Computer Modern"
    default(fontfamily=plot_font, legend=true, 
            linewidth=2, legendfontsize = 16, grid=false)
    for (unit, dict) in unit_profits
        profits = reshape([i for i in values(dict)], (length(yaxis), length(cvar_chr_params)))
        heatmap(cvar_chr_params, yaxis, profits, 
                colorbar_title="\ntotal average profits (A\$\$)",
                colorbar_titlefontsize = 16,
                right_margin = 13Plots.mm, left_margin = 7Plots.mm, top_margin = 2Plots.mm, bottom_margin = 7Plots.mm,
                xlims = (-0.05, Inf), 
                xticks = [0.0,0.1,0.2,0.3,0.4],
                # ylims = (0, 1),
                # ylims = (2, 26),
                yticks = [0.0, 0.2, 0.4, 0.6, 0.8, 0.99],
                dpi=600, c = 
                cgrad(["#f9cf95", "#fad8aa", "#fbe2bf", "#94cfd9" , "#5abbcf", "#0b7790"],
                [0.1, 0.25, 0.35, 0.5, 0.8, 0.9], rev = false),
                size=(1000,400))
        xaxis!(L"weight of the CVaR term $\beta$", guidefontsize=16, tickfontsize=16)
        yaxis!(L"risk confidence level $\alpha$", guidefontsize=16, ytickfontsize=16)
        # yaxis!("energy storage capacity (MWh)", guidefontsize=16, ytickfontsize=16)
        savefig("solution_files/profit_frontier_$(yaxis_string)_$(unit).png")
    end
    return
end

function plot_net_discharging_frontier(unit_net_discharging_levels, cvar_chr_params, cvar_dis_params, mean_prices, energy_storage_capacity, alpha_params)
    colors = ["#e6194B", "#bfef45", "#ffe119", "#911eb4", "#000075"  ]
    markers = ["-o", "-1", "-^", "-*", "-x"]
    plt.matplotlib[:rc]("mathtext",fontset="cm")    
    for (unit, dict) in unit_net_discharging_levels
        fig, ax1 = plt.subplots(figsize=(16.0, 7.0))
        ax2 = ax1.twinx()
        ax1.set_xlim([0, 49])
        xlab = [1]
        append!(xlab,[i for i in 6:6:48])
        ax1.set_xticks(xlab)
        ax1.set_xticklabels([L"%$i" for i in xlab], fontsize=30)
        ax1.set_xlabel(L"\mathrm{time\,}[k]", fontsize=30)
        ax1.set_ylabel(L"\mathrm{net\,discharging\,power\,(MW)}", fontsize=30)
        for tick in ax1.get_yticklabels()
            tick.set_fontname("Times New Roman")
            tick.set_fontsize(20)
        end
        for tick in ax2.get_yticklabels()
            tick.set_fontname("Times New Roman")
            tick.set_fontsize(20)
            tick.set_color("#48A1D5")
        end
        # ax2.set_ylabel(L"\mathrm{pre-dispatch\,price\,(A\$/MWh)}", color="#48A1D5", fontsize=30)
        ax2.set_ylabel(L"\mathrm{A\$/MWh}", color="#48A1D5", fontsize=30)
        # ax1.set_xticks([i for i in 1:48])
        T = 0
        x = []
        i=1
        for ch_cvar in cvar_chr_params
            for ds_cvar in cvar_dis_params
                for e in energy_storage_capacity
                    for a in alpha_params
                        T = length(values(dict["CVaR chr $(ch_cvar) CVaR dis $(ds_cvar) Enr cap $(e) alpha $(a)"]))
                        x = [j+(-0.21+0.07*i) for j in 1:T]
                        disc_label = L"\beta:" * L"%$(ch_cvar)"
                        ax1.step(x, [val+(3.6-1.2*i) for 
                        (time_key, val) in dict["CVaR chr $(ch_cvar) CVaR dis $(ds_cvar) Enr cap $(e) alpha $(a)"]], 
                        label = disc_label, color=colors[i], markers[i], alpha=(1.0), linewidth = (0.6))
                        i += 1
                    end
                end
            end
        end
        x = [j for j in 1:T]
        ax2.step(x, mean_prices[:,1], "--", color="#48A1D5", alpha=1.0, linewidth=0.3, label = L"\mathrm{energy\,price\,(A\$/MWh)}")
        ax2.fill_between(x, mean_prices[:,1], color="#48A1D5", step="pre",  alpha=0.1)
        ax2.spines["right"].set_color("#48A1D5")
        ax1.legend(loc="upper left", fontsize=30)
        ax2.legend(loc="upper right", fontsize=30)
        plt.savefig("solution_files/net_discharging_levels_$(unit).png", bbox_inches="tight", dpi=1200)
    end
    return
end

function plot_net_discharging_frontier_plots(unit_net_discharging_levels, 
    cvar_chr_params, cvar_dis_params, mean_prices, energy_storage_capacity, alpha_params)
    for (unit, dict) in unit_net_discharging_levels
        colors = ["#e6194B", "#bfef45", "#ffe119", "#911eb4", "#000075"  ]
        markers = [ :circle, :dtriangle, :star5, :diamond, :utriangle]
        gr()
        plot_font = "Computer Modern"
        default(fontfamily=plot_font, legend=true, 
            legendfontsize = 14, grid=false)
        p_new = twinx()
        T = 0
        x = []
        i=1
        for ch_cvar in cvar_chr_params
            for ds_cvar in cvar_dis_params
                for e in energy_storage_capacity
                    for a in alpha_params
                        T = length(values(dict["CVaR chr $(ch_cvar) CVaR dis $(ds_cvar) Enr cap $(e) alpha $(a)"]))
                        xticks = 1
                        xticks = vcat(xticks, [i for i in 6:6:T])
                        x = [j+(-0.15+0.05*i) for j in 1:T]
                        ch_label = L"$\beta$: %$(ch_cvar)"
                        if ch_cvar == cvar_chr_params[1]
                            plot(x, [val+(0.21-0.07*i) for  
                            (time_key, val) in dict["CVaR chr $(ch_cvar) CVaR dis $(ds_cvar) Enr cap $(e) alpha $(a)"]],
                            markershape = markers[i],
                            markerstrokewidth = 0,
                            # markersize  = 15,
                            # markeralpha = 1.0,
                            color=colors[i], 
                            label=ch_label, 
                            foreground_color_legend = nothing,
                            ylabel = "net discharging power (MW)", legend = :topleft, fillalpha =1.0,
                            xlims = (0, T+1), 
                            ylims = (-320, 840),
                            yticks=[-300, -150, 0, 150, 300],
                            # ylims = (-30, 30),
                            # yticks=[-30, -20, -10, 0, 10, 20, 30],
                            xlabel = L"time period $[k]$",
                            xticks = xticks,
                            xguidefontsize=16,
                            yguidefontsize=16,
                            ytickfontsize=16,
                            tickfontsize=16,
                            linewidth =0.6,
                            linetype=:steppre, dpi=600)
                            i += 1
                        else
                            # plot!(x, [val+(3.6-1.2*i) for 
                            plot!(x, [val+(0.21-0.07*i) for 
                            (time_key, val) in dict["CVaR chr $(ch_cvar) CVaR dis $(ds_cvar) Enr cap $(e) alpha $(a)"]],
                            markershape = markers[i],
                            markerstrokewidth = 0,
                            color=colors[i], 
                            label=ch_label, 
                            foreground_color_legend = nothing,
                            ylabel = "net discharging power (MW)", legend = :topleft, fillalpha =1.0,
                            xlims = (0, T+1), 
                            ylims = (-320, 840),
                            yticks=[-300, -150, 0, 150, 300],
                            # ylims = (-30, 30),
                            # yticks=[-30, -20, -10, 0, 10, 20, 30],
                            xlabel = L"time period $[k]$",
                            xticks = xticks,
                            xguidefontsize=16,
                            yguidefontsize=16,
                            ytickfontsize=16,
                            tickfontsize=16,
                            linewidth =0.6,
                            linetype=:steppre, dpi=600)
                            i += 1
                        end
                    end
                end
            end
        end
        
        x = [j for j in 1:T]
        plot!(p_new, x, zeros(T), fillrange= mean_prices[:,1], color="#48A1D5", fillalpha=0.1, 
        label = "",
        ylabel = "",
        y_foreground_color_axis = "#48A1D5", y_guidefontcolor="#48A1D5", 
        y_foreground_color_border="#48A1D5", y_foreground_color_text="#48A1D5", 
        foreground_color_legend = nothing,
        linestyle=:solid,
        legend = :topright,
        linetype = :steppre,
        yguidefontsize=16,
        ytickfontsize=16,
        linewidth = 0.1,
        xlims = (0, T+1), 
        ylims = (0, 4600),
        dpi=600)
        plot!(p_new, x, mean_prices[:,1], color="#48A1D5", fillalpha=1.0, 
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
        linewidth = 1.0,
        xlims = (0, T+1),
        ylims = (0, 4600),
        dpi=600)
        plot!(size=(1000,400), right_margin = 5Plots.mm, left_margin =5Plots.mm, bottom_margin = 6Plots.mm) 
        savefig("solution_files/net_discharging_levels_$(unit).png")
        close()
    end
    return
end

function construct_frontier(cvar_chr_params::Vector{Float64}, cvar_dis_params::Vector{Float64}, mean_prices::Vector{Float64},energy_storage_capacity::Vector{Float64}, alpha_params::Vector{Float64})
    file = open("solution_files/$(cvar_chr_params[1])_$(cvar_dis_params[1])_$(energy_storage_capacity[1])_$(alpha_params[1])/aggregate.json")
    json=JSON.parse(file, dicttype = () -> DefaultOrderedDict(nothing))
    units = keys(json)
    close(file)
    profit = OrderedDict()
    net_discharge = OrderedDict()
    for c in cvar_chr_params
        for d in cvar_dis_params
            for e in energy_storage_capacity
                for a in alpha_params
                    file = open("solution_files/$(c)_$(d)_$(e)_$(a)/aggregate.json")
                    json=JSON.parse(file, dicttype = () -> DefaultOrderedDict(nothing))
                    for u in units
                        profit["$(c) $(d) $(e) $(a) $(u)"] = json[u]["Total average profit"]
                        net_discharge["$(c) $(d) $(e) $(a) $(u)"] = json[u]["Net discharging power (MW)"]
                    end
                    close(file)
                end
            end
        end
    end
    results = OrderedDict()
    unit_profits = OrderedDict()
    unit_net_discharging_levels = OrderedDict()
    for u in units
        temp = OrderedDict()
        temp2 = OrderedDict()
        for c in cvar_chr_params
            for d in cvar_dis_params
                for e in energy_storage_capacity
                    for a in alpha_params
                        temp["CVaR chr $(c) CVaR dis $(d) Enr cap $(e) alpha $(a)"] = profit["$(c) $(d) $(e) $(a) $(u)"] 
                        temp2["CVaR chr $(c) CVaR dis $(d) Enr cap $(e) alpha $(a)"] = net_discharge["$(c) $(d) $(e) $(a) $(u)"] 
            
                    end
                end
            end
        end
        unit_profits[u] = temp
        unit_net_discharging_levels[u] = temp2
    end
    results["Total average profits (\$)"]=unit_profits
    results["Net discharging levels (MW)"]=unit_net_discharging_levels
    write("solution_files/frontier.json", results)
    # plot_profit_frontier(unit_profits, cvar_chr_params, energy_storage_capacity, "energy_storage_capacity")
    # plot_profit_frontier(unit_profits, cvar_chr_params, alpha_params, "alpha")
    plot_net_discharging_frontier_plots(unit_net_discharging_levels, cvar_chr_params, cvar_dis_params, mean_prices, energy_storage_capacity, alpha_params)
    return 
end
