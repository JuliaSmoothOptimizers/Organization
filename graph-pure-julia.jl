using Colors, GitHub, Graphs, NetworkLayout, PkgDeps, Plots, Random, Statistics, LinearAlgebra, GraphViz
pyplot()

### You need abelsiqueira/GraphViz

ignore_pkgs = ["JuliaSmoothOptimizers.github", "Organization"]
model_pkgs = ["ADNLPModels", "AmplNLReader", "BundleAdjustmentModels", "CUTEst", "LLSModels", "ManualNLPModels", "NLPModels", "NLPModelsJuMP", "NLPModelsModifiers", "NLPModelsTest", "NLSProblems", "OptimizationProblems", "PDENLPModels", "QuadraticModels", "QPSReader", "ExpressionTreeForge", "FluxNLPModels", "KnetNLPModels", "PartiallySeparableNLPModels", "RegularizedProblems"]
solver_pkgs = ["BenchmarkProfiles", "CaNNOLeS", "DCISolver", "JSOSolvers", "NLPModelsIpopt", "NLPModelsKnitro", "Percival", "RipQP", "SolverCore", "SolverTest", "SolverTools", "SolverBenchmark", "JSOSuite", "QuadraticModelsCPLEX", "QuadraticModelsGurobi", "QuadraticModelsXpress", "PartiallySeparableSolvers", "PartitionedStructures", "PartitionedVectors", "FletcherPenaltySolver"]
la_pkgs = ["AMD", "BasicLU", "HSL", "Krylov", "LDLFactorizations", "LimitedLDLFactorizations", "LinearOperators", "PROPACK", "MUMPS", "QRMumps", "SparseMatricesCOO", "SuiteSparseMatrixCollection", "OperatorScaling"]

main_branch = [
  "ADNLPModels",
  "JSOSolvers",
  "JSOSuite",
  "Krylov",
  "LinearOperators",
  "NLPModels",
  "Percival",
  "SolverCore",
]

colors = ["darkred", "darkgreen", "darkorchid4", "black"]
class_of = pkg -> if pkg in model_pkgs
  1
elseif pkg in solver_pkgs
  2
elseif pkg in la_pkgs
  3
else
  4
end

function download_stuff()
  jso_pkgs = GitHub.repos("JuliaSmoothOptimizers")
  jso_pkgs = [x.name for x in jso_pkgs[1]]
  jso_pkgs = getindex.(splitext.(jso_pkgs), 1)
  jso_pkgs = setdiff(jso_pkgs, ignore_pkgs)
  @assert jso_pkgs ∩ ignore_pkgs == []
  n = length(jso_pkgs)
  isregistered = fill(false, n)

  deps = Dict{String,Any}()
  for i = 1:n
    pkg = jso_pkgs[i]
    try
      deps[pkg] = PkgDeps.users(pkg)
      isregistered[i] = true
    catch
      println("$pkg is not registered")
    end
  end
  deleteat!(jso_pkgs, findall(.!isregistered))
  return jso_pkgs, deps
end

function draw_graph(pkgs, deps, filename; engine="dot", limit_to_jso=false, limit_to_input=false, resize=false)
  graphviz = """digraph {
    ratio="compress";
    rankdir="LR";
    node [style=filled,fontcolor=white];
  """
  # Nodes
  pkg_deps = reduce(
    (acc, cur) -> acc ∪ cur,
    [get(deps, pkg, []) for pkg in pkgs]
  )
  all_pkgs = (limit_to_input ? pkgs : pkg_deps ∪ pkgs) |> unique |> sort
  if limit_to_jso
    all_pkgs = all_pkgs ∩ jso_pkgs
  end
  for pkg in all_pkgs
    cls = class_of(pkg)
    color = colors[cls]
    shape = cls ≤ 3 ? "box" : "oval"
    size = 25 + 2 * length(get(deps, pkg, 0))
    graphviz *= "$pkg [label=$pkg, color=$color, shape=$shape, fontsize=$size];\n"
  end
  for pkg in pkgs, dep in get(deps, pkg, [])
    if limit_to_jso && !(dep in jso_pkgs)
      continue
    end
    if limit_to_input && !(dep in pkgs)
      continue
    end
    graphviz *= "$dep -> $pkg;"
  end

  graphviz *= "}\n"

  open(pipeline(`dot -Tpng -K$engine`, filename), "w", stdout) do io
    print(io, graphviz)
  end
  if resize
    run(`mogrify -resize x2000 $filename`)
  end

  GraphViz.Graph(graphviz, engine=engine)
end

function main(jso_pkgs, deps)
  missing_pkgs = setdiff(jso_pkgs, model_pkgs ∪ solver_pkgs ∪ la_pkgs)
  if length(missing_pkgs) != 0
    @show missing_pkgs
  end
  @assert missing_pkgs == []

  draw_graph(jso_pkgs, deps, "ecosystem.png", engine="dot")
  draw_graph(jso_pkgs, deps, "ecosystem_only_jso.png", engine="dot", limit_to_jso=true)
  draw_graph(["NLPModels"], deps, "nlpmodels.png", engine="fdp", limit_to_jso=true)
  draw_graph(model_pkgs, deps, "models.png", engine="fdp")
  draw_graph(model_pkgs, deps, "models_jsoonly.png", engine="dot", limit_to_input=true, limit_to_jso=true)
  draw_graph(["LinearOperators", "Krylov"], deps, "la_core.png", engine="fdp")
  draw_graph(la_pkgs, deps, "linear_algebra.png", engine="fdp")
  draw_graph(la_pkgs, deps, "linear_algebra_jsoonly.png", engine="dot", limit_to_input=true)
  draw_graph(solver_pkgs, deps, "solvers.png", engine="fdp")
  draw_graph(solver_pkgs, deps, "solvers_jsoonly.png", engine="dot", limit_to_input=true)
  draw_graph(main_branch, deps, "jsosuite_main_branch.png", engine="dot", limit_to_input=true)

  selected = String[]
  S = ["LinearOperators", "Krylov"]
  while length(S) > 0
    pkg = pop!(S)
    if pkg in selected
      continue
    end
    push!(selected, pkg)
    new_deps = get(deps, pkg, String[]) ∩ jso_pkgs
    S = setdiff(S ∪ new_deps, selected)
  end
  draw_graph(selected, deps, "selected.png", engine="dot", limit_to_jso=true)
end

# jso_pkgs, deps = download_stuff()
# jso_union = sort(unique(model_pkgs ∪ solver_pkgs ∪ la_pkgs))
# if jso_pkgs != jso_union
#   @info setdiff(jso_pkgs, jso_union)
#   @info setdiff(jso_union, jso_pkgs)
# end
main(jso_pkgs, deps)
