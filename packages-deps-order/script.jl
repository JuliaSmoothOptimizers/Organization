#=
Build the dependency graph of the organization

Detect which packages are impacted by a breaking release

Extract an update order via topological sorting + strongly connected components (grouping cycles),
taking into account test dependencies (extras + test/Project.toml).
=#

using HTTP
using TOML
using Graphs
using Pkg
using JSON3

# ---------------------------------------------------------
# 1. Read the list of repositories
# ---------------------------------------------------------

function read_repo_list(path::String)
    repos = String[]
    for line in eachline(path)
        s = strip(line)
        isempty(s) && continue
        startswith(s, "#") && continue
        repo = s * ".jl"  # ⬅ automatically append .jl
        push!(repos, repo)
    end
    return repos
end

# ---------------------------------------------------------
# 2. Fetch Project.toml files from GitHub
# ---------------------------------------------------------

function fetch_project_toml(
    repo::String;
    user::String = "JuliaSmoothOptimizers",
    branches::Tuple{Vararg{String}} = ("main", "master"),
    file::String = "Project.toml",
)
    for branch in branches
        url = "https://raw.githubusercontent.com/$user/$repo/$branch/$file"
        resp = HTTP.get(url; status_exception = false)

        if resp.status == 200
            return TOML.parse(String(resp.body))
        elseif resp.status == 404
            # try next branch
            continue
        else
            @warn "Failed to fetch $file for $repo on branch $branch" status=resp.status
        end
    end

    @info "No $file found for $repo on branches $(join(branches, "-"))"
    return nothing
end

# ---------------------------------------------------------
# 2bis. Project structure
# ---------------------------------------------------------

struct ProjectInfo
    name::String
    repo::String
    uuid::Union{String,Nothing}
    deps::Dict{String,String}        # runtime deps (name => uuid)
    test_deps::Dict{String,String}   # test deps (name => uuid)
    compat::Dict{String,Vector{String}}  # name => list of compat strings
end

function load_projects_from_github(
    listfile::String;
    user::String = "JuliaSmoothOptimizers",
    branches = ("main", "master"),
)
    repos = read_repo_list(listfile)
    projects = Dict{String,ProjectInfo}()   # key = package name

    for repo in repos
        toml = fetch_project_toml(repo; user, branches)
        toml === nothing && begin
            @warn "Skipping repo $repo (no Project.toml)"
            continue
        end

        haskey(toml, "name") || begin
            @warn "Project.toml in $repo has no name, skipping"
            continue
        end

        name = toml["name"]
        uuid = get(toml, "uuid", nothing)

        deps_raw    = get(toml, "deps",    Dict{String,Any}())
        compat_raw  = get(toml, "compat",  Dict{String,Any}())
        extras_raw  = get(toml, "extras",  Dict{String,Any}())
        targets_raw = get(toml, "targets", Dict{String,Any}())

        # runtime deps
        deps = Dict{String,String}()
        for (depname, depval) in deps_raw
            if depval isa String
                deps[depname] = depval
            else
                @warn "Unexpected deps value" repo name depname depval
            end
        end

        # test deps via extras/targets
        test_deps = Dict{String,String}()

        test_names = String[]
        if haskey(targets_raw, "test")
            t = targets_raw["test"]
            if t isa AbstractVector
                test_names = String.(t)
            elseif t isa String
                test_names = [t]
            else
                @warn "Unexpected targets.test value" repo name t
            end
        end

        for (depname, depval) in extras_raw
            depname in test_names || continue
            if depval isa String
                test_deps[depname] = depval
            else
                @warn "Unexpected extras value for test dep" repo name depname depval
            end
        end

        # test deps via test/Project.toml
        test_toml = fetch_project_toml(
            repo;
            user,
            branches,
            file = "test/Project.toml",
        )
        if test_toml !== nothing
            test_deps_raw = get(test_toml, "deps", Dict{String,Any}())
            for (depname, depval) in test_deps_raw
                depval isa String || continue
                test_deps[depname] = depval
            end
        end

        # Normalize compat to Dict{String,Vector{String}}
        compat = Dict{String,Vector{String}}()
        for (depname, val) in compat_raw
            strs = String[]
            if val isa String
                append!(strs, [strip(s) for s in split(val, ',') if !isempty(strip(s))])
            elseif val isa AbstractVector
                for el in val
                    if el isa String
                        append!(strs, [strip(s) for s in split(el, ',') if !isempty(strip(s))])
                    else
                        @warn "Unexpected compat element type" repo name depname el
                    end
                end
            else
                @warn "Unexpected compat value type" repo name depname val
            end
            compat[depname] = strs
        end

        info = ProjectInfo(name, repo, uuid, deps, test_deps, compat)
        projects[name] = info
    end

    return projects
