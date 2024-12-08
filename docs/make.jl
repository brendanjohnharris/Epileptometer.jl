using Epileptometer
using Documenter

DocMeta.setdocmeta!(Epileptometer, :DocTestSetup, :(using Epileptometer); recursive=true)

makedocs(;
    modules=[Epileptometer],
    authors="brendanjohnharris <bhar9988@uni.sydney.edu.au> and contributors",
    sitename="Epileptometer.jl",
    format=Documenter.HTML(;
        canonical="https://brendanjohnharris.github.io/Epileptometer.jl",
        edit_link="main",
        assets=String[],
    ),
    pages=[
        "Home" => "index.md",
    ],
)

deploydocs(;
    repo="github.com/brendanjohnharris/Epileptometer.jl",
    devbranch="main",
)
