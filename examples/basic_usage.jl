#!/usr/bin/env julia

"""
BashMacros.jl - Basic Usage Examples
=====================================

This file demonstrates the core functionality of BashMacros.jl
"""

using BashMacros

println("=== BashMacros.jl Examples ===\n")

# ============================================================================
# 1. Basic Command Execution
# ============================================================================
println("1. Basic Execution")
println("-" ^ 50)

# Simple execution
bash("echo 'Hello from Bash!'")

# Execute with arguments (arg_bash properly passes each arg separately)
arg_bash("echo", ["arg1", "arg2", "arg3"])

println()

# ============================================================================
# 2. Capturing Output
# ============================================================================
println("2. Capturing Output")
println("-" ^ 50)

# Capture as Julia string
current_user = capture_output("whoami")
println("Current user: ", strip(current_user))

# Get full output tuple
stdout, stderr, exitcode = bash_full("echo 'Success!'")
println("Exit code: $exitcode")
println("Output: $stdout")

println()

# ============================================================================
# 3. Using Macros
# ============================================================================
println("3. Macro Usage")
println("-" ^ 50)

# Execute with @bashwrap
@bashwrap "date +%Y-%m-%d"

# Capture with @bashcap
hostname = @bashcap "hostname"
println("Hostname: ", strip(hostname))

# Pipe and print with @bashpipe
result = @bashpipe "echo 'This is printed and returned'"
println("Returned: ", strip(result))

println()

# ============================================================================
# 4. Conditional Execution
# ============================================================================
println("4. Conditional Execution with @bashif")
println("-" ^ 50)

if @bashif("test -d /tmp")
    println("/tmp directory exists!")
end

if @bashif("test -f /etc/passwd")
    println("/etc/passwd file exists!")
end

# Check if command exists
if @bashif("which git >/dev/null 2>&1")
    git_version = @bashcap "git --version"
    println("Git is installed: ", strip(git_version))
end

println()

# ============================================================================
# 5. Piping Data Between Julia and Bash
# ============================================================================
println("5. Julia-Bash Piping")
println("-" ^ 50)

# Pipe Julia string to Bash
data = "hello world\nfoo bar\nbaz"
uppercase = julia_to_bash_pipe(data, "tr '[:lower:]' '[:upper:]'")
println("Uppercase result:")
println(uppercase)

# Sort numbers
numbers = "3\n1\n4\n1\n5\n9\n2\n6"
sorted = julia_to_bash_pipe(numbers, "sort -n")
println("Sorted numbers:")
println(sorted)

# Complex pipeline
text = "apple\nbanana\napple\norange\nbanana\napple"
unique_count = julia_to_bash_pipe(text, "sort | uniq -c")
println("Unique counts:")
println(unique_count)

println()

# ============================================================================
# 6. Error Handling
# ============================================================================
println("6. Error Handling")
println("-" ^ 50)

# Safe execution with try/catch
try
    result = @bashsafe "false"  # This will throw
catch e
    if isa(e, BashExecutionError)
        println("Caught error: ", e.command)
        println("Exit code: ", e.exitcode)
    else
        println("Unexpected error: ", e)
    end
end

# Manual error handling
stdout, stderr, exitcode = bash_full("ls /nonexistent_directory 2>&1")
if exitcode != 0
    println("Command failed with code: $exitcode")
end

println()

# ============================================================================
# 7. Argument Processing
# ============================================================================
println("7. Argument Processing")
println("-" ^ 50)

# Julia dict to Bash args
julia_args = Dict(
    "options" => Dict("l" => true, "a" => true, "color" => "always"),
    "positional" => ["/tmp"]
)
bash_args = j_bash(julia_args)
println("Bash args: ", bash_args)

# Bash args to Julia dict
bash_input = ["--verbose", "-r", "-n", "10", "file.txt"]
julia_dict = b_julia(bash_input)
println("Julia dict: ", julia_dict)

println()

# ============================================================================
# 8. Learning System
# ============================================================================
println("8. Learning System")
println("-" ^ 50)

# Learn command patterns
learn_args!("grep", ["-r", "pattern", "."])
learn_args!("grep", ["-r", "another", "."])
learn_args!("grep", ["-i", "case", "file"])

# Predict argument count
predicted = predict_args_count("grep")
println("Predicted grep args: $predicted")

# Get learned pattern
if haskey(BashMacros.LEARNED_PATTERNS, "grep")
    pattern = BashMacros.LEARNED_PATTERNS["grep"]
    sig = build_signature("grep", pattern)
    println("Learned signature: $sig")
    println("Confidence: $(round(pattern.confidence * 100, digits=2))%")
end

println()

# ============================================================================
# 9. Context Detection
# ============================================================================
println("9. Context Detection")
println("-" ^ 50)

contexts = [
    "using Pkg",
    "ls -la",
    "function foo()",
    "grep pattern file",
    "@macro something"
]

for cmd in contexts
    ctx = BashMacros.detect_context(cmd)
    println("'$cmd' → :$ctx")
end

println()

# ============================================================================
# 10. Symbol Table
# ============================================================================
println("10. Symbol Table")
println("-" ^ 50)

# Query built-in symbols
if (symbol = get_symbol("bash")) !== nothing
    println("Symbol: ", symbol.name)
    println("Signature: ", symbol.signature)
    println("Description: ", symbol.description)
end

# Check command existence
println("Git exists: ", command_exists("git"))
println("Nonexistent exists: ", command_exists("nonexistent_command"))

println()

# ============================================================================
# 11. Practical Examples
# ============================================================================
println("11. Practical Examples")
println("-" ^ 50)

# Count Julia files in current directory
julia_files = @bashcap "find . -name '*.jl' 2>/dev/null | wc -l"
println("Julia files found: ", strip(julia_files))

# Get system information
if Sys.islinux()
    os_info = @bashcap "uname -a"
    println("OS Info: ", strip(os_info))
end

# Process management
if @bashif("pgrep julia >/dev/null")
    julia_procs = @bashcap "pgrep julia | wc -l"
    println("Julia processes running: ", strip(julia_procs))
end

println()
println("=== Examples Complete ===")
