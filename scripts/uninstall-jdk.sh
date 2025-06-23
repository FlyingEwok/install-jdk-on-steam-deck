#!/bin/bash

# JDK Uninstaller for Steam Deck
# Dynamically detects and removes any installed JDK version (no hardcoded version limits)
# Works with all versions that the installer supports: JDK 8, 11-25+

INSTALLATION_DIR="${HOME}/.local/jdk"

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

log_confirm() {
    echo -e "${YELLOW}${1}${NC}"
}

log_debug() {
    [[ "${DEBUG:-0}" == "1" ]] && echo -e "${YELLOW}DEBUG: ${1}${NC}"
}

# Get list of all installed Java versions
get_installed_versions() {
    installed_versions=()
    version_homes=()
    jdk_paths=()
    
    if [[ -d "${INSTALLATION_DIR}" ]]; then
        for jdk_dir in "${INSTALLATION_DIR}"/*/; do
            if [[ -d "$jdk_dir" && -x "${jdk_dir}bin/java" ]]; then
                # Get the version from the java executable
                java_version=$("${jdk_dir}bin/java" -version 2>&1 | head -1)
                jdk_path="${jdk_dir%/}"  # Remove trailing slash
                
                # Extract version number dynamically using regex
                if [[ "$java_version" =~ version[[:space:]]+\"?([0-9]+)(\.[0-9]+)?(\.[0-9]+)?(_[0-9]+)?\"? ]]; then
                    version_number="${BASH_REMATCH[1]}"
                    
                    # Handle Java 8 special case (1.8.x format)
                    if [[ "$java_version" =~ 1\.8 ]]; then
                        version_number="8"
                    fi
                    
                    # Add to arrays
                    installed_versions+=("JDK ${version_number}")
                    version_homes+=("JAVA_${version_number}_HOME")
                    jdk_paths+=("$jdk_path")
                    
                    log_debug "Detected JDK ${version_number} at $jdk_path"
                else
                    log_warning "Could not parse version from: $java_version"
                fi
            fi
        done
    fi
}

# Check if the default Java version needs to be updated
check_if_default_needs_update() {
    local versions_to_remove=("$@")
    
    # Get current default JAVA_HOME
    if [[ -f ~/.profile ]]; then
        current_java_home=$(grep "^export JAVA_HOME=" ~/.profile | head -1 | sed 's/export JAVA_HOME=\$\(.*\)/\1/')
        
        # Check if any of the versions being removed is currently the default
        for version in "${versions_to_remove[@]}"; do
            # Extract version number from "JDK X" format
            if [[ "$version" =~ JDK[[:space:]]+([0-9]+) ]]; then
                version_number="${BASH_REMATCH[1]}"
                expected_home="JAVA_${version_number}_HOME"
                
                if [[ "$current_java_home" == "$expected_home" ]]; then
                    return 0  # Default needs update
                fi
            fi
        done
    fi
    
    return 1  # Default doesn't need update
}

# Ask user which Java version they want as default (same logic as install script)
ask_for_default_java() {
    # Get list of all installed Java versions
    get_installed_versions
    
    # Sort versions numerically and find the latest
    IFS=$'\n' sorted_versions=($(printf '%s\n' "${installed_versions[@]}" | sed 's/JDK //' | sort -n | sed 's/^/JDK /'))
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
    
    # If we have multiple versions, ask user to choose default
    if [[ ${#installed_versions[@]} -gt 1 ]]; then
        echo ""
        log_info "Multiple Java versions remaining. Please choose which one should be the default:"
        for i in "${!installed_versions[@]}"; do
            if [[ "${installed_versions[i]}" == "$latest_version" ]]; then
                echo "  $((i + 1))) ${installed_versions[i]} (recommended - latest version)"
            else
                echo "  $((i + 1))) ${installed_versions[i]}"
            fi
        done
        echo ""
        
        while true; do
            read -p "Enter your choice (1-${#installed_versions[@]}) [default: ${latest_index} for ${latest_version}]: " choice
            
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
                    log_info "Set ${selected_version} as the default Java version (latest version)"
                else
                    log_info "Set ${selected_version} as the default Java version"
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
        else
            sed -i "s|^export JAVA_HOME=.*|export JAVA_HOME=\$${selected_home}|" ~/.profile
        fi
        log_info "Set ${selected_version} as the default Java version (only remaining version)"
    fi
}

# Update .profile to reflect remaining installations
update_profile_after_removal() {
    local versions_removed=("$@")
    
    # Check if default needs updating BEFORE we clean the profile
    local default_needs_update=false
    if check_if_default_needs_update "${versions_removed[@]}"; then
        default_needs_update=true
    fi
    
    # Re-scan for remaining installations
    get_installed_versions
    
    if [[ ${#installed_versions[@]} -gt 0 ]]; then
        log_info "Updating .profile with remaining JDK installations..."
        
        # Clean existing JDK entries
        if [[ -f ~/.profile ]]; then
            grep -v -E "# ={5,}|# JDK.*[Ii]nstallation|export JAVA_.*_HOME|export JAVA_HOME=|export PATH.*jdk.*bin|# To change the default Java version" ~/.profile > ~/.profile.backup.tmp 2>/dev/null || true
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
        
        # Add remaining JDK versions
        for i in "${!installed_versions[@]}"; do
            version="${installed_versions[i]}"
            jdk_path="${jdk_paths[i]}"
            
            # Extract version number dynamically
            if [[ "$version" =~ JDK[[:space:]]+([0-9]+) ]]; then
                version_number="${BASH_REMATCH[1]}"
                
                echo "" >> ~/.profile
                echo "# JDK ${version_number} installation" >> ~/.profile
                echo "export JAVA_${version_number}_HOME=${jdk_path}" >> ~/.profile
                echo "export PATH=\$PATH:${jdk_path}/bin" >> ~/.profile
            else
                log_warning "Could not parse version number from: $version"
            fi
        done
        
        # Add footer
        echo "" >> ~/.profile
        echo "# To change the default Java version, update the JAVA_HOME line below or re-run this installer" >> ~/.profile
        echo "# ========================================" >> ~/.profile
        
        # Clean up temporary file
        rm -f ~/.profile.backup.tmp
        
        # Only ask for default selection if the removed version was the current default
        if [[ "$default_needs_update" == true ]]; then
            log_info "The default Java version was removed. Please select a new default."
            ask_for_default_java
        else
            # Set the latest remaining version as default (no prompt needed)
            if [[ ${#installed_versions[@]} -gt 0 ]]; then
                # Sort versions numerically and get the latest
                IFS=$'\n' sorted_versions=($(printf '%s\n' "${installed_versions[@]}" | sed 's/JDK //' | sort -n | sed 's/^/JDK /'))
                unset IFS
                latest_version="${sorted_versions[-1]}"
                
                # Find the corresponding version_home
                for i in "${!installed_versions[@]}"; do
                    if [[ "${installed_versions[i]}" == "$latest_version" ]]; then
                        latest_home="${version_homes[i]}"
                        break
                    fi
                done
                
                echo "export JAVA_HOME=\$${latest_home}" >> ~/.profile
                log_info "Preserved existing default (non-removed version remains active)"
            fi
        fi
        
        log_info "Updated ~/.profile with remaining JDK installations"
        
    else
        # No JDK installations left, clean up all JDK entries
        if [[ -f ~/.profile ]]; then
            grep -v -E "# ={5,}|# JDK.*[Ii]nstallation|export JAVA_.*_HOME|export JAVA_HOME=|export PATH.*jdk.*bin|# To change the default Java version" ~/.profile > ~/.profile.tmp
            mv ~/.profile.tmp ~/.profile
            
            # Remove excessive blank lines
            awk 'BEGIN{blank=0} /^$/{blank++; if(blank<=2) print; next} {blank=0; print}' ~/.profile > ~/.profile.tmp
            mv ~/.profile.tmp ~/.profile
        fi
        log_info "Removed all JDK entries from .profile"
    fi
}

# Show uninstall menu
show_uninstall_menu() {
    get_installed_versions
    
    if [[ ${#installed_versions[@]} -eq 0 ]]; then
        log_warning "No JDK installations found in ${INSTALLATION_DIR}"
        exit 0
    fi
    
    echo ""
    log_info "=== JDK Uninstaller for Steam Deck ==="
    echo ""
    log_info "Found the following JDK installations:"
    
    for i in "${!installed_versions[@]}"; do
        echo "  $((i + 1))) ${installed_versions[i]} (${jdk_paths[i]})"
    done
    
    echo "  $((${#installed_versions[@]} + 1))) Remove ALL JDK installations"
    echo "  $((${#installed_versions[@]} + 2))) Cancel"
    echo ""
}

# Confirm removal
confirm_removal() {
    local items_to_remove=("$@")
    
    echo ""
    log_confirm "You are about to remove the following:"
    for item in "${items_to_remove[@]}"; do
        log_confirm "  - $item"
    done
    echo ""
    log_confirm "This action cannot be undone!"
    echo ""
    
    while true; do
        read -p "Are you sure you want to proceed? (y/N): " confirm
        
        # If user just presses Enter, default to "no"
        if [[ -z "$confirm" ]]; then
            confirm="N"
        fi
        
        case $confirm in
            [Yy]|[Yy]es|YES)
                return 0
                ;;
            [Nn]|[Nn]o|NO)
                log_info "Uninstall cancelled."
                exit 0
                ;;
            *)
                echo "Please answer y (yes) or n (no). Default is no."
                ;;
        esac
    done
}

# Remove specific JDK versions
remove_jdk_versions() {
    local versions_to_remove=("$@")
    local paths_to_remove=()
    
    # Get paths for versions to remove
    for version in "${versions_to_remove[@]}"; do
        for i in "${!installed_versions[@]}"; do
            if [[ "${installed_versions[i]}" == "$version" ]]; then
                paths_to_remove+=("${jdk_paths[i]}")
                break
            fi
        done
    done
    
    # Confirm removal
    confirm_removal "${versions_to_remove[@]}"
    
    # Remove the directories
    for path in "${paths_to_remove[@]}"; do
        if [[ -d "$path" ]]; then
            log_info "Removing $path..."
            rm -rf "$path" || {
                log_error "Failed to remove $path"
                exit 1
            }
            log_info "Successfully removed $path"
        fi
    done
    
    # Update .profile
    update_profile_after_removal "${versions_to_remove[@]}"
    
    # Check if installation directory is empty and remove it
    if [[ -d "${INSTALLATION_DIR}" ]]; then
        if [[ -z "$(ls -A "${INSTALLATION_DIR}")" ]]; then
            log_info "Removing empty installation directory: ${INSTALLATION_DIR}"
            rmdir "${INSTALLATION_DIR}"
        fi
    fi
    
    log_info "Uninstallation completed successfully!"
    
    # Re-scan to get current state after removal and profile update
    get_installed_versions
    
    if [[ ${#installed_versions[@]} -gt 0 ]]; then
        log_warning "Note: You may need to restart your terminal or run 'source ~/.bashrc' for changes to take effect."
    else
        log_warning "All JDK installations have been removed. You may need to restart your terminal."
    fi
}

# Remove all JDK installations
remove_all_jdks() {
    if [[ ! -d "${INSTALLATION_DIR}" ]]; then
        log_warning "No JDK installation directory found."
        exit 0
    fi
    
    # Confirm removal
    confirm_removal "ALL JDK installations and the entire ${INSTALLATION_DIR} directory"
    
    # Remove the entire installation directory
    log_info "Removing all JDK installations from ${INSTALLATION_DIR}..."
    rm -rf "${INSTALLATION_DIR}" || {
        log_error "Failed to remove ${INSTALLATION_DIR}"
        exit 1
    }
    
    log_info "Successfully removed ${INSTALLATION_DIR}"
    
    # Clean up .profile completely
    if [[ -f ~/.profile ]]; then
        log_info "Cleaning up .profile..."
        grep -v -E "# ={5,}|# JDK.*[Ii]nstallation|export JAVA_.*_HOME|export JAVA_HOME=|export PATH.*jdk.*bin|# To change the default Java version" ~/.profile > ~/.profile.tmp
        mv ~/.profile.tmp ~/.profile
        
        # Remove excessive blank lines
        awk 'BEGIN{blank=0} /^$/{blank++; if(blank<=2) print; next} {blank=0; print}' ~/.profile > ~/.profile.tmp
        mv ~/.profile.tmp ~/.profile
        
        log_info "Cleaned up .profile"
    fi
    
    log_info "All JDK installations have been completely removed!"
    log_warning "You may need to restart your terminal for changes to take effect."
}

#### MAIN ####

show_uninstall_menu

while true; do
    read -p "Enter your choice (1-$((${#installed_versions[@]} + 2))): " choice
    
    if [[ "$choice" =~ ^[0-9]+$ ]]; then
        if [[ "$choice" -ge 1 ]] && [[ "$choice" -le ${#installed_versions[@]} ]]; then
            # Remove specific version
            selected_version="${installed_versions[$((choice - 1))]}"
            remove_jdk_versions "$selected_version"
            break
        elif [[ "$choice" -eq $((${#installed_versions[@]} + 1)) ]]; then
            # Remove all versions
            remove_all_jdks
            break
        elif [[ "$choice" -eq $((${#installed_versions[@]} + 2)) ]]; then
            # Cancel
            log_info "Uninstall cancelled."
            exit 0
        else
            echo "Invalid choice. Please enter a number between 1 and $((${#installed_versions[@]} + 2))."
        fi
    else
        echo "Invalid input. Please enter a number."
    fi
done
