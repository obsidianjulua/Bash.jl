#!/usr/bin/env julia

"""
Formatters: Smart Julia Type Formatting for Bash Output
========================================================

Converts Bash output into properly formatted Julia types instead of raw strings.
Provides automatic type detection and conversion.
"""

using Dates

# ============================================================================
# TYPE DETECTION
# ============================================================================

"""
    detect_output_type(output::String) -> Symbol

Detect the probable Julia type from bash output.
"""
function detect_output_type(output::String)::Symbol
    stripped = strip(output)

    # Empty output
    isempty(stripped) && return :nothing

    # Check for common patterns
    if occursin(r"^\d+$", stripped)
        return :int
    elseif occursin(r"^\d+\.\d+$", stripped)
        return :float
    elseif occursin(r"^(true|false)$"i, stripped)
        return :bool
    elseif occursin(r"^\d{4}-\d{2}-\d{2}", stripped)
        return :datetime
    elseif occursin(r"\n", stripped)
        # Multi-line - check if it's a list
        lines = split(stripped, '\n')
        if all(line -> occursin(r"^\d+$", strip(line)), lines)
            return :int_array
        elseif all(line -> occursin(r"^\d+\.\d+$", strip(line)), lines)
            return :float_array
        else
            return :string_array
        end
    elseif occursin(r"^[\[\{].*[\]\}]$"s, stripped)
        return :json
    elseif occursin(r"^[a-zA-Z_][a-zA-Z0-9_]*=", stripped)
        return :dict
    else
        return :string
    end
end

# ============================================================================
# TYPE CONVERTERS
# ============================================================================

"""
    parse_bash_output(output::String; target_type::Union{Symbol,Nothing}=nothing)

Parse bash output into appropriate Julia type.
"""
function parse_bash_output(output::String; target_type::Union{Symbol,Nothing}=nothing)
    stripped = strip(output)
    isempty(stripped) && return nothing

    # Use detected type if not specified
    detected_type = something(target_type, detect_output_type(output))

    try
        if detected_type == :int
            return parse(Int, stripped)
        elseif detected_type == :float
            return parse(Float64, stripped)
        elseif detected_type == :bool
            return lowercase(stripped) in ["true", "1", "yes"]
        elseif detected_type == :datetime
            return parse_datetime(stripped)
        elseif detected_type == :int_array
            return [parse(Int, strip(line)) for line in split(stripped, '\n') if !isempty(strip(line))]
        elseif detected_type == :float_array
            return [parse(Float64, strip(line)) for line in split(stripped, '\n') if !isempty(strip(line))]
        elseif detected_type == :string_array
            return [strip(line) for line in split(stripped, '\n') if !isempty(strip(line))]
        elseif detected_type == :json
            return parse_json_like(stripped)
        elseif detected_type == :dict
            return parse_bash_dict(stripped)
        else
            return stripped
        end
    catch e
        @warn "Failed to parse as $detected_type, returning string" exception=e
        return stripped
    end
end

"""
Parse datetime from bash output (flexible formats).
"""
function parse_datetime(s::String)
    formats = [
        "yyyy-mm-dd HH:MM:SS",
        "yyyy-mm-dd",
        "dd/mm/yyyy",
        "mm/dd/yyyy"
    ]

    for fmt in formats
        try
            return DateTime(s, fmt)
        catch
            continue
        end
    end

    return s  # Return original if can't parse
end

"""
Parse JSON-like bash output.
"""
function parse_json_like(s::String)
    # Simple JSON-like parsing for bash arrays/dicts
    if startswith(s, '[') && endswith(s, ']')
        content = s[2:end-1]
        items = split(content, ',')
        return [strip(item, [' ', '"', '\'']) for item in items]
    elseif startswith(s, '{') && endswith(s, '}')
        content = s[2:end-1]
        pairs = split(content, ',')
        result = Dict{String,Any}()
        for pair in pairs
            k, v = split(pair, ':', limit=2)
            result[strip(k, [' ', '"', '\''])] = strip(v, [' ', '"', '\''])
        end
        return result
    end
    return s
end

"""
Parse bash variable assignments into Dict.
"""
function parse_bash_dict(s::String)
    result = Dict{String,String}()
    for line in split(s, '\n')
        m = match(r"^([a-zA-Z_][a-zA-Z0-9_]*)=(.*)", strip(line))
        if m !== nothing
            result[m.captures[1]] = strip(m.captures[2], ['"', '\''])
        end
    end
    return result
end

# ============================================================================
# FORMATTED EXECUTION FUNCTIONS
# ============================================================================

"""
    bash_typed(cmd::String; type::Union{Symbol,Nothing}=nothing)

Execute bash command and return typed Julia result.
"""
function bash_typed(cmd::String; type::Union{Symbol,Nothing}=nothing)
    output = capture_output(cmd)
    return parse_bash_output(output, target_type=type)
end

"""
    @bashtyped(cmd_str, type=nothing)

Macro for executing bash and returning typed result.

# Examples
```julia
count = @bashtyped "ls | wc -l" :int
nums = @bashtyped "seq 1 10" :int_array
files = @bashtyped "ls" :string_array
```
"""
macro bashtyped(cmd_str, type=nothing)
    return :(bash_typed($(esc(cmd_str)), type=$(esc(type))))
end

"""
    bash_table(cmd::String; delim::Char=' ')

Execute bash command and return result as Julia table (Vector of NamedTuples).
Assumes first line is header.
"""
function bash_table(cmd::String; delim::Char=' ', header::Union{Vector{Symbol},Nothing}=nothing)
    output = capture_output(cmd)
    lines = [strip(line) for line in split(output, '\n') if !isempty(strip(line))]

    isempty(lines) && return []

    # Parse header
    if header === nothing
        header_line = popfirst!(lines)
        header = [Symbol(strip(col)) for col in split(header_line, delim) if !isempty(strip(col))]
    end

    # Parse rows
    result = []
    for line in lines
        cols = [strip(col) for col in split(line, delim) if !isempty(strip(col))]
        if length(cols) == length(header)
            row = NamedTuple{Tuple(header)}(Tuple(cols))
            push!(result, row)
        end
    end

    return result
end

"""
    @bashtable(cmd_str, delim=' ')

Execute bash and return as table.

# Examples
```julia
processes = @bashtable "ps aux" ' '
files = @bashtable "ls -l" ' '
```
"""
macro bashtable(cmd_str, delim=' ')
    return :(bash_table($(esc(cmd_str)), delim=$(esc(delim))))
end

"""
Pretty print bash output with Julia formatting.
"""
function bash_pretty(cmd::String)
    output = capture_output(cmd)
    result = parse_bash_output(output)

    println("Command: $cmd")
    println("Type: $(typeof(result))")
    println("Result:")

    if result isa AbstractVector
        for (i, item) in enumerate(result)
            println("  [$i] $item")
        end
    elseif result isa Dict
        for (k, v) in result
            println("  $k => $v")
        end
    else
        println("  $result")
    end

    return result
end

"""
    @bashpretty(cmd_str)

Execute and pretty print with type info.
"""
macro bashpretty(cmd_str)
    return :(bash_pretty($(esc(cmd_str))))
end

# ============================================================================
# EXPORTS
# ============================================================================

export detect_output_type, parse_bash_output, bash_typed, @bashtyped,
       bash_table, @bashtable, bash_pretty, @bashpretty,
       parse_datetime, parse_bash_dict, parse_json_like

