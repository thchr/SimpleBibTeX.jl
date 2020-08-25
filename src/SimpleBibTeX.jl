# To do a better job, one ought to check soundness relative to the 
# BibTeX specification (http://www.bibtex.org/Format/): for now, this
# is just tested against a private .bib file, where it works well. 
# Currently, one cannot e.g. have @string or @comment entries, though 
# it could easily be included.

module SimpleBibTeX

export Citation, Bibliography, parsebibtex

import Base: readuntil # icky extend
import Base: show, getindex, keys, values, haskey, get, length, iterate,    # overloads
             summary, ==

const MIN_SEPLEN = 10 # lead length for showing of `Citation`s

# ---- Types ----
struct Citation 
    kind::String
    key::String
    data::Dict{String, String}
end
Citation(kind, key) = Citation(titlecase(kind), key, Dict{String, String}()) # for 'kind', uppercase first letter, lowercase rest
getindex(C::Citation, key) = C.data[key]
keys(C::Citation) = keys(C.data)
(==)(C::Citation, C′::Citation) = C.kind == C′.kind && C.key == C′.key && C.data == C′.data

struct Bibliography <: AbstractDict{String,Citation}
    citations::Dict{String, Citation}
end
Bibliography() = Bibliography(Dict{String, Citation}())
# AbstractDict interface
keys(B::Bibliography) = keys(B.citations)
values(B::Bibliography) = values(B.citations)
getindex(B::Bibliography, key) = B.citations[key]
haskey(B::Bibliography, key::String) = haskey(B.citations, key)
get(B::Bibliography, key, default) = get(B.citations, key, default)
length(B::Bibliography) = length(B.citations)
iterate(B::Bibliography) = iterate(B.citations)
iterate(B::Bibliography, i::Int) = iterate(B.citations, i)

# ---- Show methods ----
delim(i, L) = i == 1 ? "┌" : i == L ? "└" : "│" # make connections pretty...

function show(io::IO, ::MIME"text/plain", C::Citation)
    println(io, "  ", C.key, " (", C.kind, ")")
    maxlen = !isempty(C.data) ? maximum(length.(keys(C))) : NaN
    seplen = max(MIN_SEPLEN, maxlen)
    entrystart = seplen + 4
    for (i,field) in enumerate(C.data)
        print(io, "  ", delim(i, length(C.data)), " $(field[1]) ", 
                  "─"^(seplen-length(field[1])+1), " ")
        print(io, "$(field[2])\n")
    end
    return nothing
end

function summary(io::IO, B::Bibliography)
    n = length(B)
    Base.showarg(io, B, true)
    print(io, " with ", n, (n==1 ? " Citation" : " Citations"))
end
function show(io::IO, ::MIME"text/plain", B::Bibliography)
    summary(io, B)
    println(io, ':')
    i = 1
    for C in values(B)
        if i <= 5 # no need to print any more than at most 5 citations, after that, it's just too much
            println(io); show(io, MIME"text/plain"(), C); 
            i+=1
        else 
            print(io, "\n  … (+", length(B.citations)-5, " additional entries) …")
            break
        end
    end
    return nothing
end


# ---- Auxiliary, generic functions ----
"""
    readuntil(s::IO, delims::Vector{T}; keep::Bool=false) where T<:AbstractChar

Same as `readuntil(s::IO, delim::AbstractChar; ...)` but allows `delims` to be 
a vector of characters: the first such match defines the termination condition.
"""
function readuntil(s::IO, delims::Vector{T}; keep::Bool=false) where T<:AbstractChar
    out = IOBuffer()
    while !eof(s)
        c = read(s, Char)
        if any(c .== delims)
            keep && write(out, c)
            break
        end
        write(out, c)
    end
    return String(take!(out))
end


