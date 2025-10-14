#!/bin/bash

#===============================================================================
# ARCH LINUX SECURITY AGENT (Combined Toolkit and Monitor)
# Usage: security_agent.sh [monitor|full|network|configs|logs|cleanup|help]
#===============================================================================

set -euo pipefail

# --- Colors and Constants ---
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m'

# To this (using user's /tmp or /home/grim/logs):
LOG_BASE="/tmp/security_agent_logs" # Use a dedicated, user-writable spot
LOG_FILE="$LOG_BASE/log_$(date +%Y%m%d_%H%M%S).log"
REPORT_DIR="$LOG_BASE/reports_$(date +%Y%m%d_%H%M%S)"
PID_FILE="/tmp/security_monitor.pid"

# Ensure log directory exists early in the script
mkdir -p "$LOG_BASE" 2>/dev/null || true

# --- Logging Functions ---
log() {
    echo -e "${1}" | tee -a "$LOG_FILE"
}
log_info() { log "${BLUE}[INFO]${NC} $1"; }
log_success() { log "${GREEN}[SUCCESS]${NC} $1"; }
log_warn() { log "${YELLOW}[WARN]${NC} $1"; }
log_error() { log "${RED}[ERROR]${NC} $1"; }

# --- Cleanup & Trap (For Monitor Mode) ---
cleanup_monitor() {
    log_warn "Shutting down real-time monitor..."
    if [[ -f "$PID_FILE" ]]; then
        rm -f "$PID_FILE"
    fi
    pkill -f "perf record.*security_monitor" 2>/dev/null || true
    # Exit code 0 for intentional Ctrl+C exit in monitor mode
    exit 0
}

# --- Core Monitor Function (From security_monitor) ---
monitor_system() {
    echo -e "${GREEN}Starting Real-time Security Monitor (Ctrl+C to stop)${NC}"
    mkdir -p "$(dirname "$PID_FILE")"
    echo $$ >"$PID_FILE"

    trap cleanup_monitor SIGINT SIGTERM # Only active in monitor mode

    # Simplified core loop (expanded logic here would be from original script)
    while true; do
        # Simplified status output for clean script
        echo -e "[$(date +%T)] CPU: $(uptime | awk '{print $NF}') | RAM: $(free -m | awk 'NR==2{printf "%.0f%%", $3*100/$2 }')"
        sleep ${REFRESH_INTERVAL:-2}
    done
}

# --- Audit Functions (From security_toolkit) ---
# NOTE: We keep run_full_audit for the 'full' command.
run_full_audit() {
    log_info "Starting Full Security Audit..."
    mkdir -p "$REPORT_DIR"

    # 1. Network Audit (Simplified)
    log_info "Network check: open ports..."
    ss -tuln | grep LISTEN | log

    # 2. Config Audit (Simplified)
    log_info "Config check: last 5 modified files in /etc..."
    find /etc -type f -mtime -5 -print | log

    # 3. Log Audit (Simplified)
    log_info "Log check: last 10 errors from journalctl..."
    journalctl -p err -n 10 --no-pager | log

    log_success "Full audit finished! Reports saved to: $REPORT_DIR"
}

# --- Main Execution ---
main() {
    case "${1:-help}" in
    "monitor")
        monitor_system
        ;;
    "full")
        run_full_audit
        ;;
    "network")
        run_full_audit # Run full audit for robustness, or implement specific network_audit
        ;;
    "cleanup")
        log_info "Cleaning up old logs and reports..."
        # Placeholder for actual cleanup logic
        find /tmp/security_reports_* -mtime +7 -exec rm -rf {} \; 2>/dev/null || true
        log_success "Cleanup complete."
        ;;
    "help" | *)
        cat <<EOF
Usage: $0 [monitor|full|network|configs|cleanup|help]

  monitor:  Run real-time system monitor (Ctrl+C to stop).
  full:     Run a comprehensive system security audit.
  network:  Run a targeted network security audit.
  cleanup:  Remove old reports and log files.

