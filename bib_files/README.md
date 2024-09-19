# Generate and Validate JSO Citations Files

This folder contains script that can be used to:
- Validate CITATION.cff files accross the organization, `JSO_cff_validate.sh`;
- Generate a jso.bib file will all the CITATION.bib and CITATION.cff collected, `JSO_cff_to_bib.sh`.

The list of JSO packages checked is [../pkgs_data/list_jso_packages.dat](https://github.com/JuliaSmoothOptimizers/Organization/blob/main/pkgs_data/list_jso_packages.dat).

The validation and conversion relies on [cffconvert](https://github.com/citation-file-format/cffconvert).
Note that a CFF file that doesn't pass the validation is not converted in BIB format.

## Formatting of jso.bib

The reference of each bib entry is `NameOfThePackage_jl`.

# TODO
- [ ] More formatting can be done in the jso.bib file such as handling upper cases in the titles.
- [ ] Decide wether we use `@misc` or `@software` for the entries in the bib file.
- [ ] Make this an automatic process using Github Actions
- [ ] Make sure all packages are on the branch main
- [ ] Check if url mentioned in the BIB exist
- [ ] Check if DOI exist
- [ ] Check if first-names are initials (should be literal)
