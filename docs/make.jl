using Documenter, Makie
cd(Pkg.dir("Makie", "docs"))
include("../examples/library.jl")

using Documenter: Selectors, Expanders, Markdown
using Documenter.Markdown: Link, Paragraph
struct DatabaseLookup <: Expanders.ExpanderPipeline end

Selectors.order(::Type{DatabaseLookup}) = 0.5
Selectors.matcher(::Type{DatabaseLookup}, node, page, doc) = false

const regex_pattern = r"example_database\(([\"a-zA-Z_0-9. ]+)\)"
const atomics = (
    heatmap,
    image,
    lines,
    linesegments,
    mesh,
    meshscatter,
    scatter,
    surface,
    text,
    Makie.volume
)

match_kw(x::String) = ismatch(regex_pattern, x)
match_kw(x::Paragraph) = any(match_kw, x.content)
match_kw(x::Any) = false
Selectors.matcher(::Type{DatabaseLookup}, node, page, doc) = match_kw(node)

# ============================================= Simon's implementation
function look_up_source(database_key)
    entries = find(x-> x.title == database_key, database)
    # current implementation finds titles, but we can also search for tags too
    isempty(entries) && error("No entry found for database reference $database_key")
    length(entries) > 1 && error("Multiple entries found for database reference $database_key")
    sprint() do io
        print_code(
            io, database, entries[1],
            scope_start = "",
            scope_end = "",
            indent = "",
            resolution = (entry)-> "resolution = (500, 500)",
            outputfile = (entry, ending)-> Pkg.dir("Makie", "docs", "media", string(entry.unique_name, ending))
        )
    end
end
function Selectors.runner(::Type{DatabaseLookup}, x, page, doc)
    matched = nothing
    for elem in x.content
        if isa(elem, AbstractString)
            matched = match(regex_pattern, elem)
            matched != nothing && break
        end
    end
    matched == nothing && error("No match: $x")
    # The sandboxed module -- either a new one or a cached one from this page.
    database_keys = filter(x-> !(x in ("", " ")), split(matched[1], '"'))
    content = map(database_keys) do database_key
        Markdown.Code("julia", look_up_source(database_key))
    end
    # Evaluate the code block. We redirect stdout/stderr to `buffer`.
    page.mapping[x] = Markdown.MD(content)
end

# ============================================= Anthony's implementation
# function look_up_source(database_keys...; title = nothing, author = nothing)
#     entries = find(database) do entry
#         # find tags
#         keys_found = all(key -> string(key) in entry.tags, database_keys) # only works with strings inputs right now
#         # find author, if nothing input is given, then don't filter
#         author_found = (author == nothing) || (entry.author == string(author))
#         # find title, if nothing input is given, then don't filter
#         title_found = (title == nothing) || (entry.title == string(title))
#         # boolean to return the result
#         entries = keys_found && author_found && title_found
#     end
#     # current implementation finds titles, but we can also search for tags too
#     isempty(entries) && error("No entry found for database reference $database_keys")
#     length(entries) > 1 && warn("Multiple entries found for database reference $database_keys")
#     sprint() do io #TODO: this currently only prints the first entry, even if we found multiple
#         print_code(
#             io, database, entries[1],
#             scope_start = "",
#             scope_end = "",
#             indent = "",
#             resolution = (entry)-> "resolution = (500, 500)",
#             outputfile = (entry, ending)-> Pkg.dir("Makie", "docs", "media", string(entry.unique_name, ending))
#         )
#     end
# end
#
# function Selectors.runner(::Type{DatabaseLookup}, x, page, doc)
#     matched = nothing
#     for elem in x.content
#         if isa(elem, AbstractString)
#             matched = match(regex_pattern, elem)
#             matched != nothing && break
#         end
#     end
#     matched == nothing && error("No match: $x")
#     # The sandboxed module -- either a new one or a cached one from this page.
#     database_keys = filter(x-> !(x in ("", " ")), split(matched[1], '"'))
#     content = map(database_keys) do database_key
#         Markdown.Code("julia", look_up_source(database_key))
#     end
#     # Evaluate the code block. We redirect stdout/stderr to `buffer`.
#     page.mapping[x] = Markdown.MD(content)
# end

