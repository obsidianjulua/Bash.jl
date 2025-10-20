# BashMacros.jl

[![CI](https://github.com/obsidianjulua/BashMacros.jl/actions/workflows/CI.yml/badge.svg)](https://github.com/obsidianjulua/BashMacros.jl/actions/workflows/CI.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

**The Ultimate Bash-Julia Integration** | Execute shell commands with Julia's power | Process data across languages seamlessly

Stop choosing between Bash and Julia. Use both, together, beautifully.

```julia
using BashMacros

# One-liner log analysis across your cluster
results = bash_cluster_map("grep -c ERROR {1}", log_files, cluster)
total_errors = sum(parse(Int, r[3][1]) for r in results)
println("Found $total_errors errors across $(length(log_files)) files")
```

## Why BashMacros?

🚀 **Zero friction** - Call bash commands like native Julia functions
⚡ **Distributed** - Run commands across workers, machines, and clusters
🔄 **Bidirectional** - Pipe data between Julia and Bash seamlessly
🎯 **Type-aware** - Auto-convert bash output to Julia types
🌐 **Polyglot** - Mix Julia and Bash in the same file
🛠️ **Shell integration** - Use Julia functions directly in your terminal

## Quick Start

```julia
using Pkg
Pkg.add(url="https://github.com/obsidianjulua/BashMacros.jl")
```

```julia
using BashMacros

# Execute any bash command
bash("ls -la")

# Capture output
files = @bashcap "ls *.jl"

# Pipe Julia data through bash tools
data = "foo\nbar\nbaz"
sorted = julia_to_bash_pipe(data, "sort -r")

# Conditional execution
if @bashif("which docker")
    @bashwrap "docker ps"
end
```

## Real-World Examples

### 1. Parallel Log Analysis

```julia
using Distributed, BashMacros

addprocs(8)
@everywhere using BashMacros

# Find all log files
logs = @bashtyped "find /var/log -name '*.log' 2>/dev/null" :string_array

# Count errors in parallel across 8 workers
error_counts = bash_map("grep -c ERROR {1} 2>/dev/null || echo 0", logs)

# Aggregate and rank
totals = [(file, parse(Int, strip(count))) for (file, count) in error_counts]
top_errors = sort(totals, by=x->x[2], rev=true)[1:10]

println("Top 10 files with errors:")
for (i, (file, count)) in enumerate(top_errors)
    println("$i. $file: $count errors")
end
```

**Output:**
```
Top 10 files with errors:
1. /var/log/app.log: 1,847 errors
2. /var/log/system.log: 423 errors
3. /var/log/auth.log: 89 errors
...
```

### 2. Distributed Video Processing

```julia
using BashMacros

# Find all videos
videos = @bashtyped "find ~/Videos -name '*.mp4'" :string_array

# Compress in parallel with progress tracking
results = bash_map_progress(
    "ffmpeg -i {1} -vcodec h264 -acodec aac {1}.compressed.mp4 2>&1",
    videos,
    show_progress=true
)

# Progress: 47/100 (47.0%)
```

### 3. Cluster Processing

```julia
# Configure your cluster
cluster = ClusterConfig(
    ["node1.cluster.local", "node2.cluster.local", "node3.cluster.local"],
    user="admin",
    max_concurrent=20,
    ssh_key="~/.ssh/cluster_key"
)

# Process 10,000 tasks across the cluster
tasks = 1:10_000
results = bash_cluster_map("./analyze_data.sh {1}", tasks, cluster)

successful = count(r -> r[3][3] == 0, results)
println("✓ Processed $successful/$length(tasks) tasks successfully")
```

### 4. Real-Time Log Monitoring with Alerts

```julia
using BashMacros

println("📡 Monitoring logs for critical errors...")

bash_stream("tail -f /var/log/app.log") do line
    if occursin(r"ERROR|FATAL|CRITICAL"i, line)
        # Alert via multiple channels
        bash("notify-send 'Critical Error' '$line'")

        # Could also: send to Slack, email, PagerDuty, etc.
        println("🚨 ALERT: $line")
    end
end
```

### 5. Data Pipeline: CSV Processing

```julia
using CSV, DataFrames, BashMacros

# Get CSV files modified in last 24 hours
files = @bashtyped "find . -name '*.csv' -mtime -1" :string_array

for file in files
    # Load with Julia
    df = CSV.read(file, DataFrame)

    # Compute statistics
    avg = mean(df.value)

    # Filter with Julia, process with bash
    high_values = filter(row -> row.value > avg, df)
    CSV.write("temp.csv", high_values)

    # Create report with bash tools
    @bashwrap "cat temp.csv | column -t -s, > reports/$(basename $file .csv)_report.txt"
end

println("✓ Processed $(length(files)) files")
```

### 6. Git Repository Analysis

```julia
using BashMacros, Statistics

# Get all repositories
repos = @bashtyped "find ~/projects -name '.git' -type d" :string_array
repos = dirname.(repos)

# Analyze each repo in parallel
stats = bash_map("cd {1} && git rev-list --count HEAD", repos)

commit_counts = [parse(Int, strip(count)) for (repo, count) in stats]

println("📊 Repository Statistics:")
println("Total repos: $(length(repos))")
println("Total commits: $(sum(commit_counts))")
println("Average commits/repo: $(round(mean(commit_counts), digits=2))")
println("Most active: $(repos[argmax(commit_counts)]) with $(maximum(commit_counts)) commits")
```

### 7. Polyglot Data Science Pipeline

Create `analysis.jl`:

```julia
using BashMacros, Statistics

@polyglot begin
    # Julia: Load and clean data
    data = [1, 2, 3, 4, 5, 10, 100]
    cleaned = filter(x -> x < 50, data)
    mean_val = mean(cleaned)

    println("Julia computed mean: $mean_val")

    #B> echo "Bash: Creating backup..."
    #B> cp data.csv "data_backup_$(date +%Y%m%d).csv"

    # Julia: Generate report
    report = "Mean: $mean_val\nCount: $(length(cleaned))"

    #B> echo "$report" | mail -s "Daily Report" admin@example.com

    println("✓ Report sent!")
end
```

### 8. System Administration Tasks

```julia
using BashMacros

# Check disk space across servers
servers = ["web1", "web2", "db1", "cache1"]

results = bash_remote_async("df -h / | tail -1 | awk '{print \$5}'", servers)

println("💾 Disk Usage:")
for (server, (stdout, _, exitcode)) in results
    usage = strip(stdout)
    emoji = parse(Int, replace(usage, "%" => "")) > 80 ? "🔴" : "🟢"
    println("$emoji $server: $usage")
end
```

### 9. Smart Type Conversion

```julia
using BashMacros

# Automatic type parsing
file_count = @bashtyped "ls | wc -l" :int                    # → Int: 42
file_sizes = @bashtyped "du -sh *" :string_array             # → Vector{String}
numbers = @bashtyped "seq 1 100" :int_array                   # → Vector{Int}

# Use Julia's power immediately
total = sum(numbers)  # 5050
println("Sum of 1-100: $total")

# Parse command output as structured data
@bashpretty "echo 42"
# Output:
# Command: echo 42
# Type: Int64
# Result: 42
```

### 10. Interactive Workflows

From your **bash shell** (after installing integration):

```bash
# Execute Julia code directly
j 'println("Hello from Julia")'

# Pipe bash output to Julia
echo "hello world" | jp 'uppercase'
# → HELLO WORLD

# Map over lines with Julia
ls -la | jmap 'x -> split(x)[end]'
# → filename1
# → filename2

# Filter with Julia predicates
ls | jfilter 'x -> endswith(x, ".jl")'
# → script.jl
# → test.jl

# Quick statistics
seq 1 1000 | jstats
# Count: 1000
# Sum: 500500
# Mean: 500.5
# Median: 500.5
# Std: 288.82

# Parallel processing from shell
jparallel 8 'process_file {}' *.dat
```

## Core Features

### Execute Commands

```julia
# Simple execution
bash("ls -la")

# With arguments
arg_bash("git", ["status", "--short"])

# Capture output
output = @bashcap "whoami"

# Get full details
stdout, stderr, exitcode = bash_full("ls /tmp")

# Conditional
if @bashif("test -f config.toml")
    println("Config exists!")
end

# Safe (throws on error)
try
    @bashsafe "false"
catch e
    println("Error: ", e.exitcode)
end
```

### Distributed Execution

```julia
using Distributed
addprocs(4)
@everywhere using BashMacros

# Map: Process items across workers
results = bash_map("process {1}", data_items)

# MapReduce: Aggregate results
total = bash_mapreduce("wc -l {1}", +, files) do output
    parse(Int, split(output)[1])
end

# Parallel: Run multiple commands
bash_parallel([
    "make build",
    "make test",
    "make deploy"
])

# Async: Non-blocking execution
task = bash_async("long_running_task") do result
    println("Completed: $result")
end

# Batch: Process in chunks
bash_batch(large_command_list, batch_size=50)
```

### Remote Execution

```julia
# Single host
stdout, stderr, exitcode = bash_remote("uptime", "server.com", user="admin")

# Multiple hosts
hosts = ["web1", "web2", "web3"]
results = bash_remote_async("systemctl status nginx", hosts)

# Copy and execute
bash_remote_file("script.sh", hosts, "/tmp/script.sh")

# Cluster execution
config = ClusterConfig(["node1", "node2", "node3", "node4"])
results = bash_cluster("uname -n && uptime", config)
```

### Streaming & Progress

```julia
# Stream large output
bash_stream("find / -name '*.log' 2>/dev/null") do line
    println("Found: $line")
end

# Collect with filter
jl_files = bash_stream_collect("find . -type f", filter=line -> endswith(line, ".jl"))

# Progress tracking
results = bash_map_progress("process {1}", items, show_progress=true)
# Progress: 734/1000 (73.4%)
```

### Piping Between Languages

```julia
# Julia → Bash
data = "foo\nbar\nbaz"
sorted = julia_to_bash_pipe(data, "sort -r")

# Bash → Julia → Bash
files = @bashcap "ls"
filtered = filter(x -> endswith(x, ".jl"), split(files, '\n'))
julia_to_bash_pipe(join(filtered, '\n'), "xargs wc -l")
```

### Polyglot Scripts

Mix Julia and Bash in the same file:

```julia
#!/usr/bin/env julia

using BashMacros

# Julia code
data = collect(1:100)
processed = map(x -> x^2, data)

#B> echo "Bash: Creating directories..."
#B> mkdir -p output results temp

# More Julia
mean_value = sum(processed) / length(processed)
println("Mean: $mean_value")

#B> echo "Bash: Mean = $mean_value" > results/summary.txt
#B> tar -czf results.tar.gz results/
```

Or use blocks:

```bash
#!/usr/bin/env bash

echo "Starting pipeline..."

# JULIA_BEGIN
using Statistics
data = [1, 2, 3, 4, 5]
avg = mean(data)
# JULIA_END

echo "Average: $avg"
```

Execute: `execute_polyglot_file("script.sh")`

## Shell Integration

Install to your bash/zsh shell:

```julia
using BashMacros
install_bashrc_integration()
```

Now use Julia directly from your terminal:

```bash
# Execute Julia code
j 'println(2 + 2)'

# Julia with BashMacros
jb 'bash("ls")'

# Pipe to Julia
cat file.txt | jp 'length'

# Map over stdin
seq 1 100 | jmap 'x -> x^2' | jsum
# → 338350

# Filter
ls -la | jfilter 'x -> occursin("jl", x)'

# Statistics
curl -s api.example.com/metrics | jq '.values[]' | jstats

# Distributed processing
find . -name "*.dat" | jparallel 4 'process_file {}'

# Start Julia REPL with BashMacros loaded
jrepl
```

## API Reference

### Core Execution
- `bash(cmd::String)` - Execute bash command
- `arg_bash(exe, opts)` - Execute with argument vector
- `capture_output(cmd)` - Capture output as string
- `bash_full(cmd)` - Return (stdout, stderr, exitcode)
- `spawn(cmd)` - Background execution
- `timeout(cmd, seconds)` - Execute with timeout
- `@bashwrap "cmd"` - Macro: execute command
- `@bashcap "cmd"` - Macro: capture output
- `@bashpipe "cmd"` - Macro: execute and return
- `@bashif("cmd")` - Macro: conditional execution
- `@bashsafe "cmd"` - Macro: throw on error

### Type Formatting
- `bash_typed(cmd)` - Auto-detect and parse type
- `@bashtyped "cmd" :type` - Parse as specific type
- `bash_table(cmd, delim)` - Parse as table
- `@bashtable "cmd" delim` - Macro: parse table
- `@bashpretty "cmd"` - Pretty-print output

### Distributed
- `bastributed(cmd, workers)` - Execute on all workers
- `bash_map(template, data)` - Map across items
- `bash_mapreduce(cmd, fn, data)` - MapReduce pattern
- `bash_parallel(commands)` - Run commands in parallel
- `bash_async(cmd, callback)` - Async execution
- `bash_batch(commands, size)` - Batch processing
- `bash_map_progress(cmd, data)` - Map with progress

### Remote
- `bash_remote(cmd, host, user, port)` - Execute on remote host
- `bash_remote_async(cmd, hosts)` - Execute on multiple hosts
- `bash_remote_file(file, hosts, path)` - Copy and execute
- `ClusterConfig(nodes, user, ...)` - Cluster configuration
- `bash_cluster(cmd, config)` - Execute on cluster
- `bash_cluster_map(template, data, config)` - Map across cluster

### Streaming
- `bash_stream(cmd, callback)` - Stream output line-by-line
- `bash_stream_collect(cmd; filter=nothing)` - Collect with optional filtering

### Piping
- `julia_to_bash_pipe(data, cmd)` - Pipe Julia data to bash

### Polyglot
- `execute_polyglot_file(file)` - Execute mixed script
- `execute_polyglot_string(code)` - Execute mixed code
- `@polyglot begin ... end` - Inline polyglot macro
- `create_polyglot_shebang(name, code)` - Create executable

### Shell Integration
- `generate_bashrc_integration()` - Generate shell functions
- `install_bashrc_integration()` - Install to ~/.bashrc
- `uninstall_bashrc_integration()` - Remove installation
- `generate_standalone_script(file)` - Create standalone file

### Utilities
- `find_exo(name)` - Find executable in PATH
- `command_exists(name)` - Check if command exists
- `detect_context(input)` - Detect Julia vs Bash
- `j_bash(args)` - Convert Julia dict to bash args
- `b_julia(args)` - Convert bash args to Julia dict
- `learn_args!(cmd, args)` - Learn command patterns
- `predict_args_count(cmd)` - Predict argument count

## Installation & Setup

```julia
# Basic installation
using Pkg
Pkg.add(url="https://github.com/obsidianjulua/BashMacros.jl")

# With shell integration
using BashMacros
install_bashrc_integration()

# Restart shell or:
source ~/.bashrc

# Verify
j 'println("Hello from Julia!")'
```

## Performance Tips

1. **Use workers for CPU-bound tasks**
   ```julia
   addprocs(:auto)  # Use all CPU cores
   ```

2. **Stream large datasets**
   ```julia
   bash_stream("huge_file.log") do line
       process(line)
   end
   ```

3. **Batch remote operations**
   ```julia
   bash_batch(commands, batch_size=50)
   ```

4. **Type your outputs**
   ```julia
   numbers = @bashtyped "seq 1 1000000" :int_array
   ```

## Examples Directory

Check out `/examples` for more:

- `basic_usage.jl` - Core functionality walkthrough
- `advanced_usage.jl` - Distributed, polyglot, and remote execution
- Real-world scenarios and patterns

## Troubleshooting

**Workers not responding?**
```julia
workers()  # Check active workers
rmprocs(workers())  # Remove all
addprocs(4)  # Re-add
```

**SSH failing?**
```julia
# Test connection
bash_remote("echo test", "host", user="user")

# Check keys
bash("ssh-add -l")
```

**Types not parsing?**
```julia
# Use explicit type
result = @bashtyped "command" :string_array

# Or auto-detect
result = bash_typed("command")
```

## Contributing

Contributions welcome! This framework is designed for:
- Seamless Bash-Julia integration
- Distributed computing workflows
- System administration automation
- Data pipelines mixing shell and Julia

Keep the core clean and add new features to separate modules.

## License

MIT License - See LICENSE file

---

**Made with ❤️ for developers who love both Bash and Julia**

Stop switching contexts. Stop choosing between tools. Use BashMacros.
