#!/usr/bin/env julia

"""
Polyglot: Mixed Julia-Bash Script Execution
============================================

Execute files containing both Julia and Bash code seamlessly.
Supports inline switching between languages.
"""

# ============================================================================
# POLYGLOT MARKERS
# ============================================================================

const JULIA_BLOCK_START = r"^#\s*JULIA_BEGIN"
const JULIA_BLOCK_END = r"^#\s*JULIA_END"
const BASH_BLOCK_START = r"^#\s*BASH_BEGIN"
const BASH_BLOCK_END = r"^#\s*BASH_END"

# Inline markers
const JULIA_INLINE = r"^\s*#J>\s*(.+)$"
const BASH_INLINE = r"^\s*#B>\s*(.+)$"

# Variable sharing
const JULIA_TO_BASH = r"^\s*#\s*EXPORT\s+(\w+)"
const BASH_TO_JULIA = r"^\s*#\s*IMPORT\s+(\w+)"

# ============================================================================
# POLYGLOT EXECUTION ENGINE
# ============================================================================

mutable struct PolyglotContext
    julia_env::Dict{Symbol,Any}
    bash_env::Dict{String,String}
    current_lang::Symbol
    output_buffer::Vector{String}

    PolyglotContext() = new(Dict{Symbol,Any}(), Dict{String,String}(), :bash, String[])
end

"""
    parse_polyglot_file(filename::String) -> Vector{Tuple{Symbol,String}}

Parse file into language blocks.
"""
function parse_polyglot_file(filename::String)
    lines = readlines(filename)
    blocks = Tuple{Symbol,String}[]
    current_block = String[]
    current_lang = detect_file_language(filename)

    for line in lines
        # Check for explicit language markers
        if occursin(JULIA_BLOCK_START, line)
            # Save current block
            if !isempty(current_block)
                push!(blocks, (current_lang, join(current_block, '\n')))
                current_block = String[]
            end
            current_lang = :julia
            continue
        elseif occursin(JULIA_BLOCK_END, line)
            push!(blocks, (current_lang, join(current_block, '\n')))
            current_block = String[]
            current_lang = :bash
            continue
        elseif occursin(BASH_BLOCK_START, line)
            if !isempty(current_block)
                push!(blocks, (current_lang, join(current_block, '\n')))
                current_block = String[]
            end
            current_lang = :bash
            continue
        elseif occursin(BASH_BLOCK_END, line)
            push!(blocks, (current_lang, join(current_block, '\n')))
            current_block = String[]
            current_lang = :julia
            continue
        end

        # Check for inline markers
        if (m = match(JULIA_INLINE, line)) !== nothing
            # Inline Julia execution
            if !isempty(current_block)
                push!(blocks, (current_lang, join(current_block, '\n')))
                current_block = String[]
            end
            push!(blocks, (:julia, m.captures[1]))
            continue
        elseif (m = match(BASH_INLINE, line)) !== nothing
            # Inline Bash execution
            if !isempty(current_block)
                push!(blocks, (current_lang, join(current_block, '\n')))
                current_block = String[]
            end
            push!(blocks, (:bash, m.captures[1]))
            continue
        end

        push!(current_block, line)
    end

    # Save final block
    if !isempty(current_block)
        push!(blocks, (current_lang, join(current_block, '\n')))
    end

    return blocks
end

"""
Detect primary language from file extension.
"""
function detect_file_language(filename::String)
    ext = lowercase(splitext(filename)[2])
    if ext == ".jl"
        return :julia
    elseif ext in [".sh", ".bash"]
        return :bash
    else
        return :auto
    end
end

"""
    execute_polyglot_file(filename::String; verbose::Bool=false)

Execute a polyglot script file.
"""
function execute_polyglot_file(filename::String; verbose::Bool=false)
    ctx = PolyglotContext()
    blocks = parse_polyglot_file(filename)

    for (lang, code) in blocks
        isempty(strip(code)) && continue

        verbose && println("[Executing $lang block]")

        if lang == :julia
            execute_julia_block(code, ctx)
        else
            execute_bash_block(code, ctx)
        end
    end

    return ctx
end

