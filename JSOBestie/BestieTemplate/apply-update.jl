data = Dict(
    # "PackageName" 
    # "PackageUUID" => guessed
    # "PackageAuthors" => 
    "PackageOwner" => "JuliaSmoothOptimizers",
    "JuliaMinVersion" => "lts",
    "JuliaMinCIVersion" => "lts",
    "RunJuliaNightlyOnCI" => "Y",
    # "License" => "MPL-2.0" - Write on Zulip if different to confirm
    # "LicenseCopyrightHolders" => same as authors without and contributors
    "AnswerStrategy" => "ask",
    "JuliaIndentation" => 2,
    "ConfigIndentation" => 2,
    "MarkdownIndentation" => 2,
    "CheckExplicitImports" => "Y",
    "AddPrecommit" => "Y",
    "AutoIncludeTests" => "Y",
    "ExplicitImportsChecklist" => "exclude_all_qualified_access_are_public",
    # "UseCirrusCI" => "Y", # if Cirrus is already in the package.
    "AddMacToCI" => "Y",
    "AddWinToCI" => "Y",
    "AddCopierCI" => "no",
    "AddGitHubTemplates" => "Y",
    "AddContributionDocs" => "Y",
    "AddAllcontributors" => "Y",
    "AddCodeOfConduct" => "Y",
    # "CodeOfConductContact" => same as authors
)
BestieTemplate.apply(".", data, overwrite = true)
# If BestieTemplate needs to be udpated use:
# BestieTemplate.update(data, overwrite = true)
