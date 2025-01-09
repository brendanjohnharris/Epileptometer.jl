module Epileptometer
using DrWatson
using TimeseriesTools
using TimeseriesFeatures
using Catch22
using CatchaMouse16
using BIDSTools
using EDF
using DataFrames

export formateeg, catch42, calculate

function formateeg(file::BIDSTools.File)
    X = EDF.read(file.path)
    X = map(X.signals) do x
        if x isa EDF.AnnotationsSignal
            return
        end
        dt = X.header.seconds_per_record / x.header.samples_per_record
        start = 0.0
        ts = range(start, step = dt, length = length(x.samples))
        x.header.label => Timeseries(ts, x.samples; metadata = Dict("file" => file))
    end
    filter!(!isnothing, X)
    X = cat(last.(X)...; dims = Dim{:channel}(first.(X)))
    E = file.events
    events = Timeseries(times(X), fill(false, size(X, 𝑡)))
    interval = only(E.onset) .. only(E.onset + E.duration)
    events[𝑡 = interval] .= true
    @assert only(E.recordingDuration) == duration(X) + step(X) # ! Why 1 sample discrepancy?
    return (X, events)
end
function formateeg(session::Session)
    files = session |> BIDSTools.files
    runs = [file.entities["run"] for file in files]
    xe = map(formateeg, files)
    x = DimArray(first.(xe), Dim{:run}(Meta.parse.(runs));
                 metadata = Dict("session" => session))
    events = DimArray(last.(xe), Dim{:run}(Meta.parse.(runs)))
    return (X, events)
end

const catch42 = catch24 + catchaMouse16 + FeatureSet([CR_RAD, CR_RAD_raw])

function calculate(file::File; dt = 1 / file.metadata["SamplingFrequency"]) # * Assume it is ok to concatenate data from either side of the seizure event
    x, e = formateeg(file)
    Off = x[𝑡 = .!e]
    On = x[𝑡 = e]

    x = map([Off, On], [0, 1]) do O, e # * Buffer to smaller time series
        ts = range(0, step = dt, length = size(O, 𝑡))
        O = set(O, 𝑡 => ts)
        O = buffer.(eachslice(O, dims = 2), 1000, 0) # 1000 samples, 0 overlap
        # O = [set.(o, [dims(o[1], 𝑡)]) for o in O] # Set all time indices to start at 0
        O = map(O) do o # Add window labels
            E = fill(e, size(o, 1))
            E = DimensionalData.Categorical(E; order = DimensionalData.Unordered())
            ToolsArray(o, Obs(E))
        end
        return stack(stack.(O))
    end
    x = cat(x..., dims = Obs)
    catch42(x)
end
function calculate(session::Session)
    files = session |> BIDSTools.files
    Fs = calculate.(files)
    obs = vcat(lookup.(Fs, Obs)...)
    cat(Fs..., dims = Obs(obs))
end
function calculate(subject::Subject)
    sessions = subject |> BIDSTools.sessions
    Fs = calculate.(sessions)
    obs = vcat(lookup.(Fs, Obs)...)
    cat(Fs..., dims = Obs(obs))
end

end
