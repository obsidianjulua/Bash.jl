#!/usr/bin/env julia

"""
BashRC Generator: Native Shell Integration
===========================================

Generate BashRC functions that mirror Julia BashMacros functionality.
Enables seamless Julia execution from native Bash shell.
"""

using Dates

# ============================================================================
# BASHRC TEMPLATE GENERATION
# ============================================================================

"""
Generate complete BashRC integration code.
"""
function generate_bashrc_integration()
    return """
# ============================================================================
# BashMacros.jl Integration
# Generated: $(now())
# ============================================================================

# Julia executable path
JULIA_BM_CMD="\${JULIA_BM_CMD:-julia}"

# Check if julia is available
if ! command -v "\$JULIA_BM_CMD" &> /dev/null; then
    echo "Warning: Julia not found in PATH. BashMacros functions disabled."
    return
fi

# ============================================================================
# INLINE JULIA EXECUTION
# ============================================================================

# Execute Julia code inline and return result
# Usage: j 'println("Hello from Julia")'
function j() {
    "\$JULIA_BM_CMD" -e "\$@"
}

# Execute Julia with BashMacros loaded
# Usage: jb 'bash("ls -la")'
function jb() {
    "\$JULIA_BM_CMD" -e "using BashMacros; \$*"
}

# Execute Julia and capture typed output
# Usage: jt 'split(read("file.txt", String), "\\n")' | head
function jt() {
    "\$JULIA_BM_CMD" -e "using BashMacros; result = (\$*); if result isa AbstractVector; for item in result; println(item); end; else; println(result); end"
}

# ============================================================================
# PIPE INTEGRATION
# ============================================================================

# Pipe stdin to Julia for processing
# Usage: echo "hello world" | jp 'uppercase'
function jp() {
    local julia_code="\$1"
    "\$JULIA_BM_CMD" -e "
    using BashMacros
    input = read(stdin, String)
    lines = split(strip(input), '\\\\n')
    for line in lines
        result = \$julia_code(line)
        println(result)
    end
    "
}

# Pipe to Julia and apply function
# Usage: ls | jmap 'length'
function jmap() {
    local func="\$1"
    "\$JULIA_BM_CMD" -e "
    using BashMacros
    for line in eachline(stdin)
        result = \$func(strip(line))
        println(result)
    end
    "
}

# Pipe to Julia and filter
# Usage: ls | jfilter 'x -> endswith(x, ".jl")'
function jfilter() {
    local pred="\$1"
    "\$JULIA_BM_CMD" -e "
    using BashMacros
    for line in eachline(stdin)
        if (\$pred)(strip(line))
            println(line)
        end
    end
    "
}

# Pipe to Julia and reduce
# Usage: seq 1 10 | jreduce '+' '0'
function jreduce() {
    local op="\$1"
    local init="\${2:-0}"
    "\$JULIA_BM_CMD" -e "
    using BashMacros
    acc = \$init
    for line in eachline(stdin)
        val = parse(Float64, strip(line))
        acc = \$op(acc, val)
    end
    println(acc)
    "
}

# ============================================================================
# BASH-JULIA HYBRID COMMANDS
# ============================================================================

# Count with Julia
# Usage: jcount < file.txt
function jcount() {
    "\$JULIA_BM_CMD" -e "using BashMacros; println(length(readlines(stdin)))"
}

# Sum numbers with Julia
# Usage: seq 1 100 | jsum
function jsum() {
    "\$JULIA_BM_CMD" -e "using BashMacros; println(sum(parse.(Float64, readlines(stdin))))"
}

# Statistics on numbers
# Usage: seq 1 100 | jstats
function jstats() {
    "\$JULIA_BM_CMD" -e "
    using Statistics
    nums = parse.(Float64, readlines(stdin))
    println(\\\"Count: \\\$(length(nums))\\\")
    println(\\\"Sum: \\\$(sum(nums))\\\")
    println(\\\"Mean: \\\$(mean(nums))\\\")
    println(\\\"Median: \\\$(median(nums))\\\")
    println(\\\"Std: \\\$(std(nums))\\\")
    println(\\\"Min: \\\$(minimum(nums))\\\")
    println(\\\"Max: \\\$(maximum(nums))\\\")
    "
}

# ============================================================================
# FILE OPERATIONS
# ============================================================================

# Find files with Julia regex
# Usage: jfind '.*\\.jl\$'
function jfind() {
    local pattern="\$1"
    local dir="\${2:-.}"
    "\$JULIA_BM_CMD" -e "
    using BashMacros
    for (root, dirs, files) in walkdir(\\\"\$dir\\\")
        for file in files
            if occursin(r\\\"\$pattern\\\", file)
                println(joinpath(root, file))
            end
        end
    end
    "
}

# Grep with Julia
# Usage: jgrep 'pattern' file.txt
function jgrep() {
    local pattern="\$1"
    local file="\${2:-/dev/stdin}"
    "\$JULIA_BM_CMD" -e "
    using BashMacros
    for (i, line) in enumerate(eachline(\\\"\$file\\\"))
        if occursin(r\\\"\$pattern\\\", line)
            println(\\\"\\\$i: \\\$line\\\")
        end
    end
    "
}

# ============================================================================
# DISTRIBUTED EXECUTION
# ============================================================================

# Execute command in parallel using Julia
# Usage: jparallel 4 'sleep 1 && echo {}' arg1 arg2 arg3 arg4
function jparallel() {
    local workers="\$1"
    shift
    local cmd_template="\$1"
    shift

    # Pass arguments via environment variable to avoid bash expansion issues
    export JPARALLEL_ARGS="\$*"

    "\$JULIA_BM_CMD" -e "
    using Distributed
    using BashMacros

    addprocs(\$workers)
    @everywhere using BashMacros

    args = split(ENV[\\\"JPARALLEL_ARGS\\\"])
    results = @distributed (vcat) for arg in args
        cmd = replace(\\\"\$cmd_template\\\", \\\"{}\\\" => arg)
        [(arg, capture_output(cmd))]
    end

    for (arg, output) in results
        println(\\\"[\\\$arg] \\\", strip(output))
    end
    "

    unset JPARALLEL_ARGS
}

# ============================================================================
# TYPED OPERATIONS
# ============================================================================

# Execute and get typed result
# Usage: jtyped ls :string_array
function jtyped() {
    local cmd="\$1"
    local type="\${2:-:auto}"
    "\$JULIA_BM_CMD" -e "
    using BashMacros
    include(joinpath(dirname(pathof(BashMacros)), \\\"formatters.jl\\\"))
    result = bash_typed(\\\"\$cmd\\\", type=\$type)
    if result isa AbstractVector
        for item in result
            println(item)
        end
    else
        println(result)
    end
    "
}

# ============================================================================
# POLYGLOT EXECUTION
# ============================================================================

# Execute polyglot file
# Usage: jpoly script.sh
function jpoly() {
    local file="\$1"
    "\$JULIA_BM_CMD" -e "
    using BashMacros
    include(joinpath(dirname(pathof(BashMacros)), \\\"polyglot.jl\\\"))
    execute_polyglot_file(\\\"\$file\\\", verbose=true)
    "
}

# ============================================================================
# INTERACTIVE REPL
# ============================================================================

# Start Julia REPL with BashMacros loaded
# Usage: jrepl
function jrepl() {
    "\$JULIA_BM_CMD" -i -e "using BashMacros; println(\\\"BashMacros loaded. Type 'exit()' to quit.\\\")"
}

# Start Julia REPL in directory
# Usage: jreplcd /path/to/project
function jreplcd() {
    local dir="\${1:-.}"
    cd "\$dir" && jrepl
}

# ============================================================================
# UTILITY FUNCTIONS
# ============================================================================

# Show BashMacros version
function jversion() {
    "\$JULIA_BM_CMD" -e "using Pkg; println(Pkg.status(\"BashMacros\"))"
}

# Update BashMacros
function jupdate() {
    "\$JULIA_BM_CMD" -e "using Pkg; Pkg.update(\"BashMacros\")"
}

# Show available Julia functions
function jfuncs() {
    "\$JULIA_BM_CMD" -e "
    using BashMacros
    println(\\\"Available BashMacros functions:\\\")
    for name in names(BashMacros)
        if !startswith(string(name), '#')
            println(\\\"  \\\", name)
        end
    end
    "
}

# ============================================================================
# ALIASES
# ============================================================================

alias jl='j'
alias jexec='jb'
alias jeval='j -e'

# ============================================================================
# COMPLETION
# ============================================================================

# Enable tab completion for Julia functions
if [ -n "\$BASH_VERSION" ]; then
    complete -W "\$(julia -e 'using BashMacros; println(join(names(BashMacros), \" \"))' 2>/dev/null)" jb
fi

echo "BashMacros integration loaded. Type 'jfuncs' to see available commands."

# ============================================================================
# END BashMacros.jl Integration
# ============================================================================
"""
end

