#!/bin/bash

#===============================================================================
# REAL-TIME SECURITY MONITOR
# Integrates with Zen 3 performance monitoring
#===============================================================================

set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m'

# Configuration
MONITOR_DURATION=${MONITOR_DURATION:-0}  # 0 = infinite
REFRESH_INTERVAL=${REFRESH_INTERVAL:-2}
ALERT_THRESHOLD_CPU=80
ALERT_THRESHOLD_MEM=85
ALERT_THRESHOLD_DISK=90
ALERT_THRESHOLD_NETWORK=100000000  # 100MB/s

# Files
PID_FILE="/tmp/security_monitor.pid"
ALERT_LOG="/tmp/security_alerts.log"

# Cleanup function
cleanup() {
    echo -e "\n${YELLOW}Shutting down security monitor...${NC}"
    if [[ -f "$PID_FILE" ]]; then
        rm -f "$PID_FILE"
    fi
    # Kill any background perf processes
    pkill -f "perf record.*security_monitor" 2>/dev/null || true
    exit 0
}

trap cleanup SIGINT SIGTERM

# Check if already running
if [[ -f "$PID_FILE" ]] && kill -0 "$(cat "$PID_FILE")" 2>/dev/null; then
    echo -e "${RED}Security monitor already running (PID: $(cat "$PID_FILE"))${NC}"
    exit 1
fi

echo $$ > "$PID_FILE"

# Alert function
alert() {
    local level="$1"
    local message="$2"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    
    case "$level" in
        "CRITICAL")
            echo -e "${RED}[CRITICAL]${NC} $message"
            ;;
        "WARNING")
            echo -e "${YELLOW}[WARNING]${NC} $message"
            ;;
        "INFO")
            echo -e "${BLUE}[INFO]${NC} $message"
            ;;
    esac
    
    echo "$timestamp [$level] $message" >> "$ALERT_LOG"
}

# Get system metrics
get_cpu_usage() {
    top -bn1 | grep "Cpu(s)" | awk '{print $2}' | sed 's/%us,//'
}

get_memory_usage() {
    free | awk 'NR==2{printf "%.1f", $3*100/$2}'
}

get_disk_usage() {
    df -h / | awk 'NR==2{print $5}' | sed 's/%//'
}

get_network_bytes() {
    cat /proc/net/dev | grep -E "(eth|wlan|enp|wlp)" | awk '{sum += $2 + $10} END {print sum+0}'
}

get_active_connections() {
    ss -tuln | grep -c "ESTAB" || echo "0"
}

get_listening_ports() {
    ss -tlnp | grep -c "LISTEN" || echo "0"
}

# Security checks
check_suspicious_processes() {
    # Check for processes running from tmp directories
    local suspicious=$(ps aux | grep -E '/(tmp|dev/shm|var/tmp)' | grep -v grep | wc -l)
    if (( suspicious > 0 )); then
        alert "WARNING" "Suspicious processes running from temp directories: $suspicious"
    fi
    
    # Check for high CPU processes
    local high_cpu=$(ps aux --sort=-%cpu | awk 'NR==2 {print $3}')
    if [[ $high_cpu ]] && (( $(echo "$high_cpu > $ALERT_THRESHOLD_CPU" | bc -l) )); then
        local proc_name=$(ps aux --sort=-%cpu | awk 'NR==2 {print $11}')
        alert "WARNING" "High CPU usage detected: $proc_name ($high_cpu%)"
    fi
}

check_network_security() {
    # Check for unusual number of connections
    local connections=$(get_active_connections)
    if (( connections > 50 )); then
        alert "WARNING" "High number of active connections: $connections"
    fi
    
    # Check for new listening ports
    local current_ports=$(ss -tlnp | grep "LISTEN" | awk '{print $4}' | cut -d: -f2 | sort -n)
    local port_file="/tmp/known_ports.txt"
    
    if [[ -f "$port_file" ]]; then
        local new_ports=$(comm -13 "$port_file" <(echo "$current_ports") | wc -l)
        if (( new_ports > 0 )); then
            alert "INFO" "New listening ports detected: $new_ports"
        fi
    fi
    
    echo "$current_ports" > "$port_file"
}

