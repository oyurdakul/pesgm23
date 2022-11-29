import JuMP: value, fix, set_name



function _init(model::JuMP.Model, key::Symbol)::OrderedDict
    if !(key in keys(object_dictionary(model)))
        model[key] = OrderedDict()
    end
    return model[key]
end

function scalar(x; default = nothing)
    x !== nothing || return default
    return x
end