# ============================================================================
# INSTALLATION FUNCTIONS
# ============================================================================

"""
    install_bashrc_integration(; backup::Bool=true, shell::Symbol=:bash)

Install BashMacros integration to shell RC file.
"""
function install_bashrc_integration(; backup::Bool=true, shell::Symbol=:bash)
    rc_file = if shell == :bash
        joinpath(ENV["HOME"], ".bashrc")
    elseif shell == :zsh
        joinpath(ENV["HOME"], ".zshrc")
    else
        error("Unsupported shell: $shell")
    end

    # Backup existing RC
    if backup && isfile(rc_file)
        backup_file = rc_file * ".bak." * Dates.format(now(), "yyyymmdd_HHMMSS")
        cp(rc_file, backup_file)
        println("Backed up $rc_file to $backup_file")
    end

    # Check if already installed
    if isfile(rc_file)
        content = read(rc_file, String)
        if occursin("BashMacros.jl Integration", content)
            println("BashMacros integration already installed in $rc_file")
            print("Reinstall? [y/N] ")
            response = lowercase(strip(readline()))
            response != "y" && return
        end
    end

    # Generate integration code
    integration_code = generate_bashrc_integration()

    # Append to RC file
    open(rc_file, "a") do io
        println(io, "\n")
        println(io, integration_code)
    end

    println("✓ BashMacros integration installed to $rc_file")
    println("Run 'source $rc_file' or restart your shell to activate.")