check_file_integrity() {
    # Check for modifications to critical files
    local critical_files=(
        "/etc/passwd"
        "/etc/shadow"
        "/etc/sudoers"
        "/etc/ssh/sshd_config"
        "/etc/hosts"
    )
    
    local checksum_file="/tmp/file_checksums.txt"
    local current_checksums=""
    
    for file in "${critical_files[@]}"; do
        if [[ -f "$file" ]]; then
            current_checksums+="$(md5sum "$file")\n"
        fi
    done
    
    if [[ -f "$checksum_file" ]]; then
        if ! echo -e "$current_checksums" | diff "$checksum_file" - >/dev/null 2>&1; then
            alert "CRITICAL" "Critical system file modification detected!"
        fi
    fi
    
    echo -e "$current_checksums" > "$checksum_file"
}

# Performance monitoring with perf
start_perf_monitoring() {
    # Start background perf monitoring
    perf record -e syscalls:sys_enter_execve,syscalls:sys_enter_connect,syscalls:sys_enter_bind \
        -e net:net_dev_xmit,net:netif_receive_skb \
        -g --call-graph=dwarf -o "/tmp/security_monitor_$(date +%s).data" \
        sleep "$REFRESH_INTERVAL" &
    
    return $!
}

# Main monitoring loop
monitor_system() {
    local start_time=$(date +%s)
    local iteration=0
    local prev_network_bytes=$(get_network_bytes)
    
    while true; do
        clear
        iteration=$((iteration + 1))
        local current_time=$(date +%s)
        local uptime=$((current_time - start_time))
        
        # Header
        echo -e "${PURPLE}╔══════════════════════════════════════════════════════════════╗${NC}"
        echo -e "${PURPLE}║              REAL-TIME SECURITY MONITOR                     ║${NC}"
        echo -e "${PURPLE}╠══════════════════════════════════════════════════════════════╣${NC}"
        echo -e "${PURPLE}║ Monitoring: $(hostname -s) | Uptime: ${uptime}s | Iteration: $iteration ║${NC}"
        echo -e "${PURPLE}╚══════════════════════════════════════════════════════════════╝${NC}"
        echo ""
        
        # System metrics
        local cpu_usage=$(get_cpu_usage)
        local mem_usage=$(get_memory_usage)
        local disk_usage=$(get_disk_usage)
        local current_network_bytes=$(get_network_bytes)
        local network_rate=$((($current_network_bytes - $prev_network_bytes) / $REFRESH_INTERVAL))
        
        echo -e "${CYAN}System Metrics:${NC}"
        echo "━━━━━━━━━━━━━━━"
        
        # CPU usage with color coding
        if (( $(echo "$cpu_usage > $ALERT_THRESHOLD_CPU" | bc -l) )); then
            echo -e "CPU Usage:    ${RED}${cpu_usage}%${NC} (HIGH)"
        elif (( $(echo "$cpu_usage > 50" | bc -l) )); then
            echo -e "CPU Usage:    ${YELLOW}${cpu_usage}%${NC}"
        else
            echo -e "CPU Usage:    ${GREEN}${cpu_usage}%${NC}"
        fi
        
        # Memory usage with color coding
        if (( $(echo "$mem_usage > $ALERT_THRESHOLD_MEM" | bc -l) )); then
            echo -e "Memory Usage: ${RED}${mem_usage}%${NC} (HIGH)"
        elif (( $(echo "$mem_usage > 70" | bc -l) )); then
            echo -e "Memory Usage: ${YELLOW}${mem_usage}%${NC}"
        else
            echo -e "Memory Usage: ${GREEN}${mem_usage}%${NC}"
        fi
        
        # Disk usage with color coding
        if (( disk_usage > ALERT_THRESHOLD_DISK )); then
            echo -e "Disk Usage:   ${RED}${disk_usage}%${NC} (HIGH)"
        elif (( disk_usage > 80 )); then
            echo -e "Disk Usage:   ${YELLOW}${disk_usage}%${NC}"
        else
            echo -e "Disk Usage:   ${GREEN}${disk_usage}%${NC}"
        fi
        
        # Network activity
        local network_mb=$((network_rate / 1024 / 1024))
        if (( network_rate > ALERT_THRESHOLD_NETWORK )); then
            echo -e "Network Rate: ${RED}${network_mb} MB/s${NC} (HIGH)"
        else
            echo -e "Network Rate: ${GREEN}${network_mb} MB/s${NC}"
        fi
        
        echo ""
        
        # Security status
        echo -e "${CYAN}Security Status:${NC}"
        echo "━━━━━━━━━━━━━━━━"
        
        local connections=$(get_active_connections)
        local listening=$(get_listening_ports)
        
        echo "Active Connections: $connections"
        echo "Listening Ports:    $listening"
        
        # Check for failed login attempts
        local failed_logins=$(journalctl --since="1 minute ago" | grep -c "Failed password" || echo "0")
        if (( failed_logins > 0 )); then
            echo -e "Failed Logins:      ${RED}$failed_logins${NC} (ALERT)"
        else
            echo -e "Failed Logins:      ${GREEN}$failed_logins${NC}"
        fi
        
        # Check for sudo usage
        local sudo_usage=$(journalctl --since="1 minute ago" | grep -c "sudo:" || echo "0")
        if (( sudo_usage > 0 )); then
            echo -e "Sudo Usage:         ${YELLOW}$sudo_usage${NC}"
        else
            echo -e "Sudo Usage:         ${GREEN}$sudo_usage${NC}"
        fi
        
        echo ""
        
        # Process information
        echo -e "${CYAN}Process Information:${NC}"
        echo "━━━━━━━━━━━━━━━━━━━━"
        echo "Top CPU Processes:"
        ps aux --sort=-%cpu | head -6 | tail -5 | while read -r line; do
            local cpu=$(echo "$line" | awk '{print $3}')
            local cmd=$(echo "$line" | awk '{print $11}' | cut -c1-30)
            if (( $(echo "$cpu > 10" | bc -l) )); then
                echo -e "  ${YELLOW}$cpu%${NC} $cmd"
            else
                echo -e "  $cpu% $cmd"
            fi
        done
        
        echo ""
        echo "Top Memory Processes:"
        ps aux --sort=-%mem | head -6 | tail -5 | while read -r line; do
            local mem=$(echo "$line" | awk '{print $4}')
            local cmd=$(echo "$line" | awk '{print $11}' | cut -c1-30)
            if (( $(echo "$mem > 5" | bc -l) )); then
                echo -e "  ${YELLOW}$mem%${NC} $cmd"
            else
                echo -e "  $mem% $cmd"
            fi
        done
        
        echo ""
        
        # Network connections
        echo -e "${CYAN}Network Activity:${NC}"
        echo "━━━━━━━━━━━━━━━━━"
        echo "Recent Connections:"
        ss -tuln | grep "ESTAB" | head -5 | while read -r line; do
            echo "  $line"
        done
        
        echo ""
        
        # Recent alerts
        echo -e "${CYAN}Recent Alerts:${NC}"
        echo "━━━━━━━━━━━━━━"
        if [[ -f "$ALERT_LOG" ]]; then
            tail -5 "$ALERT_LOG" | while read -r line; do
                if [[ $line == *"CRITICAL"* ]]; then
                    echo -e "${RED}$line${NC}"
                elif [[ $line == *"WARNING"* ]]; then
                    echo -e "${YELLOW}$line${NC}"
                else
                    echo "$line"
                fi
            done
        else
            echo "No alerts"
        fi
        
        echo ""
        echo -e "${BLUE}Press Ctrl+C to stop monitoring${NC}"
        
        # Run security checks
        check_suspicious_processes
        check_network_security
        check_file_integrity
        
        # Update for next iteration
        prev_network_bytes=$current_network_bytes
        
        # Check if we should exit
        if [[ $MONITOR_DURATION -gt 0 ]] && (( uptime >= MONITOR_DURATION )); then
            break
        fi
        
        # Start background perf monitoring
        start_perf_monitoring &
        local perf_pid=$!
        
        sleep "$REFRESH_INTERVAL"
        
        # Wait for perf to finish
        wait "$perf_pid" 2>/dev/null || true
    done
}

