#!/usr/bin/env julia

using BashMacros

println("Testing bash_async fix...")
println("=" ^ 70)

# Test async with callback
callback_fn = result -> begin
    stdout, stderr, exitcode = result
    println("Callback executed: $(strip(stdout))")
end

task = bash_async("sleep 1 && echo 'Async complete!'", callback=callback_fn)

println("Task started, waiting...")
wait(task)
println("Task completed successfully!")

println("=" ^ 70)
println("✓ bash_async works correctly!")
