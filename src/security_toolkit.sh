#!/bin/bash

#===============================================================================
# ARCH LINUX SECURITY & MAINTENANCE TOOLKIT
#===============================================================================

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Logging
LOG_FILE="/var/log/arch_security_scan_$(date +%Y%m%d_%H%M%S).log"
REPORT_DIR="/tmp/security_reports_$(date +%Y%m%d_%H%M%S)"

# Create report directory
mkdir -p "$REPORT_DIR"

log() {
    echo -e "${1}" | tee -a "$LOG_FILE"
}

log_info() {
    log "${BLUE}[INFO]${NC} $1"
}

log_warn() {
    log "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    log "${RED}[ERROR]${NC} $1"
}

log_success() {
    log "${GREEN}[SUCCESS]${NC} $1"
}

#===============================================================================
# NETWORK SECURITY MONITORING
#===============================================================================

monitor_network_security() {
    log_info "Starting network security monitoring..."
    
    local net_report="$REPORT_DIR/network_security.txt"
    
    {
        echo "NETWORK SECURITY ANALYSIS"
        echo "========================"
        echo "Timestamp: $(date)"
        echo "Hostname: $(hostname)"
        echo ""
        
        # Active connections
        echo "ACTIVE NETWORK CONNECTIONS:"
        echo "--------------------------"
        ss -tuln | head -20
        echo ""
        
        # Listening services
        echo "LISTENING SERVICES:"
        echo "------------------"
        ss -tlnp | grep LISTEN
        echo ""
        
        # Network interfaces and routes
        echo "NETWORK INTERFACES:"
        echo "------------------"
        ip addr show
        echo ""
        echo "ROUTING TABLE:"
        echo "-------------"
        ip route show
        echo ""
        
        # Firewall status
        echo "FIREWALL STATUS:"
        echo "---------------"
        if systemctl is-active --quiet ufw; then
            echo "UFW Status:"
            ufw status verbose 2>/dev/null || echo "UFW status check failed"
        elif systemctl is-active --quiet iptables; then
            echo "iptables rules:"
            iptables -L -n -v 2>/dev/null || echo "iptables check failed (need root)"
        elif systemctl is-active --quiet nftables; then
            echo "nftables rules:"
            nft list tables 2>/dev/null || echo "nftables check failed (need root)"
        else
            echo "No active firewall detected!"
        fi
        echo ""
        
        # DNS configuration
        echo "DNS CONFIGURATION:"
        echo "-----------------"
        cat /etc/resolv.conf 2>/dev/null || echo "Cannot read resolv.conf"
        echo ""
        if [[ -f /etc/systemd/resolved.conf ]]; then
            echo "systemd-resolved config:"
            grep -v '^#' /etc/systemd/resolved.conf | grep -v '^$'
        fi
        echo ""
        
    } > "$net_report"
    
    # Real-time network monitoring with perf
    log_info "Starting real-time network traffic analysis..."
    
    perf record -e net:* -e syscalls:sys_enter_sendto -e syscalls:sys_enter_recvfrom \
        -g --call-graph=dwarf -o "$REPORT_DIR/network_activity.data" \
        timeout 10s tcpdump -i any -c 100 2>/dev/null &
    
    local perf_pid=$!
    
    # Monitor network stats in real-time
    {
        echo "REAL-TIME NETWORK STATISTICS:"
        echo "=============================="
        for i in {1..10}; do
            echo "Sample $i ($(date)):"
            cat /proc/net/dev | grep -E "(eth|wlan|enp|wlp)" | while read line; do
                echo "  $line"
            done
            echo ""
            sleep 1
        done
    } >> "$net_report"
    
    wait "$perf_pid" 2>/dev/null || true
    
    # Analyze network performance data
    if [[ -f "$REPORT_DIR/network_activity.data" ]]; then
        {
            echo "NETWORK ACTIVITY ANALYSIS:"
            echo "========================="
            perf report -i "$REPORT_DIR/network_activity.data" --stdio --sort=overhead,symbol --no-children | head -15
        } >> "$net_report"
    fi
    
    log_success "Network security analysis saved to: $net_report"
}

