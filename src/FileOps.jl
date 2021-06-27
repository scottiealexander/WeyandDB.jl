module FileOps

export find_files, find_directories

# =========================================================================== #
find_files(dir::AbstractString, re=r".*") = return do_match(dir, re, isfile)
# --------------------------------------------------------------------------- #
find_directories(dir::AbstractString, re=r".*") = return do_match(dir, re, isdir)

# =========================================================================== #
function do_match(dir::AbstractString, re::Regex, f::Function)
    if !isdir(dir)
        error("Input is not a vaild directory path")
    end
    files = [joinpath(dir, x) for x in readdir(dir)]
    return filter(x->occursin(re, x) && f(x), files)
end
# =========================================================================== #
end # END MODULE
