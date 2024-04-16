using JSON

function write_report(
  organization_name::String = "JuliaSmoothOptimizers"
)
  list_pkgs = organization_pkgs(organization_name)
  open("pkgs_data/list_jso_packages.dat", "w") do io
    [write(io, name * "\n") for name in list_pkgs]
  end
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