# Check for suspicious network activity
check_suspicious_network() {
    log_info "Checking for suspicious network activity..."
    
    local suspicious_report="$REPORT_DIR/suspicious_network.txt"
    
    {
        echo "SUSPICIOUS NETWORK ACTIVITY CHECK"
        echo "================================="
        echo "Timestamp: $(date)"
        echo ""
        
        # Check for unusual connections
        echo "UNUSUAL OUTBOUND CONNECTIONS:"
        echo "----------------------------"
        ss -tuln | awk '/ESTAB/ && $5 !~ /^(127\.|10\.|172\.(1[6-9]|2[0-9]|3[01])\.|192\.168\.)/ {print $5}' | sort | uniq -c | sort -nr
        echo ""
        
        # Check for high-port listeners
        echo "HIGH-PORT LISTENERS (>32768):"
        echo "-----------------------------"
        ss -tlnp | awk -F: '/LISTEN/ && $NF > 32768 {print $0}'
        echo ""
        
        # Check for processes with network activity
        echo "TOP NETWORK-ACTIVE PROCESSES:"
        echo "----------------------------"
        lsof -i -n | awk '{print $1}' | sort | uniq -c | sort -nr | head -10
        echo ""
        
        # Check recent failed connection attempts (if available)
        echo "RECENT FAILED CONNECTIONS (journalctl):"
        echo "---------------------------------------"
        journalctl --since="1 hour ago" | grep -i "failed\|denied\|refused" | grep -i "connection\|connect" | tail -10
        echo ""
        
    } > "$suspicious_report"
    
    log_success "Suspicious network activity check saved to: $suspicious_report"
}

#===============================================================================
# SYSTEM CONFIGURATION SECURITY
#===============================================================================

audit_system_configs() {
    log_info "Auditing system configurations..."
    
    local config_report="$REPORT_DIR/config_audit.txt"
    
    {
        echo "SYSTEM CONFIGURATION AUDIT"
        echo "=========================="
        echo "Timestamp: $(date)"
        echo ""
        
        # Critical file permissions
        echo "CRITICAL FILE PERMISSIONS:"
        echo "-------------------------"
        local critical_files=(
            "/etc/passwd"
            "/etc/shadow"
            "/etc/group"
            "/etc/gshadow"
            "/etc/sudoers"
            "/etc/ssh/sshd_config"
            "/etc/hosts"
            "/etc/fstab"
        )
        
        for file in "${critical_files[@]}"; do
            if [[ -e "$file" ]]; then
                ls -la "$file"
            else
                echo "$file: NOT FOUND"
            fi
        done
        echo ""
        
        # SUID/SGID files
        echo "SUID/SGID FILES:"
        echo "---------------"
        find /usr -type f \( -perm -4000 -o -perm -2000 \) -exec ls -la {} \; 2>/dev/null | head -20
        echo ""
        
        # World-writable files (security risk)
        echo "WORLD-WRITABLE FILES (potential security risk):"
        echo "----------------------------------------------"
        find /etc /usr -type f -perm -002 2>/dev/null | head -10
        echo ""
        
        # SSH configuration audit
        echo "SSH CONFIGURATION AUDIT:"
        echo "-----------------------"
        if [[ -f /etc/ssh/sshd_config ]]; then
            echo "SSH settings:"
            grep -E "^(PermitRootLogin|PasswordAuthentication|PubkeyAuthentication|Port|Protocol)" /etc/ssh/sshd_config
            echo ""
            echo "SSH service status:"
            systemctl status sshd --no-pager -l || echo "SSH service not running"
        else
            echo "SSH not configured"
        fi
        echo ""
        
        # Sudo configuration
        echo "SUDO CONFIGURATION:"
        echo "------------------"
        if [[ -f /etc/sudoers ]]; then
            echo "Sudoers file permissions:"
            ls -la /etc/sudoers
            echo "Non-comment sudoers entries:"
            grep -v '^#' /etc/sudoers | grep -v '^$' | head -10
        fi
        echo ""
        
        # Systemd services analysis
        echo "SYSTEMD SERVICES ANALYSIS:"
        echo "-------------------------"
        echo "Enabled services:"
        systemctl list-unit-files --type=service --state=enabled | head -15
        echo ""
        echo "Failed services:"
        systemctl --failed --no-legend
        echo ""
        
        # Network configuration
        echo "NETWORK CONFIGURATION FILES:"
        echo "---------------------------"
        if [[ -d /etc/netctl ]]; then
            echo "Netctl profiles:"
            ls -la /etc/netctl/ 2>/dev/null | head -10
        fi
        if [[ -d /etc/NetworkManager ]]; then
            echo "NetworkManager configuration:"
            ls -la /etc/NetworkManager/ 2>/dev/null | head -10
        fi
        echo ""
        
        # Package manager security
        echo "PACKAGE MANAGER SECURITY:"
        echo "------------------------"
        echo "Pacman configuration:"
        grep -E "^(SigLevel|LocalFileSigLevel|RemoteFileSigLevel)" /etc/pacman.conf 2>/dev/null || echo "Pacman signature settings not found"
        echo ""
        echo "Trusted keys:"
        pacman-key --list-sigs 2>/dev/null | wc -l || echo "Cannot check pacman keys"
        echo ""
        
    } > "$config_report"
    
    log_success "Configuration audit saved to: $config_report"
}

