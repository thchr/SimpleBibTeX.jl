# To do a better job, one ought to check soundness relative to the 
# BibTeX specification (http://www.bibtex.org/Format/): for now, this
# is just tested against a private .bib file, where it works well. 
# Currently, one cannot e.g. have @string or @comment entries, though 
# it could easily be included.

module SimpleBibTeX

export Citation, Bibliography, parsebibtex
import Base: readuntil
import Base: show, getindex, keys, values, haskey, get, length, iterate

# ---- Types ----
struct Citation 
    kind::String
    key::String
    data::Dict{String, String}
end
Citation(kind, key) = Citation(titlecase(kind), key, Dict{String, String}()) # for 'kind', uppercase first letter, lowercase rest
getindex(C::Citation, key) = C.data[key]
keys(C::Citation) = keys(C.data)

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

const MIN_SEPLEN = 10 # lead length for showing of `Citation`s

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

function show(io::IO, ::MIME"text/plain", B::Bibliography)
    println(io, "Bibliography with ", length(B.citations), " entries:")
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
    readfield(f::IO)

Reads a field/preamble entry from a BibTeX file, assuming that `f::IO` (e.g. `IOStream`
or `IOBuffer`) has _just_ read `fieldkey =` or `@preamble`, (where `fieldkey` is e.g.
`author`, `title`, etc). In that case, the field/preamble contents are enclosed in 
a set of {...} brances. We do a small dance to allow braces within those braces.
The output is the contents within those braces. The `IOStream`/`IOBuffer` is moved to the
end of the matching braces.
"""
function readfield(f::IO)
    readuntil(f, '{') # move "read-cursor" up to start of contents
    bracesum = 1 # brace counter: `{` adds 1, `}` subtracts one; contents "done" when `bracesum = 0`
    fieldentry = ""
    # start reading contents (a loop, because we need to allow for braces within contents)
    while !eof(f) 
        step = readuntil(f, ['{', '}'], keep=true)
        bracesum += last(step) == '}' ? -1 : 1
        fieldentry *= step # "add" what we have read so far into field contents
        if iszero(bracesum) # contents are terminated, cf. brace count; go to next field
            break 
        end
    end
    return fieldentry[1:end-ncodeunits("}")] # remove the closing `}`, which is not part of field contents
end


"""
    parsebibtex(f::IO)

Builds a `Bibliography`, containing `Citation` fields, corresponding 
to the BibTeX entries in the `f::IO` object (e.g. `IOStream` or `IOBuffer`).
Also outputs a preamble as a `String` (empty, if no such content exists in `f`)
"""
function parsebibtex(f::IO)
    B = Bibliography()
    preamble = ""
    while !eof(f)
        if last(readuntil(f, '@', keep = true)) == '@' # @ marks new citation
            kind = readuntil(f, '{') # type of citation (e.g., Article, Book, etc.)  
            if lowercase(kind) == "preamble" # BibTeX entry of the `preamble` kind
                preamble *= readfield(f) 
            
            else                         # assume this is an "ordinary" BibTeX entry (e.g., kind is not `preamble`, `comment`, or `string`)
                key  = readuntil(f, ",") # key of citation  (e.g., John:2012)
                C = Citation(kind, key)
                # find fields in citation
                while !eof(f) 
                    # some citations may have no fields; check for `}` in that case; 
                    # if it has any fields, their key terminates with `=`
                    fieldkey = lowercase(readuntil(f, ['=', '}'], keep=true)) 
                    if last(fieldkey) == '}' # no fields in citation; go to next one
                        break
                    else
                        fieldkey = fieldkey[1:end-sizeof("=")] # a field was found; remove `=` from key string
                    end

                    # remove comma from last line & do some simple clean-up, in 
                    # case user entered quasi-garbled format. `fieldkey` is e.g.,
                    # 'author', 'title', etc.
                    for swap in ["\n", "\r", " ", "\t", ","]   
                        fieldkey = replace(fieldkey, swap=>"")
                    end
                    
                    # read the field contents (delimited by {...} braces)
                    fieldentry = readfield(f) 
                    for swap in ["\n"=>" ", "\r"=>" ", "\t"=>" ", r"[ ]{2,}"=>" "] 
                        fieldentry = replace(fieldentry, swap) # clean up if user gave quasi-garbled format for field contents
                    end
                    C.data[fieldkey] = fieldentry # add the field in the Citation's dict entry
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
Also outputs a preamble as a `String` (empty, if no such content exists in input)
"""
function parsebibtex(filename_or_string::String; isfilename::Bool=true)
    # treat string-input as the name of a file, relative to caller
    if isfilename == true 
        f = open(filename_or_string)
        B, preamble = parsebibtex(f)
        close(f)
        return B, preamble

    # treat input as a valid BibTeX entry
    else  
        return parsebibtex(IOBuffer(filename_or_string))
    end
end

end # module