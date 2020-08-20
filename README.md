# SimpleBibTeX

[![Build Status](https://github.com/thchr/SimpleBibTeX.jl/workflows/CI/badge.svg)](https://github.com/thchr/SimpleBibTeX.jl/actions)
[![Coverage](https://codecov.io/gh/thchr/SimpleBibTeX.jl/branch/master/graph/badge.svg)](https://codecov.io/gh/thchr/SimpleBibTeX.jl)

SimpleBibTeX.jl provides a simple parser of .bib files and .bib-formatted strings.
Two types, `Citation` and `Bibliography` (an `AbstractDict` wrapper over `Citations` and keys), and a single method `parsebibtex(...)` are exported (see help).

# Examples

```julia
bib = """
      @article{Silver:1862,
          author    = {Silver, L. J.},
          title     = {A guide to treasure islands},
          journal   = {Pirates Weekly},
          year      = {1862},
          volume    = {2},
          pages     = {666},
      }
      @book{Stevenson:1882,
          title = {Treasure Island},
          year  = {1882},
          author = {Stevenson, R. L.},
          publisher = {London: Cassell and Company},
      }
      @preamble{Pirates!}
      """
B, preamble = parsebibtex(IOBuffer(bib))
```

returns `B::Bibliography` and `preamble::Union{Nothing, String}`:
```julia
julia> B
Bibliography with 2 Citations:

  Stevenson:1882 (Book)
  ┌ publisher ── London: Cassell and Company
  │ author ───── Stevenson, R. L.
  │ year ─────── 1882
  └ title ────── Treasure Island

  Silver:1862 (Article)
  ┌ volume ───── 2
  │ author ───── Silver, L. J.
  │ year ─────── 1862
  │ journal ──── Pirates Weekly
  │ pages ────── 666
  └ title ────── A guide to treasury islands

julia> preamble
"Pirates!"
```

The `Bibliography` type implements the `AbstractDict` interface, allowing indexing by keys:
```julia
julia> B["Stevenson:1882"]
  Stevenson:1882 (Book)
  ┌ publisher ── London: Cassell and Company
  │ author ───── Stevenson, R. L.
  │ year ─────── 1882
  └ title ────── Treasure Island
```

which in turn can be indexed by fields:
```julia
julia> B["Stevenson:1882"]["author"]
"Stevenson, R. L."
```