# Check for configuration changes
monitor_config_changes() {
    log_info "Monitoring recent configuration changes..."
    
    local changes_report="$REPORT_DIR/config_changes.txt"
    
    {
        echo "RECENT CONFIGURATION CHANGES"
        echo "============================"
        echo "Timestamp: $(date)"
        echo ""
        
        # Recently modified files in /etc
        echo "RECENTLY MODIFIED /etc FILES (last 7 days):"
        echo "------------------------------------------"
        find /etc -type f -mtime -7 -exec ls -la {} \; 2>/dev/null | head -20
        echo ""
        
        # Package changes
        echo "RECENT PACKAGE CHANGES:"
        echo "----------------------"
        echo "Recently installed packages:"
        grep "installed" /var/log/pacman.log | tail -10
        echo ""
        echo "Recently upgraded packages:"
        grep "upgraded" /var/log/pacman.log | tail -10
        echo ""
        echo "Recently removed packages:"
        grep "removed" /var/log/pacman.log | tail -10
        echo ""
        
        # Systemd service changes
        echo "SYSTEMD SERVICE CHANGES:"
        echo "-----------------------"
        journalctl --since="7 days ago" | grep "systemd" | grep -E "(started|stopped|enabled|disabled)" | tail -15
        echo ""
        
    } > "$changes_report"
    
    log_success "Configuration changes report saved to: $changes_report"
}

#===============================================================================
# LOG ANALYSIS
#===============================================================================

analyze_system_logs() {
    log_info "Analyzing system logs..."
    
    local logs_report="$REPORT_DIR/log_analysis.txt"
    
    {
        echo "SYSTEM LOG ANALYSIS"
        echo "=================="
        echo "Timestamp: $(date)"
        echo ""
        
        # System errors and warnings
        echo "SYSTEM ERRORS (last 24 hours):"
        echo "------------------------------"
        journalctl --since="24 hours ago" --priority=err -n 20
        echo ""
        
        echo "SYSTEM WARNINGS (last 24 hours):"
        echo "--------------------------------"
        journalctl --since="24 hours ago" --priority=warning -n 15
        echo ""
        
        # Authentication logs
        echo "AUTHENTICATION EVENTS:"
        echo "---------------------"
        journalctl --since="24 hours ago" | grep -i "auth\|login\|sudo" | tail -15
        echo ""
        
        # Hardware errors
        echo "HARDWARE ERRORS:"
        echo "---------------"
        journalctl --since="24 hours ago" | grep -i "error" | grep -E "(hardware|thermal|cpu|memory|disk)" | tail -10
        echo ""
        
        # Kernel messages
        echo "KERNEL MESSAGES:"
        echo "---------------"
        journalctl --since="24 hours ago" -k -n 15
        echo ""
        
        # Systemd boot analysis
        echo "BOOT ANALYSIS:"
        echo "-------------"
        systemd-analyze blame | head -10
        echo ""
        systemd-analyze critical-chain
        echo ""
        
        # Failed systemd units
        echo "FAILED SYSTEMD UNITS:"
        echo "--------------------"
        journalctl --since="24 hours ago" | grep "Failed to start" | tail -10
        echo ""
        
        # Security-related logs
        echo "SECURITY-RELATED EVENTS:"
        echo "-----------------------"
        journalctl --since="24 hours ago" | grep -i -E "(denied|refused|failed.*auth|invalid|breach|attack)" | tail -15
        echo ""
        
    } > "$logs_report"
    
    # Performance analysis of logging system
    log_info "Analyzing logging performance..."
    
    perf record -e syscalls:sys_enter_write -e syscalls:sys_enter_fsync \
        -g --call-graph=dwarf -o "$REPORT_DIR/logging_perf.data" \
        timeout 5s journalctl --since="1 minute ago" >/dev/null 2>&1 &
    
    wait $! 2>/dev/null || true
    
    if [[ -f "$REPORT_DIR/logging_perf.data" ]]; then
        {
            echo "LOGGING PERFORMANCE ANALYSIS:"
            echo "=============================="
            perf report -i "$REPORT_DIR/logging_perf.data" --stdio --sort=overhead,symbol --no-children | head -10
        } >> "$logs_report"
    fi
    
    log_success "Log analysis saved to: $logs_report"
}

