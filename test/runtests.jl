using SimpleBibTeX
using Test

@testset "SimpleBibTeX.jl" begin
    bibstr = """
        @article{Rudin:1997,
            author    = {Rudin, S. and Dyakonov, M.},
            title     = {Edge and strip plasmons in a two-dimensional electron fluid},
            journal   = {Phys. Rev. B},
            year      = {1997},
            volume    = {55},
            pages     = {4684},
            doi       = {10.1103/PhysRevB.55.4684},
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

    B, preamble = parsebibtex(bibstr, isfilename=false)
    C = B["Abajo:1997"]
    # test basic functionality
    @test length(B) == 2
    @test B["Abajo:1997"]["volume"] == "56"
    @test B["Rudin:1997"]["pages"] == "4684"
    @test sort(collect(keys(B))) == ["Abajo:1997", "Rudin:1997"]
    @test preamble === nothing

    # test show methods
    display_string(x) = (io=IOBuffer(); show(io, MIME"text/plain"(), x); String(take!(io)))

    strB = display_string(B)
    strC =  display_string(C)
    ioC  = IOBuffer(strC)
    
    @test (readline(IOBuffer(strB)) ==                    # Bibliography summary
           "Bibliography with 2 Citations:" ==
           summary(B)*':')
    @test readline(ioC) == "  Abajo:1997 (Article)"       # Citation "header"
    @test readline(ioC)[1:3] == "  ┌"                     # Citation opening bracket
    
    # test preamble
    B′, preamble′ = parsebibtex(bibstr*"\n@preamble{A nice preamble}", isfilename=false)
    @test all(values(B) .== values(B′))
    @test keys(B) == keys(B′)
    @test preamble′ == "A nice preamble"

    # test citation keys
    println(Set(keys(C)))
    ks = ["volume","author","year","journal","pages","doi","title","timestamp"]
    @test Set(keys(C)) == Set(ks)
end
