# =========================================================================
# STARTUP.JL: GRIM'S JULIA POWER REPL CONFIGURATION
# Julia-Bash Integration, Workspace Tools, and Workflow Utilities
# =========================================================================

# --- 1. Module and Package Imports ---
# NOTE: Ensure Julia is launched with `--threads` flag set externally (e.g., in .bashrc)

include("/home/grim/Desktop/op/Bash.jl") # Custom Bash integration framework
using .Bash                               # Access functions/macros from Bash.jl
using Revise                              # Automatic code reloading
using REPL                                # For REPL customization (e.g., numbered prompt)
using LinearAlgebra                       # Essential for math operations (e.g., BLAS threads in env_info)
using InteractiveUtils                    # For introspection tools like @which, methods
using MacroTools                          # For expression manipulation (prewalk, postwalk)
using ProgressMeter
using TerminalMenus

# --- 2. Initialization Hook (atreplinit) ---
# Code here runs *after* the REPL is fully initialized.
atreplinit() do repl
    try
        # Enables numbered prompts for easy command history reference (julia> 1:, 2: etc.)
        REPL.numbered_prompt!(repl)
    catch e
        # Silently fail if numbered prompts can't be enabled
    end
    # Add any other REPL-specific setup here (e.g., OhMyREPL theme, if installed)
end

# --- 3. Constant Command Definitions ---
# Defines constant strings for common external executables/commands.
# This centralizes command strings, making macros/functions cleaner and easier to update.
const LLAMA3_CMD = "ollama run llama3.2:latest"
const OCODE_CMD = "ollama run codellama:7b-instruct-q4_K_M"
const SMOLLM2_CMD = "ollama run smollm2:latest"
const PYCHARM_CMD = "pycharm"
const CD_CMD = "cd"
const NANO_CMD = "nano"
const PYTHON_CMD = "python"
const GREP_CMD = "grep"
const PALADIN_SCRIPT = "/home/grim/Desktop/Projects/Paladin/Paladin_v2.py"
const VENV_ACTIVATE = "source /home/grim/venv/bin/activate"
const PALADIN_MODEL = "ollama run Paladin"
const SECURITY_MONITOR_SCRIPT = "/home/grim/.julia/config/security_monitor"
const SECURITY_TOOLKIT_SCRIPT = "/home/grim/.julia/config/security_toolkit"
const SECURITY_AGENT_SCRIPT = "/home/grim/.julia/config/security_agent.sh"

# --- 4. Movement Functions (Leveraging Bash.bash) ---
# Simple wrappers for common Bash directory changes.
home() = Bash.bash("cd ~")
Projects() = Bash.bash("cd /home/grim/Desktop/Projects")

# --- 5. Zero-Argument Command Macros ---
# Macros that run constant commands via the @bashwrap macro (non-interactive shell).

macro llama3()
    return :(@bashwrap(LLAMA3_CMD))
end


macro Paladin_model()
    return :(@bashwrap(PALADIN_MODEL))
end

macro Ocode()
    return :(@bashwrap(OCODE_CMD))
end

macro smollm2()
    return :(@bashwrap(SMOLLM2_CMD))
end

# FIX 1: Corrected macro to use PYCHARM_CMD constant
macro pycharm()
    return :(@bashwrap(PYCHARM_CMD))
end

# Standard macro for quickly checking methods of a function
macro methods(ex)
    quote
        methods($(esc(ex)))
    end
end

# --- 6. Core Terminal Tool Functions (With Arguments) ---

function nano(args::String="")
    full_cmd = "$NANO_CMD $args"
    # FIX 2: Use @bashprompt for interactive editor session
    @bashprompt(full_cmd)
end

function python(args::String="")
    full_cmd = "$PYTHON_CMD $args"
    Bash.bash(full_cmd) # Non-interactive execution for running scripts
end

function grep(args::String)
    full_cmd = "$GREP_CMD $args"
    Bash.bash(full_cmd)
end

# --- 7. Julia/Bash Execution Bridge (+J & +JX Equivalents) ---

# Helper: Executes Julia code in a new Julia process
function j_exec(code::String)
    run(`julia --project=. -e $code`)
end

