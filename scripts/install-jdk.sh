#!/bin/bash

# Logging utils using colors

RED='\033[1;31m'
BLUE='\033[0;34m'
GREEN='\033[0;32m'
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

# Installation directory - define early so functions can use it
INSTALLATION_DIR="${HOME}/.local/jdk"

# Check which JDK versions are already installed
check_installed_versions() {
    local installed=()
    
    # Debug: Print installation directory path
    [[ "${DEBUG:-0}" == "1" ]] && log_info "DEBUG: Checking installation directory: ${INSTALLATION_DIR}"
    
    if [[ -d "${INSTALLATION_DIR}" ]]; then
        # Debug: List contents of installation directory
        [[ "${DEBUG:-0}" == "1" ]] && log_info "DEBUG: Installation directory contents:" && ls -la "${INSTALLATION_DIR}"
        
        for jdk_dir in "${INSTALLATION_DIR}"/*/; do
            # Skip if glob doesn't match any directories
            [[ ! -d "$jdk_dir" ]] && continue
            
            [[ "${DEBUG:-0}" == "1" ]] && log_info "DEBUG: Checking directory: $jdk_dir"
            
            # Check if java executable exists and is executable
            if [[ -x "${jdk_dir}bin/java" ]]; then
                # Get the version from the java executable with timeout to prevent hanging
                java_version=$(timeout 10s "${jdk_dir}bin/java" -version 2>&1 | head -1)
                local java_exit_code=$?
                
                [[ "${DEBUG:-0}" == "1" ]] && log_info "DEBUG: Java version output from ${jdk_dir}: $java_version"
                
                # Skip if java command failed or timed out
                if [[ $java_exit_code -ne 0 ]]; then
                    [[ "${DEBUG:-0}" == "1" ]] && log_warning "DEBUG: Java command failed in $jdk_dir (exit code: $java_exit_code)"
                    continue
                fi
                
                # More robust version detection with multiple patterns
                if echo "$java_version" | grep -qE "(1\.8\.|openjdk version \"8|java version \"1\.8)"; then
                    installed+=(8)
                    [[ "${DEBUG:-0}" == "1" ]] && log_info "DEBUG: Detected JDK 8 in $jdk_dir"
                elif echo "$java_version" | grep -qE "(openjdk version \"16|java version \"16)"; then
                    installed+=(16)
                    [[ "${DEBUG:-0}" == "1" ]] && log_info "DEBUG: Detected JDK 16 in $jdk_dir"
                elif echo "$java_version" | grep -qE "(openjdk version \"17|java version \"17)"; then
                    installed+=(17)
                    [[ "${DEBUG:-0}" == "1" ]] && log_info "DEBUG: Detected JDK 17 in $jdk_dir"
                elif echo "$java_version" | grep -qE "(openjdk version \"21|java version \"21)"; then
                    installed+=(21)
                    [[ "${DEBUG:-0}" == "1" ]] && log_info "DEBUG: Detected JDK 21 in $jdk_dir"
                elif echo "$java_version" | grep -qE "(openjdk version \"23|java version \"23)"; then
                    installed+=(23)
                    [[ "${DEBUG:-0}" == "1" ]] && log_info "DEBUG: Detected JDK 23 in $jdk_dir"
                elif echo "$java_version" | grep -qE "(openjdk version \"24|java version \"24)"; then
                    installed+=(24)
                    [[ "${DEBUG:-0}" == "1" ]] && log_info "DEBUG: Detected JDK 24 in $jdk_dir"
                else
                    [[ "${DEBUG:-0}" == "1" ]] && log_warning "DEBUG: Unrecognized Java version in $jdk_dir: $java_version"
                fi
            else
                [[ "${DEBUG:-0}" == "1" ]] && log_warning "DEBUG: No executable java found in ${jdk_dir}bin/"
            fi
        done
    else
        [[ "${DEBUG:-0}" == "1" ]] && log_info "DEBUG: Installation directory ${INSTALLATION_DIR} does not exist"
    fi
    
    [[ "${DEBUG:-0}" == "1" ]] && log_info "DEBUG: Found installed versions: ${installed[*]}"
    echo "${installed[@]}"
}

# Interactive JDK version selection if not specified via environment variable
select_jdk_version_interactive() {
    # Check which versions are already installed
    local installed_versions=($(check_installed_versions))
    local available_versions=(8 16 17 21 23 24)
    local uninstalled_versions=()
    
    # Find versions that are not installed
    for version in "${available_versions[@]}"; do
        local is_installed=false
        for installed in "${installed_versions[@]}"; do
            if [[ "$version" == "$installed" ]]; then
                is_installed=true
                break
            fi
        done
        if [[ "$is_installed" == "false" ]]; then
            uninstalled_versions+=("$version")
        fi
    done
    
    # If all versions are installed, skip to default selection
    if [[ ${#uninstalled_versions[@]} -eq 0 ]]; then
        log_info "All JDK versions (8, 16, 17, 21, 23, 24) are already installed."
        log_info "Proceeding to default Java version selection..."
        JDK_VERSION="SKIP_TO_DEFAULT"
        return
    fi
    
    # Show available uninstalled versions plus install all option
    echo ""
    log_info "=== JDK Installer for Steam Deck ==="
    echo ""
    
    if [[ ${#installed_versions[@]} -gt 0 ]]; then
        log_info "Already installed JDK versions: ${installed_versions[*]}"
        echo ""
    fi
    
    log_info "Please select which JDK version you would like to install:"
    echo ""
    
    local option_counter=1
    local version_map=()
    
    # Show uninstalled versions
    for version in "${uninstalled_versions[@]}"; do
        case $version in
            8)
                echo "  ${option_counter}) JDK 8 (Eclipse Temurin)"
                version_map[${option_counter}]="8"
                ;;
            16)
                echo "  ${option_counter}) JDK 16 (OpenJDK)"
                version_map[${option_counter}]="16"
                ;;
            17)
                echo "  ${option_counter}) JDK 17 (OpenJDK)"
                version_map[${option_counter}]="17"
                ;;
            21)
                echo "  ${option_counter}) JDK 21 (Oracle)"
                version_map[${option_counter}]="21"
                ;;
            23)
                echo "  ${option_counter}) JDK 23 (OpenJDK)"
                version_map[${option_counter}]="23"
                ;;
            24)
                echo "  ${option_counter}) JDK 24 (Oracle - recommended)"
                version_map[${option_counter}]="24"
                ;;
        esac
        ((option_counter++))
    done
    
    # Add install remaining versions option if there are multiple uninstalled versions
    if [[ ${#uninstalled_versions[@]} -gt 1 ]]; then
        echo "  ${option_counter}) Install All Remaining JDK Versions (${uninstalled_versions[*]})"
        version_map[${option_counter}]="REMAINING"
        ((option_counter++))
    fi
    
    # Add skip to change defaults option (always show if there are installed versions)
    if [[ ${#installed_versions[@]} -gt 0 ]]; then
        echo "  ${option_counter}) Skip installation and change default Java version"
        version_map[${option_counter}]="SKIP_TO_DEFAULT"
        ((option_counter++))
    fi
    
    echo ""
    
    # Determine default option (JDK 24 if available, otherwise the highest uninstalled version)
    local default_option=1
    local default_version=""
    for i in "${!version_map[@]}"; do
        if [[ "${version_map[i]}" == "24" ]]; then
            default_option=$i
            default_version="24"
            break
        fi
    done
    
    # If JDK 24 not available, use the highest numbered uninstalled version
    if [[ -z "$default_version" ]]; then
        local highest_version=0
        for version in "${uninstalled_versions[@]}"; do
            if [[ $version -gt $highest_version ]]; then
                highest_version=$version
            fi
        done
        for i in "${!version_map[@]}"; do
            if [[ "${version_map[i]}" == "$highest_version" ]]; then
                default_option=$i
                default_version="$highest_version"
                break
            fi
        done
    fi
    
    local max_option=$((option_counter - 1))
    
    while true; do
        if [[ -n "$default_version" ]]; then
            read -p "Enter your choice (1-${max_option}) [default: ${default_option} for JDK ${default_version}]: " choice
        else
            read -p "Enter your choice (1-${max_option}): " choice
        fi
        
        # If user just presses Enter, use default
        if [[ -z "$choice" ]]; then
            choice=$default_option
        fi
        
        if [[ "$choice" =~ ^[0-9]+$ ]] && [[ "$choice" -ge 1 ]] && [[ "$choice" -le $max_option ]]; then
            local selected_version="${version_map[$choice]}"
            
            if [[ "$selected_version" == "REMAINING" ]]; then
                JDK_VERSION="REMAINING"
                log_info "Selected to install all remaining JDK versions (${uninstalled_versions[*]})"
            elif [[ "$selected_version" == "SKIP_TO_DEFAULT" ]]; then
                JDK_VERSION="SKIP_TO_DEFAULT"
                log_info "Selected to skip installation and change default Java version"
            else
                JDK_VERSION="$selected_version"
                case $selected_version in
                    8) log_info "Selected JDK 8 (Eclipse Temurin)" ;;
                    16) log_info "Selected JDK 16 (OpenJDK)" ;;
                    17) log_info "Selected JDK 17 (OpenJDK)" ;;
                    21) log_info "Selected JDK 21 (Oracle)" ;;
                    23) log_info "Selected JDK 23 (OpenJDK)" ;;
                    24) log_info "Selected JDK 24 (Oracle - latest version)" ;;
                esac
            fi
            break
        else
            echo "Invalid choice. Please enter a number between 1 and ${max_option}."
        fi
    done
}

# Determine JDK version - interactive prompt if not set via environment variable
# Also determine if we're in environment variable mode
ENV_VAR_MODE=false
if [[ -z "$JDK_VERSION" ]]; then
    select_jdk_version_interactive
else
    ENV_VAR_MODE=true
    log_info "Using JDK version ${JDK_VERSION} specified via environment variable"
    # Validate the provided version
    case $JDK_VERSION in
        8|16|17|21|23|24|ALL|REMAINING|SKIP_TO_DEFAULT)
            # Valid version, continue
            ;;
        *)
            log_error "Invalid JDK_VERSION specified: ${JDK_VERSION}"
            log_error "Supported versions are: 8, 16, 17, 21, 23, 24, ALL, REMAINING, SKIP_TO_DEFAULT"
            exit 1
            ;;
    esac
fi

JDK_8_URL=https://github.com/adoptium/temurin8-binaries/releases/download/jdk8u422-b05/OpenJDK8U-jdk_x64_linux_hotspot_8u422b05.tar.gz
JDK_8_CHECKSUM_URL=https://github.com/adoptium/temurin8-binaries/releases/download/jdk8u422-b05/OpenJDK8U-jdk_x64_linux_hotspot_8u422b05.tar.gz.sha256.txt
JDK_8_EXTRACTED_DIR=to-be-known-later
JDK_8_FILE_NAME=jdk-8_linux-x64_bin.tar.gz
JDK_8_CHECKSUM_FILE_NAME=jdk-8_linux-x64_bin.tar.gz.sha256

JDK_16_URL=https://download.java.net/java/GA/jdk16.0.2/d4a915d82b4c4fbb9bde534da945d746/7/GPL/openjdk-16.0.2_linux-x64_bin.tar.gz
JDK_16_CHECKSUM_URL=https://download.java.net/java/GA/jdk16.0.2/d4a915d82b4c4fbb9bde534da945d746/7/GPL/openjdk-16.0.2_linux-x64_bin.tar.gz.sha256
JDK_16_EXTRACTED_DIR=to-be-known-later
JDK_16_FILE_NAME=jdk-16_linux-x64_bin.tar.gz
JDK_16_CHECKSUM_FILE_NAME=jdk-16_linux-x64_bin.tar.gz.sha256

JDK_17_URL=https://download.java.net/java/GA/jdk17.0.1/2a2082e5a09d4267845be086888add4f/12/GPL/openjdk-17.0.1_linux-x64_bin.tar.gz
JDK_17_CHECKSUM_URL=https://download.java.net/java/GA/jdk17.0.1/2a2082e5a09d4267845be086888add4f/12/GPL/openjdk-17.0.1_linux-x64_bin.tar.gz.sha256
JDK_17_EXTRACTED_DIR=to-be-known-later
JDK_17_FILE_NAME=jdk-17_linux-x64_bin.tar.gz
JDK_17_CHECKSUM_FILE_NAME=jdk-17_linux-x64_bin.tar.gz.sha256

JDK_21_URL=https://download.oracle.com/java/21/latest/jdk-21_linux-x64_bin.tar.gz
JDK_21_CHECKSUM_URL=https://download.oracle.com/java/21/latest/jdk-21_linux-x64_bin.tar.gz.sha256
JDK_21_EXTRACTED_DIR=to-be-known-later
JDK_21_FILE_NAME=jdk-21_linux-x64_bin.tar.gz
JDK_21_CHECKSUM_FILE_NAME=jdk-21_linux-x64_bin.tar.gz.sha256

JDK_23_URL=https://download.java.net/java/GA/jdk23.0.1/c28985cbf10d4e648e4004050f8781aa/11/GPL/openjdk-23.0.1_linux-x64_bin.tar.gz
JDK_23_CHECKSUM_URL=https://download.java.net/java/GA/jdk23.0.1/c28985cbf10d4e648e4004050f8781aa/11/GPL/openjdk-23.0.1_linux-x64_bin.tar.gz.sha256
JDK_23_EXTRACTED_DIR=to-be-known-later
JDK_23_FILE_NAME=jdk-23_linux-x64_bin.tar.gz
JDK_23_CHECKSUM_FILE_NAME=jdk-23_linux-x64_bin.tar.gz.sha256

JDK_24_URL=https://download.oracle.com/java/24/latest/jdk-24_linux-x64_bin.tar.gz
JDK_24_CHECKSUM_URL=https://download.oracle.com/java/24/latest/jdk-24_linux-x64_bin.tar.gz.sha256
JDK_24_EXTRACTED_DIR=to-be-known-later
JDK_24_FILE_NAME=jdk-24_linux-x64_bin.tar.gz
JDK_24_CHECKSUM_FILE_NAME=jdk-24_linux-x64_bin.tar.gz.sha256

JDK_URL=""
JDK_CHECKSUM_URL=""
JDK_EXTRACTED_DIR=""
JDK_FILE_NAME=""
JDK_CHECKSUM_FILE_NAME=""

CURRENT_DIR=$(pwd)

cleanup() {
    # Only clean up the downloaded files, not the entire JDK directory
    # This preserves other installed JDK versions
    if [[ -n "${JDK_FILE_NAME}" && -f "${INSTALLATION_DIR}/${JDK_FILE_NAME}" ]]; then
        cleanup_command="rm -f ${INSTALLATION_DIR}/${JDK_FILE_NAME}"
        log_info "Cleaning downloaded file: ${cleanup_command}"
        $cleanup_command
    fi
    
    if [[ -n "${JDK_CHECKSUM_FILE_NAME}" && -f "${INSTALLATION_DIR}/${JDK_CHECKSUM_FILE_NAME}" ]]; then
        cleanup_command="rm -f ${INSTALLATION_DIR}/${JDK_CHECKSUM_FILE_NAME}"
        log_info "Cleaning checksum file: ${cleanup_command}"
        $cleanup_command
    fi
    
    # If extraction started but failed, clean up the partially extracted directory
    if [[ -n "${JDK_EXTRACTED_DIR}" && "${JDK_EXTRACTED_DIR}" != "to-be-known-later" && -d "${INSTALLATION_DIR}/${JDK_EXTRACTED_DIR}" ]]; then
        cleanup_command="rm -rf ${INSTALLATION_DIR}/${JDK_EXTRACTED_DIR}"
        log_info "Cleaning partially extracted directory: ${cleanup_command}"
        $cleanup_command
    fi
}

# Clean up any existing messy .profile file from previous script runs
cleanup_profile() {
    if [[ -f ~/.profile ]]; then
        log_info "Cleaning up previous JDK entries from .profile..."
        
        # Create a clean version by removing all JDK-related content and excessive blank lines
        grep -v -E "# ={5,}|# JDK.*[Ii]nstallation|# JDK Installations managed by|export JAVA_.*_HOME|export JAVA_HOME=|export PATH.*jdk.*bin|# To change the default Java version" ~/.profile | \
        awk '
        BEGIN { blank_count = 0 }
        /^[[:space:]]*$/ { 
            blank_count++
            if (blank_count <= 2) print
            next 
        }
        { 
            blank_count = 0
            print 
        }
        ' > ~/.profile.clean
        
        # Replace the original with the cleaned version
        mv ~/.profile.clean ~/.profile
        
        log_info "Cleaned up .profile file"
    fi
}

# Allows the user to select which version of the jdk to install
select_jdk_version() {
    case $JDK_VERSION in
        8)
            log_info "You've selected version jdk-8"
            JDK_URL="${JDK_8_URL}"
            JDK_CHECKSUM_URL="${JDK_8_CHECKSUM_URL}"
            JDK_EXTRACTED_DIR="${JDK_8_EXTRACTED_DIR}"
            JDK_FILE_NAME="${JDK_8_FILE_NAME}"
            JDK_CHECKSUM_FILE_NAME="${JDK_8_CHECKSUM_FILE_NAME}"
            ;;
        16)
            log_info "You've selected version jdk-16"
            JDK_URL="${JDK_16_URL}"
            JDK_CHECKSUM_URL="${JDK_16_CHECKSUM_URL}"
            JDK_EXTRACTED_DIR="${JDK_16_EXTRACTED_DIR}"
            JDK_FILE_NAME="${JDK_16_FILE_NAME}"
            JDK_CHECKSUM_FILE_NAME="${JDK_16_CHECKSUM_FILE_NAME}"
            ;;
        17)
            log_info "You've selected version jdk-17"
            JDK_URL="${JDK_17_URL}"
            JDK_CHECKSUM_URL="${JDK_17_CHECKSUM_URL}"
            JDK_EXTRACTED_DIR="${JDK_17_EXTRACTED_DIR}"
            JDK_FILE_NAME="${JDK_17_FILE_NAME}"
            JDK_CHECKSUM_FILE_NAME="${JDK_17_CHECKSUM_FILE_NAME}"
            ;;
        21)
            log_info "You've selected version jdk-21"
            JDK_URL="${JDK_21_URL}"
            JDK_CHECKSUM_URL="${JDK_21_CHECKSUM_URL}"
            JDK_EXTRACTED_DIR="${JDK_21_EXTRACTED_DIR}"
            JDK_FILE_NAME="${JDK_21_FILE_NAME}"
            JDK_CHECKSUM_FILE_NAME="${JDK_21_CHECKSUM_FILE_NAME}"
            ;;
        23)
            log_info "You've selected version jdk-23"
            JDK_URL="${JDK_23_URL}"
            JDK_CHECKSUM_URL="${JDK_23_CHECKSUM_URL}"
            JDK_EXTRACTED_DIR="${JDK_23_EXTRACTED_DIR}"
            JDK_FILE_NAME="${JDK_23_FILE_NAME}"
            JDK_CHECKSUM_FILE_NAME="${JDK_23_CHECKSUM_FILE_NAME}"
            ;;
        24)
            log_info "You've selected version jdk-24"
            JDK_URL="${JDK_24_URL}"
            JDK_CHECKSUM_URL="${JDK_24_CHECKSUM_URL}"
            JDK_EXTRACTED_DIR="${JDK_24_EXTRACTED_DIR}"
            JDK_FILE_NAME="${JDK_24_FILE_NAME}"
            JDK_CHECKSUM_FILE_NAME="${JDK_24_CHECKSUM_FILE_NAME}"
            ;;
        ALL)
            log_info "You've selected to install all JDK versions"
            # For "ALL" case, we'll handle installation differently in the main section
            ;;
        REMAINING)
            log_info "You've selected to install all remaining JDK versions"
            # For "REMAINING" case, we'll handle installation differently in the main section
            ;;
        SKIP_TO_DEFAULT)
            log_info "All versions are installed, proceeding to default selection"
            # For "SKIP_TO_DEFAULT" case, we'll skip installation and go to default selection
            ;;
        *)
            log_error "The version you've selected isn't supported, either set JDK_VERSION=8, JDK_VERSION=16, JDK_VERSION=17, JDK_VERSION=21, JDK_VERSION=23, JDK_VERSION=24, or JDK_VERSION=ALL"
            cleanup
            exit 1
            ;;
    esac
}

# Check if the specific JDK version is already installed in our installation directory
check_if_jdk_version_is_installed() {
    [[ "${DEBUG:-0}" == "1" ]] && log_info "DEBUG: Checking if JDK ${JDK_VERSION} is installed in ${INSTALLATION_DIR}"
    
    if [[ -d "${INSTALLATION_DIR}" ]]; then
        # Look for any JDK directory that might contain the version we're trying to install
        for jdk_dir in "${INSTALLATION_DIR}"/*/; do
            # Skip if glob doesn't match any directories
            [[ ! -d "$jdk_dir" ]] && continue
            
            [[ "${DEBUG:-0}" == "1" ]] && log_info "DEBUG: Checking directory: $jdk_dir"
            
            if [[ -x "${jdk_dir}bin/java" ]]; then
                # Get the version from the java executable with timeout
                java_version=$(timeout 10s "${jdk_dir}bin/java" -version 2>&1 | head -1)
                local java_exit_code=$?
                
                [[ "${DEBUG:-0}" == "1" ]] && log_info "DEBUG: Java version output from ${jdk_dir}: $java_version"
                
                # Skip if java command failed or timed out
                if [[ $java_exit_code -ne 0 ]]; then
                    [[ "${DEBUG:-0}" == "1" ]] && log_warning "DEBUG: Java command failed in $jdk_dir (exit code: $java_exit_code)"
                    continue
                fi
                
                case $JDK_VERSION in
                    8)
                        if echo "$java_version" | grep -qE "(1\.8\.|openjdk version \"8|java version \"1\.8)"; then
                            log_warning "JDK ${JDK_VERSION} is already installed in ${jdk_dir}, skipping installation and proceeding to default selection"
                            return 0
                        fi
                        ;;
                    16|17|21|23|24)
                        if echo "$java_version" | grep -qE "(openjdk version \"${JDK_VERSION}|java version \"${JDK_VERSION})"; then
                            log_warning "JDK ${JDK_VERSION} is already installed in ${jdk_dir}, skipping installation and proceeding to default selection"
                            return 0
                        fi
                        ;;
                esac
            else
                [[ "${DEBUG:-0}" == "1" ]] && log_warning "DEBUG: No executable java found in ${jdk_dir}bin/"
            fi
        done
    else
        [[ "${DEBUG:-0}" == "1" ]] && log_info "DEBUG: Installation directory ${INSTALLATION_DIR} does not exist"
    fi
    return 1
}

