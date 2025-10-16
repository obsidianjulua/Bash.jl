#!/usr/bin/env julia

"""
BashMacros.jl - Advanced Usage Examples
========================================

Demonstrates advanced features:
- Smart type formatting
- Distributed execution
- Polyglot scripts
- Native shell integration
"""

using Distributed
using BashMacros
using Statistics

println("=== BashMacros.jl Advanced Examples ===\n")

# ============================================================================
# 1. SMART TYPE FORMATTING
# ============================================================================
println("1. Smart Type Formatting")
println("-" ^ 70)

# Auto-detect types
count = @bashtyped "ls | wc -l" :int
println("File count (as Int): $count (type: $(typeof(count)))")

# Array of integers
numbers = @bashtyped "seq 1 10" :int_array
println("Numbers: $numbers")
println("Sum: $(sum(numbers))")

# Array of strings
files = @bashtyped "ls" :string_array
println("Files: $(length(files)) files")

# Pretty formatted output
println("\nPretty output:")
@bashpretty "echo 42"

println()

# ============================================================================
# 2. TABLE PARSING
# ============================================================================
println("2. Table Parsing")
println("-" ^ 70)

# Parse ls -l output as table
# Note: This is a demonstration - actual column names may vary
println("Parsing directory listing as table:")
output = @bashcap "ls -l"
lines = split(output, '\n')[2:end]  # Skip header
for line in lines[1:min(5, length(lines))]
    !isempty(strip(line)) && println("  ", line)
end

println()

# ============================================================================
# 3. DISTRIBUTED EXECUTION
# ============================================================================
println("3. Distributed Execution")
println("-" ^ 70)

# Add workers
println("Adding 2 workers...")
addprocs(2, exeflags="--project")
@everywhere using BashMacros

# Parallel execution
commands = [
    "sleep 1 && echo 'Task 1'",
    "sleep 1 && echo 'Task 2'",
    "sleep 1 && echo 'Task 3'"
]

println("Executing tasks in parallel...")
results = bash_parallel(commands)

for (i, (stdout, stderr, exitcode)) in enumerate(results)
    println("Task $i: $(strip(stdout)) (exit: $exitcode)")
end

# Map operation
data = ["apple", "banana", "cherry"]
results = bash_map("echo 'Processing {1}' && echo {1} | wc -c", data)

println("\nString lengths (via bash):")
for (item, output) in results
    println("  $item: $(strip(output)) chars")
end

# Clean up workers
rmprocs(workers())
println("Workers removed")

println()

# ============================================================================
# 4. ASYNC EXECUTION
# ============================================================================
println("4. Asynchronous Execution")
println("-" ^ 70)

# Execute async with callback
println("Starting async task...")
callback_fn = result -> begin
    stdout, stderr, exitcode = result
    println("Callback: $(strip(stdout))")
end
task = bash_async("sleep 2 && echo 'Async complete!'", callback=callback_fn)

println("Continuing while task runs in background...")
sleep(1)
println("Still running...")

# Wait for completion
wait(task)
println("Task completed")

println()

# ============================================================================
# 5. STREAMING OUTPUT
# ============================================================================
println("5. Streaming Output")
println("-" ^ 70)

println("Streaming find output:")
count = Ref(0)
callback_fn = line -> begin
    count[] += 1
    println("  [$(count[])] $(strip(line))")
end
bash_stream("find . -name '*.jl' 2>/dev/null | head -5", callback_fn)

println()

# ============================================================================
# 6. POLYGLOT EXECUTION
# ============================================================================
println("6. Polyglot Execution")
println("-" ^ 70)

# Create a polyglot script
polyglot_code = """
x = 10
y = 20
println("Julia: x = \$x, y = \$y")

#B> echo "Bash: x = \$x, y = \$y"

z = x + y
println("Julia: z = \$z")

#B> echo "Bash: z = \$z"
"""

println("Executing polyglot code:")
ctx = execute_polyglot_string(polyglot_code)

println()

# ============================================================================
# 7. REMOTE EXECUTION (if SSH is available)
# ============================================================================
println("7. Remote Execution")
println("-" ^ 70)