# Executes Julia code, replacing '?' placeholders with arguments
function j_exec_multi(code::String, args...)
    # Start with the input code string
    final_code = code

    # Iterate through the arguments and replace the '?' placeholder
    for arg in args
        # Replace the first instance of '?' with the string version of the argument
        final_code = replace(final_code, "?" => string(arg); count=1)
    end

    # FIX 3: Execute the final code string using the helper function
    j_exec(final_code)
end

# --- 8. Grep & Logging Utilities ---

function rgrep(pattern::String)
    # Recursive grep for pattern in current directory
    cmd = "grep -r --color=auto $(pattern) ."
    Bash.bash(cmd)
end

function grep_logs(pattern::String; since::String="1 hour ago")
    # Searches system logs with a time filter
    cmd = "journalctl --since=\"$since\" | grep -i --color=auto \"$pattern\""
    Bash.bash(cmd)
end

function ls(args::String="")
    # Versatile ls command with long-listing and all-files flags
    cmd = "ls -la $args"
    Bash.bash(cmd)
end

# --- 9. File Operations ---

"""touch(file::String): Creates an empty file or updates timestamp."""
function touch(file::String)
    Bash.bash("touch \"$file\"")
end

"""rm(path::String): Recursively and forcefully removes a file or directory (sudo)."""
function rm(path::String)
    Bash.bash("sudo rm -rf \"$path\"")
end

"""mkcd(dir::String): Creates and changes directory into it."""
function mkcd(dir::String)
    Bash.bash("mkdir -p \"$dir\" && cd \"$dir\"")
end

"""cpb(source::String): Copies a file and creates a timestamped backup."""
function cpb(source::String)
    cmd = """
    cp \"$source\" \"$source.bak.\$(date +%Y%m%d_%H%M%S)\"
    """
    Bash.bash(cmd)
end

# --- 10. FZF Integration ---

"""fe(): Find and edit a file using fzf."""
function fe()
    cmd = """
    file=\$(fzf --preview 'head -100 {}') && [ -f "\$file" ] && \${EDITOR:-nano} "\$file"
    """
    @bashprompt(cmd)
end

"""fif(search_pattern::String): Find in files using grep, pipe to fzf, and open in editor."""
function fif(search_pattern::String)
    cmd = """
    grep -r -l \"$search_pattern\" . 2>/dev/null |
    fzf --preview "grep -n '$search_pattern' {}" |
    xargs \${EDITOR:-nano}
    """
    @bashprompt(cmd)
end

# --- 11. REPL Introspection and Workspace Utilities ---

function clear_vars()
    cleared = []
    # Iterates over variables in Main scope and sets non-functions/non-modules to nothing
    for name in names(Main, all=false, imported=false)
        if name ∉ [:Base, :Core, :Main, :InteractiveUtils] &&
           !startswith(string(name), "#") &&
           isdefined(Main, name)
            try
                val = getfield(Main, name)
                if !(val isa Function || val isa Module || val isa Type)
                    @eval Main $(name) = nothing
                    push!(cleared, name)
                end
            catch
            end
        end
    end
    println("Cleared: ", join(cleared, ", "))
    GC.gc()
end

function find_functions(pattern::String)
    # Searches Main, Base, and Core modules for functions matching a pattern
    matching = []
    for name in names(Main, all=true)
        if occursin(pattern, string(name)) && isdefined(Main, name)
            try
                val = getfield(Main, name)
                if val isa Function
                    push!(matching, name)
                end
            catch
            end
        end
    end

    # Check Base and Core functions as well
    for mod in [Base, Core]
        for name in names(mod, all=true)
            if occursin(pattern, string(name))
                try
                    val = getfield(mod, name)
                    if val isa Function
                        push!(matching, Symbol("$mod.$name"))
                    end
                catch
                end
            end
        end
    end

    return sort(unique(matching))
end

function find_jl_files(dir=".")
    # Recursively finds all .jl files starting from a given directory
    jl_files = []
    for (root, dirs, files) in walkdir(dir)
        for file in files
            if endswith(file, ".jl")
                push!(jl_files, joinpath(root, file))
            end
        end
    end
    return jl_files
end

function include_all(dir=".")
    # Includes all .jl files found recursively
    jl_files = find_jl_files(dir)
    for file in jl_files
        try
            include(file)
            println("✓ Included: $file")
        catch e
            println("✗ Failed to include $file: $e")
        end
    end
end

