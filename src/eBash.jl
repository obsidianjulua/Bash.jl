#!/usr/bin/env julia

"""
Pipe a Julia string to a Bash command's STDIN and capture STDOUT as a string.
This is similar to: echo \$input_data | bash -c \$cmd
"""
function julia_to_bash_pipe(input_data::String, cmd::String)
    # The `cmd` is executed by bash -c
    bash_cmd = `bash -c $cmd`

    # Create a pipeline where stdin is an IOBuffer of the input data,
    # and stderr is redirected to the main process's stderr.
    pl = pipeline(bash_cmd, stdin=IOBuffer(input_data), stderr=stderr)
    return read(pl, String)
end

"""
Macro for executing a Bash command and using its exit code
    (0 for success, non-zero for failure) as the condition in a Julia `if` statement.
        Usage: if @bashif("ls /tmp/existing_file"); ... end
        """
macro bashif(cmd_str)
    # This expands to: bash_full(cmd_str)[3] == 0
    # bash_full returns (stdout, stderr, exitcode)
    return :(bash_full($(esc(cmd_str)))[3] == 0)
end

"""
Execute a Bash command, print its output to STDOUT, and return the output
as a Julia String.
This is a functional equivalent to the @bashpipe macro.
"""
function bash_return(cmd::String)
    # 1. Execute the command and capture the output
    output = capture_output(cmd)

    # 2. Print the output to Julia's STDOUT (for visibility/debugging)
    println(output)

    # 3. Return the output as a Julia String variable
    return output
end

function parse_and_process(data::String)
    # Assume the Bash command returns a number, like a file count
    count = parse(Int, strip(data))
    return count * 10
end

"""
Execute a Bash command and throw BashExecutionError if the exit code is non-zero.
    Returns STDOUT on success.
    """
function execute_or_throw(cmd::String)
    (stdout, stderr, exitcode) = bash_full(cmd)

    if exitcode != 0
        throw(BashExecutionError(cmd, stdout, stderr, exitcode))
    end

    # Return STDOUT on success
    return stdout
end

"""
Macro for executing a Bash command inside a try/catch block.
If the command fails (non-zero exit code), it throws a BashExecutionError.
"""
macro bashsafe(cmd_str)
    return :(execute_or_throw($(esc(cmd_str))))
end

"""
Macro for executing a Bash command with full interactive terminal feedback.
    The command's STDIN, STDOUT, and STDERR are connected directly to the Julia terminal.
    This allows the command to prompt the user for input (e.g., passwords or confirmation).
        Usage: @bashprompt("sudo pacman -Syu") or @bashprompt(my_cmd_variable)
        """
macro bashprompt(cmd_str)
    # 1. We must explicitly unquote the variable cmd_str using $(esc(cmd_str))
    #    to ensure the variable's VALUE (the string) is interpolated into the
    #    Cmd object at runtime, not the variable's NAME (interactive_cmd).
    # 2. The construction is $`bash -c $cmd_str`
    #    The inner $ is for the Cmd backticks.
    #    The outer $ is to substitute the variable's value from the REPL/calling scope.

    return esc(quote
        # The use of $(esc(cmd_str)) ensures that the string held by the Julia variable
        # is substituted here.
        cmd = `bash -c $(esc(cmd_str))`

        run(pipeline(cmd,
            stdin=Base.stdin,
            stdout=Base.stdout,
            stderr=Base.stderr))
    end)
end

"""
Execute a Bash command with full interactive terminal feedback.
This function avoids macro scoping issues by accepting the command string
    as a function argument. It routes STDIN/STDOUT/STDERR to the terminal.
        """
function bash_prompt(cmd::String)
    # 1. Build the command object
    bash_cmd = `bash -c $cmd`

    # 2. Run the command with all streams explicitly connected to the terminal.
    #    This enables interactive input/output.
    run(pipeline(bash_cmd,
        stdin=Base.stdin,
        stdout=Base.stdout,
        stderr=Base.stderr))
end

# Simple wrappers for common Bash directory changes. change or replicate for other locations
function home()
    cmd = "cd ~"
    BashMacros.bash(cmd)
end

function nano(args::String="")
    if isempty(Sys.which(EDITOR))
        error("Editor '$EDITOR' not found in PATH")
    end
    full_cmd = "$EDITOR $(Base.shell_escape(args))"
    @bashprompt(full_cmd)
end

function python(args::String="")
    full_cmd = "$PYTHON_CMD $args"
    BashMacros.bash(full_cmd) # Non-interactive execution for running scripts
end

function grep(args::String)
    full_cmd = "$GREP_CMD $args"
    BashMacros.bash(full_cmd)
end

# Julia/Bash Execution Bridge (+J & +JX Equivalents)

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

    # Execute the final code string using the helper function
    j_exec(final_code)
end

function rgrep(pattern::String)
    # Recursive grep for pattern in current directory
    cmd = "grep -r --color=auto $(pattern) ."
    BashMacros.bash(cmd)
end

function grep_logs(pattern::String; since::String="1 hour ago")
    # Searches system logs with a time filter
    cmd = "journalctl --since=\"$since\" | grep -i --color=auto \"$pattern\""
    BashMacros.bash(cmd)
end

function ls(args::String="")
    # Versatile ls command with long-listing and all-files flags
    cmd = "ls -la $args"
    BashMacros.bash(cmd)
end

# --- 9. File Operations ---

"""touch(file::String): Creates an empty file or updates timestamp."""
function touch(file::String)
    BashMacros.bash("touch \"$file\"")
end

"""rm(path::String): Recursively and forcefully removes a file or directory (sudo)."""
function rm(path::String)
    BashMacros.bash("sudo rm -rf \"$path\"")
end

"""mkcd(dir::String): Creates and changes directory into it."""
function mkcd(dir::String)
    BashMacros.bash("mkdir -p \"$dir\" && cd \"$dir\"")
end

"""cpb(source::String): Copies a file and creates a timestamped backup."""
function cpb(source::String)
    cmd = """
    cp \"$source\" \"$source.bak.\$(date +%Y%m%d_%H%M%S)\"
    """
    BashMacros.bash(cmd)
end

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

export julia_to_bash_pipe, @bashif, bash_return, parse_and_process, execute_or_throw, @bashsafe, BashExecutionError
export @bashprompt, bash_prompt
