
# using CSV, Tables
# using DataFrames
# using DataStructures
# using Random, Distributions, LinearAlgebra


# using LaTeXStrings
# using Plots
# gr()
# plot_font = "Computer Modern"
# default(fontfamily=plot_font, legend=true, 
#         linewidth=2, legendfontsize = 12, grid=false)

# heatmap(a,b,c, colorbar_title=
#         "\ntotal average profits (A\$\$)", right_margin = 5Plots.mm, c = 
#         cgrad(["#fbe2bf", "#fad8aa", "#f9cf95", "#0b7790", "#5abbcf", "	#94cfd9" ],
#         [0.1, 0.25, 0.35, 0.5, 0.8, 0.9], rev = false))
# xaxis!(L"charging CVaR weight $\beta^{c}$", tickfontsize=10)
# yaxis!(L"discharging CVaR weight $\beta^{d}$", ytickfontsize=10)
# a = OrderedDict("a" => 1.23, "b" => 2.34, "c" => 2.32)
# c = [i for i in range(0.0, step=0.1, length=5)]
# print((c))

# a = 3
# @info "alpha chr parameter: $(a)"

# a = vcat([i for i in range(0.1, step = 0.1, stop=0.9)], 0.99)
# print("$(a) 3\n")
# print(4)

xticks = 1
xticks = vcat(xticks, [i for i in 6:6:48])
print(xticks[1])