# Install a specific JDK version with given parameters
install_single_jdk() {
    local version=$1
    local url=$2
    local checksum_url=$3
    local file_name=$4
    local checksum_file_name=$5
    
    log_info "Installing JDK ${version}..."
    
    mkdir -p "${INSTALLATION_DIR}" || { log_error "Couldn't create the installation directory, exiting..."; cleanup; exit 1; }
    cd "${INSTALLATION_DIR}" || { log_error "Couldn't 'cd' into the installation directory, exiting..."; cleanup; exit 1; }

    # Download JDK and checksum
    wget -O "${file_name}" "${url}" --show-progress || \
        { log_error "Couldn't download JDK ${version} release, skipping..."; cd "${CURRENT_DIR}"; return 1; }

    wget -O "${checksum_file_name}" "${checksum_url}" --show-progress || \
        { log_error "Couldn't download JDK ${version} checksum release, skipping..."; rm -f "${file_name}"; cd "${CURRENT_DIR}"; return 1; }

    # Handle different checksum file formats
    if [[ "$version" == "8" ]]; then
        # Eclipse Temurin: Extract just the hash and create proper checksum file
        checksum_hash=$(head -1 "${checksum_file_name}" | awk '{print $1}')
        echo "${checksum_hash}  ${file_name}" > "${checksum_file_name}"
        sha256sum -c "${checksum_file_name}" || \
            { log_error "Downloaded JDK ${version} doesn't match the checksum, skipping..."; rm -f "${file_name}" "${checksum_file_name}"; cd "${CURRENT_DIR}"; return 1; }
    else
        # Oracle checksum files contain only the hash, need to append filename
        echo "  ${file_name}" >> "${checksum_file_name}"
        sha256sum -c "${checksum_file_name}" || \
            { log_error "Downloaded JDK ${version} doesn't match the checksum, skipping..."; rm -f "${file_name}" "${checksum_file_name}"; cd "${CURRENT_DIR}"; return 1; }
    fi

    tar xvf "${file_name}" || { log_error "Couldn't decompress JDK ${version} file, skipping..."; rm -f "${file_name}" "${checksum_file_name}"; cd "${CURRENT_DIR}"; return 1; }

    rm -f "${file_name}" "${checksum_file_name}"
    
    log_info "JDK ${version} installed successfully"
    cd "${CURRENT_DIR}" || exit 1
    return 0
}