end

"""
    uninstall_bashrc_integration(; shell::Symbol=:bash)

Remove BashMacros integration from shell RC file.
"""
function uninstall_bashrc_integration(; shell::Symbol=:bash)
    rc_file = if shell == :bash
        joinpath(ENV["HOME"], ".bashrc")
    elseif shell == :zsh
        joinpath(ENV["HOME"], ".zshrc")
    else
        error("Unsupported shell: $shell")
    end

    if !isfile(rc_file)
        println("RC file not found: $rc_file")
        return
    end

    lines = readlines(rc_file)
    filtered_lines = String[]
    in_bashmacros_block = false
    skip_leading_separators = 0

    for line in lines
        # Start marker
        if occursin("BashMacros.jl Integration", line) && occursin("# =", line)
            in_bashmacros_block = true
            # Skip the separator lines before the block (up to 2)
            skip_leading_separators = min(length(filtered_lines), 2)
            while skip_leading_separators > 0 &&
                  !isempty(filtered_lines) &&
                  (occursin("# =", filtered_lines[end]) || isempty(strip(filtered_lines[end])))
                pop!(filtered_lines)
                skip_leading_separators -= 1
            end
            continue
        end

        # End marker
        if in_bashmacros_block && occursin("END BashMacros.jl Integration", line)
            in_bashmacros_block = false
            continue
        end

        # Skip everything in the block
        if in_bashmacros_block
            continue
        end

        # Keep everything outside the block
        push!(filtered_lines, line)
    end

    write(rc_file, join(filtered_lines, '\n'))
    println("✓ BashMacros integration removed from $rc_file")
end

"""
Generate standalone BashMacros shell script.
"""
function generate_standalone_script(output_file::String="bashmacros.sh")
    script = generate_bashrc_integration()

    write(output_file, script)
    chmod(output_file, 0o755)

    println("✓ Standalone script created: $output_file")
    println("Source it: source $output_file")
end

# ============================================================================
# EXPORTS
# ============================================================================

export generate_bashrc_integration, install_bashrc_integration,
       uninstall_bashrc_integration, generate_standalone_script

