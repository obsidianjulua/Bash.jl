#!/usr/bin/env julia

"""
Basher: Julia–Bash Integration Framework
Core functions and symbol table for unified LSP
"""

module Basher

using Distributed
using Dates

include("eBash.jl")

"""
Exception thrown when a Bash command fails (non-zero exit code).
"""
struct BashExecutionError <: Exception
    command::String
    stdout::String
    stderr::String
    exitcode::Int
end

Base.showerror(io::IO, e::BashExecutionError) =
    print(io, "BashExecutionError (Code ", e.exitcode, "): Command failed.\n",
        "  Command: ", e.command, "\n",
        "  STDERR: ", e.stderr)

# ============================================================================
# CORE EXECUTION FUNCTIONS
# ============================================================================

"""
Execute basic Bash command using run with string interpolation
"""
function bash(cmd::String)
    run(`bash -c $cmd`)
end

"""
Build and execute command with multiple flags and arguments
"""
function arg_bash(exe::String, opts::Vector{String})
    run(`$(exe) $(opts...)`)
end

"""
Spawn Bash command as distributed worker using @spawn
"""
function spawn(cmd::String)
    p = run(pipeline(`bash -c $cmd`, stdout=Base.stdout, stderr=Base.stderr))
    println("Worker finished with code $(p.exitcode)")
    return p
end

"""
Capture output of Bash command as Julia string
"""
function capture_output(cmd::String)
    return read(`bash -c $cmd`, String)
end

"""
Capture output of Cmd object as Julia string
"""
function capture_output(cmd::Cmd)
    return read(cmd, String)
end

"""
Execute command and return (stdout, stderr, exitcode)
"""
function bash_full(cmd::String)
    try
        stdout = capture_output(cmd)
        return (stdout, "", 0)
    catch e
        if isa(e, ProcessFailedException)
            exitcode = try
                e.code
            catch
                -1
            end
            return ("", string(e), exitcode)
        else
            return ("", string(e), -1)
        end
    end
end

"""
Macro for inline Bash execution
    """
macro bashwrap(cmd_str)
    return :(run(Cmd(["bash", "-c", $(esc(cmd_str))])))
end

"""
Macro for inline Bash output capture
    """
macro bashcap(cmd_str)
    return :(capture_output(Cmd(["bash", "-c", $(esc(cmd_str))])))
end

"""
Macro for executing a Bash command, printing its output, and also returning it as a string.
"""
macro bashpipe(cmd_str)
    quote
        local output = capture_output(Cmd(["bash", "-c", $(esc(cmd_str))]))
        println(output)
        output
    end
end

"""
Find executable in PATH
"""
function find_exo(name::String)
    path = Sys.which(name)
    return path !== nothing ? path : ""
end

"""
Check if command exists in system
    """
function command_exists(name::String)
    return !isempty(find_exo(name))
end

"""
Run command with timeout (safe version)
"""
function timeout(cmd::String, timeout_seconds::Int=30)
    result = Channel{Any}(1)

    @async begin
        try
            put!(result, (capture_output(cmd), "", 0))
        catch e
            put!(result, ("", string(e), -1))
        end
    end

    t = Timer(timeout_seconds)
    try
        return take!(result)
    catch
        close(result)
        return ("", "Command timed out", -1)
    finally
        close(t)
    end
end

# ============================================================================
# ARGUMENT PROCESSING FUNCTIONS
# ============================================================================

"""
Convert Julia args to Bash-compatible vector
"""
function j_bash(args::Dict)
    bash_args = String[]

    # Process options
    for (key, value) in get(args, "options", Dict())
        if length(key) == 1
            # Short option
            if value === true
                push!(bash_args, "-$key")
            else
                push!(bash_args, "-$key", string(value))
            end
        else
            # Long option
            if value === true
                push!(bash_args, "--$key")
            else
                push!(bash_args, "--$key", string(value))
            end
        end
    end

    # Add positional arguments
    append!(bash_args, get(args, "positional", String[]))
    return bash_args
end