function inspect(x)
    # Quick data inspection helper
    println("Value: $x")
    println("Type: $(typeof(x))")
    println("Size: $(sizeof(x)) bytes")
    if hasmethod(length, (typeof(x),))
        println("Length: $(length(x))")
    end
    if hasmethod(size, (typeof(x),))
        println("Dimensions: $(size(x))")
    end
    if hasmethod(fieldnames, (typeof(x),))
        fields = fieldnames(typeof(x))
        if !isempty(fields)
            println("Fields: $fields")
        end
    end
end

function env_info()
    # Prints key environment and performance settings
    println("Julia version: $(VERSION)")
    println("CPU threads: $(Threads.nthreads())")
    println("BLAS threads: $(BLAS.get_num_threads())")
    println("DEPOT_PATH: $(DEPOT_PATH)")
    println("LOAD_PATH: $(LOAD_PATH)")
end

function compare_performance(expr1, expr2, name1="expr1", name2="expr2")
    # Compares execution time of two expressions
    println("Comparing $name1 vs $name2:")
    print("$name1: ")
    t1 = @time eval(expr1)
    print("$name2: ")
    t2 = @time eval(expr2)
    return (t1, t2)
end

function memory_usage()
    # Prints garbage collection statistics
    stats = Base.gc_num()
    println("GC stats:")
    println("  Total allocations: $(stats.total_allocd) bytes")
    println("  GC time: $(stats.total_time/1e9) seconds")
    println("  Collections: $(stats.pause)")
end

function force_gc()
    # Forces garbage collection and prints usage stats
    println("Running garbage collection...")
    @time GC.gc()
    memory_usage()
end

function save_workspace(filename="workspace.jl")
    # Saves non-function, non-module variables from Main scope to a file
    open(filename, "w") do io
        for name in names(Main, all=false, imported=false)
            if name ∉ [:Base, :Core, :Main, :InteractiveUtils] &&
               isdefined(Main, name) &&
               !startswith(string(name), "#")
                try
                    val = getfield(Main, name)
                    if !(val isa Function || val isa Module)
                        println(io, "$name = $val")
                    end
                catch
                end
            end
        end
    end
    println("Workspace saved to $filename")
end

function load_workspace(filename="workspace.jl")
    # Loads saved variables back into the Main scope
    if isfile(filename)
        include(filename)
        println("Workspace loaded from $filename")
    else
        println("File $filename not found")
    end
end

"""source(f): Finds and opens the source code of a Julia function using the editor."""
function source(f::Function)
    try
        m = @which f
        file = String(m.file)
        line = m.line

        if !isempty(file) && isfile(file)
            @info "Source found: $file:$line. Opening in editor..."
            # Uses the Bash editor command to open the file at the specific line
            cmd = """
            \${EDITOR:-nano} +$line \"$file\"
            """
            @bashprompt(cmd)
        else
            println("Source code not available for $f.")
        end
    catch e
        println("Could not find source for $f: $e")
    end
end

"""code_prewalk(ex::Expr): Uses MacroTools.prewalk to replace symbol :x with :y in an expression."""
function code_prewalk(ex::Expr)
    new_ex = MacroTools.prewalk(ex) do x
        if x == :x
            @info "Replacing symbol :x with :y"
            return :y
        else
            return x
        end
    end
    return new_ex
end

"""
ollama_menu()

Presents an interactive menu of Ollama models defined as constants
and executes the selected model using the corresponding macro.
"""
function ollama_menu()
    # List of (Display Name, Macro Expression) pairs
    model_options = [
        "llama3.2:latest" => :(@llama3),
        "codellama:7b-instruct" => :(@Ocode),
        "smollm2:latest" => :(@smollm2),
        "Exit Menu" => nothing
    ]

    # Create the menu for display names
    menu = RadioMenu([m[1] for m in model_options], pagesize=5)

    # Request user input
    choice = request("Select an Ollama Model to Run:", menu)

    if 1 <= choice <= length(model_options) - 1
        # Get the expression (e.g., :(@llama3)) and execute it
        model_macro_expr = model_options[choice][2]
        println("Launching $(model_options[choice][1])...")
        eval(model_macro_expr)
    elseif choice == length(model_options)
        println("Menu exited.")
    else
        println("Selection cancelled.")
    end
end