# Install all JDK versions
install_all_jdks() {
    log_info "Installing all JDK versions (8, 16, 17, 21, 23, 24)..."
    
    # Check which versions are already installed
    local versions_to_install=()
    for version in 8 16 17 21 23 24; do
        temp_jdk_version=$JDK_VERSION
        JDK_VERSION=$version
        if ! check_if_jdk_version_is_installed; then
            versions_to_install+=($version)
        else
            log_info "JDK ${version} is already installed, skipping"
        fi
        JDK_VERSION=$temp_jdk_version
    done
    
    # Install missing versions
    for version in "${versions_to_install[@]}"; do
        case $version in
            8)
                install_single_jdk "8" "${JDK_8_URL}" "${JDK_8_CHECKSUM_URL}" "${JDK_8_FILE_NAME}" "${JDK_8_CHECKSUM_FILE_NAME}"
                ;;
            16)
                install_single_jdk "16" "${JDK_16_URL}" "${JDK_16_CHECKSUM_URL}" "${JDK_16_FILE_NAME}" "${JDK_16_CHECKSUM_FILE_NAME}"
                ;;
            17)
                install_single_jdk "17" "${JDK_17_URL}" "${JDK_17_CHECKSUM_URL}" "${JDK_17_FILE_NAME}" "${JDK_17_CHECKSUM_FILE_NAME}"
                ;;
            21)
                install_single_jdk "21" "${JDK_21_URL}" "${JDK_21_CHECKSUM_URL}" "${JDK_21_FILE_NAME}" "${JDK_21_CHECKSUM_FILE_NAME}"
                ;;
            23)
                install_single_jdk "23" "${JDK_23_URL}" "${JDK_23_CHECKSUM_URL}" "${JDK_23_FILE_NAME}" "${JDK_23_CHECKSUM_FILE_NAME}"
                ;;
            24)
                install_single_jdk "24" "${JDK_24_URL}" "${JDK_24_CHECKSUM_URL}" "${JDK_24_FILE_NAME}" "${JDK_24_CHECKSUM_FILE_NAME}"
                ;;
        esac
    done
    
    log_info "All JDK installations completed"
}

