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

export julia_to_bash_pipe, @bashif, bash_return, parse_and_process, execute_or_throw, @bashsafe, BashExecutionError
export @bashprompt, bash_prompt
