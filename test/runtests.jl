using SimpleBibTeX
using Test

@testset "SimpleBibTeX.jl" begin
    entries = """
        @article{Rudin:1997,
            author    = {Rudin, S. and Dyakonov, M.},
            title     = {Edge and strip plasmons in a two-dimensional electron fluid},
            journal   = {Phys. Rev. B},
            year      = {1997},
            volume    = {55},
            pages     = {4684},
            doi       = {10.1103/PhysRevB.55.4684},
            owner     = {tomch},
            timestamp = {2015.07.03}
        }
        @article{Abajo:1997,
            author    = {Garc\\'\\i{}a de Abajo, {\\relax F.J} and Aizpurua, J.},
            title     = {Numerical simulation of electron energy loss near inhomogeneous dielectrics},
            journal   = {Phys. Rev.~B},
            year      = {1997},
            volume    = {56},
            pages     = {15873-15884},
            doi       = {10.1103/PhysRevB.56.15873},
            timestamp = {2015.08.19}
        }
        """

    B, preamble = parsebibtex(entries, isfilename=false)

    @test length(B) == 2
    @test B["Abajo:1997"]["volume"] == "56"
    @test B["Rudin:1997"]["pages"] == "4684"
    @test sort(collect(keys(B))) == ["Abajo:1997", "Rudin:1997"]
    @test isempty(preamble)
end