end

# ---------------------------------------------------------
# 3. Build the internal dependency graph
# ---------------------------------------------------------

"""
    build_dep_graph(projects)

Build a directed graph where each node is an internal package.
Edges: dep → pkg (the package `dep` must be updated before `pkg`).

Includes:
- runtime dependencies (`deps`)
- test dependencies (`test_deps`)

Returns (g, names) where names[i] = the package name for node i.
"""
function build_dep_graph(projects::Dict{String,ProjectInfo})
    names = collect(keys(projects))
    sort!(names)
    idx = Dict(name => i for (i, name) in enumerate(names))

    g = DiGraph(length(names))
    for (pkgname, proj) in projects
        # runtime deps
        for (depname, _) in proj.deps
            haskey(idx, depname) || continue
            add_edge!(g, idx[depname], idx[pkgname])
        end
        # test deps
        for (depname, _) in proj.test_deps
            haskey(idx, depname) || continue
            add_edge!(g, idx[depname], idx[pkgname])
        end
    end

    return g, names
end

# ---------------------------------------------------------
# 4. Detect which packages are impacted by a breaking release
# ---------------------------------------------------------

function compat_allows(compat_vec::Vector{String}, v::VersionNumber)
    for s in compat_vec
        try
            spec = Pkg.Types.VersionSpec(s)
            if v in spec
                return true
            end
        catch e
            @warn "Failed to parse compat string" compat_str=s exception=e
        end
    end
    return false
end

"""
    impacted_packages(projects, breaking_pkg, new_version)

Return the list of packages that must be updated because their compat entry
for `breaking_pkg` does not accept `new_version`.

Includes `breaking_pkg` itself if present.
"""
function impacted_packages(
    projects::Dict{String,ProjectInfo},
    breaking_pkg::String,
    new_version::VersionNumber,
)
    impacted = String[]
    if haskey(projects, breaking_pkg)
        push!(impacted, breaking_pkg)
    else
        @warn "breaking_pkg $breaking_pkg is not in projects"
    end

    for (name, proj) in projects
        name == breaking_pkg && continue
        haskey(proj.compat, breaking_pkg) || continue
        compat_vec = proj.compat[breaking_pkg]
        if !compat_allows(compat_vec, new_version)
            push!(impacted, name)
        end
    end

    return impacted
end

# ---------------------------------------------------------
# 5. Group into update blocks (SCC + topological order)
# ---------------------------------------------------------

"""
    update_blocks(g, names, impacted)

Return a list of blocks, where each block is a `Vector{String}` of package names
that must be updated together (cycle or isolated node).

- `g`      : graph with edges dep → pkg
- `names`  : names[i] = package name
- `impacted` : list of impacted packages
"""
function update_blocks(
    g::DiGraph,
    names::Vector{String},
    impacted::Vector{String},
)
    # 1. Strongly connected components
    scc = strongly_connected_components(g)

    # comp_of[v] = SCC index of vertex v
    comp_of = Dict{Int,Int}()
    for (cid, vertices) in enumerate(scc)
        for v in vertices
            comp_of[v] = cid
        end
    end

    # 2. Condensation graph (one node per SCC)
    C = DiGraph(length(scc))
    for e in edges(g)
        u = src(e)
        v = dst(e)
        cu = comp_of[u]
        cv = comp_of[v]
        cu == cv && continue
        add_edge!(C, cu, cv)
    end

    # 3. Topological sort of SCC graph
    comp_order = topological_sort_by_dfs(C)

    impacted_set = Set(impacted)
    blocks = Vector{Vector{String}}()

    # 4. Build blocks in order
    for cid in comp_order
        block = String[]
        for v in scc[cid]
            name = names[v]
            if name in impacted_set
                push!(block, name)
            end
        end
        isempty(block) && continue
        push!(blocks, block)
    end

    return blocks
end