# Install remaining (uninstalled) JDK versions
install_remaining_jdks() {
    # Get the list of uninstalled versions
    local installed_versions=($(check_installed_versions))
    local available_versions=(8 16 17 21 23 24)
    local uninstalled_versions=()
    
    # Find versions that are not installed
    for version in "${available_versions[@]}"; do
        local is_installed=false
        for installed in "${installed_versions[@]}"; do
            if [[ "$version" == "$installed" ]]; then
                is_installed=true
                break
            fi
        done
        if [[ "$is_installed" == "false" ]]; then
            uninstalled_versions+=("$version")
        fi
    done
    
    log_info "Installing remaining JDK versions: ${uninstalled_versions[*]}"
    
    # Install each uninstalled version
    for version in "${uninstalled_versions[@]}"; do
        case $version in
            8)
                install_single_jdk "8" "${JDK_8_URL}" "${JDK_8_CHECKSUM_URL}" "${JDK_8_FILE_NAME}" "${JDK_8_CHECKSUM_FILE_NAME}"
                ;;
            16)
                install_single_jdk "16" "${JDK_16_URL}" "${JDK_16_CHECKSUM_URL}" "${JDK_16_FILE_NAME}" "${JDK_16_CHECKSUM_FILE_NAME}"
                ;;
            17)
                install_single_jdk "17" "${JDK_17_URL}" "${JDK_17_CHECKSUM_URL}" "${JDK_17_FILE_NAME}" "${JDK_17_CHECKSUM_FILE_NAME}"
                ;;
            21)
                install_single_jdk "21" "${JDK_21_URL}" "${JDK_21_CHECKSUM_URL}" "${JDK_21_FILE_NAME}" "${JDK_21_CHECKSUM_FILE_NAME}"
                ;;
            23)
                install_single_jdk "23" "${JDK_23_URL}" "${JDK_23_CHECKSUM_URL}" "${JDK_23_FILE_NAME}" "${JDK_23_CHECKSUM_FILE_NAME}"
                ;;
            24)
                install_single_jdk "24" "${JDK_24_URL}" "${JDK_24_CHECKSUM_URL}" "${JDK_24_FILE_NAME}" "${JDK_24_CHECKSUM_FILE_NAME}"
                ;;
        esac
    done
    
    log_info "Remaining JDK installations completed"
}

