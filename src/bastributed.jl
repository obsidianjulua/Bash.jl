#!/usr/bin/env julia

"""
bastributed: Distributed Bash Execution System
===============================================

Execute bash commands across multiple workers, machines, or clusters.
Provides map-reduce style operations on bash commands.
"""

using Distributed
using Dates

# ============================================================================
# DISTRIBUTED EXECUTION
# ============================================================================

"""
    bastributed(cmd::String, workers::Vector{Int}=workers())

Execute bash command on all specified workers and collect results.
"""
function bastributed(cmd::String, worker_ids::Vector{Int}=workers())
    futures = [@spawnat worker capture_output(cmd) for worker in worker_ids]
    results = fetch.(futures)
    return results
end

"""
    bash_map(cmd_template::String, data::Vector; workers::Vector{Int}=workers())

Map bash command across data items, distributed across workers.
Use {1}, {2}, etc. as placeholders in command template.

# Examples
```julia
files = ["file1.txt", "file2.txt", "file3.txt"]
results = bash_map("wc -l {1}", files)
```
"""
function bash_map(cmd_template::String, data::Vector; worker_ids::Vector{Int}=workers())
    @assert nworkers() > 0 "No workers available. Use addprocs() first."

    # Create commands for each data item
    commands = [replace(cmd_template, "{1}" => string(item)) for item in data]

    # Distribute across workers
    futures = [@spawnat worker_ids[((i-1) % length(worker_ids)) + 1] capture_output(cmd)
               for (i, cmd) in enumerate(commands)]

    results = fetch.(futures)
    return collect(zip(data, results))
end

"""
    bash_mapreduce(map_cmd::String, reduce_fn::Function, data::Vector; workers::Vector{Int}=workers())

Map-reduce pattern for bash commands.

# Examples
```julia
files = readdir()
# Count total lines across all files
total = bash_mapreduce("wc -l {1}", +, files) do output
    parse(Int, split(strip(output))[1])
end
```
"""
function bash_mapreduce(map_cmd::String, reduce_fn::Function, data::Vector;
                        worker_ids::Vector{Int}=workers(), parser::Function=identity)
    results = bash_map(map_cmd, data, worker_ids=worker_ids)
    parsed = [parser(result[2]) for result in results]
    return reduce(reduce_fn, parsed)
end

"""
    bash_parallel(commands::Vector{String}; workers::Vector{Int}=workers())

Execute multiple bash commands in parallel across workers.
"""
function bash_parallel(commands::Vector{String}; worker_ids::Vector{Int}=workers())
    @assert !isempty(worker_ids) "No workers available"

    futures = [@spawnat worker_ids[((i-1) % length(worker_ids)) + 1] bash_full(cmd)
               for (i, cmd) in enumerate(commands)]

    results = fetch.(futures)
    return results
end

"""
    bash_async(cmd::String; callback::Union{Function,Nothing}=nothing)

Execute bash command asynchronously and optionally call callback with result.
"""
function bash_async(cmd::String; callback::Union{Function,Nothing}=nothing)
    task = @async begin
        result = bash_full(cmd)
        if callback !== nothing
            callback(result)
        end
        result
    end
    return task
end

"""
    bash_batch(commands::Vector{String}, batch_size::Int=10)

Execute commands in batches across workers.
"""
function bash_batch(commands::Vector{String}, batch_size::Int=10; worker_ids::Vector{Int}=workers())
    results = []

    for i in 1:batch_size:length(commands)
        batch = commands[i:min(i+batch_size-1, length(commands))]
        batch_results = bash_parallel(batch, workers=worker_ids)
        append!(results, batch_results)
    end

    return results
end

# ============================================================================
# REMOTE EXECUTION
# ============================================================================

"""
    bash_remote(cmd::String, host::String; user::String=ENV["USER"], port::Int=22)

Execute bash command on remote host via SSH.
"""
function bash_remote(cmd::String, host::String; user::String=get(ENV, "USER", ""), port::Int=22)
    ssh_cmd = "ssh -p $port $user@$host '$cmd'"
    return bash_full(ssh_cmd)
end

"""
    bash_remote_async(cmd::String, hosts::Vector{String}; user::String=ENV["USER"])

Execute command on multiple remote hosts in parallel.
"""
function bash_remote_async(cmd::String, hosts::Vector{String}; user::String=get(ENV, "USER", ""))
    futures = [@async bash_remote(cmd, host, user=user) for host in hosts]
    results = fetch.(futures)
    return collect(zip(hosts, results))
end