# Generate summary report
generate_summary() {
    local report_file="/tmp/security_monitor_summary_$(date +%Y%m%d_%H%M%S).txt"
    
    {
        echo "SECURITY MONITORING SUMMARY"
        echo "=========================="
        echo "Timestamp: $(date)"
        echo "Hostname: $(hostname)"
        echo "Monitoring Duration: $(($(date +%s) - start_time)) seconds"
        echo ""
        
        echo "ALERTS SUMMARY:"
        echo "--------------"
        if [[ -f "$ALERT_LOG" ]]; then
            echo "Total alerts: $(wc -l < "$ALERT_LOG")"
            echo "Critical alerts: $(grep -c "CRITICAL" "$ALERT_LOG" || echo "0")"
            echo "Warning alerts: $(grep -c "WARNING" "$ALERT_LOG" || echo "0")"
            echo "Info alerts: $(grep -c "INFO" "$ALERT_LOG" || echo "0")"
            echo ""
            echo "Recent alerts:"
            tail -10 "$ALERT_LOG"
        else
            echo "No alerts recorded"
        fi
        echo ""
        
        echo "SYSTEM STATE:"
        echo "------------"
        echo "CPU Usage: $(get_cpu_usage)%"
        echo "Memory Usage: $(get_memory_usage)%"
        echo "Disk Usage: $(get_disk_usage)%"
        echo "Active Connections: $(get_active_connections)"
        echo "Listening Ports: $(get_listening_ports)"
        echo ""
        
        echo "PERFORMANCE DATA:"
        echo "----------------"
        local latest_perf=$(find /tmp -name "security_monitor_*.data" -mtime -1 | tail -1)
        if [[ -f "$latest_perf" ]]; then
            echo "Latest perf data: $latest_perf"
            perf report -i "$latest_perf" --stdio --sort=overhead,symbol --no-children | head -10
        else
            echo "No performance data available"
        fi
        
    } > "$report_file"
    
    echo -e "\n${GREEN}Summary report saved to: $report_file${NC}"
}