# ---------------------------------------------------------
# 6. "Main" helper function
# ---------------------------------------------------------

"""
    compute_update_plan(listfile, breaking_pkg, new_version_str; user, branches)

Compute and print:
- the list of impacted packages
- the recommended update/release order (grouped into blocks)
"""
function compute_update_plan(
    breaking_pkg::String,
    new_version_str::String;
    listfile::String = "list_jso_packages.dat",
    user::String = "JuliaSmoothOptimizers",
    branches::Tuple{Vararg{String}} = ("main", "master"),
)
    new_version = VersionNumber(new_version_str)

    projects = load_projects_from_github(listfile; user, branches)
    g, names = build_dep_graph(projects)

    imp = impacted_packages(projects, breaking_pkg, new_version)
    println("Packages impacted by $breaking_pkg $new_version :")
    println(join(imp, ", "))

    blocks = update_blocks(g, names, imp)
    println("\nUpdate/release blocks:")
    for (k, block) in enumerate(blocks)
        println("$(k). $(join(block, ", "))")
    end

    println("\nRecommended update plan:")
    for (step, block) in enumerate(blocks)
        if length(block) == 1
            println("Step $step : update $(block[1])")
        else
            println("Step $step : update together: $(join(block, "-")) (cycle)")
        end
    end

    return blocks
end

"""
    compute_update_plan_data(listfile, breaking_pkg, new_version_str; user, branches)

Same as `compute_update_plan`, but returns a data structure instead of printing.

Returns a NamedTuple with:
- breaking_package :: String
- new_version      :: String
- impacted         :: Vector{String}
- blocks           :: Vector{Vector{String}}
"""
function compute_update_plan_data(
    breaking_pkg::String,
    new_version_str::String;
    listfile::String = "list_jso_packages.dat",
    user::String = "JuliaSmoothOptimizers",
    branches::Tuple{Vararg{String}} = ("main", "master"),
)
    new_version = VersionNumber(new_version_str)

    projects = load_projects_from_github(listfile; user, branches)
    g, names = build_dep_graph(projects)

    imp = impacted_packages(projects, breaking_pkg, new_version)
    blocks = update_blocks(g, names, imp)

    return (
        breaking_package = breaking_pkg,
        new_version      = string(new_version),
        impacted         = imp,
        blocks           = blocks,
    )
end

"""
    write_update_plan_json(outfile, listfile, breaking_pkg, new_version_str; user, branches)

Compute the update plan and write it as JSON into `outfile`.
"""
function write_update_plan_json(
    breaking_pkg::String,
    new_version_str::String;
    outfile::String = "update_plan.json",
    listfile::String = "list_jso_packages.dat",
    user::String = "JuliaSmoothOptimizers",
    branches = ("main", "master"),
)
    data = compute_update_plan_data(
        breaking_pkg,
        new_version_str;
        listfile = listfile,
        user = user,
        branches = branches,
    )

    open(outfile, "w") do io
        JSON3.pretty(io, data)
    end

    return outfile
end

# Helper to inspect successors
function print_outneighbors(g::DiGraph, names::Vector{String}, pkg::String)
    idx = Dict(n => i for (i, n) in enumerate(names))
    haskey(idx, pkg) || (println("Package $pkg not in graph"); return)
    v = idx[pkg]
    println("Successors of $pkg :")
    for u in outneighbors(g, v)
        println("  → ", names[u])
    end
end

# ---------------------------------------------------------
# 7. Graph visualization (optional)
# Check https://github.com/JuliaGraphs/GraphPlot.jl for more options
# ---------------------------------------------------------

using Compose, GraphPlot
using Cairo, Fontconfig, Colors

function print_graph(
    listfile::String = "list_jso_packages.dat";
    user::String = "JuliaSmoothOptimizers",
    branches::Tuple{Vararg{String}} = ("main", "master"),
)
    projects = load_projects_from_github(listfile; user, branches)
    g, names = build_dep_graph(projects)

    saveplot(gplot(g, nodelabel = names, plot_size = (16cm, 16cm)), "karate.svg")
end

#=
Example usage (REPL):

julia> write_update_plan_json("NLPModels", "0.22.0")
julia> print_graph()
julia> projects = load_projects_from_github("list_jso_packages.dat");
       g, names = build_dep_graph(projects);
       print_outneighbors(g, names, "NLPModels")
=#
