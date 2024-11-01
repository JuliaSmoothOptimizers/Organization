"""
    apply(dst_path[, data]; kwargs...)
    apply(src_path, dst_path[, data]; true, kwargs...)

Applies the template to an existing project at path ``dst_path``.
If the `dst_path` does not exist, this will throw an error.
For new packages, use `BestieTemplate.generate` instead.

## Keyword arguments

- `warn_existing_pkg::Bool = true`: Whether to check if you actually meant `update`. If you run `apply` and the `dst_path` contains a `.copier-answers.yml`, it means that the copy was already made, so you might have means `update` instead. When `true`, a warning is shown and execution is stopped.
- `quiet::Bool = false`: Whether to print greetings, info, and other messages. This keyword is also used by copier.

The other keyword arguments are passed directly to the internal [`Copier.copy`](@ref).
"""
function apply(
  src_path,
  dst_path;
  add_benchmark = true,
  warn_existing_pkg = true,
  kwargs...,
)
  quiet = get(kwargs, :quiet, false)

  if !isdir(dst_path)
    error("$dst_path does not exist. For new packages, use `BestieTemplate` first.")
  end
  if !isdir(joinpath(dst_path, ".git"))
    error("""No folder $dst_path/.git found. Are you using git on the project?
          To apply to existing packages, git is required to avoid data loss.""")
  end
  if isdir(joinpath(dst_path, "benchmark"))
    add_benchmark = false
  end

  if warn_existing_pkg && isfile(joinpath(dst_path, ".copier-answers.jso.yml"))
    @warn """There already exists a `.copier-answers.jso.yml` file in the destination path.
    You might have meant to use `(JSO)BestieTemplate.update` instead, which only fetches the non-applying updates.
    If you really meant to use this command, then pass the `warn_existing_pkg = false` flag to this call.
    """

    return nothing
  end

  # generate_jso_copier_answers(dst_path)
  data = YAML.load_file(joinpath(dst_path, ".copier-answers.yml"))
  jso_data = OrderedDict{String,Any}()
  names_copier = ["PackageName", "PackageOwner", "PackageUUID", "_src_path", "_commit"]
  for entry in names_copier
    jso_data[entry] = data[entry]
  end
  jso_data["AddBreakage"] = true
  jso_data["AddBenchmark"] = !isdir(joinpath(dst_path, "benchmark")) | add_benchmark
  jso_data["AddBenchmarkCI"] =
    isdir(joinpath(dst_path, "benchmark")) | jso_data["AddBenchmark"]
  jso_data["AddCirrusCI"] = true
  YAML.write_file(joinpath(dst_path, ".copier-answers.jso.yml"), jso_data)

  BestieTemplate.Copier.copy(src_path, dst_path, answers_file = ".copier-answers.jso.yml")

  package_name = data["PackageName"]
  quiet || println("""JSOBestieTemplate was applied to $package_name.jl! 🎉 """)

  return nothing
end

function apply(dst_path; kwargs...)
  apply("https://github.com/tmigot/JSOBestieTemplate.jl/template", dst_path; kwargs...)
end