# download the jdk tar release from oracle and it's checksum
# uncompress and check
# clean uneeded files
install_jdk() {
    mkdir -p "${INSTALLATION_DIR}" || { log_error "Couldn't create the installation directory, exiting..."; cleanup; exit 1; }
    cd "${INSTALLATION_DIR}" || { log_error "Couldn't 'cd' into the installation directory, exiting..."; cleanup; exit 1; }

    # this repeated trick works as: if the command returns anything other than 0, it will exec what's on the right side
    # of the || (or) operator
    wget -O "${JDK_FILE_NAME}" "${JDK_URL}" --show-progress || \
        { log_error "Couldn't download the jdk release, exiting..."; cleanup; exit 1; }

    wget -O "${JDK_CHECKSUM_FILE_NAME}" "${JDK_CHECKSUM_URL}" --show-progress || \
        { log_error "Couldn't download the jdk checksum release, exiting..."; cleanup; exit 1; }

    # Handle different checksum file formats
    if [[ "$JDK_VERSION" == "8" ]]; then
        # Eclipse Temurin: Extract just the hash and create proper checksum file
        checksum_hash=$(head -1 "${JDK_CHECKSUM_FILE_NAME}" | awk '{print $1}')
        echo "${checksum_hash}  ${JDK_FILE_NAME}" > "${JDK_CHECKSUM_FILE_NAME}"
        sha256sum -c "${JDK_CHECKSUM_FILE_NAME}" || \
            { log_error "Downloaded jdk doesn't match the checksum, don't trust this url!!!\n${JDK_URL}"; cleanup; exit 1; }
    else
        # Oracle checksum files contain only the hash, need to append filename
        echo "  ${JDK_FILE_NAME}" >> "${JDK_CHECKSUM_FILE_NAME}"
        sha256sum -c "${JDK_CHECKSUM_FILE_NAME}" || \
            { log_error "Downloaded jdk doesn't match the checksum, don't trust this url!!!\n${JDK_URL}"; cleanup; exit 1; }
    fi

    tar xvf "${JDK_FILE_NAME}" || { log_error "Couldn't decompress the jdk file, exiting..."; cleanup; exit 1; }

    JDK_EXTRACTED_DIR=$(tar tf $JDK_FILE_NAME | head -1 | cut -f1 -d"/")

    rm -f "${JDK_FILE_NAME}" "${JDK_CHECKSUM_FILE_NAME}"

    cd "${CURRENT_DIR}" || exit 1
}

