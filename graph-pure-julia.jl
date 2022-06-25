using Colors, GitHub, Graphs, NetworkLayout, PkgDeps, Plots, Random, Statistics, LinearAlgebra
pyplot()

ignore_pkgs = ["JuliaSmoothOptimizers.github", "Organization"]
model_pkgs = ["ADNLPModels", "AmplNLReader", "BundleAdjustmentModels", "CUTEst", "LLSModels", "ManualNLPModels", "NLPModels", "NLPModelsJuMP", "NLPModelsModifiers", "NLPModelsTest", "NLSProblems", "OptimizationProblems", "PDENLPModels", "QuadraticModels", "QPSReader"]
solver_pkgs = ["BenchmarkProfiles", "CaNNOLeS", "DCISolver", "JSOSolvers", "NLPModelsIpopt", "NLPModelsKnitro", "Percival", "RipQP", "SolverCore", "SolverTest", "SolverTools", "SolverBenchmark"]
la_pkgs = ["AMD", "BasicLU", "HSL", "Krylov", "LDLFactorizations", "LimitedLDLFactorizations", "LinearOperators", "PROPACK", "MUMPS", "QRMumps", "SparseMatricesCOO", "SuiteSparseMatrixCollection"]
loose_pkgs = ["BasicLU", "MUMPS", "OptimizationProblems", "QRMumps", "SuiteSparseMatrixCollection"]

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

function compute_positions(jso_pkgs, deps)
  all_pkgs = (vcat(values(deps)...) ∪ jso_pkgs) |> unique |> sort
  external = setdiff(all_pkgs, jso_pkgs)

  n = length(all_pkgs)
  G = SimpleDiGraph(n)
  for (i,x) in enumerate(all_pkgs)
    for y in get(deps, x, [])
      j = findfirst(y .== all_pkgs)
      add_edge!(G, i, j)
    end
  end

  A = adjacency_matrix(G)

  # Not great, but working
  # layout = spring(
  #   A,
  #   # seed = 7,
  #   # initialpos = [(i, i * 0.1) for i = 1:n]
  # )
  # posx = getindex.(layout, 1)
  # posy = getindex.(layout, 2)

  # Separate clusters
  posx = zeros(n)
  posy = zeros(n)
  offset = [(0, 0), (-35, -6), (35, -6)]
  for (k, pkg_set) in enumerate([model_pkgs, solver_pkgs, la_pkgs])
    # Add external pkgs
    neighs = vcat([
      all_pkgs[neighbors(G, findfirst(pkg .== all_pkgs))] for pkg in pkg_set
    ]...) |> unique |> sort
    neighs = neighs ∩ external
    pkg_set = pkg_set ∪ neighs

    idxs = indexin(pkg_set, all_pkgs)
    Aset = A[idxs, idxs]
    layout = spring(
      Aset,
      iterations = 1000,
      seed = 2,
      # C = sqrt(length(pkg_set)) * 2.5,
      C = 14,
    )
    x = getindex.(layout, 1)
    y = getindex.(layout, 2)
    posx[idxs] = x .+ offset[k][1]
    posy[idxs] = y .+ offset[k][2]
  end

  layout = spring(
    A,
    initialpos = zip(posx, posy),
    C = 10000,
    iterations = 50,
  )
  posx = getindex.(layout, 1)
  posy = getindex.(layout, 2)

  return G, all_pkgs, posx, posy
end

function plot_graph(G, all_pkgs, posx, posy, jso_pkgs)
  n = length(posx)

  external = setdiff(all_pkgs, jso_pkgs)

  classes = [
    if pkg in model_pkgs
        1
    elseif pkg in solver_pkgs
        2
    elseif pkg in la_pkgs
      3
    else
      4
    end
    for pkg in all_pkgs
  ]
  JL = Colors.JULIA_LOGO_COLORS
  color_map = [JL.red, JL.green, JL.purple, JL.blue]
  colors = color_map[classes]
  neighbs = [neighbors(G, i) for i = 1:n]
  text_size(w) = ceil(Int, 14 + w * 0.6)
  text_sizes = [text_size(length(neighbs[i])) for i = 1:n]

  function box_around!(x, y, ℓ, h, c)
    plot!(
      x .+ ℓ * [-1, 1, 1, -1, -1],
      y .+ h * [-1, -1, 1, 1, -1],
      c = :gray,
      fill = true,
      fillcolor = :white,
      lab = "",
      opacity = 0.8,
    )
  end

  plt = plot(size=(1920, 1080), leg=false, grid=false, axis=false)
  for i = 1:n, j = 1:n
    if has_edge(G, i, j)
      p = [posx[i]; posy[i]]
      q = [posx[j]; posy[j]]
      d = q - p
      p = p + d / norm(d)
      q = q - 2 * d / norm(d)
      if classes[j] == 4
        scatter!([p[1]], [p[2]], c=colors[i], ms=5)
        plot!([p[1], q[1]], [p[2], q[2]], l=:arrow, lab="", c=:black, opacity=0.2, lw=2)
      else
        plot!([p[1], q[1]], [p[2], q[2]], l=:dash, lab="", c=:black, opacity=0.1, lw=1)
      end
    end
  end


  for i = sort(1:n, by=j -> text_sizes[j])
    h = 0.07 * text_sizes[i]
    ℓ = 0.025 * length(all_pkgs[i]) * text_sizes[i] + 0.08 * text_sizes[i]
    box_around!(posx[i], posy[i], ℓ, h, colors[i])
  end

  annotate!(
    [(posx[i], posy[i], text(all_pkgs[i], text_sizes[i], colors[i])) for i = 1:n],
  )

  # legends
  legends = ["Models", "Solvers", "Linear Algebra", "External"]
  x_leg = -60 * ones(4)
  y_leg = 28 .- 3 * (0:3)
  scatter!(
    x_leg,
    y_leg,
    m = :square,
    ms = 20,
    c = color_map,
    lab = "",
  )

  annotate!(
    [(
      x_leg[i] + length(legends[i]) * 0.4 + 2,
      y_leg[i],
      text(legends[i], 16)
    ) for i = 1:4]
  )

  png("graph")
  plt
end

function main(jso_pkgs, deps)
  G, all_pkgs, posx, posy = compute_positions(jso_pkgs, deps)
  indexof(pkg) = findfirst(pkg .== all_pkgs)
  fix_list = [
    ("BasicLU", 0, -5),
    ("MRIsim", 0, -2),
    ("LDLFactorizations", -10, 0),
    ("Krylov", -10, 0),
    ("MRFingerprintingRecon", 50, -10),
    ("QDLDL", -2, -2),
    ("ScHoLP", -10, -15),
    ("MadNLPTests", 0, 20),
    ("SparsityOperators", 0, -2),
    ("Preconditioners", 3, 0),
    ("StoppingInterface", 8, 13),
    ("SparseMatricesCOO", 30, -3),
    ("Cloudy", 25, 0),
    ("CaNNOLeS", 3, 0),
  ]
  for (pkg, Δx, Δy) in fix_list
    k = indexof(pkg)
    posx[k] += Δx
    posy[k] += Δy
  end
  plot_graph(G, all_pkgs, posx, posy, jso_pkgs)
end

# jso_pkgs, deps = download_stuff()
jso_union = sort(unique(model_pkgs ∪ solver_pkgs ∪ la_pkgs))
if jso_pkgs != jso_union
  @info setdiff(jso_pkgs, jso_union)
  @info setdiff(jso_union, jso_pkgs)
end
main(jso_pkgs, deps)