# Extract security events from logs
extract_security_events() {
    log_info "Extracting security-relevant events..."
    
    local security_report="$REPORT_DIR/security_events.txt"
    
    {
        echo "SECURITY EVENTS ANALYSIS"
        echo "======================="
        echo "Timestamp: $(date)"
        echo ""
        
        # Failed login attempts
        echo "FAILED LOGIN ATTEMPTS:"
        echo "---------------------"
        journalctl --since="7 days ago" | grep -i "failed password\|authentication failure\|invalid user" | tail -10
        echo ""
        
        # Sudo usage
        echo "SUDO USAGE:"
        echo "----------"
        journalctl --since="7 days ago" | grep "sudo:" | tail -15
        echo ""
        
        # System file access attempts
        echo "SYSTEM FILE ACCESS:"
        echo "------------------"
        journalctl --since="24 hours ago" | grep -E "/etc/|/root/|/boot/" | grep -i "access\|open\|read" | tail -10
        echo ""
        
        # Network security events
        echo "NETWORK SECURITY EVENTS:"
        echo "-----------------------"
        journalctl --since="24 hours ago" | grep -i -E "(firewall|iptables|connection.*refused|port.*blocked)" | tail -10
        echo ""
        
        # Process execution monitoring
        echo "UNUSUAL PROCESS EXECUTIONS:"
        echo "--------------------------"
        journalctl --since="24 hours ago" | grep -E "execve.*\/(tmp|dev\/shm|var\/tmp)" | tail -5
        echo ""
        
    } > "$security_report"
    
    log_success "Security events analysis saved to: $security_report"
}

#===============================================================================
# CACHE AND SYSTEM CLEANUP
#===============================================================================