# Ask user which Java version they want as default
ask_for_default_java() {
    local is_env_var_mode=${1:-false}  # Parameter to indicate if we're in environment variable mode
    
    # Get list of all installed Java versions
    installed_versions=()
    version_homes=()
    
    if [[ -d "${INSTALLATION_DIR}" ]]; then
        for jdk_dir in "${INSTALLATION_DIR}"/*/; do
            if [[ -d "$jdk_dir" && -x "${jdk_dir}bin/java" ]]; then
                # Get the version from the java executable
                java_version=$("${jdk_dir}bin/java" -version 2>&1 | head -1)
                if echo "$java_version" | grep -q "1\.8\|openjdk version \"8"; then
                    installed_versions+=("8")
                    version_homes+=("JAVA_8_HOME")
                elif echo "$java_version" | grep -q "openjdk version \"16\|java version \"16"; then
                    installed_versions+=("16")
                    version_homes+=("JAVA_16_HOME")
                elif echo "$java_version" | grep -q "openjdk version \"17\|java version \"17"; then
                    installed_versions+=("17")
                    version_homes+=("JAVA_17_HOME")
                elif echo "$java_version" | grep -q "openjdk version \"21\|java version \"21"; then
                    installed_versions+=("21")
                    version_homes+=("JAVA_21_HOME")
                elif echo "$java_version" | grep -q "openjdk version \"23\|java version \"23"; then
                    installed_versions+=("23")
                    version_homes+=("JAVA_23_HOME")
                elif echo "$java_version" | grep -q "openjdk version \"24\|java version \"24"; then
                    installed_versions+=("24")
                    version_homes+=("JAVA_24_HOME")
                fi
            fi
        done
    fi
    
    # Sort versions numerically and find the latest
    IFS=$'\n' sorted_versions=($(sort -n <<<"${installed_versions[*]}"))
    unset IFS
    latest_version="${sorted_versions[-1]}"
    
    # Find the index of the latest version for default selection
    latest_index=-1
    for i in "${!installed_versions[@]}"; do
        if [[ "${installed_versions[i]}" == "$latest_version" ]]; then
            latest_index=$((i + 1))
            break
        fi
    done
    
    # If environment variable mode, automatically set the latest version
    if [[ "$is_env_var_mode" == "true" ]]; then
        # Automatically set latest version as default
        selected_version="$latest_version"
        for i in "${!installed_versions[@]}"; do
            if [[ "${installed_versions[i]}" == "$latest_version" ]]; then
                selected_home="${version_homes[i]}"
                break
            fi
        done
        
        # Update JAVA_HOME in profile
        if grep "export JAVA_HOME=" ~/.profile > /dev/null 2>&1; then
            sed -i "s|^export JAVA_HOME=.*|export JAVA_HOME=\$${selected_home}|" ~/.profile
        else
            echo "export JAVA_HOME=\$${selected_home}" >> ~/.profile
        fi
        
        log_info "Automatically set JDK ${selected_version} as the default Java version (latest version)"
        return
    fi
    
    # Interactive mode: ask user to choose default if multiple versions exist
    if [[ ${#installed_versions[@]} -gt 1 ]]; then
        echo ""
        log_info "Multiple Java versions detected. Please choose which one should be the default:"
        for i in "${!installed_versions[@]}"; do
            if [[ "${installed_versions[i]}" == "$latest_version" ]]; then
                echo "  $((i + 1))) JDK ${installed_versions[i]} (recommended - latest version)"
            else
                echo "  $((i + 1))) JDK ${installed_versions[i]}"
            fi
        done
        echo ""
        
        while true; do
            read -p "Enter your choice (1-${#installed_versions[@]}) [default: ${latest_index} for JDK ${latest_version}]: " choice
            
            # If user just presses Enter, use the latest version
            if [[ -z "$choice" ]]; then
                choice=$latest_index
            fi
            
            if [[ "$choice" =~ ^[0-9]+$ ]] && [[ "$choice" -ge 1 ]] && [[ "$choice" -le ${#installed_versions[@]} ]]; then
                selected_version="${installed_versions[$((choice - 1))]}"
                selected_home="${version_homes[$((choice - 1))]}"
                
                # Update JAVA_HOME in profile
                if grep "export JAVA_HOME=" ~/.profile > /dev/null 2>&1; then
                    sed -i "s|^export JAVA_HOME=.*|export JAVA_HOME=\$${selected_home}|" ~/.profile
                else
                    echo "export JAVA_HOME=\$${selected_home}" >> ~/.profile
                fi
                
                if [[ "$selected_version" == "$latest_version" ]]; then
                    log_info "Set JDK ${selected_version} as the default Java version (latest version)"
                else
                    log_info "Set JDK ${selected_version} as the default Java version"
                fi
                break
            else
                echo "Invalid choice. Please enter a number between 1 and ${#installed_versions[@]}, or press Enter for default."
            fi
        done
    elif [[ ${#installed_versions[@]} -eq 1 ]]; then
        # Only one version, set it as default
        selected_version="${installed_versions[0]}"
        selected_home="${version_homes[0]}"
        
        if ! grep "export JAVA_HOME=" ~/.profile > /dev/null 2>&1; then
            echo "export JAVA_HOME=\$${selected_home}" >> ~/.profile
            log_info "Set JDK ${selected_version} as the default Java version"
        fi
    fi
}
# This will set JAVA_HOME and will also append the java/bin folder to PATH
set_variables_for_the_installation() {
    local is_env_var_mode=${1:-false}  # Parameter to indicate if we're in environment variable mode
    
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
        for jdk_dir in "${INSTALLATION_DIR}"/*/; do
            if [[ -d "$jdk_dir" && -x "${jdk_dir}bin/java" ]]; then
                # Get the version from the java executable
                java_version=$("${jdk_dir}bin/java" -version 2>&1 | head -1)
                jdk_path="${jdk_dir%/}"  # Remove trailing slash
                jdk_name=$(basename "$jdk_path")
                
                if echo "$java_version" | grep -q "1\.8\|openjdk version \"8"; then
                    echo "" >> ~/.profile
                    echo "# JDK 8 installation" >> ~/.profile
                    echo "export JAVA_8_HOME=${jdk_path}" >> ~/.profile
                    echo "export PATH=\$PATH:${jdk_path}/bin" >> ~/.profile
                elif echo "$java_version" | grep -q "openjdk version \"16\|java version \"16"; then
                    echo "" >> ~/.profile
                    echo "# JDK 16 installation" >> ~/.profile
                    echo "export JAVA_16_HOME=${jdk_path}" >> ~/.profile
                    echo "export PATH=\$PATH:${jdk_path}/bin" >> ~/.profile
                elif echo "$java_version" | grep -q "openjdk version \"17\|java version \"17"; then
                    echo "" >> ~/.profile
                    echo "# JDK 17 installation" >> ~/.profile
                    echo "export JAVA_17_HOME=${jdk_path}" >> ~/.profile
                    echo "export PATH=\$PATH:${jdk_path}/bin" >> ~/.profile
                elif echo "$java_version" | grep -q "openjdk version \"21\|java version \"21"; then
                    echo "" >> ~/.profile
                    echo "# JDK 21 installation" >> ~/.profile
                    echo "export JAVA_21_HOME=${jdk_path}" >> ~/.profile
                    echo "export PATH=\$PATH:${jdk_path}/bin" >> ~/.profile
                elif echo "$java_version" | grep -q "openjdk version \"23\|java version \"23"; then
                    echo "" >> ~/.profile
                    echo "# JDK 23 installation" >> ~/.profile
                    echo "export JAVA_23_HOME=${jdk_path}" >> ~/.profile
                    echo "export PATH=\$PATH:${jdk_path}/bin" >> ~/.profile
                elif echo "$java_version" | grep -q "openjdk version \"24\|java version \"24"; then
                    echo "" >> ~/.profile
                    echo "# JDK 24 installation" >> ~/.profile
                    echo "export JAVA_24_HOME=${jdk_path}" >> ~/.profile
                    echo "export PATH=\$PATH:${jdk_path}/bin" >> ~/.profile
                fi
            fi
        done
    fi
    
    # Add footer and instructions
    echo "" >> ~/.profile
    echo "# To change the default Java version, update the JAVA_HOME line below or re-run this installer" >> ~/.profile
    echo "# ========================================" >> ~/.profile
    
    # Ensure .profile is sourced in .bashrc
    if ! grep "source ~/.profile" ~/.bashrc > /dev/null 2>&1 && ! grep "\[\[ -f ~/.profile \]\] && source ~/.profile" ~/.bashrc > /dev/null 2>&1; then
        echo "[[ -f ~/.profile ]] && source ~/.profile" >> ~/.bashrc
    fi
    
    # Clean up temporary file
    rm -f ~/.profile.backup.tmp
    
    # Ask user to choose default Java version (or auto-select if env var mode)
    ask_for_default_java "$is_env_var_mode"
    
    log_info "Updated ~/.profile with all installed JDK versions"
}

