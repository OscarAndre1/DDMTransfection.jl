using DDMTransfection
using Documenter

DocMeta.setdocmeta!(DDMTransfection, :DocTestSetup, :(using DDMTransfection); recursive=true)

makedocs(;
    modules=[DDMTransfection],
    authors="Oscar Andre <bmp13oan@student.lu.se> and contributors",
    repo="https://github.com/oscarandre1/DDMTransfection.jl/blob/{commit}{path}#{line}",
    sitename="DDMTransfection.jl",
    format=Documenter.HTML(;
        prettyurls=get(ENV, "CI", "false") == "true",
        canonical="https://oscarandre1.github.io/DDMTransfection.jl",
        assets=String[],
    ),
    pages=[
        "Home" => "index.md",
    ],
)

deploydocs(;
    repo="github.com/oscarandre1/DDMTransfection.jl",
    devbranch="main",
)