"""
Convert Bash args to Julia-compatible dict
"""
function b_julia(args::Vector{String})
    result = Dict{String,Any}(
        "options" => Dict{String,Any}(),
        "positional" => String[]
    )

    i = 1
    while i <= length(args)
        arg = args[i]
        if startswith(arg, "--")
            key = arg[3:end]
            if i < length(args) && !startswith(args[i+1], "-")
                result["options"][key] = args[i+1]
                i += 1
            else
                result["options"][key] = true
            end
        elseif startswith(arg, "-") && length(arg) > 1
            for char in arg[2:end]
                result["options"][string(char)] = true
            end
        else
            push!(result["positional"], arg)
        end
        i += 1
    end
    return result
end

# ============================================================================
# CONTEXT DETECTION
# ============================================================================

"""
Detect execution context from input string
"""
function detect_context(input::String)::Symbol
    input = strip(input)

    julia_patterns = [
        r"^using\s+", r"^import\s+", r"^function\s+",
        r"^@\w+", r"getopt|getargs", r"@bashwrap|@bashcap",
        r"^\w+\s*=\s*\[.*\]", r"^\w+\.\w+"
    ]

    bash_patterns = [
        r"^#!/bin/bash", r"^\$\w+", r"^export\s+",
        r"^source\s+", r".*\|\s*\w+", r".*&&.*",
        r"^[a-zA-Z_][a-zA-Z0-9_-]*\s+[^=]*$"
    ]

    for pattern in julia_patterns
        if occursin(pattern, input)
            return :julia
        end
    end

    for pattern in bash_patterns
        if occursin(pattern, input)
            return :bash
        end
    end

    return :auto
end

# ============================================================================
# SYMBOL TABLE DEFINITIONS
# ============================================================================

struct SymbolEntry
    name::String
    type::Symbol
    signature::String
    description::String
    context::Symbol
    handler::Union{Function,String}
end

const SYMBOL_TABLE = Dict{String,SymbolEntry}()

# Prepopulate built-ins
SYMBOL_TABLE["bash"] = SymbolEntry("bash", :julia_function,
    "bash(cmd::String)", "Execute basic Bash command", :julia, bash)

SYMBOL_TABLE["arg_bash"] = SymbolEntry("arg_bash", :julia_function,
    "arg_bash(exe::String, opts::Vector{String})", "Execute command with arguments", :julia, arg_bash)

SYMBOL_TABLE["capture_output"] = SymbolEntry("capture_output", :julia_function,
    "capture_output(cmd::String)", "Capture command output", :julia, capture_output)

SYMBOL_TABLE["spawn"] = SymbolEntry("spawn", :julia_function,
    "spawn(cmd::String)", "Spawn command as background task", :julia, spawn)

SYMBOL_TABLE["bash_full"] = SymbolEntry("bash_full", :julia_function,
    "bash_full(cmd::String)", "Execute and return (stdout, stderr, exitcode)", :julia, bash_full)

# ============================================================================
# EXECUTION DISPATCHERS
# ============================================================================

function julia_command(command::String, args::Dict)
    if haskey(SYMBOL_TABLE, command)
        symbol = SYMBOL_TABLE[command]
        if symbol.context == :julia && isa(symbol.handler, Function)
            try
                if command == "bash" && haskey(args, "positional")
                    return symbol.handler(join(args["positional"], " "))
                elseif command == "arg_bash" && haskey(args, "positional") && !isempty(args["positional"])
                    exe = args["positional"][1]
                    opts = args["positional"][2:end]
                    return symbol.handler(exe, opts)
                elseif command == "capture_output" && haskey(args, "positional")
                    return symbol.handler(join(args["positional"], " "))
                else
                    return ("Function executed: $command", "", 0)
                end
            catch e
                return ("", string(e), -1)
            end
        end
    end
    return ("Unknown Julia command: $command", "", -1)
end

function bash_command(command::String, args::Dict)
    bash_args = j_bash(args)
    full_cmd = [command; bash_args]

    if command_exists(command)
        try
            return (capture_output(join(full_cmd, " ")), "", 0)
        catch e
            return ("", string(e), -1)
        end
    end
    return ("Unknown Bash command: $command", "", -1)
