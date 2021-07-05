using Colors, GitHub, LightGraphs, NetworkLayout, PkgDeps, Plots, Random, Statistics

ignore_pkgs = ["JuliaSmoothOptimizers.github", "MUMPS", "OptimizationProblems", "Organization", "QRMumps", "SuiteSparseMatrixCollection"]
model_pkgs = ["ADNLPModels", "AmplNLReader", "CUTEst", "LLSModels", "NLPModels", "NLPModelsJuMP", "NLPModelsModifiers", "NLPModelsTest", "PDENLPModels", "QuadraticModels"]
solver_pkgs = ["CaNNOLeS", "DCISolver", "JSOSolvers", "NLPModelsIpopt", "NLPModelsKnitro", "Percival", "RipQP", "SolverCore", "SolverTest", "SolverTools"]
la_pkgs = ["AMD", "HSL", "Krylov", "LDLFactorizations", "LimitedLDLFactorizations", "LinearOperators", "PROPACK"]

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

function gen_tex_file(G, nodes, jso_pkgs, posx, posy, reach)
  colors = ["black", "magenta", "blue", "red", "brown", "green!60!black", "cyan", "orange", "lime!50!black", "violet"]
  colors = [
    colors;
    colors .* ", dashed";
    colors .* ", dotted";
  ]
  n = length(nodes)
  A = adjacency_matrix(G)

  open("graph.tex", "w") do io
    println(io, raw"""
    \documentclass[tikz]{standalone}
    \usetikzlibrary{arrows}
    \begin{document}
    \begin{tikzpicture}[]
    """)
    for i = 1:n
      x = round(posx[i], digits=2)
      y = round(posy[i], digits=2)
      w = log(reach[i] + 4) / 4
      lbl = nodes[i]
      println(io, "\\node[draw, inner sep=$(w) cm, rounded corners] (p$i) at ($x,$y) {\\Large \\bf $lbl};")
    end
    count = 0
    for i = 1:n
      I = findall(A[i,:] .> 0)
      if length(I) > 0
        count += 1
      end
      sort!(I, by=j->posx[j])
      for j = I
        color = colors[count % length(colors) + 1]
        w = 1 + log(reach[i] + reach[j] + 1) / 2
        println(io, "\\draw[->,$color, shorten >= 0.2cm, line width=$w, bend left=20] (p$i) to (p$j);")
      end
    end
    count = 0
    for i = 1:n
      color = if nodes[i] ∈ model_pkgs
        "red!40"
      elseif nodes[i] ∈ solver_pkgs
        "green!40"
      elseif nodes[i] ∈ la_pkgs
        "blue!50"
      elseif nodes[i] ∈ jso_pkgs
        "yellow!40"
      else
        "gray!30"
      end
      x = round(posx[i], digits=2)
      y = round(posy[i], digits=2)
      w = log(reach[i] + 4) / 4
      lbl = nodes[i]
      brd = "gray"
      if sum(A[i,:]) > 0
        count += 1
        brd = colors[count % length(colors) + 1]
      end
      println(io, "\\node[draw=$brd, line width=0.1cm, inner sep=$(w) cm, rounded corners, fill=$color, opacity=0.9] (p$i) at ($x,$y) {\\Large \\bf $lbl};")
    end
    println(io, raw"""
    \draw[fill=white, opacity=0.9] (-24.5,21.5) rectangle(-15.5, 14.3);
    \node at (-20, 21) {\Large \bf Legend};
    \node[draw, opacity=0.9, text width=8cm, minimum size=1.1cm, rounded corners, fill=red!40] at (-20, 20) {\huge \bf Models};
    \node[draw, opacity=0.9, text width=8cm, minimum size=1.1cm, rounded corners, fill=green!40] at (-20, 18.8) {\huge \bf Solvers};
    \node[draw, opacity=0.9, text width=8cm, minimum size=1.1cm, rounded corners, fill=blue!50] at (-20, 17.6) {\huge \bf Linear Algebra};
    \node[draw, opacity=0.9, text width=8cm, minimum size=1.1cm, rounded corners, fill=yellow!40] at (-20, 16.4) {\huge \bf Other JSO};
    \node[draw, opacity=0.9, text width=8cm, minimum size=1.1cm, rounded corners, fill=gray!30] at (-20, 15.2) {\huge \bf Outside JSO};
    \end{tikzpicture}
    \end{document}
    """)
  end
end

# function build_graph(jso_pkgs, deps)
# end
# build_graph(jso_pkgs, deps)
# deps_copy = deepcopy(deps)

function compute_positions(jso_pkgs, deps)
  nodes = (vcat(values(deps)...) ∪ jso_pkgs) |> unique |> sort
  n = length(nodes)
  function weight(i)
    w = 1
    for y in get(deps, nodes[i], [])
      j = findfirst(y .== nodes)
      w += weight(j)
    end
    return w
  end
  reach = weight.(collect(1:n))
  idx = sortperm(reach, rev=true)
  nodes = nodes[idx]
  reach = reach[idx]

  G = SimpleDiGraph(n)
  for (i,x) in enumerate(nodes)
    for y in get(deps, x, [])
      j = findfirst(y .== nodes)
      add_edge!(G, i, j)
    end
  end
  A = adjacency_matrix(G)

  # posx = zeros(Int, n)
  # posy = zeros(Int, n)
  # L = 1:n |> collect
  # δx = 8
  # while length(L) > 0
  #   j = popfirst!(L)
  #   I = findall(A[j,:] .> 0)
  #   posx[I] .= max.(posx[I], posx[j] + δx)
  #   append!(L, I)
  # end
  # for x in unique(posx)
  #   I = findall(posx .== x)
  #   sort!(I, by=i->-10*reach[i] - Int(nodes[i] ∈ jso_pkgs))
  #   posy[I] = 1:length(I)
  # end

  alg = spring(
    A,
    seed=2,
    C=15.0,
    iterations=5000
  )
  gdx = getindex.(alg, 1) * 2.5
  gdy = getindex.(alg, 2) * 1.3
  # α = 0.0
  # posx = α * posx + (1 - α) * gdx
  # posy = α * posy + (1 - α) * gdy
  posx = gdx
  posy = gdy

  for (pkg, Δx, Δy) in [
    ("CombinatorialMultigrid", 20, -5),
    ("COSMO", 0, 13),
    ("ExaPF", 0, -5),
    ("HSL", 0, 12),
    ("LimitedLDLFactorizations", 0, -6),
    ("LinearOperators", 0, 10),
    ("MRIReco", -10, 6),
    ("PDENLPModels", 0, 20),
    ("Preconditioners", 12, 3),
    ("QDLDL", 0, -10),
    ("QPSReader", -8, 0),
  ]
    i = findfirst(nodes .== pkg)
    posx[i] += Δx
    posy[i] += Δy
  end

  return G, nodes, posx, posy, reach
end

jso_pkgs, deps = download_stuff()
G, nodes, posx, posy, reach = compute_positions(jso_pkgs, deps)
gen_tex_file(G, nodes, jso_pkgs, posx, posy, reach)