# Main execution
main() {
    echo -e "${GREEN}Starting Real-time Security Monitor${NC}"
    echo -e "${BLUE}Monitoring system security and performance...${NC}"
    echo ""
    
    # Initialize
    > "$ALERT_LOG"  # Clear alert log
    local start_time=$(date +%s)
    
    # Start monitoring
    monitor_system
    
    # Generate summary
    generate_summary
    
    # Cleanup
    cleanup
}

# Show help
show_help() {
    cat << EOF
Real-time Security Monitor

Usage: $0 [OPTIONS]

Environment Variables:
    MONITOR_DURATION    Duration in seconds (0 = infinite, default: 0)
    REFRESH_INTERVAL    Refresh interval in seconds (default: 2)

Examples:
    $0                              # Start infinite monitoring
    MONITOR_DURATION=300 $0         # Monitor for 5 minutes
    REFRESH_INTERVAL=5 $0           # Update every 5 seconds

Controls:
    Ctrl+C                          # Stop monitoring and generate summary

Files:
    $ALERT_LOG                      # Alert log
    $PID_FILE                       # Process ID file
    /tmp/security_monitor_*.data    # Performance data files

EOF
}

# Handle command line arguments
case "${1:-}" in
    "help"|"-h"|"--help")
        show_help
        exit 0
        ;;
    *)
        main "$@"
        ;;
esac