# =============================================
# automatically generate an overview of the atomic functions
path = joinpath(@__DIR__, "..", "docs", "src", "functions-autogen.md")
open(path, "w") do io
    println(io, "# `Makie.jl` Functions -- autogenerated")
    for func in atomics
        println(io, "## `$(to_string(func))`")
        try
            Makie._help(io, func; extended = true)
        catch
            println("ERROR: Didn't work with $func\n")
        end
        println(io, "\n")
    end
end

# =============================================
# automatically generate an detailed overview of each of the atomic functions
atomics_pages = nothing
atomics_list = String[]
for func in atomics
    path = joinpath(@__DIR__, "..", "docs", "src", "atomics_examples", "$(to_string(func)).md")
    open(path, "w") do io
        println(io, "# `$(to_string(func))`")
        # println(io, "## `$func`")
        try
            Makie._help(io, func; extended = true)
        catch
            println("ERROR: Didn't work with $func\n")
        end
        println(io, "\n")
    end
    push!(atomics_list, "atomics_examples/$(to_string(func)).md")
end
atomics_pages = "Atomic Functions" => atomics_list

# # =============================================
# # automatically generate gallery based on tags - 1 randomly-selected example
# tags_list = sort(unique(tags_list))
# path = joinpath(@__DIR__, "..", "docs", "src", "examples-for-tags.md")
# open(path, "w") do io
#     println(io, "# List of all tags including 1 randomly-selected example from each tag")
#     println(io, "## List of all tags, sorted alphabetically")
#     for tag in tags_list
#         println(io, "  * [$tag](@ref tag_$(replace(tag, " ", "_")))")
#     end
#     println(io, "\n")
#     for tag in tags_list
#         # search for the indices where tag is found
#         indices = find_indices(tag; title = nothing, author = nothing)
#         # pick a random example from the list
#         idx = indices[rand(1:length(indices))];
#         println(io, "## [$tag](@id tag_$(replace(tag, " ", "_")))")
#         try
#             _print_source(io, idx; style = "julia")
#         catch
#             println("ERROR: Didn't work with $tag\n")
#         end
#         println(io, "\n")
#     end
# end

# =============================================
# automatically generate gallery based on tags - all examples
tags_list = sort(unique(tags_list))
path = joinpath(@__DIR__, "..", "docs", "src", "examples-for-tags.md")
open(path, "w") do io
    println(io, "# List of all tags including all examples from each tag")
    println(io, "## List of all tags, sorted alphabetically")
    for tag in tags_list
        println(io, "  * [$tag](@ref tag_$(replace(tag, " ", "_")))")
    end
    println(io, "\n")
    for tag in tags_list
        counter = 1
        # search for the indices where tag is found
        indices = find_indices(tag; title = nothing, author = nothing)
        # # pick a random example from the list
        # idx = indices[rand(1:length(indices))];
        println(io, "## [$tag](@id tag_$(replace(tag, " ", "_")))")
        for idx in indices
            try
                println(io, "Example $counter, \"$(database[idx].title)\"")
                _print_source(io, idx; style = "julia")
                println(io, "`plot goes here\n`")
                # TODO: add code to generate + embed plots
                counter += 1
            catch
                println("ERROR: Didn't work with $tag at index $idx\n")
            end
        end
        println(io, "\n")
    end
end

