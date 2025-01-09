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

WINDOWLEN = 2000 # Samples, arbitrary choice

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
end
begin # * LDA on Foff and Fon (probably should do ICA first to pull out signals that are consistent across subjects)
    F = calculate(session; windowlen = WINDOWLEN)
    f, e = makeflat(F)
    f[isnan.(f)] .= 0 # ! Hackety hack
    m = fit(MulticlassLDA, f, e; outdim = 2)
    fpred = predict(m, f)
end
begin # * Plot
    fig = Figure(size = (800, 400))
    ax = Axis(fig[1, 1])
    fpred_on = fpred[:, e .== 1]
    fpred_off = fpred[:, e .== 0]
    scatter!(ax, Point2f.(eachcol(fpred_off)), color = :cornflowerblue, alpha = 0.5)
    scatter!(ax, Point2f.(eachcol(fpred_on)), color = :crimson, alpha = 0.5)
    fig
end

begin # * Try on a different session (same subject)
    subject = layout |> subjects |> first
    session = subject |> sessions |> last
end
begin # * LDA on Foff and Fon (probably should do ICA first to pull out signals that are consistent across subjects)
    Ft = calculate(session; windowlen = WINDOWLEN)
    ft, et = makeflat(F)
    ft[isnan.(ft)] .= 0 # ! Hackety hack
    ftpred = predict(m, ft) # Using the LDA model from a different session
end
begin # * Plot
    ax = Axis(fig[1, 2])
    ftpred_on = ftpred[:, e .== 1]
    ftpred_off = ftpred[:, e .== 0]
    scatter!(ax, Point2f.(eachcol(fpred_off)), color = :cornflowerblue, alpha = 0.5)
    scatter!(ax, Point2f.(eachcol(fpred_on)), color = :crimson, alpha = 0.5)
    fig
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