"""
Execute Julia code block with context.
"""
function execute_julia_block(code::String, ctx::PolyglotContext)
    # Import bash variables
    for (k, v) in ctx.bash_env
        try
            ctx.julia_env[Symbol(k)] = v
        catch
        end
    end

    # Execute in isolated module to capture variables
    mod = Module()
    Core.eval(mod, :(using BashMacros))

    # Add context variables
    for (k, v) in ctx.julia_env
        Core.eval(mod, :($k = $v))
    end

    # Execute code
    try
        result = Core.eval(mod, Meta.parse(code))

        # Export new variables
        for name in names(mod, all=true)
            if !startswith(string(name), '#') && name != :eval && name != :include
                try
                    ctx.julia_env[name] = Core.eval(mod, name)
                catch
                end
            end
        end

        return result
    catch e
        @error "Julia execution failed" exception=e
        rethrow(e)
    end
end

"""
Execute Bash code block with context.
"""
function execute_bash_block(code::String, ctx::PolyglotContext)
    # Export Julia variables to bash
    env_exports = String[]
    for (k, v) in ctx.julia_env
        if v isa Union{String,Number,Bool}
            push!(env_exports, "export $(String(k))='$v'")
        end
    end

    # Prepend exports to code
    full_code = join([env_exports..., code], '\n')

    # Execute bash
    stdout, stderr, exitcode = bash_full(full_code)

    # Capture bash exports
    if exitcode == 0
        # Try to capture set variables
        env_cmd = "$(full_code)\nenv"
        env_output, _, _ = bash_full(env_cmd)

        for line in split(env_output, '\n')
            m = match(r"^([A-Z_][A-Z0-9_]*)=(.*)$", line)
            if m !== nothing
                ctx.bash_env[m.captures[1]] = m.captures[2]
            end
        end
    end

    if exitcode != 0
        @error "Bash execution failed" stderr=stderr
    end

    return (stdout, stderr, exitcode)
end

# ============================================================================
# MACRO POLYGLOT EXECUTION
# ============================================================================

"""
    @polyglot(code_block)

Execute mixed Julia/Bash code inline.

# Example
```julia
@polyglot begin
    # This is Julia
    x = 10

    #B> echo "Bash sees: \$x"

    # Back to Julia
    y = x * 2

    #B> echo "Result: \$y"
end
```
"""
macro polyglot(code_block)
    code_str = string(code_block)
    return :(execute_polyglot_string($code_str))
end

"""
Execute polyglot code from string.
"""
function execute_polyglot_string(code::String)
    ctx = PolyglotContext()
    lines = split(code, '\n')

    current_block = String[]
    current_lang = :julia

    for line in lines
        if (m = match(JULIA_INLINE, line)) !== nothing
            if !isempty(current_block)
                if current_lang == :julia
                    execute_julia_block(join(current_block, '\n'), ctx)
                else
                    execute_bash_block(join(current_block, '\n'), ctx)
                end
                current_block = String[]
            end
            execute_julia_block(m.captures[1], ctx)
            continue
        elseif (m = match(BASH_INLINE, line)) !== nothing
            if !isempty(current_block)
                if current_lang == :julia
                    execute_julia_block(join(current_block, '\n'), ctx)
                else
                    execute_bash_block(join(current_block, '\n'), ctx)
                end
                current_block = String[]
            end
            execute_bash_block(m.captures[1], ctx)
            continue
        end

        push!(current_block, line)
    end

    # Execute final block
    if !isempty(current_block)
        if current_lang == :julia
            execute_julia_block(join(current_block, '\n'), ctx)
        else
            execute_bash_block(join(current_block, '\n'), ctx)
        end
    end

    return ctx
end

# ============================================================================
# SHEBANG HANDLER
# ============================================================================

"""
Make polyglot script executable with custom shebang.
"""
function create_polyglot_shebang(output_file::String, code::String)
    shebang = "#!/usr/bin/env julia"

    wrapper = """
    $shebang

    using BashMacros

    const SCRIPT_CODE = raw\"\"\"
    $code
    \"\"\"

    execute_polyglot_string(SCRIPT_CODE)
    """

    write(output_file, wrapper)
    chmod(output_file, 0o755)

    println("Created executable polyglot script: $output_file")
end

# ============================================================================
# EXPORTS
# ============================================================================

export PolyglotContext, parse_polyglot_file, execute_polyglot_file,
       execute_polyglot_string, @polyglot, create_polyglot_shebang,
       detect_file_language