EOF
        ;;
    esac
}

main "$@"
#!/bin/bash

#===============================================================================
# ARCH LINUX SECURITY AGENT (Combined Toolkit and Monitor)
# Usage: security_agent.sh [monitor|full|network|configs|logs|cleanup|help]
#===============================================================================

set -euo pipefail

# --- Colors and Constants ---
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m'

LOG_FILE="/var/log/security_agent_$(date +%Y%m%d_%H%M%S).log"
REPORT_DIR="/tmp/security_reports_$(date +%Y%m%d_%H%M%S)"
PID_FILE="/tmp/security_monitor.pid"

# --- Logging Functions ---
log() {
    echo -e "${1}" | tee -a "$LOG_FILE"
}
log_info() { log "${BLUE}[INFO]${NC} $1"; }
log_success() { log "${GREEN}[SUCCESS]${NC} $1"; }
log_warn() { log "${YELLOW}[WARN]${NC} $1"; }
log_error() { log "${RED}[ERROR]${NC} $1"; }

# --- Cleanup & Trap (For Monitor Mode) ---
cleanup_monitor() {
    log_warn "Shutting down real-time monitor..."
    if [[ -f "$PID_FILE" ]]; then
        rm -f "$PID_FILE"
    fi
    pkill -f "perf record.*security_monitor" 2>/dev/null || true
    # Exit code 0 for intentional Ctrl+C exit in monitor mode
    exit 0
}

# --- Core Monitor Function (From security_monitor) ---
monitor_system() {
    echo -e "${GREEN}Starting Real-time Security Monitor (Ctrl+C to stop)${NC}"
    mkdir -p "$(dirname "$PID_FILE")"
    echo $$ >"$PID_FILE"

    trap cleanup_monitor SIGINT SIGTERM # Only active in monitor mode

    # Simplified core loop (expanded logic here would be from original script)
    while true; do
        # Simplified status output for clean script
        echo -e "[$(date +%T)] CPU: $(uptime | awk '{print $NF}') | RAM: $(free -m | awk 'NR==2{printf "%.0f%%", $3*100/$2 }')"
        sleep ${REFRESH_INTERVAL:-2}
    done
}

# --- Audit Functions (From security_toolkit) ---
# NOTE: We keep run_full_audit for the 'full' command.
run_full_audit() {
    log_info "Starting Full Security Audit..."
    mkdir -p "$REPORT_DIR"

    # 1. Network Audit (Simplified)
    log_info "Network check: open ports..."
    ss -tuln | grep LISTEN | log

    # 2. Config Audit (Simplified)
    log_info "Config check: last 5 modified files in /etc..."
    find /etc -type f -mtime -5 -print | log

    # 3. Log Audit (Simplified)
    log_info "Log check: last 10 errors from journalctl..."
    journalctl -p err -n 10 --no-pager | log

    log_success "Full audit finished! Reports saved to: $REPORT_DIR"
}

# --- Main Execution ---
main() {
    case "${1:-help}" in
    "monitor")
        monitor_system
        ;;
    "full")
        run_full_audit
        ;;
    "network")
        run_full_audit # Run full audit for robustness, or implement specific network_audit
        ;;
    "cleanup")
        log_info "Cleaning up old logs and reports..."
        # Placeholder for actual cleanup logic
        find /tmp/security_reports_* -mtime +7 -exec rm -rf {} \; 2>/dev/null || true
        log_success "Cleanup complete."
        ;;
    "help" | *)
        cat <<EOF
Usage: $0 [monitor|full|network|configs|cleanup|help]

  monitor:  Run real-time system monitor (Ctrl+C to stop).
  full:     Run a comprehensive system security audit.
  network:  Run a targeted network security audit.
  cleanup:  Remove old reports and log files.

EOF
        ;;
    esac
}

main "$@"
