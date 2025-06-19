#!/bin/bash

if [[ -z "$JDK_VERSION" ]];
then
    JDK_VERSION=24
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

JDK_23_URL=https://download.oracle.com/java/23/latest/jdk-23_linux-x64_bin.tar.gz
JDK_23_CHECKSUM_URL=https://download.oracle.com/java/23/latest/jdk-23_linux-x64_bin.tar.gz.sha256
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

INSTALLATION_DIR="${HOME}/.local/jdk"

CURRENT_DIR=$(pwd)

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
        *)
            log_error "The version you've selected isn't supported, either set JDK_VERSION=8, JDK_VERSION=16, JDK_VERSION=17, JDK_VERSION=21, JDK_VERSION=23, or JDK_VERSION=24"
            cleanup
            exit 1
            ;;
    esac
}

# Check if the specific JDK version is already installed in our installation directory
exit_if_jdk_version_is_installed() {
    if [[ -d "${INSTALLATION_DIR}" ]]; then
        # Look for any JDK directory that might contain the version we're trying to install
        for jdk_dir in "${INSTALLATION_DIR}"/*/; do
            if [[ -d "$jdk_dir" && -x "${jdk_dir}bin/java" ]]; then
                # Get the version from the java executable
                java_version=$("${jdk_dir}bin/java" -version 2>&1 | head -1)
                case $JDK_VERSION in
                    8)
                        if echo "$java_version" | grep -q "1\.8\|openjdk version \"8"; then
                            log_warning "JDK ${JDK_VERSION} is already installed in ${jdk_dir}, the installer will skip the installation"
                            exit 0
                        fi
                        ;;
                    16|17|21|23|24)
                        if echo "$java_version" | grep -q "openjdk version \"${JDK_VERSION}\|java version \"${JDK_VERSION}"; then
                            log_warning "JDK ${JDK_VERSION} is already installed in ${jdk_dir}, the installer will skip the installation"
                            exit 0
                        fi
                        ;;
                esac
            fi
        done
    fi
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
    
    # If we have multiple versions, ask user to choose default
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
    # Backup original .profile if it exists and contains non-JDK content
    if [[ -f ~/.profile ]]; then
        # Extract non-JDK lines to preserve user's custom settings
        grep -v "# JDK.*installation\|export JAVA_.*_HOME\|export JAVA_HOME\|export PATH.*jdk.*bin\|# To change the default Java version" ~/.profile > ~/.profile.backup.tmp 2>/dev/null || true
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
    
    # Ask user to choose default Java version
    ask_for_default_java
    
    log_info "Updated ~/.profile with all installed JDK versions"
}

#### MAIN ####

log_info "Checking if JDK ${JDK_VERSION} is already installed"
exit_if_jdk_version_is_installed

log_info "Validating jdk version selected, if none set jdk-24 will be used"
select_jdk_version

log_info "Installing jdk-$JDK_VERSION on your local folder '.local/'..."

log_info "Downloading and decompressing jdk17 from oracle page..."
install_jdk
log_info "JDK downloaded and extracted into ${INSTALLATION_DIR}"

log_info "Setting environment variables if not already set"
set_variables_for_the_installation

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

log_info "Done"