"""
include_progress(dir=".")

Finds all .jl files recursively and includes them, showing a progress bar widget.
This is a robust replacement for the basic `include_all`.
    """
function include_progress(dir=".")
    jl_files = find_jl_files(dir)
    num_files = length(jl_files)

    if num_files == 0
        println("No .jl files found in $dir.")
        return
    end

    # Initialize the progress meter widget
    p = Progress(num_files,
        desc="Including Julia files: ",
        barglyphs=BarGlyphs("[=> ]"),
        color=:yellow)

    # Process each file with progress update
    for file in jl_files
        try
            include(file)
            # Add file info to the progress bar extra display
            next!(p; showvalues=[(:File, basename(file))])
        catch e
            println("✗ Failed to include $file: $e")
            next!(p) # Still increment, even on failure
        end
    end

    finish!(p)
    println("Successfully processed $num_files file(s).")
end

"""
venv()

Activates the Python virtual environment defined by VENV_ACTIVATE.
NOTE: This typically requires running Julia within a shell that is *already*
in the virtual environment, or using a sub-shell that is kept alive.
Since Bash.bash runs a new, disposable shell process, we create a function
    to keep the command handy, but direct activation is best done externally
    before starting Julia, or by using the interactive `paladin_launch` function below.
        """
function venv()
    # Execute the activation command. Note: Its effect will be lost immediately
    # after the shell spawned by Bash.bash exits.
    Bash.bash(VENV_ACTIVATE)
    @warn "Virtual environment activated in disposable shell. Effect may not persist."
end

"""
paladin_launch(args::String="")

Activates the virtual environment and then executes the Paladin Python script.
Uses Bash.bash_prompt to handle the interactive session correctly.
"""
function paladin_launch(args::String="")
    # The command string is built using local variables.
    full_cmd = "$VENV_ACTIVATE && python $PALADIN_SCRIPT $args"

    # CORRECT: Use the function Bash.bash_prompt to pass the command string
    # as an argument, bypassing macro scoping issues.
    Bash.bash_prompt(full_cmd)
end

"""
tool_menu()

Presents an interactive menu of all integrated Ollama models, Paladin script,
and security tools.
"""
function tool_menu()
    # List of (Display Name, Expression to Eval) pairs
    model_options = [
        # --- LLM/Agent Tools ---
        "Ollama: llama3.2:latest" => :(@llama3),
        "Ollama: codellama:7b-instruct" => :(@Ocode),
        "Ollama: smollm2:latest" => :(@smollm2),
        "Ollama: Paladin (Model Only)" => :(@Paladin_model),
        "Launch Paladin Script (with venv)" => :(paladin_launch()),

        # --- Security Tools ---
        "Launch Security Monitor (Live)" => :(security_monitor()),
        "Run Security Toolkit (Full Audit)" => :(security_toolkit("full")),
        "Run Security Toolkit (Network Audit)" => :(security_toolkit("network")), "Exit Menu" => nothing
    ]

    # Create the menu for display names
    menu = RadioMenu([m[1] for m in model_options], pagesize=10)

    # Request user input
    choice = request("Select a Tool or Model to Run:", menu)

    if 1 <= choice <= length(model_options) - 1
        chosen_option = model_options[choice]

        # Simple logging for better feedback
        println("Executing: $(chosen_option[1])...")

        # Execute the function/macro
        eval(chosen_option[2])

    elseif choice == length(model_options)
        println("Menu exited.")
    else
        println("Selection cancelled.")
    end
end

"""
security_monitor()

Launches the real-time security monitor script. Since this is a long-running,
full-terminal application (like htop), it must use Bash.bash_prompt.
"""
function security_monitor()
    println("Launching real-time security monitor...")
    # Use Bash.bash_prompt for interactive, persistent terminal application
    Bash.bash_prompt(SECURITY_MONITOR_SCRIPT)
end

"""
security_toolkit(command::String="help", args::String="")

Launches the Arch Linux security and maintenance toolkit script.
Takes a command (e.g., 'full', 'network') and optional arguments.
"""
function security_toolkit(command::String="help", args::String="")
    full_cmd = "$SECURITY_TOOLKIT_SCRIPT $command $args"
    println("Running security toolkit command: $command...")
    # Use Bash.bash for non-interactive, command-and-exit scripts
    Bash.bash(full_cmd)
end