# Test if localhost SSH works
if @bashif("ssh -o ConnectTimeout=1 localhost 'exit' 2>/dev/null")
    println("Testing remote execution on localhost...")

    stdout, stderr, exitcode = bash_remote("uname -a", "localhost")
    if exitcode == 0
        println("Remote result: $(strip(stdout))")
    end
else
    println("SSH not configured for localhost, skipping remote execution demo")
end

println()

# ============================================================================
# 8. PRACTICAL EXAMPLE: File Statistics
# ============================================================================
println("8. Practical Example: File Statistics")
println("-" ^ 70)

# Get all .jl files
jl_files = @bashtyped "find . -name '*.jl' -type f 2>/dev/null | head -10" :string_array

if !isempty(jl_files)
    println("Analyzing $(length(jl_files)) Julia files...")

    # Count lines in each file
    line_counts = []
    for file in jl_files
        lines = @bashtyped "wc -l < '$file'" :int
        push!(line_counts, lines)
    end

    println("\nStatistics:")
    println("  Total lines: $(sum(line_counts))")
    println("  Average lines: $(round(mean(line_counts), digits=2))")
    println("  Max lines: $(maximum(line_counts))")
    println("  Min lines: $(minimum(line_counts))")
else
    println("No .jl files found for analysis")
end

println()

# ============================================================================
# 9. BASHRC INTEGRATION
# ============================================================================
println("9. BashRC Integration")
println("-" ^ 70)

println("Generating BashRC integration code...")
bashrc_code = generate_bashrc_integration()
println("Generated $(length(split(bashrc_code, '\n'))) lines of shell functions")

println("\nTo install:")
println("  julia -e 'using BashMacros; install_bashrc_integration()'")
println("\nOr generate standalone:")
println("  julia -e 'using BashMacros; generate_standalone_script(\"bashmacros.sh\")'")

println()

# ============================================================================
# 10. ADVANCED PIPING
# ============================================================================
println("10. Advanced Piping")
println("-" ^ 70)

# Julia -> Bash -> Julia pipeline
data = "hello\nworld\ntest"

println("Original data:")
println(data)

# Pipe to bash for uppercase
uppercase_data = julia_to_bash_pipe(data, "tr '[:lower:]' '[:upper:]'")

println("\nAfter bash processing:")
println(uppercase_data)

# Process further in Julia
julia_lines = split(strip(uppercase_data), '\n')
println("\nJulia array: $julia_lines")
println("Reversed: $(reverse(julia_lines))")

println()

# ============================================================================
# 11. ERROR HANDLING
# ============================================================================
println("11. Error Handling")
println("-" ^ 70)

# Safe execution
try
    result = @bashsafe "false"
catch e
    if isa(e, BashExecutionError)
        println("Caught BashExecutionError:")
        println("  Command: $(e.command)")
        println("  Exit code: $(e.exitcode)")
    end
end

# Full error info
stdout, stderr, exitcode = bash_full("ls /nonexistent_path 2>&1")
println("\nManual error handling:")
println("  Exit code: $exitcode")
println("  Output: $(strip(stdout))")

println()

# ============================================================================
# 12. COMPLEX PIPELINE EXAMPLE
# ============================================================================
println("12. Complex Pipeline Example")
println("-" ^ 70)

println("Finding and analyzing large files...")

# Find files > 1KB, sort by size
large_files_output = @bashcap "find . -type f -size +1k 2>/dev/null | head -5"
large_files = split(strip(large_files_output), '\n')

if !isempty(large_files) && !isempty(large_files[1])
    println("Found $(length(large_files)) large files")

    for file in large_files
        if !isempty(strip(file))
            size = @bashcap "du -h '$file' | cut -f1"
            ext = splitext(file)[2]
            println("  $(strip(size))\t$ext\t$file")
        end
    end
else
    println("No large files found")
end

println()

println("=== Advanced Examples Complete ===")
println("\nNext steps:")
println("1. Install BashRC integration for shell functions")
println("2. Try distributed execution with more workers")
println("3. Create polyglot scripts for your workflows")
println("4. Explore remote execution across your cluster")