#### MAIN ####

log_info "Setting up JDK ${JDK_VERSION} installation parameters"
select_jdk_version

log_info "Cleaning up any previous JDK entries in .profile"
cleanup_profile

if [[ "$JDK_VERSION" == "ALL" ]]; then
    # Install all JDK versions
    log_info "Installing all JDK versions..."
    install_all_jdks
    
    log_info "Setting environment variables for all installed JDKs"
    set_variables_for_the_installation "$ENV_VAR_MODE"
elif [[ "$JDK_VERSION" == "REMAINING" ]]; then
    # Install remaining JDK versions
    log_info "Installing remaining JDK versions..."
    install_remaining_jdks
    
    log_info "Setting environment variables for all installed JDKs"
    set_variables_for_the_installation "$ENV_VAR_MODE"
elif [[ "$JDK_VERSION" == "SKIP_TO_DEFAULT" ]]; then
    # All versions are installed, skip to default selection
    log_info "Setting environment variables and selecting default JDK"
    set_variables_for_the_installation "$ENV_VAR_MODE"
else
    # Single JDK version installation
    log_info "Checking if JDK ${JDK_VERSION} is already installed"
    if check_if_jdk_version_is_installed; then
        # JDK is already installed, proceed to default selection
        log_info "Setting environment variables if not already set"
        set_variables_for_the_installation "$ENV_VAR_MODE"
    else
        # JDK is not installed, proceed with installation
        log_info "Installing jdk-$JDK_VERSION on your local folder '.local/'..."

        log_info "Downloading and decompressing jdk${JDK_VERSION} from source..."
        install_jdk
        log_info "JDK downloaded and extracted into ${INSTALLATION_DIR}"

        log_info "Setting environment variables if not already set"
        set_variables_for_the_installation "$ENV_VAR_MODE"

        log_info "Checking that java is properly installed..."
        # shellcheck disable=SC1090
        source ~/.bashrc
        if "${INSTALLATION_DIR}/${JDK_EXTRACTED_DIR}/bin/java" -version
        then
            log_info "Java is succesfully installed!"

            how_to_use="
            \tTo start using this java installation, open a new terminal or start a new shell by running 'bash'
            \n\tJDK ${JDK_VERSION} is now available at: ${INSTALLATION_DIR}/${JDK_EXTRACTED_DIR}/bin/java
            \n\tYou can also use JAVA_${JDK_VERSION}_HOME environment variable to reference this specific version
            \n\tOriginally you could run 'source ~/.bashrc', but since some time there's an issue with it
            \tor more info check the issue: https://github.com/BlackCorsair/install-jdk-on-steam-deck/issues/5"
            log_warning "${how_to_use}"
        else
            log_error "Java wasn't installed properly, please check the script :("
            cleanup
        fi
    fi
fi

log_info "Done"
