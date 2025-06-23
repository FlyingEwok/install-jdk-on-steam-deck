#!/bin/bash

# Dynamic JDK Installer for Steam Deck
# This script automatically discovers available JDK versions from official sources
# and allows installation of any available version without hardcoding

# Logging utils using colors
RED='\033[1;31m'
BLUE='\033[0;34m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

log_info() {
    echo -e "${GREEN}${1}${NC}"
}

log_warning() {
    echo -e "${BLUE}${1}${NC}"
}

log_error() {
    echo -e "${RED}${1}${NC}"
}

log_debug() {
    [[ "${DEBUG:-0}" == "1" ]] && echo -e "${YELLOW}DEBUG: ${1}${NC}"
}

# Installation directory - define early so functions can use it
INSTALLATION_DIR="${HOME}/.local/jdk"

# Track if we're running in interactive mode or using environment variables
INTERACTIVE_MODE=false

# Cache directory for storing version discovery results
CACHE_DIR="${HOME}/.cache/jdk-installer"
CACHE_TIMEOUT=3600  # 1 hour cache timeout

# Global arrays to store discovered JDK information
declare -A JDK_VERSIONS_INFO  # version -> json info
declare -a AVAILABLE_VERSIONS  # sorted array of available versions
declare -A VERSION_SOURCES     # version -> source (adoptium, oracle, openjdk)

# Create cache directory
mkdir -p "${CACHE_DIR}"

