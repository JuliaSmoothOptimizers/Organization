using Pkg
Pkg.activate(@__DIR__)
Pkg.instantiate()

using JSON

function write_report(
    organization_name::String = "JuliaSmoothOptimizers";
    filepath::String = joinpath(dirname(@__DIR__), "pkgs_data", "list_jso_packages.dat"),
)
    # --- 1) Get current packages from GitHub ---
    current_pkgs = Set(organization_pkgs(organization_name))
    if isempty(current_pkgs)
        @warn "No packages found - this might indicate an API error"
    end

    # --- 2) Read existing file if present ---
    existing_pkgs = if isfile(filepath)
        Set(filter(!isempty, readlines(filepath)))
    else
        Set{String}()  # empty set
    end

    # --- 3) Compute differences ---
    added   = setdiff(current_pkgs,  existing_pkgs)
    removed = setdiff(existing_pkgs, current_pkgs)

    # --- 4) Report differences ---
    for pkg in added
        @info "New package detected" pkg
    end
    for pkg in removed
        @warn "Package in file not found in organization anymore" pkg
    end

    # --- 5) Write updated file (sorted for reproducibility) ---
    open(filepath, "w") do io
        for pkg in sort(collect(current_pkgs))
            write(io, pkg, "\n")
        end
    end

    return (added = added, removed = removed, current = current_pkgs)
end

# maximum 100 packages
function organization_pkgs(organization_name::String = "JuliaSmoothOptimizers")
  json = JSON.parse(
    read(`curl https://api.github.com/orgs/$(organization_name)/repos\?per_page=100`, String),
  )
  pkgs = map(x -> x["name"], json)
  pkgs = filter(x -> x[(end - 1):end] == "jl", pkgs)
  pkgs = map(x -> x[1:(end - 3)], pkgs)
  return sort(pkgs)
end

write_report()
