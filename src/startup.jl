# This centralizes command strings, making macros/functions cleaner and easier to update.
const CD_CMD = "cd"
const PYTHON_CMD = "python"
const GREP_CMD = "grep"
const EDITOR = get(ENV, "EDITOR", "nano")

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

