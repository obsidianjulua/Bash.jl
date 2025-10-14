using .Bash

if @bashif("test -d /home/grim/Desktop/op")
    println("Directory exists! Proceeding with file operations.")
    @bashwrap("touch ./log.txt")
else
    println("Directory does not exist. Aborting.")
end

# Check if a command fails (non-zero exit code for failure)
try
    @bashwrap("echp who")
catch e
    (stdout, stderr, exitcode) = bash_full("echp who")
    if exitcode != 0
        println("Command failed with error: $(stderr)")
    end
    endtry
    @bashwrap("echp who")
    catch e
    (stdout, stderr, exitcode) = bash_full("echp who")
    if exitcode != 0
        println("Command failed with error: $(stderr)")
    end
end

# Array of filenames to create
filenames = ["data_01.txt", "data_02.txt", "config.yml"]

println("--- Starting Bash Loop ---")
for file in filenames
    # 1. Prepare the Bash command
    bash_cmd = "echo 'This is data for file: $file' > $file"

    # 2. Execute the command to create the file (using the inline macro for brevity)
    @bashwrap(bash_cmd)

    # 3. Verify creation and capture contents
    if @bashif("test -f $file")
        content = capture_output("cat $file")
        println("Created and verified: $file")
        println("   Content: $(strip(content))")
    else
        println("Failed to create: $file")
    end
end
println("--- Loop Finished ---")

# try catch safe macro
using .Bash

risky_command = "grep 'non_existent_pattern' /etc/passwd"
successful_command = "echo 'Success'"

# Use try/catch to safely handle the Bash failure
try
    println("--- Trying Success ---")
    output = @bashsafe(successful_command)
    println("SUCCESS! Output: $(strip(output))")

    println("\n--- Trying Risky Command ---")
    # This line will execute the Bash command, get a non-zero exit code,
    # and trigger a BashExecutionError
    output = @bashsafe(risky_command)

    # This line will not be reached if the command fails
    println("Should not see this.")

catch e
    if isa(e, BashExecutionError)
        println("\nBASH FAILURE CAUGHT! Handling error gracefully.")
        println("  Error Code: $(e.exitcode)")
        println("  Command: $(e.command)")
        # We can log the error details stored in the exception
        @bashwrap("echo 'Error occurred on $(e.command)' >> error.log")
    else
        # Catch any other unexpected Julia errors
        println("A non-Bash error occurred: $e")
    end
end

println("\nScript continues after handling the failure.")

# script logic
target_dir = "/home/grim/Desktop/new_project_op"
log_file = "log.txt"
full_log_path = joinpath(target_dir, log_file)

# 1. Check if the directory exists using the @bashif macro
if @bashif("test -d $(target_dir)")
    println("Directory already exists at: $target_dir")

    # Run a Bash command to touch the log file inside the existing directory
    @bashwrap("touch $(full_log_path)") [cite: 6]
    println("   Created log file: $(log_file)")

else
    println("Directory NOT found at: $target_dir")

    # 2. Execute Bash command to create the directory and its parents (-p flag)
    # The output shows the Cmd object and its success code.
    @bashwrap("mkdir -p $(target_dir)") [cite: 6]
    println("   Directory created successfully.")

    # 3. Now that the directory exists, run the command to create the log file
    @bashwrap("touch $(full_log_path)") [cite: 6]
    println("   Created log file: $(log_file)")
end

# 4. Optional: Verify the file and directory exist using Bash commands
if @bashif("test -f $(full_log_path)") [cite: 8]
    println("\nVerification successful! Full path is ready: $(full_log_path)")
else
    println("\nVerification failed. Check system permissions.")
end
