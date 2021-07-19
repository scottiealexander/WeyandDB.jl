module WeyandDB

include("./CSV.jl")
include("./FileOps.jl")
using .CSV, .FileOps

export eachpair

const DATEDICT = Dict{Vector{String}, Int}(
    ["ja", "jan", "january"]   => 01,
    ["fe", "feb", "february"]  => 02,
    ["ma", "mar", "march"]     => 03,
    ["ap", "apr", "april"]     => 04,
    ["may"]                    => 05,
    ["ju", "jun", "june"]      => 06,
    ["jl", "jul", "july"]      => 07,
    ["au", "aug", "august"]    => 08,
    ["se", "sep", "september"] => 09,
    ["oc", "oct", "october"]   => 10,
    ["no", "nov", "november"]  => 11,
    ["de", "dec", "december"]  => 12
)
# ============================================================================ #
struct DB
    db::Vector{Pair{Int,String}}
end
get_ids(db::DB) = first.(db.db)
Base.length(db::DB) = length(db.db)
Base.getindex(db::DB, k::Integer) = db.db[k]
function Base.getindex(db::DB; id::Integer=-1)
    k = findfirst(isequal(id), get_ids(db))
    k == nothing && error("No entry with id $(id) exists in the database")
    return db.db[k]
end
# ============================================================================ #
struct DBIterator
    db::DB
end

eachpair(db::DB) = DBIterator(db)

Base.IteratorSize() = HasLength()
Base.IteratorEltype() = HasEltype()
Base.length(db::DBIterator) = length(db.db)
Base.eltype(db::DBIterator) = Tuple{Vector{Float64}, Vector{Float64}}
Base.iterate(db::DBIterator) = Base.iterate(db, 1)
function Base.iterate(db::DBIterator, state::Integer)
    state > length(db) && return nothing
    return get_data(db.db, state), state+1
end
# ============================================================================ #
function get_month_id(str::AbstractString)
    for (k, v) in DATEDICT
        if str in k
            return v
        end
    end
    return -1
end
# ============================================================================ #
function get_id(file::AbstractString)
    idstr = replace(basename(file), "S_SPK.csv"=>"")
    m = match(r"(\d{4})([A-Za-z]{2,3})(\d+)", idstr)
    m == nothing && error("Failed to parse file name into id")

    yr = parse(Int, m[1])
    mo = get_month_id(lowercase(m[2]))
    id = parse(Int, m[3])

    return yr * Int(1e5) + mo * Int(1e3) + id
end
# ============================================================================ #
function get_database(::String, f::Function=x->true)
    files = find_files(joinpath(@__DIR__, "..", "data"), r".*\.csv")
    filter!(files) do file
        f(get_id(file))
    end
    ids = get_id.(files)
    ks = sortperm(ids)
    return DB(map((x,y)->x=>y, ids[ks], files[ks]))
end
# ============================================================================ #
function get_data(db::DB, idx::Integer=0; id::Integer=-1)
    MS2SEC = 0.001

    ((idx < 1 && id < 0) || idx > length(db)) && error("Invalid index / id!")
    if idx > 0
        file = db[idx].second
    elseif id > -1
        file = db[id=id].second
    end

    d = CSV.parse(file, ',', [Float64, Float64])

    lgn = d["timestamps_ms"][findall(isequal(0), d["ids"])] .* MS2SEC
    ret = d["timestamps_ms"][findall(>(0), d["ids"])] .* MS2SEC

    # some records have negative timestamps, so shift both accordingly (plus
    # 100ms so we don't have any timestamps at exactly 0)
    t0 = min(minimum(ret), minimum(lgn))
    t0 = t0 < 0 ? abs(t0) + 0.1 : 0.1

    # retina recordings are S-potentials, so they do NOT include conduction
    # delays, thus we shift the LGN timestamps forwards by 2ms (relative to the
    # retina) to avoid any weirdness that the short delay may introduce
    return ret .+ t0, lgn .+ (t0 + 0.002)
end
# ============================================================================ #
end