# ---- Functionality to parse a BibTeX file ----
"""
    readfield(io::IO)

Reads a field/preamble entry from a BibTeX file, assuming that `io::IO` (e.g. `IOStream`
or `IOBuffer`) has _just_ read `fieldkey =` or `@preamble`, (where `fieldkey` is e.g.
`author`, `title`, etc). In that case, the field/preamble contents are enclosed in 
a set of {...} brances. We do a small dance to allow braces within those braces.
The output is the contents within those braces. The `IOStream`/`IOBuffer` is moved to the
end of the matching braces.
"""
function readfield(io::IO, ispreamble::Bool=false)
    ispreamble || readuntil(io, '{') # move "read-cursor" up to start of contents
    bracesum = 1 # brace counter: `{` adds 1, `}` subtracts 1; "done" when `bracesum = 0`
    fieldentry_io = IOBuffer()
    # start reading contents (loop, because we need to allow for braces within contents)
    while !eof(io) 
        step = readuntil(io, ['{', '}'], keep=true)
        if length(step) == 1 || step[end-1] ≠ '\\'
            bracesum += last(step) == '}' ? -1 : 1
        end

        if iszero(bracesum) # contents are terminated, cf. brace count; return field string
            write(fieldentry_io, SubString(step, 1, ncodeunits(step)-ncodeunits('}')))
            return String(take!(fieldentry_io))
        else
            write(fieldentry_io, step) # "add" what we have read so far into field contents
        end
    end
end


"""
    parsebibtex(io::IO)

Builds a `Bibliography`, containing `Citation` fields, corresponding 
to the BibTeX entries in the `io::IO` object (e.g. `IOStream` or `IOBuffer`).
Also outputs a preamble as a `String` if present (`nothing` otherwise)
"""
function parsebibtex(io::IO)
    B = Bibliography()
    preamble = nothing
    while !eof(io)
        if last(readuntil(io, '@', keep = true)) == '@' # @ marks new citation
            kind = readuntil(io, '{') # type of citation (e.g., Article, Book, etc.)  
            if lowercase(kind) == "preamble" # BibTeX entry of the `preamble` kind
                preamble = readfield(io, true)
            
            else  
                # assume this is an "ordinary" BibTeX entry (e.g., kind is not `preamble`,
                # `comment`, or `string`)
                key  = readuntil(io, ",") # key of citation  (e.g., John:2012)
                C = Citation(kind, key)
                # find fields in citation
                while !eof(io) 
                    # some citations may have no fields; check for `}` in that case; 
                    # if it has any fields, their key terminates with `=`
                    fieldkey = lowercase(readuntil(io, ['=', '}'], keep=true)) 
                    if last(fieldkey) == '}' # no fields in citation; go to next one
                        break
                    else
                        fieldkey = fieldkey[1:end-sizeof("=")] # a field was found; remove `=` from key string
                    end

                    # remove comma from last line & do some simple clean-up, in case user
                    # entered quasi-garbled format. `fieldkey` is e.g., author, title, etc.
                    for swap in ('\n', '\r', ' ', '\t', ',') 
                        fieldkey = replace(fieldkey, swap=>"")
                    end
                    
                    # read the field contents (delimited by {...} braces)
                    fieldentry = readfield(io) 
                    for swap in ('\n'=>' ', '\r'=>' ', '\t'=>' ', r"[ ]{2,}"=>' ') 
                        # clean up if user gave quasi-garbled format for field contents
                        fieldentry = replace(fieldentry, swap)
                    end
                    C.data[fieldkey] = fieldentry # add field to the Citation's dict entry
                end
                B.citations[key] = C # add the Citation to the Bibliography
            end     
        end
    end

    return B, preamble
end

""" 
    parsebibtex(filename_or_string::String; isfilename::Bool=true)

Constructs a `Bibliography` struct, containing `Citation` fields, corresponding 
to the BibTeX entries in the `filename_or_string` string. 
If `isfilename=true` (default), the input string is interpreted as the 
location of a file. If `false`, the string is interpreted and parsed as BibTeX.
Also outputs a preamble as a `String` if present (`nothing` otherwise)
"""
function parsebibtex(filename_or_string::String; isfilename::Bool=true)
    # treat string-input as the name of a file, relative to caller
    if isfilename == true 
        open(filename_or_string) do io
            return parsebibtex(io)
        end

    # treat input as a valid BibTeX entry
    else  
        return parsebibtex(IOBuffer(filename_or_string))
    end
end

end # module