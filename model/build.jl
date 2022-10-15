using JuMP, MathOptInterface, DataStructures
import JuMP: value, fix, set_name
using JSON: print

function build_model(;
    instance::StorageProblemInstance,
    optimizer = nothing,
)::JuMP.Model
    @info "Building model..."
    time_model = @elapsed begin
        model = Model()
        if optimizer !== nothing
            set_optimizer(model, optimizer)
        end
        model[:obj] = AffExpr()
        model[:instance] = instance
        for g in instance.units
            _add_unit!(model, g)
        end
        @objective(model, Min, model[:obj])
    end
    @info @sprintf("Built model in %.2f seconds", time_model)

    return model
end