"""
    bash_remote_file(local_file::String, hosts::Vector{String}, remote_path::String)

Copy file to remote hosts and execute it.
"""
function bash_remote_file(local_file::String, hosts::Vector{String}, remote_path::String;
                          user::String=get(ENV, "USER", ""))
    results = []

    for host in hosts
        # Copy file
        scp_cmd = "scp $local_file $user@$host:$remote_path"
        bash(scp_cmd)

        # Execute
        result = bash_remote("bash $remote_path", host, user=user)
        push!(results, (host, result))
    end

    return results
end

# ============================================================================
# CLUSTER EXECUTION
# ============================================================================

"""
Cluster configuration for distributed bash execution.
"""
mutable struct ClusterConfig
    nodes::Vector{String}
    user::String
    port::Int
    max_concurrent::Int
    ssh_key::Union{String,Nothing}

    ClusterConfig(nodes; user=get(ENV, "USER", ""), port=22, max_concurrent=10, ssh_key=nothing) =
        new(nodes, user, port, max_concurrent, ssh_key)
end

"""
    bash_cluster(cmd::String, config::ClusterConfig)

Execute bash command across cluster nodes.
"""
function bash_cluster(cmd::String, config::ClusterConfig)
    results = []
    semaphore = Threads.Condition()
    running = 0

    @sync for node in config.nodes
        @async begin
            # Wait if too many concurrent
            while running >= config.max_concurrent
                wait(semaphore)
            end

            running += 1
            try
                ssh_key_arg = config.ssh_key !== nothing ? "-i $(config.ssh_key)" : ""
                ssh_cmd = "ssh $ssh_key_arg -p $(config.port) $(config.user)@$node '$cmd'"
                result = bash_full(ssh_cmd)
                push!(results, (node, result))
            finally
                running -= 1
                notify(semaphore)
            end
        end
    end

    return results
end

"""
    bash_cluster_map(cmd_template::String, data::Vector, config::ClusterConfig)

Map bash command across data using cluster nodes.
"""
function bash_cluster_map(cmd_template::String, data::Vector, config::ClusterConfig)
    results = []

    @sync for (i, item) in enumerate(data)
        @async begin
            node = config.nodes[((i-1) % length(config.nodes)) + 1]
            cmd = replace(cmd_template, "{1}" => string(item))

            ssh_key_arg = config.ssh_key !== nothing ? "-i $(config.ssh_key)" : ""
            ssh_cmd = "ssh $ssh_key_arg -p $(config.port) $(config.user)@$node '$cmd'"

            result = bash_full(ssh_cmd)
            push!(results, (item, node, result))
        end
    end

    return results
end

# ============================================================================
# PROGRESS TRACKING
# ============================================================================

"""
    bash_map_progress(cmd_template::String, data::Vector; show_progress=true)

Map with progress bar.
"""
function bash_map_progress(cmd_template::String, data::Vector;
                           worker_ids::Vector{Int}=workers(), show_progress::Bool=true)
    total = length(data)
    completed = Threads.Atomic{Int}(0)

    if show_progress
        println("Processing $total items...")
    end

    results = []

    @sync for (i, item) in enumerate(data)
        @async begin
            worker = worker_ids[((i-1) % length(worker_ids)) + 1]
            cmd = replace(cmd_template, "{1}" => string(item))

            result = @spawnat worker capture_output(cmd)
            output = fetch(result)

            push!(results, (item, output))

            if show_progress
                Threads.atomic_add!(completed, 1)
                progress = Threads.atomic_add!(completed, 0)
                pct = round(progress / total * 100, digits=1)
                print("\rProgress: $progress/$total ($pct%)    ")
            end
        end
    end

    show_progress && println("\nDone!")
    return results
end

# ============================================================================
# STREAM PROCESSING
# ============================================================================

"""
    bash_stream(cmd::String, callback::Function)

Stream bash output line-by-line to callback function.
"""
function bash_stream(cmd::String, callback::Function)
    process = open(`bash -c $cmd`)

    try
        for line in eachline(process.out)
            callback(line)
        end
    finally
        close(process)
    end
end

"""
    bash_stream_collect(cmd::String; filter::Union{Function,Nothing}=nothing)

Stream and collect lines, optionally filtering.
"""
function bash_stream_collect(cmd::String; filter::Union{Function,Nothing}=nothing)
    lines = String[]

    bash_stream(cmd) do line
        if filter === nothing || filter(line)
            push!(lines, line)
        end
    end

    return lines
end

# ============================================================================
# EXPORTS
# ============================================================================

export bastributed, bash_map, bash_mapreduce, bash_parallel,
       bash_async, bash_batch, bash_remote, bash_remote_async,
       bash_remote_file, ClusterConfig, bash_cluster, bash_cluster_map,
       bash_map_progress, bash_stream, bash_stream_collect
