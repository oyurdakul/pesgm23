function plot_net_discharging_frontier_plots(unit_net_discharging_levels, 
    cvar_chr_params, cvar_dis_params, mean_prices, energy_storage_capacity, alpha_params)
    for (unit, dict) in unit_net_discharging_levels
        colors = ["#e6194B", "#bfef45", "#ffe119", "#911eb4", "#000075"  ]
        gr()
        plot_font = "Computer Modern"
        default(fontfamily=plot_font, legend=true, 
            legendfontsize = 14, grid=false)
        p = twinx()
        xticks = 1
        xticks = vcat(xticks, [i for i in 6:6:T])
        plot(size=(1000,400), right_margin = 5Plots.mm, left_margin =5Plots.mm, bottom_margin = 6Plots.mm, 
            y_foreground_color_text = "#c7a577",) 
        T = 0
        x = []
        i=1
        for ch_cvar in cvar_chr_params
            for ds_cvar in cvar_dis_params
                for e in energy_storage_capacity
                    for a in alpha_params
                        T = length(values(dict["CVaR chr $(ch_cvar) CVaR dis $(ds_cvar) Enr cap $(e) alpha $(a)"]))
                        x = [j+(-0.09+0.03*i) for j in 1:T]
                        ch_label = L"\beta:" * L"%$(ch_cvar)"
                        plot!(x, [val+(3.6-1.2*i) for 
                        (time_key, val) in dict["CVaR chr $(ch_cvar) CVaR dis $(ds_cvar) Enr cap $(e) alpha $(a)"]],
                        color=colors[i], 
                        label=ch_label, 
                        ylabel = "net discharging power (MW)", legend = :topleft, fillalpha =1.0,
                        xlims = (0, T+1), 
                        ylims = (0, 25),
                        xlabel = L"time period $[k]$",
                        xticks = xticks,
                        xguidefontsize=16,
                        yguidefontsize=16,
                        ytickfontsize=16,
                        tickfontsize=16,
                        linewidth = 2.0,
                        linetype=:steppre, dpi=600)
                    end
                end
            end
        end
        plot!(p, x, mean_prices[:,1], color="#48A1D5", fillalpha=1.0, 
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
        ylims = (100, 400),
        dpi=600)
        plot!(x, zeros(T), fillrange= mean_prices[:,1], color="#48A1D5", fillalpha=0.3, 
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
        linewidth = 0.3,
        xlims = (0, T+1), 
        ylims = (100, 400),
        dpi=600)
    end
    return
end