clean_system_caches() {
    log_info "Cleaning system caches and temporary files..."
    
    local cleanup_report="$REPORT_DIR/cleanup_report.txt"
    local total_freed=0
    
    {
        echo "SYSTEM CLEANUP REPORT"
        echo "===================="
        echo "Timestamp: $(date)"
        echo ""
        
        # Pacman package cache
        echo "PACMAN CACHE CLEANUP:"
        echo "--------------------"
        local pacman_cache_before=$(du -sh /var/cache/pacman/pkg/ 2>/dev/null | awk '{print $1}' || echo "0")
        echo "Cache size before: $pacman_cache_before"
        
        # Clean package cache (keep only latest versions)
        if command -v paccache >/dev/null; then
            paccache -r -k 2 2>/dev/null || true
            paccache -r -u -k 0 2>/dev/null || true  # Remove uninstalled packages
        fi
        
        local pacman_cache_after=$(du -sh /var/cache/pacman/pkg/ 2>/dev/null | awk '{print $1}' || echo "0")
        echo "Cache size after: $pacman_cache_after"
        echo ""
        
        # System temporary files
        echo "TEMPORARY FILES CLEANUP:"
        echo "-----------------------"
        local temp_dirs=("/tmp" "/var/tmp" "/var/cache/fontconfig" "/var/cache/ldconfig")
        
        for dir in "${temp_dirs[@]}"; do
            if [[ -d "$dir" ]]; then
                local size_before=$(du -sh "$dir" 2>/dev/null | awk '{print $1}' || echo "0")
                echo "$dir size before: $size_before"
                
                # Clean safely
                find "$dir" -type f -atime +7 -delete 2>/dev/null || true
                find "$dir" -type d -empty -delete 2>/dev/null || true
                
                local size_after=$(du -sh "$dir" 2>/dev/null | awk '{print $1}' || echo "0")
                echo "$dir size after: $size_after"
            fi
        done
        echo ""
        
        # Browser caches
        echo "BROWSER CACHE CLEANUP:"
        echo "---------------------"
        local browser_caches=(
            "$HOME/.cache/mozilla"
            "$HOME/.cache/chromium"
            "$HOME/.cache/google-chrome"
            "$HOME/.cache/opera"
        )
        
        for cache_dir in "${browser_caches[@]}"; do
            if [[ -d "$cache_dir" ]]; then
                local size_before=$(du -sh "$cache_dir" 2>/dev/null | awk '{print $1}' || echo "0")
                echo "$(basename "$cache_dir") cache before: $size_before"
                
                # Clean old cache files
                find "$cache_dir" -type f -atime +30 -delete 2>/dev/null || true
                
                local size_after=$(du -sh "$cache_dir" 2>/dev/null | awk '{print $1}' || echo "0")
                echo "$(basename "$cache_dir") cache after: $size_after"
            fi
        done
        echo ""
        
        # Journald logs
        echo "JOURNALD LOG CLEANUP:"
        echo "--------------------"
        local journal_size_before=$(journalctl --disk-usage 2>/dev/null | awk '{print $6}' || echo "0")
        echo "Journal size before: $journal_size_before"
        
        # Clean old journal entries (keep last 2 weeks)
        journalctl --vacuum-time=2weeks 2>/dev/null || true
        
        local journal_size_after=$(journalctl --disk-usage 2>/dev/null | awk '{print $6}' || echo "0")
        echo "Journal size after: $journal_size_after"
        echo ""
        
        # Thumbnail caches
        echo "THUMBNAIL CACHE CLEANUP:"
        echo "-----------------------"
        local thumb_cache="$HOME/.cache/thumbnails"
        if [[ -d "$thumb_cache" ]]; then
            local size_before=$(du -sh "$thumb_cache" 2>/dev/null | awk '{print $1}' || echo "0")
            echo "Thumbnail cache before: $size_before"
            
            find "$thumb_cache" -type f -atime +30 -delete 2>/dev/null || true
            
            local size_after=$(du -sh "$thumb_cache" 2>/dev/null | awk '{print $1}' || echo "0")
            echo "Thumbnail cache after: $size_after"
        fi
        echo ""
        
        # System font caches
        echo "FONT CACHE CLEANUP:"
        echo "------------------"
        fc-cache -f -v > /dev/null 2>&1 || true
        echo "Font cache rebuilt"
        echo ""
        
        # Shared library cache
        echo "LIBRARY CACHE CLEANUP:"
        echo "---------------------"
        ldconfig 2>/dev/null || echo "ldconfig requires root privileges"
        echo "Library cache updated"
        echo ""
        
    } > "$cleanup_report"
    
    log_success "System cleanup report saved to: $cleanup_report"
}