# Utility function to check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Check if required tools are available
check_dependencies() {
    local missing_deps=()
    
    if ! command_exists curl && ! command_exists wget; then
        missing_deps+=("curl or wget")
    fi
    
    if ! command_exists jq; then
        missing_deps+=("jq")
    fi
    
    if [[ ${#missing_deps[@]} -gt 0 ]]; then
        log_error "Missing required dependencies: ${missing_deps[*]}"
        log_error "Please install them using your package manager:"
        log_error "  sudo pacman -S curl jq  # or"
        log_error "  sudo pacman -S wget jq"
        exit 1
    fi
}

# Utility function to download content
download_content() {
    local url="$1"
    local output_file="$2"
    local timeout="${3:-30}"
    
    if command_exists curl; then
        curl -L -s --connect-timeout "$timeout" --max-time "$((timeout * 2))" "$url" > "$output_file" 2>/dev/null
    elif command_exists wget; then
        wget -q -T "$timeout" -O "$output_file" "$url" >/dev/null 2>&1
    else
        log_error "Neither curl nor wget available"
        return 1
    fi
}

# Function to get cache file path for a specific discovery method
get_cache_file() {
    local cache_type="$1"
    echo "${CACHE_DIR}/${cache_type}_versions.json"
}

# Check if cache is valid (not older than CACHE_TIMEOUT)
is_cache_valid() {
    local cache_file="$1"
    
    if [[ ! -f "$cache_file" ]]; then
        return 1
    fi
    
    local cache_age=$(( $(date +%s) - $(stat -c %Y "$cache_file" 2>/dev/null || echo 0) ))
    
    if [[ $cache_age -gt $CACHE_TIMEOUT ]]; then
        return 1
    fi
    
    return 0
}

# Discover JDK versions from Eclipse Adoptium (Temurin) - Fully Dynamic
discover_adoptium_versions() {
    local cache_file=$(get_cache_file "adoptium")
    
    if is_cache_valid "$cache_file"; then
        log_debug "Using cached Adoptium versions"
        return 0
    fi
    
    log_info "Discovering ALL JDK versions from Eclipse Adoptium..."
    
    # Adoptium API endpoint for available versions
    local api_url="https://api.adoptium.net/v3/info/available_releases"
    local temp_file=$(mktemp)
    
    if download_content "$api_url" "$temp_file"; then
        if jq -e '.available_releases' "$temp_file" >/dev/null 2>&1; then
            jq -r '.available_releases[]' "$temp_file" | while read -r version; do
                [[ -z "$version" || ! "$version" =~ ^[0-9]+$ ]] && continue
                
                log_debug "Checking Adoptium JDK version: $version"
                
                # Get the actual release information with proper download and checksum URLs
                local assets_api="https://api.adoptium.net/v3/assets/feature_releases/${version}/ga?os=linux&image_type=jdk"
                local assets_temp=$(mktemp)
                
                if download_content "$assets_api" "$assets_temp" && [[ -s "$assets_temp" ]]; then
                    local has_assets=$(jq '. | length' "$assets_temp" 2>/dev/null || echo "0")
                    
                    if [[ "$has_assets" != "0" && "$has_assets" != "null" ]]; then
                        # Extract x64 binary information specifically (not the first binary which might be ARM)
                        local download_url=$(jq -r '.[0].binaries[] | select(.architecture == "x64") | .package.link' "$assets_temp" 2>/dev/null | head -1)
                        local checksum_url=$(jq -r '.[0].binaries[] | select(.architecture == "x64") | .package.checksum_link' "$assets_temp" 2>/dev/null | head -1)
                        
                        if [[ -n "$download_url" && "$download_url" != "null" && "$download_url" != "" ]]; then
                            local version_info=$(jq -n \
                                --arg version "$version" \
                                --arg source "adoptium" \
                                --arg download_url "$download_url" \
                                --arg checksum_url "$checksum_url" \
                                '{
                                    version: $version,
                                    source: $source,
                                    download_url: $download_url,
                                    checksum_url: $checksum_url,
                                    description: ("JDK " + $version + " (Eclipse Temurin)")
                                }')
                            
                            echo "$version_info" | jq -c '.' >> "${cache_file}.tmp"
                            log_debug "Found Adoptium JDK $version"
                        fi
                    fi
                fi
                
                rm -f "$assets_temp"
            done
            
            # Finalize cache file
            if [[ -f "${cache_file}.tmp" ]]; then
                mv "${cache_file}.tmp" "$cache_file"
                log_debug "Cached Adoptium versions to $cache_file"
            fi
        fi
    fi
    
    rm -f "$temp_file"
}

# Simple Oracle discovery (just try current LTS versions)
discover_oracle_versions() {
    local cache_file=$(get_cache_file "oracle")
    
    if is_cache_valid "$cache_file"; then
        log_debug "Using cached Oracle versions"
        return 0
    fi
    
    log_info "Discovering JDK versions from Oracle..."
    
    # Try known LTS and recent versions
    local oracle_versions=(8 11 17 21 22 23)
    
    for version in "${oracle_versions[@]}"; do
        local download_url="https://download.oracle.com/java/${version}/latest/jdk-${version}_linux-x64_bin.tar.gz"
        
        if command_exists curl; then
            local http_code=$(curl -s -L -I -w '%{http_code}' -o /dev/null "$download_url" 2>/dev/null)
            if [[ "$http_code" == "200" ]]; then
                local version_info=$(jq -n \
                    --arg version "$version" \
                    --arg source "oracle" \
                    --arg download_url "$download_url" \
                    --arg checksum_url "${download_url}.sha256" \
                    '{
                        version: $version,
                        source: $source,
                        download_url: $download_url,
                        checksum_url: $checksum_url,
                        description: ("JDK " + $version + " (Oracle)")
                    }')
                
                echo "$version_info" | jq -c '.' >> "${cache_file}.tmp"
                log_debug "Found Oracle JDK $version"
            fi
        fi
    done
    
    # Finalize cache file
    if [[ -f "${cache_file}.tmp" ]]; then
        mv "${cache_file}.tmp" "$cache_file"
        log_debug "Cached Oracle versions to $cache_file"
    fi
}

# OpenJDK discovery (try known versions)
discover_openjdk_versions() {
    local cache_file=$(get_cache_file "openjdk")
    
    if is_cache_valid "$cache_file"; then
        log_debug "Using cached OpenJDK versions"
        return 0
    fi
    
    log_info "Discovering JDK versions from OpenJDK..."
    
    # Try versions 11 through 25
    for version in {11..25}; do
        local download_url="https://download.java.net/java/GA/jdk${version}/jdk-${version}_linux-x64_bin.tar.gz"
        
        if command_exists curl; then
            local http_code=$(curl -s -L -I -w '%{http_code}' -o /dev/null "$download_url" 2>/dev/null)
            if [[ "$http_code" == "200" ]]; then
                local version_info=$(jq -n \
                    --arg version "$version" \
                    --arg source "openjdk" \
                    --arg download_url "$download_url" \
                    --arg checksum_url "${download_url}.sha256" \
                    '{
                        version: $version,
                        source: $source,
                        download_url: $download_url,
                        checksum_url: $checksum_url,
                        description: ("JDK " + $version + " (OpenJDK)")
                    }')
                
                echo "$version_info" | jq -c '.' >> "${cache_file}.tmp"
                log_debug "Found OpenJDK $version"
            fi
        fi
    done
    
    # Finalize cache file
    if [[ -f "${cache_file}.tmp" ]]; then
        mv "${cache_file}.tmp" "$cache_file"
        log_debug "Cached OpenJDK versions to $cache_file"
    fi
}

# Aggregate all discovered versions and populate global arrays
aggregate_discovered_versions() {
    log_info "Aggregating discovered JDK versions from all sources..."
    
    # Clear global arrays
    AVAILABLE_VERSIONS=()
    unset JDK_VERSIONS_INFO
    unset VERSION_SOURCES
    declare -g -A JDK_VERSIONS_INFO
    declare -g -A VERSION_SOURCES
    
    # Process each cache file
    for cache_file in "${CACHE_DIR}"/*_versions.json; do
        if [[ -f "$cache_file" && -s "$cache_file" ]]; then
            log_debug "Processing cache file: $cache_file"
            
            # Use jq to parse each JSON object separately
            # The cache files contain multiple JSON objects (one per line in compact format or multi-line)
            # We need to split them properly
            local temp_file=$(mktemp)
            
            # Convert multi-line JSON objects to single-line format
            jq -c '.' "$cache_file" 2>/dev/null > "$temp_file" || {
                # If that fails, try reading as line-delimited JSON
                while IFS= read -r line; do
                    if [[ -n "$line" && "$line" =~ ^\{ ]]; then
                        echo "$line" | jq -c '.' 2>/dev/null || continue
                    fi
                done < "$cache_file" > "$temp_file"
            }
            
            # Process each JSON object
            while IFS= read -r json_line; do
                if [[ -n "$json_line" ]]; then
                    local version=$(echo "$json_line" | jq -r '.version' 2>/dev/null)
                    local source=$(echo "$json_line" | jq -r '.source' 2>/dev/null)
                    
                    if [[ "$version" != "null" && "$source" != "null" && "$version" =~ ^[0-9]+$ ]]; then
                        # If version already exists, prefer Adoptium over other sources
                        if [[ -n "${JDK_VERSIONS_INFO[$version]:-}" ]]; then
                            local existing_source="${VERSION_SOURCES[$version]}"
                            # Prefer adoptium over oracle, and oracle over openjdk
                            if [[ "$source" == "adoptium" || ("$source" == "oracle" && "$existing_source" == "openjdk") ]]; then
                                JDK_VERSIONS_INFO["$version"]="$json_line"
                                VERSION_SOURCES["$version"]="$source"
                                log_debug "Updated JDK version $version to use $source (was $existing_source)"
                            else
                                log_debug "Keeping existing JDK version $version from $existing_source (skipping $source)"
                            fi
                        else
                            # Store version info for new version
                            JDK_VERSIONS_INFO["$version"]="$json_line"
                            VERSION_SOURCES["$version"]="$source"
                            log_debug "Added JDK version $version from $source"
                        fi
                        
                        # Add to available versions if not already present
                        if [[ ! " ${AVAILABLE_VERSIONS[*]} " =~ " ${version} " ]]; then
                            AVAILABLE_VERSIONS+=("$version")
                        fi
                    fi
                fi
            done < "$temp_file"
            
            rm -f "$temp_file"
        fi
    done
    
    # Sort available versions numerically
    if [[ ${#AVAILABLE_VERSIONS[@]} -gt 0 ]]; then
        IFS=$'\n' AVAILABLE_VERSIONS=($(sort -n <<<"${AVAILABLE_VERSIONS[*]}"))
        unset IFS
    fi
    
    log_debug "Found ${#AVAILABLE_VERSIONS[@]} unique JDK versions: ${AVAILABLE_VERSIONS[*]}"
}

# Main function to discover all available JDK versions
discover_all_jdk_versions() {
    log_info "Discovering available JDK versions from multiple sources..."
    
    # Run discovery for each source
    discover_adoptium_versions
    discover_oracle_versions
    discover_openjdk_versions
    
    # Aggregate results
    aggregate_discovered_versions
    
    if [[ ${#AVAILABLE_VERSIONS[@]} -eq 0 ]]; then
        log_error "No JDK versions discovered. Check your internet connection or try clearing cache with --reset-cache"
        exit 1
    fi
    
    log_info "Successfully discovered ${#AVAILABLE_VERSIONS[@]} JDK versions from multiple sources"
}

# Function to get version info as JSON
get_version_info() {
    local version="$1"
    echo "${JDK_VERSIONS_INFO[$version]}"
}

# Function to extract specific field from version info
get_version_field() {
    local version="$1"
    local field="$2"
    local version_info="${JDK_VERSIONS_INFO[$version]}"
    
    if [[ -n "$version_info" ]]; then
        echo "$version_info" | jq -r ".$field"
    fi
}

# Interactive JDK version selection
select_jdk_version_interactive() {
    echo ""
    log_info "=== Dynamic JDK Installer for Steam Deck ==="
    echo ""
    
    # Check for already installed JDKs
    local installed_versions=($(detect_installed_jdks))
    if [[ ${#installed_versions[@]} -gt 0 ]]; then
        log_info "Already installed JDK versions: ${installed_versions[*]}"
        echo ""
    fi
    
    local uninstalled_versions=($(get_uninstalled_versions))
    
    if [[ ${#uninstalled_versions[@]} -eq 0 ]]; then
        log_info "All ${#AVAILABLE_VERSIONS[@]} available JDK versions are already installed!"
        echo ""
        log_info "Proceeding directly to change default Java version..."
        echo ""
        change_default_java_version
        exit 0
    fi
    
    log_info "Please select which JDK version you would like to install:"
    echo ""
    
    local option_counter=1
    local version_map=()
    
    # Show available uninstalled versions
    for version in "${uninstalled_versions[@]}"; do
        local description=$(get_version_field "$version" "description")
        echo "  ${option_counter}) $description"
        version_map[${option_counter}]="$version"
        ((option_counter++))
    done
    
    # Add "Install All" option if there are multiple uninstalled versions
    if [[ ${#uninstalled_versions[@]} -gt 1 ]]; then
        echo "  ${option_counter}) Install All Remaining JDK Versions (${uninstalled_versions[*]})"
        version_map[${option_counter}]="INSTALL_ALL"
        ((option_counter++))
    fi
    
    # Add "Skip and change default" option only if at least one JDK is already installed
    if [[ ${#installed_versions[@]} -gt 0 ]]; then
        echo "  ${option_counter}) Skip installation and change default Java version"
        version_map[${option_counter}]="CHANGE_DEFAULT"
        ((option_counter++))
    fi
    
    echo ""
    local max_option=$((option_counter - 1))
    local latest_available_version="${AVAILABLE_VERSIONS[-1]}"  # Latest version from all available
    local default_choice=1
    
    # Find the position of the latest available version for default (prefer latest over uninstalled order)
    for i in "${!version_map[@]}"; do
        if [[ "${version_map[$i]}" == "$latest_available_version" ]]; then
            default_choice=$i
            break
        fi
    done
    
    # If the latest version is already installed, recommend "Install All" or "Change Default"
    if [[ " ${installed_versions[*]} " =~ " ${latest_available_version} " ]]; then
        # Latest is installed, recommend Install All if available, otherwise Change Default (if available)
        for i in "${!version_map[@]}"; do
            if [[ "${version_map[$i]}" == "INSTALL_ALL" ]]; then
                default_choice=$i
                break
            elif [[ "${version_map[$i]}" == "CHANGE_DEFAULT" ]]; then
                default_choice=$i
                break
            fi
        done
    fi
    
    # Create the appropriate prompt message
    local prompt_msg
    if [[ " ${installed_versions[*]} " =~ " ${latest_available_version} " ]]; then
        if [[ "${version_map[$default_choice]}" == "INSTALL_ALL" ]]; then
            prompt_msg="Enter your choice (1-${max_option}) [default: ${default_choice} to install all remaining versions]: "
        elif [[ "${version_map[$default_choice]}" == "CHANGE_DEFAULT" ]]; then
            prompt_msg="Enter your choice (1-${max_option}) [default: ${default_choice} to change default Java version]: "
        else
            # Fallback if neither INSTALL_ALL nor CHANGE_DEFAULT are available
            prompt_msg="Enter your choice (1-${max_option}) [default: ${default_choice}]: "
        fi
    else
        prompt_msg="Enter your choice (1-${max_option}) [default: ${default_choice} for JDK ${latest_available_version} - RECOMMENDED]: "
    fi
    
    while true; do
        read -p "$prompt_msg" choice
        
        # If user just presses Enter, use default choice
        if [[ -z "$choice" ]]; then
            choice=$default_choice
        fi
        
        if [[ "$choice" =~ ^[0-9]+$ ]] && [[ "$choice" -ge 1 ]] && [[ "$choice" -le $max_option ]]; then
            local selected_option="${version_map[$choice]}"
            
            if [[ "$selected_option" == "INSTALL_ALL" ]]; then
                install_all_remaining_jdks
                exit 0
            elif [[ "$selected_option" == "CHANGE_DEFAULT" ]]; then
                change_default_java_version
                exit 0
            else
                JDK_VERSION="$selected_option"
                local description=$(get_version_field "$selected_option" "description")
                log_info "Selected $description"
                break
            fi
        else
            echo "Invalid choice. Please enter a number between 1 and ${max_option}."
        fi
    done
}

# Determine JDK version
determine_jdk_version() {
    if [[ -z "$JDK_VERSION" ]]; then
        INTERACTIVE_MODE=true
        select_jdk_version_interactive
    else
        INTERACTIVE_MODE=false
        log_info "Using JDK version ${JDK_VERSION} specified via environment variable"
        
        if [[ ! " ${AVAILABLE_VERSIONS[*]} " =~ " ${JDK_VERSION} " ]]; then
            log_error "Invalid JDK_VERSION specified: ${JDK_VERSION}"
            log_error "Available versions are: ${AVAILABLE_VERSIONS[*]}"
            exit 1
        fi
    fi
}

# Install JDK
install_jdk() {
    # Get version information
    local version_info="${JDK_VERSIONS_INFO[$JDK_VERSION]}"
    if [[ -z "$version_info" ]]; then
        log_error "No information available for JDK version $JDK_VERSION"
        exit 1
    fi
    
    local download_url=$(echo "$version_info" | jq -r '.download_url')
    local checksum_url=$(echo "$version_info" | jq -r '.checksum_url')
    local source=$(echo "$version_info" | jq -r '.source')
    
    # Use a simple, short filename to avoid "filename too long" errors
    local file_name="jdk-${JDK_VERSION}-${source}.tar.gz"
    local checksum_file_name="jdk-${JDK_VERSION}-${source}.sha256"
    
    # Store the original directory
    local original_dir="$(pwd)"
    
    mkdir -p "${INSTALLATION_DIR}" || { 
        log_error "Couldn't create the installation directory"
        exit 1
    }
    
    cd "${INSTALLATION_DIR}" || { 
        log_error "Couldn't 'cd' into the installation directory"
        exit 1
    }

    # Download JDK
    log_info "Downloading JDK ${JDK_VERSION} from ${source}..."
    if ! wget -O "${file_name}" "${download_url}" --show-progress; then
        log_error "Couldn't download JDK ${JDK_VERSION} release"
        exit 1
    fi

    # Download checksum if available
    local checksum_ok=true
    if [[ -n "$checksum_url" && "$checksum_url" != "null" ]]; then
        # For Adoptium, the checksum file has .sha256.txt extension, for others .sha256
        local checksum_file_name
        if [[ "$source" == "adoptium" ]]; then
            checksum_file_name="${file_name}.sha256.txt"
        else
            checksum_file_name="${file_name}.sha256"
        fi
        
        if wget -O "$checksum_file_name" "$checksum_url" --show-progress 2>/dev/null; then
            # Fix the checksum file to use our simplified filename instead of the original
            # The checksum files contain the original filename, but we use simplified names
            local original_filename=$(awk '{print $2}' "$checksum_file_name")
            
            if [[ -n "$original_filename" ]]; then
                # Checksum file has filename (Adoptium format)
                # Replace the original filename with our simplified filename in the checksum file
                sed -i "s|${original_filename}|${file_name}|g" "$checksum_file_name"
                log_debug "Updated checksum file to use simplified filename: $file_name"
            else
                # Checksum file contains only hash (Oracle format)
                # Add our filename to make it compatible with sha256sum -c
                local hash_only=$(cat "$checksum_file_name" | tr -d '\n')
                echo "${hash_only}  ${file_name}" > "$checksum_file_name"
                log_debug "Added filename to hash-only checksum file: $file_name"
            fi
            
            # Verify checksum
            if sha256sum -c "$checksum_file_name" >/dev/null 2>&1; then
                log_info "✓ Checksum verified successfully"
            else
                log_warning "⚠ Checksum verification failed for JDK ${JDK_VERSION}, but continuing with installation..."
                checksum_ok=false
            fi
        else
            log_warning "Could not download checksum for JDK ${JDK_VERSION}, proceeding without verification"
        fi
    else
        log_warning "Checksum not available for JDK ${JDK_VERSION}, proceeding without verification"
    fi

    # Extract JDK
    log_info "Extracting JDK ${JDK_VERSION}..."
    # Use tar with --strip-components to avoid long path issues and extract to a simple directory name
    local extract_dir="jdk-${JDK_VERSION}"
    mkdir -p "$extract_dir" || {
        log_error "Could not create extraction directory"
        exit 1
    }
    
    if ! tar --strip-components=1 -xf "${file_name}" -C "$extract_dir"; then
        log_error "Couldn't decompress the JDK file"
        exit 1
    fi

    # The extracted directory name is what we created
    local JDK_EXTRACTED_DIR="$extract_dir"
    
    # Verify the extraction worked and we have a java executable
    if [[ ! -x "${JDK_EXTRACTED_DIR}/bin/java" ]]; then
        log_error "JDK extraction failed - no java executable found in ${JDK_EXTRACTED_DIR}/bin/"
        exit 1
    fi
    
    # Clean up
    rm -f "${file_name}" "${file_name}.sha256" "${file_name}.sha256.txt"
    
    # Return to original directory
    cd "$original_dir" || {
        log_warning "Could not return to original directory: $original_dir"
        # Don't exit, just continue
    }
    
    log_info "✓ JDK ${JDK_VERSION} extraction completed successfully"
    return 0  # Success
}

# Show help information
show_help() {
    cat << EOF
Dynamic JDK Installer for Steam Deck

USAGE:
    $0 [OPTIONS]

OPTIONS:
    -h, --help          Show this help message
    -l, --list          List all available JDK versions and exit
    --reset-cache       Clear discovery cache and exit
    --debug             Enable debug output
    --version=VERSION   Install specific version (bypasses interactive mode)

ENVIRONMENT VARIABLES:
    JDK_VERSION         JDK version to install (same as --version)
    DEBUG               Enable debug output (1 = enabled)

EXAMPLES:
    $0                          # Interactive mode
    $0 --list                   # List all available versions
    $0 --version=21            # Install JDK 21
    JDK_VERSION=17 $0          # Install JDK 17 via environment variable

This script discovers JDK versions dynamically from official sources:
- Eclipse Adoptium (Temurin)
- Oracle JDK
- OpenJDK

EOF
}

# Clean up old cache files and reset discovery
reset_discovery_cache() {
    log_info "Clearing JDK discovery cache..."
    rm -rf "${CACHE_DIR}"/*_versions.json 2>/dev/null || true
    log_info "Cache cleared. Next run will rediscover all JDK versions."
}

# Function to detect already installed JDK versions
detect_installed_jdks() {
    local installed_versions=()
    
    if [[ -d "${INSTALLATION_DIR}" ]]; then
        for dir in "${INSTALLATION_DIR}"/jdk-*; do
            if [[ -d "$dir" && -x "$dir/bin/java" ]]; then
                local dir_name=$(basename "$dir")
                local version=$(echo "$dir_name" | sed 's/jdk-//')
                if [[ "$version" =~ ^[0-9]+$ ]]; then
                    installed_versions+=("$version")
                fi
            fi
        done
    fi
    
    # Sort versions numerically
    if [[ ${#installed_versions[@]} -gt 0 ]]; then
        IFS=$'\n' installed_versions=($(sort -n <<<"${installed_versions[*]}"))
        unset IFS
    fi
    
    echo "${installed_versions[@]}"
}

# Function to get versions that are not yet installed
get_uninstalled_versions() {
    local installed_versions=($(detect_installed_jdks))
    local uninstalled_versions=()
    
    for version in "${AVAILABLE_VERSIONS[@]}"; do
        if [[ ! " ${installed_versions[*]} " =~ " ${version} " ]]; then
            uninstalled_versions+=("$version")
        fi
    done
    
    echo "${uninstalled_versions[@]}"
}

# Function to install all remaining JDK versions
install_all_remaining_jdks() {
    local uninstalled_versions=($(get_uninstalled_versions))
    
    if [[ ${#uninstalled_versions[@]} -eq 0 ]]; then
        log_info "All available JDK versions are already installed!"
        return 0
    fi
    
    log_info "Installing ${#uninstalled_versions[@]} remaining JDK versions: ${uninstalled_versions[*]}"
    echo ""
    
    local successful_installs=0
    for version in "${uninstalled_versions[@]}"; do
        log_info "Installing JDK ${version}..."
        JDK_VERSION="$version"
        
        if install_jdk; then
            local jdk_dir="jdk-${version}"
            if [[ -x "${INSTALLATION_DIR}/${jdk_dir}/bin/java" ]]; then
                log_info "✓ JDK ${version} installed successfully"
                ((successful_installs++))
            else
                log_error "✗ JDK ${version} installation failed"
            fi
        else
            log_error "✗ JDK ${version} installation failed"
        fi
        echo ""
    done
    
    log_info "Batch installation completed! (${successful_installs}/${#uninstalled_versions[@]} successful)"
    
    # Automatically set the latest JDK as default
    if [[ $successful_installs -gt 0 ]]; then
        echo ""
        set_latest_jdk_as_default
        
        # In interactive mode, offer to change default 
        if [[ "$INTERACTIVE_MODE" == "true" ]]; then
            local installed_versions=($(detect_installed_jdks))
            if [[ ${#installed_versions[@]} -gt 1 ]]; then
                echo ""
                log_info "You now have ${#installed_versions[@]} JDK versions installed: ${installed_versions[*]}"
                echo ""
                
                while true; do
                    read -p "Would you like to change the default Java version? (y/N): " change_default
                    case $change_default in
                        [Yy]* ) 
                            echo ""
                            change_default_java_version
                            break
                            ;;
                        [Nn]* | "" ) 
                            local latest_version="${installed_versions[-1]}"
                            log_info "Keeping JDK ${latest_version} as the default"
                            break
                            ;;
                        * ) 
                            echo "Please answer yes (y) or no (n)."
                            ;;
                    esac
                done
            fi
        fi
    fi
}

# Function to change default Java version
change_default_java_version() {
    local installed_versions=($(detect_installed_jdks))
    
    if [[ ${#installed_versions[@]} -eq 0 ]]; then
        log_error "No JDK versions are installed yet. Please install a JDK first."
        return 1
    fi
    
    echo ""
    log_info "=== Change Default Java Version ==="
    echo ""
    log_info "Installed JDK versions:"
    
    local option_counter=1
    local version_map=()
    
    for version in "${installed_versions[@]}"; do
        local jdk_path="${INSTALLATION_DIR}/jdk-${version}"
        if [[ -x "${jdk_path}/bin/java" ]]; then
            local java_version=$("${jdk_path}/bin/java" -version 2>&1 | head -1)
            echo "  ${option_counter}) JDK ${version} - ${java_version}"
            version_map[${option_counter}]="$version"
            ((option_counter++))
        fi
    done
    
    echo ""
    local max_option=$((option_counter - 1))
    local latest_installed_version="${installed_versions[-1]}"  # Latest (highest numbered) installed version
    local default_choice=$max_option  # Default to the last option (latest version)
    
    while true; do
        read -p "Select which JDK to set as default (1-${max_option}) [default: ${default_choice} for JDK ${latest_installed_version} - RECOMMENDED]: " choice
        
        # If user just presses Enter, use the latest version
        if [[ -z "$choice" ]]; then
            choice=$default_choice
        fi
        
        if [[ "$choice" =~ ^[0-9]+$ ]] && [[ "$choice" -ge 1 ]] && [[ "$choice" -le $max_option ]]; then
            local selected_version="${version_map[$choice]}"
            local selected_home="JAVA_${selected_version}_HOME"
            
            # Ensure all JDKs are set up in profile first
            setup_profile_for_all_jdks
            
            # Update JAVA_HOME in profile
            if grep "export JAVA_HOME=" ~/.profile > /dev/null 2>&1; then
                sed -i "s|^export JAVA_HOME=.*|export JAVA_HOME=\$${selected_home}|" ~/.profile
            else
                echo "" >> ~/.profile
                echo "export JAVA_HOME=\$${selected_home}" >> ~/.profile
            fi
            
            # Ensure .profile is sourced in .bashrc
            if ! grep "source ~/.profile" ~/.bashrc > /dev/null 2>&1 && ! grep "\[\[ -f ~/.profile \]\] && source ~/.profile" ~/.bashrc > /dev/null 2>&1; then
                echo "[[ -f ~/.profile ]] && source ~/.profile" >> ~/.bashrc
            fi
            
            echo ""
            if [[ "$selected_version" == "$latest_installed_version" ]]; then
                log_info "✓ Set JDK ${selected_version} as the default Java version (latest version)"
            else
                log_info "✓ Set JDK ${selected_version} as the default Java version"
            fi
            log_info "  Updated ~/.profile with all installed JDK versions"
            log_info "  For new terminals, restart your shell or run: source ~/.profile"
            echo ""
            log_info "For current session, run:"
            echo "source ~/.profile"
            break
        else
            echo "Invalid choice. Please enter a number between 1 and ${max_option}."
        fi
    done
}

# Function to automatically set the latest JDK as default
set_latest_jdk_as_default() {
    local installed_versions=($(detect_installed_jdks))
    
    if [[ ${#installed_versions[@]} -eq 0 ]]; then
        log_debug "No JDK versions installed, cannot set default"
        return 1
    fi
    
    # Get the latest (highest numbered) version
    local latest_version="${installed_versions[-1]}"
    local jdk_path="${INSTALLATION_DIR}/jdk-${latest_version}"
    
    if [[ -x "${jdk_path}/bin/java" ]]; then
        log_info "Setting JDK ${latest_version} as the default Java version..."
        
        # Clean up and rebuild ~/.profile like the original script
        setup_profile_for_all_jdks
        
        # Set the latest version as default in profile
        local selected_home="JAVA_${latest_version}_HOME"
        
        # Update JAVA_HOME in profile
        if grep "export JAVA_HOME=" ~/.profile > /dev/null 2>&1; then
            sed -i "s|^export JAVA_HOME=.*|export JAVA_HOME=\$${selected_home}|" ~/.profile
        else
            echo "" >> ~/.profile
            echo "export JAVA_HOME=\$${selected_home}" >> ~/.profile
        fi
        
        # Ensure .profile is sourced in .bashrc
        if ! grep "source ~/.profile" ~/.bashrc > /dev/null 2>&1 && ! grep "\[\[ -f ~/.profile \]\] && source ~/.profile" ~/.bashrc > /dev/null 2>&1; then
            echo "[[ -f ~/.profile ]] && source ~/.profile" >> ~/.bashrc
        fi
        
        # Set for current session
        export JAVA_HOME="$jdk_path"
        export PATH="${JAVA_HOME}/bin:$PATH"
        
        log_info "✓ JDK ${latest_version} set as default Java version"
        log_info "  Updated ~/.profile with all installed JDK versions"
        log_info "  For new terminals, restart your shell or run: source ~/.profile"
        
        # Show current Java version
        if command -v java >/dev/null 2>&1; then
            local current_java_version=$(java -version 2>&1 | head -1)
            log_info "  Current Java version: $current_java_version"
        fi
        
        return 0
    else
        log_error "JDK ${latest_version} installation appears to be corrupted"
        return 1
    fi
}

# Function to setup ~/.profile with all installed JDKs (like original script)
setup_profile_for_all_jdks() {
    # Backup original .profile if it exists and contains non-JDK content
    if [[ -f ~/.profile ]]; then
        # Extract non-JDK lines to preserve user's custom settings
        # More comprehensive pattern to catch all JDK-related lines
        grep -v -E "# ={5,}|# JDK.*installation|# JDK Installations managed by|export JAVA_.*_HOME|export JAVA_HOME|export PATH.*jdk.*bin|# To change the default Java version|^$" ~/.profile | \
        awk 'BEGIN{blank=0} /^$/{blank++; if(blank<=1) print; next} {blank=0; print}' > ~/.profile.backup.tmp 2>/dev/null || true
    else
        touch ~/.profile.backup.tmp
    fi
    
    # Start fresh .profile with preserved content
    cp ~/.profile.backup.tmp ~/.profile
    
    # Add header for JDK section
    echo "" >> ~/.profile
    echo "# ========================================" >> ~/.profile
    echo "# JDK Installations managed by install-jdk-on-steam-deck" >> ~/.profile
    echo "# ========================================" >> ~/.profile
    
    # Scan for all installed JDK versions and add them to .profile
    if [[ -d "${INSTALLATION_DIR}" ]]; then
        for jdk_dir in "${INSTALLATION_DIR}"/jdk-*; do
            if [[ -d "$jdk_dir" && -x "${jdk_dir}/bin/java" ]]; then
                # Get the version from the directory name
                local dir_name=$(basename "$jdk_dir")
                local version=$(echo "$dir_name" | sed 's/jdk-//')
                
                if [[ "$version" =~ ^[0-9]+$ ]]; then
                    echo "" >> ~/.profile
                    echo "# JDK ${version} installation" >> ~/.profile
                    echo "export JAVA_${version}_HOME=${jdk_dir}" >> ~/.profile
                    echo "export PATH=\$PATH:${jdk_dir}/bin" >> ~/.profile
                fi
            fi
        done
    fi
    
    # Add footer and instructions
    echo "" >> ~/.profile
    echo "# To change the default Java version, update the JAVA_HOME line below or re-run this installer" >> ~/.profile
    echo "# ========================================" >> ~/.profile
    
    # Clean up temporary file
    rm -f ~/.profile.backup.tmp
}

#### MAIN ####

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --help|-h)
            show_help
            exit 0
            ;;
        --list|-l)
            LIST_ONLY=true
            shift
            ;;
        --reset-cache)
            reset_discovery_cache
            exit 0
            ;;
        --debug)
            DEBUG=1
            shift
            ;;
        --version=*)
            JDK_VERSION="${1#*=}"
            shift
            ;;
        *)
            log_error "Unknown option: $1"
            show_help
            exit 1
            ;;
    esac
done

# Check dependencies first
check_dependencies

# Discover all available JDK versions
discover_all_jdk_versions

# List only mode - show all versions and exit
if [[ "${LIST_ONLY:-false}" == "true" ]]; then
    echo ""
    log_info "All Available JDK Versions:"
    echo ""
    for version in "${AVAILABLE_VERSIONS[@]}"; do
        description=$(get_version_field "$version" "description")
        echo "  JDK $version - $description"
    done
    echo ""
    log_info "Total: ${#AVAILABLE_VERSIONS[@]} versions from multiple sources"
    echo ""
    log_info "Use '$0 --version=VERSION' to install a specific version"
    exit 0
fi

# Determine which version to install
determine_jdk_version

# Install the selected JDK
log_info "Installing JDK ${JDK_VERSION}..."

# Call install_jdk and check if it succeeds
if install_jdk; then
    # Construct the expected directory name
    JDK_EXTRACTED_DIR="jdk-${JDK_VERSION}"
    log_info "JDK downloaded and extracted into ${INSTALLATION_DIR}"
else
    log_error "JDK installation failed"
    exit 1
fi

# Test the installation
log_info "Verifying JDK installation..."
log_debug "Testing path: ${INSTALLATION_DIR}/${JDK_EXTRACTED_DIR}/bin/java"

# Check each condition separately for better debugging
if [[ ! -f "${INSTALLATION_DIR}/${JDK_EXTRACTED_DIR}/bin/java" ]]; then
    log_error "✗ JDK installation failed - Java executable not found"
    log_error "Expected location: ${INSTALLATION_DIR}/${JDK_EXTRACTED_DIR}/bin/java"
    exit 1
elif [[ ! -x "${INSTALLATION_DIR}/${JDK_EXTRACTED_DIR}/bin/java" ]]; then
    log_error "✗ JDK installation failed - Java executable is not executable"
    log_error "Location: ${INSTALLATION_DIR}/${JDK_EXTRACTED_DIR}/bin/java"
    exit 1
fi

# Test if Java actually runs
log_debug "Testing Java execution..."
if "${INSTALLATION_DIR}/${JDK_EXTRACTED_DIR}/bin/java" -version >/dev/null 2>&1; then
    log_info "✓ JDK ${JDK_VERSION} installation completed successfully!"
    echo ""
    log_info "JDK ${JDK_VERSION} is now available at: ${INSTALLATION_DIR}/${JDK_EXTRACTED_DIR}/"
    log_info "Java executable: ${INSTALLATION_DIR}/${JDK_EXTRACTED_DIR}/bin/java"
    echo ""
    
    # Automatically set this JDK as the default (it will be the latest after installation)
    set_latest_jdk_as_default
    echo ""
    
    # In interactive mode, offer to change default if multiple JDKs are installed
    if [[ "$INTERACTIVE_MODE" == "true" ]]; then
        installed_versions=($(detect_installed_jdks))
        if [[ ${#installed_versions[@]} -gt 1 ]]; then
            echo ""
            log_info "You now have ${#installed_versions[@]} JDK versions installed: ${installed_versions[*]}"
            echo ""
            
            while true; do
                read -p "Would you like to change the default Java version? (y/N): " change_default
                case $change_default in
                    [Yy]* ) 
                        echo ""
                        change_default_java_version
                        break
                        ;;
                    [Nn]* | "" ) 
                        log_info "Keeping JDK ${JDK_VERSION} as the default"
                        break
                        ;;
                    * ) 
                        echo "Please answer yes (y) or no (n)."
                        ;;
                esac
            done
        fi
    fi
    
    echo ""
    log_info "To manually configure this JDK, you can also use:"
    log_info "  • Add to PATH: export PATH=\"${INSTALLATION_DIR}/${JDK_EXTRACTED_DIR}/bin:\$PATH\""
    log_info "  • Set JAVA_HOME: export JAVA_HOME=\"${INSTALLATION_DIR}/${JDK_EXTRACTED_DIR}\""
else
    log_error "✗ JDK installation failed - Java executable found but cannot run properly"
    log_error "Location: ${INSTALLATION_DIR}/${JDK_EXTRACTED_DIR}/bin/java"
    log_error "Try running manually to see the error: ${INSTALLATION_DIR}/${JDK_EXTRACTED_DIR}/bin/java -version"
    exit 1
fi

log_info "Dynamic JDK installation completed!"
