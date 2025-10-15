# Julia–Bash Bridge: Seamless Workflow Integration

## Purpose

This project creates a two-way bridge between Julia and Bash, eliminating the friction between the Julia REPL and the Unix shell. It enables native-style command execution, process control, and macro-level command translation in both directions, making Julia a first-class shell citizen and Bash a controllable, state-aware subsystem.

---

## 🚀 Installation & Setup (MANDATORY)

For the seamless integration features (like `+J` in Bash and automatic REPL settings) to work, you must configure your shell and Julia startup file.

### 1. Configure Bash (`~/.bashrc` or `~/.zshrc`)

You must copy the contents of the `bashrc` file (provided in this repository) into your main shell configuration file (e.g., `~/.bashrc`, `~/.zshrc`). This defines the critical shell functions (`+J`, `+JX`, `+JCall`) and environment variables.

**What to Copy:**
```bash
# =========================================================================
# JULIA BRIDGE SHORTCUTS (from the provided bashrc)
# =========================================================================
# Run arbitrary Julia code with project context
+J() {
    julia --project=. -e "$*"
}

# Replace each ? in Julia code with corresponding argument
+JX() {
    # Usage: +JX 'foo(?, ?)' bar baz
    local code="$1"
    shift
    for arg in "$@"; do
        code="${code/\?/$arg}"
    done
    julia --project=. -e "$code"
}
# ... and other shortcuts like +JCall
```

### 2. Configure Julia Startup (`~/.julia/config/startup.jl`)

The provided `startup.jl` file automatically loads the core `JBash.jl` module and sets up various REPL quality-of-life improvements (like `Revise.jl` and numbered prompts).

Place `startup.jl` in your Julia configuration directory (e.g., `~/.julia/config/startup.jl`).

> **Note:** Ensure `JBash.jl` and its dependencies (`eBash.jl`, etc.) are accessible (e.g., by ensuring your project directory is in the `JULIA_LOAD_PATH`).

```julia
# In your ~/.julia/config/startup.jl file:
# ... (contents from the provided startup.jl file)
include("JBash.jl") # Custom Bash integration framework
using .JBash         # Access functions/macros like @bash, bash_full
using Revise
# ... other utilities
```

### 3. Launching Julia

Always launch Julia from your project root to ensure it loads the correct environment and modules:
```bash
julia --project=.
```

---

## Core Features & Advanced Workflows

### A. Julia-Driven Bash Orchestration

Use Julia to manage application state and intelligently decide which Bash commands to run and on what data, leveraging the two-way bridge to simplify complex system logic.

| Macro/Function     | Use Case            | Description                                                              |
| ------------------ | ------------------- | ------------------------------------------------------------------------ |
| `@bash "cmd"`      | Inline Execution    | Run Bash command synchronously. Prints output to Julia STDOUT.           |
| `@bashif("cmd")`   | Conditional Flow    | Returns `true` if Bash command succeeds (exit code 0), otherwise `false`.  |
| `bash_full("cmd")` | Capture Metadata    | Returns `(stdout, stderr, exitcode)`. Essential for robust error handling. |
| `@bashprompt("cmd")`| Interactive Shell   | Executes a command allowing user interaction (e.g., `nano`, `vi`).       |

#### Advanced Workflow Example: Conditional Directory Setup

This Julia script uses a Bash conditional macro (`@bashif`) to check for a directory's existence and then uses a standard Julia `try/catch` block combined with the captured Bash exit code to handle execution failures.

```julia
# Example from f(bash).jl:
using .Bash

target_dir = "/tmp/new_project_op"

# 1. Use the Bash exit code (0=success) to drive Julia's control flow
if @bashif("test -d $(target_dir)")
    println("Directory already exists at: $target_dir")
else
    println("Directory NOT found. Creating...")
    # 2. Execute Bash command to create the directory
    (out, err, code) = bash_full("mkdir -p $(target_dir)")
    
    if code == 0
        println("   Directory created successfully.")
    else
        # 3. Robust error handling using captured metadata
        println("✗ Failed to create directory (Code $code): $err")
    end
end
```

### B. Bash Scripting with Embedded Julia Computation

Inject Julia's high-level computation directly into existing, robust shell scripts using the shortcuts defined in your `bashrc`. This allows Bash to focus on I/O and flow control, and Julia to focus on non-trivial numerical or statistical computation.

#### Advanced Workflow Example: Live Data Processing & Alerting

```bash
#!/usr/bin/bash
# Script to analyze a benchmark file using Julia's DataFrames package

DATA_FILE="benchmark.csv"

# 1. Bash prepares the environment and variables
RESULT_COUNT=$(wc -l < "$DATA_FILE")

# 2. Use +J to execute multi-line Julia code and capture the result
AVG_LATENCY=$(+J "
  using CSV, DataFrames
  # The file is in the Bash scope, so we pass it as a Julia string literal
  df = CSV.read("$DATA_FILE", DataFrame) 
  avg = mean(df.latency_ms)
  # Julia prints the result, which Bash captures as AVG_LATENCY
  println(round(avg, digits=2))
")

# 3. Bash uses the Julia result for decision making (using bc for float comparison)
echo "Processed $RESULT_COUNT entries."
echo "Average Latency (calculated by Julia): ${AVG_LATENCY}ms"

if (( $(echo "$AVG_LATENCY > 50.0" | bc -l) )); then
  echo "⚠️ Alert: Latency is too high."
fi
```

### C. Bi-directional Pipelining

The bridge enables advanced process composition by allowing Julia and Bash to exchange data seamlessly via STDIN/STDOUT.

| Direction      | Tool                               | Description                               |
| -------------- | ---------------------------------- | ----------------------------------------- |
| **Bash → Julia** | `... | +JP 'Julia code'`            | Pipes Bash `STDOUT` to Julia's `STDIN`.   |
| **Julia → Bash** | `@bash "julia -e '...' | cmd ..."` | Pipes Julia `STDOUT` to a Bash command.   |


#### Example: Complex Data Filtering

In this example, Julia generates a complex sequence, and Bash sorts and filters it.

```julia
# Julia REPL
@bash """
  julia -e '
    # Generate a list of complex calculations
    data = [i^3 - i*10 for i in 1:20]; 
    println.(data)' | 
  grep '-' |       # Bash filters out positive numbers
  sort -n |        # Bash sorts the negative numbers
  head -n 5        # Bash gets the 5 smallest (most negative)
"""
```

---

## Summary

This bridge provides the connective tissue for users who live on the command line but want high-level control and distributed computation without managing environment boundaries.

| For Bash Users                                               | For Julia Users                                                      |
| ------------------------------------------------------------ | -------------------------------------------------------------------- |
| Run Julia like a native shell command (`+J`, `+JX`).         | Run Bash commands inline without boilerplate (`@bash`, `bash_full`).   |
| Integrate complex numeric computation into shell pipelines.  | Automate complex shell pipelines with Julia logic.                   |
| Leverage Bash for I/O efficiency and flow control.           | Extend the REPL as a system terminal with persistent state.          |
| Learn Julia gradually through command-line helpers.          | Leverage the entire Unix ecosystem natively.                         |
