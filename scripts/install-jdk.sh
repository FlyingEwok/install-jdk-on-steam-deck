#!/bin/bash

# Condensed JDK Installer for Steam Deck - Maintains dynamic discovery
# Supports all JDK versions from Adoptium, Oracle, and OpenJDK

# Colors and logging
RED='\033[1;31m'; BLUE='\033[0;34m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; NC='\033[0m'
log_info() { echo -e "${GREEN}${1}${NC}"; }
log_warning() { echo -e "${BLUE}${1}${NC}"; }
log_error() { echo -e "${RED}${1}${NC}"; }
log_debug() { [[ "${DEBUG:-0}" == "1" ]] && echo -e "${YELLOW}DEBUG: ${1}${NC}"; }

# Configuration
INSTALLATION_DIR="${HOME}/.local/jdk"
CACHE_DIR="${HOME}/.cache/jdk-installer"
CACHE_TIMEOUT=3600
INTERACTIVE_MODE=false

# Global arrays for discovered JDK information
declare -A JDK_VERSIONS_INFO
declare -a AVAILABLE_VERSIONS
declare -A VERSION_SOURCES

mkdir -p "${CACHE_DIR}"

# Utilities
command_exists() { command -v "$1" >/dev/null 2>&1; }

check_dependencies() {
    local missing=()
    command_exists curl || command_exists wget || missing+=("curl or wget")
    command_exists jq || missing+=("jq")
    if [[ ${#missing[@]} -gt 0 ]]; then
        log_error "Missing dependencies: ${missing[*]}"
        log_error "Install with: sudo pacman -S curl jq"
        exit 1
    fi
}

download_content() {
    local url="$1" output_file="$2" timeout="${3:-30}"
    if command_exists curl; then
        curl -L -s --connect-timeout "$timeout" --max-time "$((timeout * 2))" "$url" > "$output_file" 2>/dev/null
    elif command_exists wget; then
        wget -q -T "$timeout" -O "$output_file" "$url" >/dev/null 2>&1
    else
        log_error "Neither curl nor wget available"; return 1
    fi
}

get_cache_file() { echo "${CACHE_DIR}/${1}_versions.json"; }

is_cache_valid() {
    local cache_file="$1"
    [[ -f "$cache_file" ]] && [[ $(( $(date +%s) - $(stat -c %Y "$cache_file" 2>/dev/null || echo 0) )) -lt $CACHE_TIMEOUT ]]
}

# Discovery functions (condensed but keeping working logic)
discover_adoptium_versions() {
    local cache_file=$(get_cache_file "adoptium")
    is_cache_valid "$cache_file" && { log_debug "Using cached Adoptium versions"; return 0; }
    
    log_info "Discovering JDK versions from Eclipse Adoptium..."
    local temp_file=$(mktemp)
    
    if download_content "https://api.adoptium.net/v3/info/available_releases" "$temp_file"; then
        if jq -e '.available_releases' "$temp_file" >/dev/null 2>&1; then
            jq -r '.available_releases[]' "$temp_file" | while read -r version; do
                [[ -z "$version" || ! "$version" =~ ^[0-9]+$ ]] && continue
                log_debug "Checking Adoptium JDK version: $version"
                
                local assets_temp=$(mktemp)
                if download_content "https://api.adoptium.net/v3/assets/feature_releases/${version}/ga?os=linux&image_type=jdk" "$assets_temp" && [[ -s "$assets_temp" ]]; then
                    local has_assets=$(jq '. | length' "$assets_temp" 2>/dev/null || echo "0")
                    
                    if [[ "$has_assets" != "0" && "$has_assets" != "null" ]]; then
                        local download_url=$(jq -r '.[0].binaries[] | select(.architecture == "x64") | .package.link' "$assets_temp" 2>/dev/null | head -1)
                        local checksum_url=$(jq -r '.[0].binaries[] | select(.architecture == "x64") | .package.checksum_link' "$assets_temp" 2>/dev/null | head -1)
                        
                        if [[ -n "$download_url" && "$download_url" != "null" && "$download_url" != "" ]]; then
                            jq -n \
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
                                }' | jq -c '.' >> "${cache_file}.tmp"
                            log_debug "Found Adoptium JDK $version"
                        fi
                    fi
                fi
                rm -f "$assets_temp"
            done
            [[ -f "${cache_file}.tmp" ]] && mv "${cache_file}.tmp" "$cache_file"
        fi
    fi
    rm -f "$temp_file"
}

discover_oracle_versions() {
    local cache_file=$(get_cache_file "oracle")
    is_cache_valid "$cache_file" && { log_debug "Using cached Oracle versions"; return 0; }
    
    log_info "Discovering JDK versions from Oracle..."
    for version in 8 11 17 21 22 23; do
        local download_url="https://download.oracle.com/java/${version}/latest/jdk-${version}_linux-x64_bin.tar.gz"
        if command_exists curl; then
            local http_code=$(curl -s -L -I -w '%{http_code}' -o /dev/null "$download_url" 2>/dev/null)
            if [[ "$http_code" == "200" ]]; then
                jq -n \
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
                    }' | jq -c '.' >> "${cache_file}.tmp"
                log_debug "Found Oracle JDK $version"
            fi
        fi
    done
    [[ -f "${cache_file}.tmp" ]] && mv "${cache_file}.tmp" "$cache_file"
}

discover_openjdk_versions() {
    local cache_file=$(get_cache_file "openjdk")
    is_cache_valid "$cache_file" && { log_debug "Using cached OpenJDK versions"; return 0; }
    
    log_info "Discovering JDK versions from OpenJDK..."
    for version in {11..25}; do
        local download_url="https://download.java.net/java/GA/jdk${version}/jdk-${version}_linux-x64_bin.tar.gz"
        if command_exists curl; then
            local http_code=$(curl -s -L -I -w '%{http_code}' -o /dev/null "$download_url" 2>/dev/null)
            if [[ "$http_code" == "200" ]]; then
                jq -n \
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
                    }' | jq -c '.' >> "${cache_file}.tmp"
                log_debug "Found OpenJDK $version"
            fi
        fi
    done
    [[ -f "${cache_file}.tmp" ]] && mv "${cache_file}.tmp" "$cache_file"
}

# Aggregate discovered versions (condensed)
aggregate_discovered_versions() {
    log_info "Aggregating discovered JDK versions..."
    AVAILABLE_VERSIONS=()
    unset JDK_VERSIONS_INFO VERSION_SOURCES
    declare -g -A JDK_VERSIONS_INFO VERSION_SOURCES
    
    for cache_file in "${CACHE_DIR}"/*_versions.json; do
        [[ -f "$cache_file" && -s "$cache_file" ]] || continue
        
        while IFS= read -r json_line; do
            if [[ -n "$json_line" ]]; then
                local version=$(echo "$json_line" | jq -r '.version' 2>/dev/null)
                local source=$(echo "$json_line" | jq -r '.source' 2>/dev/null)
                
                if [[ "$version" != "null" && "$source" != "null" && "$version" =~ ^[0-9]+$ ]]; then
                    # Prefer adoptium > oracle > openjdk
                    if [[ -n "${JDK_VERSIONS_INFO[$version]:-}" ]]; then
                        local existing_source="${VERSION_SOURCES[$version]}"
                        if [[ "$source" == "adoptium" || ("$source" == "oracle" && "$existing_source" == "openjdk") ]]; then
                            JDK_VERSIONS_INFO["$version"]="$json_line"
                            VERSION_SOURCES["$version"]="$source"
                        fi
                    else
                        JDK_VERSIONS_INFO["$version"]="$json_line"
                        VERSION_SOURCES["$version"]="$source"
                        [[ ! " ${AVAILABLE_VERSIONS[*]} " =~ " ${version} " ]] && AVAILABLE_VERSIONS+=("$version")
                    fi
                fi
            fi
        done < <(jq -c '.' "$cache_file" 2>/dev/null || cat "$cache_file")
    done
    
    # Sort versions numerically
    [[ ${#AVAILABLE_VERSIONS[@]} -gt 0 ]] && {
        IFS=$'\n' AVAILABLE_VERSIONS=($(sort -n <<<"${AVAILABLE_VERSIONS[*]}"))
        unset IFS
    }
}

discover_all_jdk_versions() {
    log_info "Discovering available JDK versions..."
    discover_adoptium_versions
    discover_oracle_versions  
    discover_openjdk_versions
    aggregate_discovered_versions
    
    if [[ ${#AVAILABLE_VERSIONS[@]} -eq 0 ]]; then
        log_error "No JDK versions discovered. Check connection or try --reset-cache"
        exit 1
    fi
    log_info "Discovered ${#AVAILABLE_VERSIONS[@]} JDK versions"
}

# Version utilities
get_version_info() { echo "${JDK_VERSIONS_INFO[$1]}"; }
get_version_field() { local info="${JDK_VERSIONS_INFO[$1]}"; [[ -n "$info" ]] && echo "$info" | jq -r ".$2"; }

# Detection functions
detect_installed_jdks() {
    local installed=()
    [[ -d "${INSTALLATION_DIR}" ]] && for dir in "${INSTALLATION_DIR}"/jdk-*; do
        if [[ -d "$dir" && -x "$dir/bin/java" ]]; then
            local version=$(basename "$dir" | sed 's/jdk-//')
            [[ "$version" =~ ^[0-9]+$ ]] && installed+=("$version")
        fi
    done
    [[ ${#installed[@]} -gt 0 ]] && {
        IFS=$'\n' installed=($(sort -n <<<"${installed[*]}"))
        unset IFS
    }
    echo "${installed[@]}"
}

get_uninstalled_versions() {
    local installed=($(detect_installed_jdks)) uninstalled=()
    for version in "${AVAILABLE_VERSIONS[@]}"; do
        [[ ! " ${installed[*]} " =~ " ${version} " ]] && uninstalled+=("$version")
    done
    echo "${uninstalled[@]}"
}

# Interactive selection (condensed)
select_jdk_version_interactive() {
    echo; log_info "=== Dynamic JDK Installer for Steam Deck ==="; echo
    
    local installed=($(detect_installed_jdks)) uninstalled=($(get_uninstalled_versions))
    [[ ${#installed[@]} -gt 0 ]] && { log_info "Installed: ${installed[*]}"; echo; }
    
    if [[ ${#uninstalled[@]} -eq 0 ]]; then
        log_info "All versions installed. Change default?"
        change_default_java_version; exit 0
    fi
    
    log_info "Available versions to install:"
    local option=1 version_map=()
    for version in "${uninstalled[@]}"; do
        local desc=$(get_version_field "$version" "description")
        echo "  ${option}) $desc"
        version_map[${option}]="$version"
        ((option++))
    done
    
    [[ ${#uninstalled[@]} -gt 1 ]] && {
        echo "  ${option}) Install All Remaining"
        version_map[${option}]="INSTALL_ALL"
        ((option++))
    }
    
    [[ ${#installed[@]} -gt 0 ]] && {
        echo "  ${option}) Change Default Only"
        version_map[${option}]="CHANGE_DEFAULT"
        ((option++))
    }
    
    echo; local max_option=$((option - 1)) latest="${AVAILABLE_VERSIONS[-1]}" default_choice=1
    
    # Find latest version position
    for i in "${!version_map[@]}"; do
        [[ "${version_map[$i]}" == "$latest" ]] && { default_choice=$i; break; }
    done
    
    # Handle special cases if latest is installed
    if [[ " ${installed[*]} " =~ " ${latest} " ]]; then
        for i in "${!version_map[@]}"; do
            [[ "${version_map[$i]}" == "INSTALL_ALL" ]] && { default_choice=$i; break; }
            [[ "${version_map[$i]}" == "CHANGE_DEFAULT" ]] && { default_choice=$i; break; }
        done
    fi
    
    while true; do
        read -p "Choice (1-${max_option}) [default: ${default_choice}]: " choice
        choice=${choice:-$default_choice}
        
        if [[ "$choice" =~ ^[0-9]+$ && "$choice" -ge 1 && "$choice" -le $max_option ]]; then
            local selected="${version_map[$choice]}"
            case "$selected" in
                "INSTALL_ALL") install_all_remaining_jdks; exit 0 ;;
                "CHANGE_DEFAULT") change_default_java_version; exit 0 ;;
                *) JDK_VERSION="$selected"; log_info "Selected $(get_version_field "$selected" "description")"; break ;;
            esac
        fi
        echo "Invalid choice."
    done
}

# Installation functions
install_all_remaining_jdks() {
    local uninstalled=($(get_uninstalled_versions))
    [[ ${#uninstalled[@]} -eq 0 ]] && { log_info "All versions installed!"; return; }
    
    log_info "Installing ${#uninstalled[@]} versions: ${uninstalled[*]}"
    local successful=0
    for version in "${uninstalled[@]}"; do
        log_info "Installing JDK ${version}..."
        JDK_VERSION="$version"
        install_jdk && ((successful++))
    done
    
    log_info "Batch install: ${successful}/${#uninstalled[@]} successful"
    [[ $successful -gt 0 ]] && set_latest_jdk_as_default
}

install_jdk() {
    local version_info="${JDK_VERSIONS_INFO[$JDK_VERSION]}"
    [[ -z "$version_info" ]] && { log_error "No info for JDK $JDK_VERSION"; exit 1; }
    
    local download_url=$(echo "$version_info" | jq -r '.download_url')
    local checksum_url=$(echo "$version_info" | jq -r '.checksum_url')
    local source=$(echo "$version_info" | jq -r '.source')
    local file_name="jdk-${JDK_VERSION}-${source}.tar.gz"
    
    mkdir -p "${INSTALLATION_DIR}"
    cd "${INSTALLATION_DIR}"
    
    # Download
    log_info "Downloading JDK ${JDK_VERSION} from ${source}..."
    wget -O "${file_name}" "${download_url}" --show-progress || { log_error "Download failed"; exit 1; }
    
    # Checksum verification (using working logic from original)
    if [[ -n "$checksum_url" && "$checksum_url" != "null" ]]; then
        local checksum_file="${file_name}.sha256"
        [[ "$source" == "adoptium" ]] && checksum_file="${file_name}.sha256.txt"
        
        if wget -O "$checksum_file" "$checksum_url" --show-progress 2>/dev/null; then
            # Fix the checksum file to use our simplified filename instead of the original
            local original_filename=$(awk '{print $2}' "$checksum_file")
            
            if [[ -n "$original_filename" ]]; then
                # Checksum file has filename (Adoptium format) - replace with our filename
                sed -i "s|${original_filename}|${file_name}|g" "$checksum_file"
                log_debug "Updated checksum file to use simplified filename: $file_name"
            else
                # Checksum file contains only hash (Oracle format) - add filename
                local hash_only=$(cat "$checksum_file" | tr -d '\n')
                echo "${hash_only}  ${file_name}" > "$checksum_file"
                log_debug "Added filename to hash-only checksum file: $file_name"
            fi
            
            sha256sum -c "$checksum_file" >/dev/null 2>&1 && log_info "✓ Checksum verified" || log_warning "⚠ Checksum failed, continuing..."
        else
            log_warning "Could not download checksum for JDK ${JDK_VERSION}, proceeding without verification"
        fi
    else
        log_warning "Checksum not available for JDK ${JDK_VERSION}, proceeding without verification"
    fi
    
    # Extract
    log_info "Extracting JDK ${JDK_VERSION}..."
    local extract_dir="jdk-${JDK_VERSION}"
    mkdir -p "$extract_dir"
    tar --strip-components=1 -xf "${file_name}" -C "$extract_dir" || { log_error "Extraction failed"; exit 1; }
    
    # Verify
    [[ -x "${extract_dir}/bin/java" ]] || { log_error "No java executable found"; exit 1; }
    "${extract_dir}/bin/java" -version >/dev/null 2>&1 || { log_error "Java doesn't run"; exit 1; }
    
    # Cleanup
    rm -f "${file_name}" "${file_name}".sha256*
    log_info "✓ JDK ${JDK_VERSION} installed successfully"
}

# Profile management (condensed)
setup_profile_for_all_jdks() {
    # Backup non-JDK content
    if [[ -f ~/.profile ]]; then
        grep -v -E "# ={5,}|# JDK.*installation|export JAVA_.*_HOME|export JAVA_HOME|export PATH.*jdk.*bin|# To change" ~/.profile | \
        awk 'BEGIN{blank=0} /^$/{blank++; if(blank<=1) print; next} {blank=0; print}' > ~/.profile.backup.tmp 2>/dev/null || true
    else
        touch ~/.profile.backup.tmp
    fi
    
    cp ~/.profile.backup.tmp ~/.profile
    
    # Add JDK section
    cat >> ~/.profile << 'EOF'

# ========================================
# JDK Installations managed by install-jdk-on-steam-deck
# ========================================
EOF
    
    # Add all installed JDKs
    [[ -d "${INSTALLATION_DIR}" ]] && for jdk_dir in "${INSTALLATION_DIR}"/jdk-*; do
        if [[ -d "$jdk_dir" && -x "${jdk_dir}/bin/java" ]]; then
            local version=$(basename "$jdk_dir" | sed 's/jdk-//')
            [[ "$version" =~ ^[0-9]+$ ]] && cat >> ~/.profile << EOF

# JDK ${version} installation
export JAVA_${version}_HOME=${jdk_dir}
export PATH=\$PATH:${jdk_dir}/bin
EOF
        fi
    done
    
    echo -e "\n# To change default, update JAVA_HOME line below or re-run installer\n# ========================================" >> ~/.profile
    rm -f ~/.profile.backup.tmp
}

set_latest_jdk_as_default() {
    local installed=($(detect_installed_jdks))
    [[ ${#installed[@]} -eq 0 ]] && return
    
    local latest="${installed[-1]}"
    log_info "Setting JDK ${latest} as default..."
    
    setup_profile_for_all_jdks
    
    local home_var="JAVA_${latest}_HOME"
    if grep -q "export JAVA_HOME=" ~/.profile; then
        sed -i "s|^export JAVA_HOME=.*|export JAVA_HOME=\$${home_var}|" ~/.profile
    else
        echo "export JAVA_HOME=\$${home_var}" >> ~/.profile
    fi
    
    # Ensure .profile is sourced
    grep -q "source ~/.profile\|\[\[ -f ~/.profile \]\] && source ~/.profile" ~/.bashrc || \
        echo "[[ -f ~/.profile ]] && source ~/.profile" >> ~/.bashrc
    
    log_info "✓ JDK ${latest} set as default"
}

change_default_java_version() {
    local installed_versions=($(detect_installed_jdks))
    [[ ${#installed_versions[@]} -eq 0 ]] && { log_error "No JDK versions installed yet. Please install a JDK first."; return 1; }
    
    echo; log_info "=== Change Default Java Version ==="; echo
    log_info "Installed JDK versions:"
    
    local option_counter=1 version_map=()
    for version in "${installed_versions[@]}"; do
        local jdk_path="${INSTALLATION_DIR}/jdk-${version}"
        if [[ -x "${jdk_path}/bin/java" ]]; then
            local java_version=$("${jdk_path}/bin/java" -version 2>&1 | head -1)
            echo "  ${option_counter}) JDK ${version} - ${java_version}"
            version_map[${option_counter}]="$version"
            ((option_counter++))
        fi
    done
    
    echo
    local max_option=$((option_counter - 1))
    local latest_installed_version="${installed_versions[-1]}"  # Latest (highest numbered) installed version
    local default_choice=$max_option  # Default to the last option (latest version)
    
    while true; do
        read -p "Select which JDK to set as default (1-${max_option}) [default: ${default_choice} for JDK ${latest_installed_version} - RECOMMENDED]: " choice
        
        # If user just presses Enter, use the default choice
        if [[ -z "$choice" ]]; then
            choice=$default_choice
        fi
        
        if [[ "$choice" =~ ^[0-9]+$ && "$choice" -ge 1 && "$choice" -le $max_option ]]; then
            local selected_version="${version_map[$choice]}"
            local selected_home="JAVA_${selected_version}_HOME"
            
            setup_profile_for_all_jdks
            
            if grep -q "export JAVA_HOME=" ~/.profile; then
                sed -i "s|^export JAVA_HOME=.*|export JAVA_HOME=\$${selected_home}|" ~/.profile
            else
                echo "export JAVA_HOME=\$${selected_home}" >> ~/.profile
            fi
            
            echo
            if [[ "$selected_version" == "$latest_installed_version" ]]; then
                log_info "✓ Set JDK ${selected_version} as the default Java version (latest version)"
            else
                log_info "✓ Set JDK ${selected_version} as the default Java version"
            fi
            log_info "  Updated ~/.profile with all installed JDK versions"
            log_info "  For new terminals, restart your shell or run: source ~/.profile"
            break
        else
            echo "Invalid choice. Please enter a number between 1 and ${max_option}."
        fi
    done
}

# Utilities
show_help() {
    cat << 'EOF'
Dynamic JDK Installer for Steam Deck

USAGE: $0 [OPTIONS]

OPTIONS:
    -h, --help          Show help
    -l, --list          List available versions
    --reset-cache       Clear discovery cache
    --debug             Enable debug output  
    --version=VERSION   Install specific version

EXAMPLES:
    $0                  # Interactive mode
    $0 --list           # List versions
    $0 --version=21     # Install JDK 21
    JDK_VERSION=17 $0   # Via environment variable
EOF
}

reset_discovery_cache() {
    log_info "Clearing cache..."
    rm -rf "${CACHE_DIR}"/*_versions.json 2>/dev/null || true
    log_info "Cache cleared. Next run will rediscover versions."
}

# Argument parsing
while [[ $# -gt 0 ]]; do
    case $1 in
        -h|--help) show_help; exit 0 ;;
        -l|--list) LIST_ONLY=true; shift ;;
        --reset-cache) reset_discovery_cache; exit 0 ;;
        --debug) DEBUG=1; shift ;;
        --version=*) JDK_VERSION="${1#*=}"; shift ;;
        *) log_error "Unknown option: $1"; show_help; exit 1 ;;
    esac
done

# Main execution
check_dependencies
discover_all_jdk_versions

# List mode
if [[ "${LIST_ONLY:-false}" == "true" ]]; then
    echo; log_info "Available JDK Versions:"; echo
    for version in "${AVAILABLE_VERSIONS[@]}"; do
        echo "  JDK $version - $(get_version_field "$version" "description")"
    done
    echo; log_info "Total: ${#AVAILABLE_VERSIONS[@]} versions"; exit 0
fi

# Determine version
if [[ -z "${JDK_VERSION:-}" ]]; then
    INTERACTIVE_MODE=true
    select_jdk_version_interactive
else
    INTERACTIVE_MODE=false
    [[ ! " ${AVAILABLE_VERSIONS[*]} " =~ " ${JDK_VERSION} " ]] && {
        log_error "Invalid version: ${JDK_VERSION}. Available: ${AVAILABLE_VERSIONS[*]}"
        exit 1
    }
fi

# Check if already installed
installed=($(detect_installed_jdks))
if [[ " ${installed[*]} " =~ " ${JDK_VERSION} " ]]; then
    log_warning "JDK $JDK_VERSION already installed"
    if [[ "$INTERACTIVE_MODE" == "true" ]]; then
        echo; read -p "Change default? (y/N): " change
        [[ "$change" =~ ^[Yy] ]] && change_default_java_version
    fi
    exit 0
fi

# Install and setup
log_info "Installing JDK ${JDK_VERSION}..."
original_dir="$(pwd)"

if install_jdk; then
    cd "$original_dir" 2>/dev/null || true
    
    log_info "✓ JDK ${JDK_VERSION} installation completed!"
    echo; log_info "Location: ${INSTALLATION_DIR}/jdk-${JDK_VERSION}/"
    log_info "Executable: ${INSTALLATION_DIR}/jdk-${JDK_VERSION}/bin/java"; echo
    
    set_latest_jdk_as_default; echo
    
    # Interactive post-install
    if [[ "$INTERACTIVE_MODE" == "true" ]]; then
        final_installed=($(detect_installed_jdks))
        if [[ ${#final_installed[@]} -gt 1 ]]; then
            echo; log_info "You have ${#final_installed[@]} JDK versions: ${final_installed[*]}"; echo
            
            while true; do
                read -p "Change default Java version? (y/N): " change_default
                case $change_default in
                    [Yy]*) echo; change_default_java_version; break ;;
                    [Nn]*|"") log_info "Keeping JDK ${JDK_VERSION} as default"; break ;;
                    *) echo "Please answer y or n." ;;
                esac
            done
        fi
    fi
    
    echo; log_info "Manual config commands:"
    log_info "  export PATH=\"${INSTALLATION_DIR}/jdk-${JDK_VERSION}/bin:\$PATH\""
    log_info "  export JAVA_HOME=\"${INSTALLATION_DIR}/jdk-${JDK_VERSION}\""
else
    log_error "Installation failed"
    exit 1
fi

log_info "Installation completed!"