# =============================================
# automatically generate gallery based on looping through the database - all examples
# TODO: FYI: database[44].title == "Theming Step 1"
pathroot = joinpath(@__DIR__, "..", "docs", "src")
buildpath = joinpath(@__DIR__, "build")
imgpath = joinpath(pathroot, "plots")
path = joinpath(pathroot, "examples-database.md")
open(path, "w") do io
    println(io, "# All examples from the example database")
    counter = 1
    groupid_last = NO_GROUP
    for (i, entry) in enumerate(database)
        # print bibliographic stuff
        println(io, "## $(entry.title)")
        # println(io, "line(s): $(entry.file_range)\n")
        println(io, "Tags:\n")
        foreach(tag -> println(io, "* `$tag`"), collect(entry.tags))
        print(io, "\n\n")
        # print(io, "$(collect(entry.tags))\n\n")
        if isgroup(entry) && entry.groupid == groupid_last
            try
                # println(io, "condition 2 -- group continuation\n")
                # println(io, "group ID = $(entry.groupid)\n")
                println(io, "Example $counter, \"$(entry.title)\"\n")
                _print_source(io, i; style = "example", example_counter = counter)
                filename = string(entry.unique_name)
                # plotting
                    println(io, "```@example $counter")
                    # println(io, "println(STDOUT, \"Example $(counter) \", \"$(entry.title)\", \" index $i\")")
                    # println(io, "Makie.save(joinpath(imgpath, \"$(filename).png\"), scene)")
                    println(io, "Makie.save(\"$(filename).png\", scene)")
                    println(io, "```")
                # embed plot
                # println(io, "![]($(joinpath(relpath(imgpath, buildpath), "$(filename).png")))")
                println(io, "![]($(filename).png)")
            catch
                println("ERROR: Didn't work with \"$(entry.title)\" at index $i\n")
            end
        elseif isgroup(entry)
            try
                # println(io, "condition 1 -- new group encountered!\n")
                # println(io, "group ID = $(entry.groupid)\n")
                groupid_last = entry.groupid
                println(io, "Example $counter, \"$(entry.title)\"\n")
                _print_source(io, i; style = "example", example_counter = counter)
                filename = string(entry.unique_name)
                # plotting
                    println(io, "```@example $counter")
                    # println(io, "println(STDOUT, \"Example $(counter) \", \"$(entry.title)\", \" index $i\")")
                    # println(io, "Makie.save(joinpath(imgpath, \"$(filename).png\"), scene)")
                    println(io, "Makie.save(\"$(filename).png\", scene)")
                    println(io, "```")
                # embed plot
                # println(io, "![]($(joinpath(relpath(imgpath, buildpath), "$(filename).png")))")
                println(io, "![]($(filename).png)")
            catch
                println("ERROR: Didn't work with \"$(entry.title)\" at index $i\n")
            end
        else
            try
                # println(io, "condition 3 -- not part of a group\n")
                println(io, "Example $counter, \"$(entry.title)\"\n")
                _print_source(io, i; style = "example", example_counter = counter)
                filename = string(entry.unique_name)
                # plotting
                    println(io, "```@example $counter")
                    # println(io, "println(STDOUT, \"Example $(counter) \", \"$(entry.title)\", \" index $i\")")
                    # println(io, "Makie.save(joinpath(imgpath, \"$(filename).png\"), scene)")
                    println(io, "Makie.save(\"$(filename).png\", scene)")
                    println(io, "```")
                # embed plot
                # println(io, "![]($(joinpath(relpath(imgpath, buildpath), "$(filename).png")))")
                println(io, "![]($(filename).png)")
                counter += 1
                groupid_last = entry.groupid
            catch
                println("ERROR: Didn't work with \"$(entry.title)\" at index $i\n")
            end
        end
    end
end

makedocs(
    modules = [Makie],
    doctest = false, clean = true,
    format = :html,
    sitename = "Makie.jl Documentation",
    pages = Any[
        "Home" => "index.md",
        "Basics" => [
            # "scene.md",
            # "conversions.md",
            "help_functions.md",
            "functions-autogen.md",
            "functions.md"
            # "documentation.md",
            # "backends.md",
            # "extending.md",
            # "themes.md",
            # "interaction.md",
            # "axis.md",
            # "legends.md",
            # "output.md",
            # "reflection.md",
            # "layout.md"
        ],
        atomics_pages,
        "Examples" => [
            "examples-for-tags.md",
            "tags_wordcloud.md",
            "linking-test.md"
        ]
        # "Developper Documentation" => [
        #     "devdocs.md",
        # ],
    ]
)


#
# ENV["TRAVIS_BRANCH"] = "latest"
# ENV["TRAVIS_PULL_REQUEST"] = "false"
# ENV["TRAVIS_REPO_SLUG"] = "github.com/SimonDanisch/MakieDocs.git"
# ENV["TRAVIS_TAG"] = "tag"
# ENV["TRAVIS_OS_NAME"] = "linux"
# ENV["TRAVIS_JULIA_VERSION"] = "0.6"
#
# deploydocs(
#     deps   = Deps.pip("mkdocs", "python-markdown-math", "mkdocs-cinder"),
#     repo   = "github.com/SimonDanisch/MakieDocs.git",
#     julia  = "0.6",
#     target = "build",
#     osname = "linux",
#     make = nothing
# )