end

function auto_command(command::String, args::Dict)
    ctx = detect_context(command)
    if ctx == :julia
        return julia_command(command, args)
    elseif ctx == :bash
        return bash_command(command, args)
    else
        bash_result = bash_command(command, args)
        if bash_result[3] == 0
            return bash_result
        end
        return julia_command(command, args)
    end
end

# ============================================================================
# SYMBOL UTILITIES
# ============================================================================

function add_symbol!(name::String, entry::SymbolEntry)
    SYMBOL_TABLE[name] = entry
end

function get_symbol(name::String)
    return get(SYMBOL_TABLE, name, nothing)
end

# ============================================================================
# SYSTEM COMMAND DISCOVERY
# ============================================================================

function isexecutable(path::String)
    try
        return isfile(path) && (stat(path).mode & 0o111 != 0)
    catch
        return false
    end
end

function search_commands!(paths::Vector{String}=["/usr/bin", "/usr/local/bin"])
    for path in paths
        if isdir(path)
            for file in readdir(path)
                full_path = joinpath(path, file)
                if isexecutable(full_path) && !haskey(SYMBOL_TABLE, file)
                    SYMBOL_TABLE[file] = SymbolEntry(file, :system_binary,
                        "$file [args...]", "System command at $full_path", :system, file)
                end
            end
        end
    end
end

# ============================================================================
# LEARNING SYSTEM
# ============================================================================

mutable struct ArgumentPattern
    command::String
    patterns::Dict{Int,Int}
    last_used::Float64
    confidence::Float64
end

const LEARNED_PATTERNS = Dict{String,ArgumentPattern}()
const DYNAMIC_CONSTANTS = Dict{String,Any}()

function learn_args!(command::String, args::Vector{String})
    arg_count = length(args)

    pattern = get!(LEARNED_PATTERNS, command) do
        ArgumentPattern(command, Dict{Int,Int}(), time(), 0.0)
    end

    pattern.patterns[arg_count] = get(pattern.patterns, arg_count, 0) + 1
    pattern.last_used = time()
    total_uses = sum(values(pattern.patterns))
    max_uses = maximum(values(pattern.patterns))
    pattern.confidence = max_uses / total_uses

    const_name = "args$(arg_count)"
    DYNAMIC_CONSTANTS[const_name] = arg_count

    return arg_count
end

function build_signature(command::String, pattern::ArgumentPattern)
    if isempty(pattern.patterns)
        return "$command [args...]"
    end
    most_common = first(argmax(pattern.patterns))
    return "$command " * join(["arg$i" for i in 1:most_common], " ")
end

function predict_args_count(command::String)::Int
    if haskey(LEARNED_PATTERNS, command) && !isempty(LEARNED_PATTERNS[command].patterns)
        return first(argmax(LEARNED_PATTERNS[command].patterns))
    end
    return 0
end

function get_dynamic_const(name::String)
    return get(DYNAMIC_CONSTANTS, name, nothing)
end

function julia_learn(command::String, args::Vector{String})
    learned_count = learn_args!(command, args)
    args_dict = b_julia(args)
    result = auto_command(command, args_dict)
    return (result, learned_count)
end

# ============================================================================
# INITIALIZATION
# ============================================================================

function __init__()
    @async search_commands!()
    println("Bash initialized with $(length(SYMBOL_TABLE)) symbols")
end

# ============================================================================
# EXPORTS
# ============================================================================

export bash, arg_bash, spawn, capture_output,
    bash_full, timeout, find_exo, command_exists,
    julia_command, bash_command, auto_command,
    julia_learn, j_bash, b_julia,
    learn_args!, predict_args_count, get_dynamic_const,
    build_signature, add_symbol!, get_symbol, search_commands!,
    @bashwrap, @bashcap, @bashpipe,
    BashExecutionError, julia_to_bash_pipe, @bashif, bash_return, parse_and_process, execute_or_throw, @bashsafe, @bashprompt, bash_prompt

end # module
