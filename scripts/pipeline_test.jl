#! /bin/bash
# -*- mode: julia -*-
#=
exec julia -t auto --startup-file=no --color=yes "${BASH_SOURCE[0]}" "$@"
=#
using DrWatson
DrWatson.@quickactivate
using Epileptometer
using TimeseriesTools
using StatsBase
using TimeseriesFeatures
using Catch22
using CatchaMouse16
using BIDSTools
using EDF
using DelimitedFiles
using DataFrames
using CairoMakie
using MultivariateStats

function makeflat(F)
    f = permutedims(F, (Feat, :channel, Obs)) # * So that observations are on rows
    e = lookup(f, Obs)
    f = reshape(f, :, size(f, 3))
    return f, e
end

begin # * Check out data and select a subject
    layout = Layout(datadir("BIDS_Siena"))
    subject = layout |> subjects |> first
    session = subject |> sessions |> first
    file = session |> files |> first
end
begin # * LDA on Foff and Fon (probably should do ICA first to pull out signals that are consistent across subjects)
    F = calculate(subject)

    f = permutedims(F, (Feat, :channel, Obs)) # * So that observations are on rows
    e = lookup(f, Obs)
    f = reshape(f, :, size(f, 3))
    f, e = makeflat(F)
    f[isnan.(f)] .= 0 # ! Hackety hack
    m = fit(MulticlassLDA, f, e; outdim = 2)
    fpred = predict(m, f)
end
begin # * Plot
    f = Figure()
    ax = Axis(f[1, 1])
    fpred_on = fpred[:, e .== 1]
    fpred_off = fpred[:, e .== 0]
    scatter!(ax, Point2f.(eachcol(fpred_off)), color = :blue, alpha = 0.5)
    scatter!(ax, Point2f.(eachcol(fpred_on)), color = :red, alpha = 0.5)
    f
end

begin # * Try on a different session (same subject)
    subject = layout |> subjects |> first
    session = subject |> sessions |> last
    file = session |> files |> first
end
begin # * LDA on Foff and Fon (probably should do ICA first to pull out signals that are consistent across subjects)
    F = calculate(subject)
    f = permutedims(F, (Feat, :channel, Obs)) # * So that observations are on rows
    e = lookup(f, Obs)
    f = reshape(f, :, size(f, 3))
    f, e = makeflat(F)
    f[isnan.(f)] .= 0 # ! Hackety hack
    fpred = predict(m, f) # Using the LDA model from a different session
end
begin # * Plot
    f = Figure()
    ax = Axis(f[1, 1])
    fpred_on = fpred[:, e .== 1]
    fpred_off = fpred[:, e .== 0]
    scatter!(ax, Point2f.(eachcol(fpred_off)), color = :blue, alpha = 0.5)
    scatter!(ax, Point2f.(eachcol(fpred_on)), color = :red, alpha = 0.5)
    f
end

if false
    map(layout |> files) do file
        X, e = formateeg(file)
        Off = X[𝑡 = .!e]
        On = X[𝑡 = e]
        Foff = catch24.(Off)
        Fon = catch24(On)
        return (Foff, Fon)
    end
end