"""
security_agent(command::String="help", args::String="")

Launches the unified security agent script with a command (e.g., 'monitor', 'full', 'network').
Uses Bash.bash_prompt for 'monitor' mode, and Bash.bash for audit/exit modes.
    """
    function security_agent(command::String="help", args::String="")
        full_cmd = "$SECURITY_AGENT_SCRIPT $command $args"

        if command == "monitor"
            println("Launching INTERACTIVE security monitor. Press Ctrl+C to exit and return to REPL.")
            # Use bash_prompt for the long-running, interactive monitor
            Bash.bash_prompt(full_cmd)

            # After monitor exits (via Ctrl+C in the Bash script):
            println("\nSecurity Monitor Session Ended.")
        else
            println("Running security agent audit: $command...")
            # Use bash for non-interactive commands that exit immediately
            Bash.bash(full_cmd)
        end

        # Check for exceptions/fails and provide feedback
        # NOTE: The check for command exit code happens implicitly inside Bash.bash
        #       and Bash.bash_prompt; non-zero codes will often throw an error in Julia.
        #       This print gives user feedback regardless of success.
        println("Security Agent command finished.")
        return
    end

    """
    tool_menu()

    Presents an interactive menu of all integrated tools and handles tool exit exceptions.
    """
    function tool_menu()
        options = [
            # ... (Your options list is unchanged)
            "Ollama: llama3.2:latest"       => :(@llama3),
            "Ollama: codellama:7b-instruct" => :(@Ocode),
            "Ollama: smollm2:latest"        => :(@smollm2),
            "Ollama: Paladin (Model Only)"  => :(@Paladin_model),
            "Launch Paladin Script (with venv)" => :(paladin_launch()),

            "SECURITY: Launch Live Monitor (Interactive)" => :(security_agent("monitor")),
            "SECURITY: Run Full System Audit (Exit/Fail Handled)" => :(security_agent("full")),
            "SECURITY: Run Network Audit Only" => :(security_agent("network")),
            "SECURITY: Cleanup Old Reports" => :(security_agent("cleanup")),

            "Exit Menu"                       => nothing
            ]

        menu = RadioMenu([m[1] for m in options], pagesize=10)
            choice = request("Select a Tool or Model to Run:", menu)

            if 1 <= choice <= length(options) - 1
                chosen_option = options[choice]

                println("Executing: $(chosen_option[1])...")

                # **Exception Handling for External Tool Exit/Failure**
                try
                    eval(chosen_option[2])
                    catch e
                    if e isa InterruptException
                        # This catches Ctrl+C if it interrupts Julia code (less likely here)
                        println(stderr, "\n[ERROR] Julia execution interrupted by user.")
                        elseif e isa ProcessFailedException
                        # This catches non-zero exits from external commands (like your security agent)
                        proc = e.procs[1] # Get the first (and usually only) process that failed
                        cmd = String(proc.cmd)
                        code = proc.exitcode

                        println(stderr, "\n[WARNING] Tool execution failed or exited with error code.")
                        println(stderr, "   Command: $cmd")
                        println(stderr, "   Exit Code: $code")

                        if code == 126
                            println(stderr, "   SUGGESTION: Code 126 means 'Permission Denied'. Did you run 'chmod +x' on the script?")
                        end
                    else
                        # Catch all other Julia-related errors (e.g., UndefVarError)
                        println(stderr, "\n[ERROR] An unexpected Julia error occurred: $(typeof(e)): $e")
                    end
                finally
                    println("\n--- REPL Control Restored ---")
                end

                elseif choice == length(options)
                println("Menu exited gracefully.")
            else
                println("Selection cancelled.")
            end
        end

# --- 12. Exports ---
# Makes all custom functions and macros available in the global REPL scope without prefixing (e.g., just 'ls()' instead of 'Main.ls()')
export @llama3, @Ocode, @smollm2, @methods, @pycharm, nano, python, grep, j_exec
export j_exec_multi, rgrep, grep_logs, fe, ls, mkcd, rm, touch, fif, cpb, clear_vars
export find_functions, find_jl_files, include_all, load_workspace, save_workspace
export memory_usage, compare_performance, inspect, env_info, source, code_prewalk, tool_menu
export home, Projects, ollama_menu, include_progress, venv, paladin_launch, @Paladin_model
export security_monitor, security_toolkit, security_agent
