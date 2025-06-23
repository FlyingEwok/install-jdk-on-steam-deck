#!/bin/bash
# JDK Uninstaller for Steam Deck - Compact Version
# Dynamically detects and removes any installed JDK version (no hardcoded version limits)

INSTALLATION_DIR="${HOME}/.local/jdk"
RED='\033[1;31m' BLUE='\033[0;34m' GREEN='\033[0;32m' YELLOW='\033[1;33m' NC='\033[0m'
log_info() { echo -e "${GREEN}${1}${NC}"; }
log_warning() { echo -e "${BLUE}${1}${NC}"; }
log_error() { echo -e "${RED}${1}${NC}"; }
log_confirm() { echo -e "${YELLOW}${1}${NC}"; }

# Get all installed versions and build arrays
get_installed_versions() {
    installed_versions=() version_homes=() jdk_paths=()
    [[ ! -d "${INSTALLATION_DIR}" ]] && return
    
    for jdk_dir in "${INSTALLATION_DIR}"/*/; do
        [[ ! -d "$jdk_dir" || ! -x "${jdk_dir}bin/java" ]] && continue
        
        java_version=$("${jdk_dir}bin/java" -version 2>&1 | head -1)
        jdk_path="${jdk_dir%/}"
        
        if [[ "$java_version" =~ version[[:space:]]+\"?([0-9]+)(\.[0-9]+)?(\.[0-9]+)?(_[0-9]+)?\"? ]]; then
            version_number="${BASH_REMATCH[1]}"
            [[ "$java_version" =~ 1\.8 ]] && version_number="8"
            
            installed_versions+=("JDK ${version_number}")
            version_homes+=("JAVA_${version_number}_HOME")
            jdk_paths+=("$jdk_path")
        fi
    done
}

# Update profile after removal and handle default selection
update_profile_after_removal() {
    local versions_removed=("$@")
    local default_needs_update=false
    
    # Check if default needs updating
    if [[ -f ~/.profile ]]; then
        current_java_home=$(grep "^export JAVA_HOME=" ~/.profile | head -1 | sed 's/export JAVA_HOME=\$\(.*\)/\1/')
        for version in "${versions_removed[@]}"; do
            [[ "$version" =~ JDK[[:space:]]+([0-9]+) ]] && expected_home="JAVA_${BASH_REMATCH[1]}_HOME"
            [[ "$current_java_home" == "$expected_home" ]] && default_needs_update=true && break
        done
    fi
    
    # Re-scan remaining installations
    get_installed_versions
    
    if [[ ${#installed_versions[@]} -gt 0 ]]; then
        log_info "Updating .profile with remaining JDK installations..."
        
        # Clean and rebuild profile
        [[ -f ~/.profile ]] && grep -v -E "# ={5,}|# JDK.*[Ii]nstallation|export JAVA_.*_HOME|export JAVA_HOME=|export PATH.*jdk.*bin|# To change the default Java version" ~/.profile > ~/.profile.tmp || touch ~/.profile.tmp
        cp ~/.profile.tmp ~/.profile && rm -f ~/.profile.tmp
        
        # Add JDK section
        cat >> ~/.profile << EOF

# ========================================
# JDK Installations managed by install-jdk-on-steam-deck
# ========================================
EOF
        
        # Add remaining JDK versions
        for i in "${!installed_versions[@]}"; do
            version="${installed_versions[i]}" jdk_path="${jdk_paths[i]}"
            [[ "$version" =~ JDK[[:space:]]+([0-9]+) ]] && version_number="${BASH_REMATCH[1]}" || continue
            
            cat >> ~/.profile << EOF

# JDK ${version_number} installation
export JAVA_${version_number}_HOME=${jdk_path}
export PATH=\$PATH:${jdk_path}/bin
EOF
        done
        
        cat >> ~/.profile << EOF

# To change the default Java version, update the JAVA_HOME line below or re-run this installer
# ========================================
EOF
        
        # Handle default Java selection
        if [[ "$default_needs_update" == true && ${#installed_versions[@]} -gt 1 ]]; then
            # Sort and find latest for recommendation
            IFS=$'\n' sorted_versions=($(printf '%s\n' "${installed_versions[@]}" | sed 's/JDK //' | sort -n | sed 's/^/JDK /'))
            unset IFS
            latest_version="${sorted_versions[-1]}"
            latest_index=-1
            for i in "${!installed_versions[@]}"; do
                [[ "${installed_versions[i]}" == "$latest_version" ]] && latest_index=$((i + 1)) && break
            done
            
            echo && log_info "The default Java version was removed. Please choose a new default:"
            for i in "${!installed_versions[@]}"; do
                [[ "${installed_versions[i]}" == "$latest_version" ]] && 
                    echo "  $((i + 1))) ${installed_versions[i]} (recommended - latest version)" ||
                    echo "  $((i + 1))) ${installed_versions[i]}"
            done
            echo
            
            while true; do
                read -p "Enter your choice (1-${#installed_versions[@]}) [default: ${latest_index} for ${latest_version}]: " choice
                [[ -z "$choice" ]] && choice=$latest_index
                
                if [[ "$choice" =~ ^[0-9]+$ && "$choice" -ge 1 && "$choice" -le ${#installed_versions[@]} ]]; then
                    selected_version="${installed_versions[$((choice - 1))]}"
                    selected_home="${version_homes[$((choice - 1))]}"
                    echo "export JAVA_HOME=\$${selected_home}" >> ~/.profile
                    [[ "$selected_version" == "$latest_version" ]] && 
                        log_info "Set ${selected_version} as the default Java version (latest version)" ||
                        log_info "Set ${selected_version} as the default Java version"
                    break
                else
                    echo "Invalid choice. Please enter a number between 1 and ${#installed_versions[@]}, or press Enter for default."
                fi
            done
        else
            # Auto-set latest as default (single version or non-removed default)
            IFS=$'\n' sorted_versions=($(printf '%s\n' "${installed_versions[@]}" | sed 's/JDK //' | sort -n | sed 's/^/JDK /'))
            unset IFS
            latest_version="${sorted_versions[-1]}"
            for i in "${!installed_versions[@]}"; do
                [[ "${installed_versions[i]}" == "$latest_version" ]] && latest_home="${version_homes[i]}" && break
            done
            echo "export JAVA_HOME=\$${latest_home}" >> ~/.profile
            [[ "$default_needs_update" == true ]] && 
                log_info "Set ${latest_version} as the default Java version (only remaining version)" ||
                log_info "Preserved existing default (non-removed version remains active)"
        fi
        
        log_info "Updated ~/.profile with remaining JDK installations"
    else
        # Remove all JDK entries
        [[ -f ~/.profile ]] && {
            grep -v -E "# ={5,}|# JDK.*[Ii]nstallation|export JAVA_.*_HOME|export JAVA_HOME=|export PATH.*jdk.*bin|# To change the default Java version" ~/.profile > ~/.profile.tmp
            mv ~/.profile.tmp ~/.profile
            awk 'BEGIN{blank=0} /^$/{blank++; if(blank<=2) print; next} {blank=0; print}' ~/.profile > ~/.profile.tmp
            mv ~/.profile.tmp ~/.profile
        }
        log_info "Removed all JDK entries from .profile"
    fi
}

# Confirm removal with user
confirm_removal() {
    local items_to_remove=("$@")
    echo && log_confirm "You are about to remove the following:"
    for item in "${items_to_remove[@]}"; do log_confirm "  - $item"; done
    echo && log_confirm "This action cannot be undone!" && echo
    
    while true; do
        read -p "Are you sure you want to proceed? (y/N): " confirm
        [[ -z "$confirm" ]] && confirm="N"
        case $confirm in
            [Yy]|[Yy]es|YES) return 0 ;;
            [Nn]|[Nn]o|NO) log_info "Uninstall cancelled." && exit 0 ;;
            *) echo "Please answer y (yes) or n (no). Default is no." ;;
        esac
    done
}

# Remove specific JDK versions
remove_jdk_versions() {
    local versions_to_remove=("$@") paths_to_remove=()
    
    # Get paths for versions to remove
    for version in "${versions_to_remove[@]}"; do
        for i in "${!installed_versions[@]}"; do
            [[ "${installed_versions[i]}" == "$version" ]] && paths_to_remove+=("${jdk_paths[i]}") && break
        done
    done
    
    confirm_removal "${versions_to_remove[@]}"
    
    # Remove directories
    for path in "${paths_to_remove[@]}"; do
        [[ ! -d "$path" ]] && continue
        log_info "Removing $path..."
        rm -rf "$path" || { log_error "Failed to remove $path" && exit 1; }
        log_info "Successfully removed $path"
    done
    
    update_profile_after_removal "${versions_to_remove[@]}"
    
    # Clean up empty installation directory
    [[ -d "${INSTALLATION_DIR}" && -z "$(ls -A "${INSTALLATION_DIR}")" ]] && {
        log_info "Removing empty installation directory: ${INSTALLATION_DIR}"
        rmdir "${INSTALLATION_DIR}"
    }
    
    log_info "Uninstallation completed successfully!"
    get_installed_versions
    [[ ${#installed_versions[@]} -gt 0 ]] && 
        log_warning "Note: You may need to restart your terminal or run 'source ~/.bashrc' for changes to take effect." ||
        log_warning "All JDK installations have been removed. You may need to restart your terminal."
}

# Remove all JDK installations
remove_all_jdks() {
    [[ ! -d "${INSTALLATION_DIR}" ]] && { log_warning "No JDK installation directory found." && exit 0; }
    
    confirm_removal "ALL JDK installations and the entire ${INSTALLATION_DIR} directory"
    
    log_info "Removing all JDK installations from ${INSTALLATION_DIR}..."
    rm -rf "${INSTALLATION_DIR}" || { log_error "Failed to remove ${INSTALLATION_DIR}" && exit 1; }
    log_info "Successfully removed ${INSTALLATION_DIR}"
    
    # Clean profile completely
    [[ -f ~/.profile ]] && {
        log_info "Cleaning up .profile..."
        grep -v -E "# ={5,}|# JDK.*[Ii]nstallation|export JAVA_.*_HOME|export JAVA_HOME=|export PATH.*jdk.*bin|# To change the default Java version" ~/.profile > ~/.profile.tmp
        mv ~/.profile.tmp ~/.profile
        awk 'BEGIN{blank=0} /^$/{blank++; if(blank<=2) print; next} {blank=0; print}' ~/.profile > ~/.profile.tmp
        mv ~/.profile.tmp ~/.profile
        log_info "Cleaned up .profile"
    }
    
    log_info "All JDK installations have been completely removed!"
    log_warning "You may need to restart your terminal for changes to take effect."
}

#### MAIN ####

get_installed_versions

[[ ${#installed_versions[@]} -eq 0 ]] && { log_warning "No JDK installations found in ${INSTALLATION_DIR}" && exit 0; }

echo && log_info "=== JDK Uninstaller for Steam Deck ===" && echo
log_info "Found the following JDK installations:"

for i in "${!installed_versions[@]}"; do
    echo "  $((i + 1))) ${installed_versions[i]} (${jdk_paths[i]})"
done

echo "  $((${#installed_versions[@]} + 1))) Remove ALL JDK installations"
echo "  $((${#installed_versions[@]} + 2))) Cancel"
echo

while true; do
    read -p "Enter your choice (1-$((${#installed_versions[@]} + 2))): " choice
    
    [[ ! "$choice" =~ ^[0-9]+$ ]] && { echo "Invalid input. Please enter a number." && continue; }
    
    if [[ "$choice" -ge 1 && "$choice" -le ${#installed_versions[@]} ]]; then
        remove_jdk_versions "${installed_versions[$((choice - 1))]}" && break
    elif [[ "$choice" -eq $((${#installed_versions[@]} + 1)) ]]; then
        remove_all_jdks && break
    elif [[ "$choice" -eq $((${#installed_versions[@]} + 2)) ]]; then
        log_info "Uninstall cancelled." && exit 0
    else
        echo "Invalid choice. Please enter a number between 1 and $((${#installed_versions[@]} + 2))."
    fi
done
