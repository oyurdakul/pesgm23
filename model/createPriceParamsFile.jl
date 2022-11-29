using Base: Float64
using DataStructures: push!
using Printf
using JSON
using DataStructures
using GZip
import Base: getindex, time
using Random, Distributions


function createPriceParamsFile(path::AbstractString)
    function scalar(x; default = nothing)
        x !== nothing || return default
        return x
    end
    file = open(path)
    json = JSON.parse(file, dicttype = () -> DefaultOrderedDict(nothing))
    simulation_horizon = json["Parameters"]["Simulation horizon (min)"]
    time_step = scalar(json["Parameters"]["Time step (min)"], default = 60)
    (60 % time_step == 0) ||
        error("Time step $time_step is not a divisor of 60")
    T = simulation_horizon ÷ time_step
    close(file)
    mkpath("input_files/price_params/")
    for s in 1:T
        price_file = OrderedDict()
        price_file["Prices"] = OrderedDict()
        for t in 1:(T-s+1)
            price_file["Prices"]["time period $(t)"] = OrderedDict()
            price_file["Prices"]["time period $(t)"]["mean"] =  10
            temp = OrderedDict()
            for k in 1:T
                if k !== t
                    temp["time period $(k)"]=0
                else
                    temp["time period $(k)"]=k
                end
            end
            price_file["Prices"]["time period $(t)"]["covariance"] = temp
        end 
        open("input_files/price_params/$(s).json", "w") do f
            JSON.print(f, price_file, 4)
        end
    end
    return T
end