# Advanced cache analysis
analyze_cache_usage() {
    log_info "Analyzing cache usage patterns..."
    
    local cache_analysis="$REPORT_DIR/cache_analysis.txt"
    
    {
        echo "CACHE USAGE ANALYSIS"
        echo "==================="
        echo "Timestamp: $(date)"
        echo ""
        
        # Memory caches
        echo "MEMORY CACHE ANALYSIS:"
        echo "---------------------"
        echo "System memory usage:"
        free -h
        echo ""
        echo "Cache and buffer details:"
        cat /proc/meminfo | grep -E "(Cached|Buffers|SReclaimable|Shmem)"
        echo ""
        
        # Disk cache analysis
        echo "DISK CACHE ANALYSIS:"
        echo "-------------------"
        echo "Largest cache directories:"
        find /var/cache -type d -exec du -sh {} \; 2>/dev/null | sort -hr | head -10
        echo ""
        
        # User cache analysis
        echo "USER CACHE ANALYSIS:"
        echo "-------------------"
        if [[ -d "$HOME/.cache" ]]; then
            echo "User cache directories:"
            du -sh "$HOME/.cache"/* 2>/dev/null | sort -hr | head -15
        fi
        echo ""
        
        # Process cache usage
        echo "PROCESS CACHE USAGE:"
        echo "-------------------"
        echo "Top memory-using processes:"
        ps aux --sort=-%mem | head -15
        echo ""
        
    } > "$cache_analysis"
    
    # Performance analysis of cache operations
    perf record -e cache-references,cache-misses -g \
        --call-graph=dwarf -o "$REPORT_DIR/cache_perf.data" \
        timeout 3s find /var/cache -type f 2>/dev/null &
    
    wait $! 2>/dev/null || true
    
    if [[ -f "$REPORT_DIR/cache_perf.data" ]]; then
        {
            echo "CACHE PERFORMANCE ANALYSIS:"
            echo "============================"
            perf report -i "$REPORT_DIR/cache_perf.data" --stdio --sort=overhead,symbol --no-children | head -10
        } >> "$cache_analysis"
    fi
    
    log_success "Cache analysis saved to: $cache_analysis"
}

#===============================================================================
# MAIN EXECUTION FUNCTIONS
#===============================================================================

show_help() {
    cat << EOF
Arch Linux Security & Maintenance Toolkit

Usage: $0 [OPTION]

Options:
    network         Monitor network security and analyze traffic
    configs         Audit system configurations and check for changes
    logs            Analyze system logs and extract security events
    cleanup         Clean system caches and temporary files
    full            Run complete security audit and maintenance
    help            Show this help message

Examples:
    $0 network      # Network security monitoring
    $0 configs      # Configuration audit
    $0 logs         # Log analysis
    $0 cleanup      # Cache cleanup
    $0 full         # Complete system audit

Reports are saved to: $REPORT_DIR
Log file: $LOG_FILE
EOF
}

run_network_audit() {
    log_info "Running network security audit..."
    monitor_network_security
    check_suspicious_network
}

run_config_audit() {
    log_info "Running configuration audit..."
    audit_system_configs
    monitor_config_changes
}

run_log_audit() {
    log_info "Running log analysis..."
    analyze_system_logs
    extract_security_events
}

run_cleanup() {
    log_info "Running system cleanup..."
    analyze_cache_usage
    clean_system_caches
}

run_full_audit() {
    log_info "Running complete security audit and maintenance..."
    
    echo -e "${PURPLE}╔══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${PURPLE}║           ARCH LINUX SECURITY & MAINTENANCE TOOLKIT         ║${NC}"
    echo -e "${PURPLE}╚══════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    
    run_network_audit
    echo ""
    run_config_audit
    echo ""
    run_log_audit
    echo ""
    run_cleanup
    
    # Generate summary report
    local summary_report="$REPORT_DIR/SUMMARY_REPORT.txt"
    {
        echo "SECURITY AUDIT SUMMARY"
        echo "====================="
        echo "Timestamp: $(date)"
        echo "System: $(uname -a)"
        echo "Hostname: $(hostname)"
        echo "User: $(whoami)"
        echo ""
        echo "Generated Reports:"
        find "$REPORT_DIR" -name "*.txt" -exec basename {} \; | sort
        echo ""
        echo "Log File: $LOG_FILE"
        echo "Report Directory: $REPORT_DIR"
        echo ""
        echo "Next Steps:"
        echo "- Review all generated reports"
        echo "- Check suspicious network activity"
        echo "- Verify configuration changes"
        echo "- Monitor system logs for errors"
        echo ""
    } > "$summary_report"
    
    log_success "Complete audit finished!"
    log_success "Summary report: $summary_report"
    log_success "All reports saved to: $REPORT_DIR"
}

# Main execution
main() {
    # Check if running as root for some operations
    if [[ $EUID -eq 0 ]]; then
        log_warn "Running as root - full system access available"
    else
        log_info "Running as user - some operations may have limited access"
    fi
    
    case "${1:-help}" in
        "network")
            run_network_audit
            ;;
        "configs")
            run_config_audit
            ;;
        "logs")
            run_log_audit
            ;;
        "cleanup")
            run_cleanup
            ;;
        "full")
            run_full_audit
            ;;
        "help"|*)
            show_help
            ;;
    esac
}

# Execute main function
main "$@"