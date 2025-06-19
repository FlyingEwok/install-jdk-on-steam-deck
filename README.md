install-jdk-on-steam-deck
=========================

<!--ts-->
* [How it works](#how-it-works)
* [Usage](#usage)
* [TO-DO](#to-do)
<!--te-->

How it works
============
By default, the SteamDeck has a [read-only][1] immutable OS file system, which means that you can't simply
install anything using the `pacman` package manager that comes with the OS (arch linux), since it would modify
the OS file system.

So in order to install anything outside the Software Center (which installs programs in a way that doesn't affect
the OS by using [flatpak][2]), you have to modify things in you *home* directory, which shouldn't mess up with the OS
and break the system.

Taking this into account, the script located in the `scripts` directory of this repository will:
* Download the official JDK compressed file into your **home** directory, more specifically into `~/.local/jdk`
* Exec a checksum of the file using the official sha256 checksum
* Extract the file into the JDK's own version-specific directory (e.g., `~/.local/jdk/jdk-17.0.1/`, `~/.local/jdk/jdk-21.0.5/`, `~/.local/jdk/jdk-24.0.1/`, etc.)
* Add environment variables to your `~/.profile` and source it in your bashrc for each installed version:
    * `JAVA_{VERSION}_HOME`: Version-specific home (e.g., `JAVA_17_HOME`, `JAVA_21_HOME`)
    * `JAVA_HOME`: Points to your chosen default version (with smart recommendations)
    * `PATH`: Adds each version's `bin` directory so all executables are available

**Multi-Version Support**: You can install multiple JDK versions side-by-side. Each version gets its own directory and environment variables, allowing you to easily switch between Java versions for different projects. The script also supports installing all supported JDK versions at once for maximum compatibility.

By adding the variables to `.profile` instead of `.bashrc` we ensure to be more "shell agnostic", so if you run
a script in another shell like `sh` or launch a graphical program, it should read the environment variables defined there.

`.profile` is "manually" sourced in `.bashrc` since `bash` will try to source first `.bash_profile` and `.bash_login` if they exist.
To learn about this:
* [man sh: Invocation][4]
* [bash manual: Invoked with name sh][5].

With this, you will have a *local* installation of java and even better, you can install multiple versions and then point
to the one you need.

**Supported JDK Versions:**
* **JDK 8**: Eclipse Temurin (no authentication required)
* **JDK 16**: OpenJDK from java.net
* **JDK 17**: OpenJDK from java.net
* **JDK 21**: Oracle JDK (latest)
* **JDK 23**: OpenJDK from java.net
* **JDK 24**: Oracle JDK (latest)

**Smart Version Detection**: The script intelligently detects which JDK versions are already installed by scanning for Java executables and parsing their version output. It only shows uninstalled versions in the installation menu, making it clear what options are available.

**Intelligent Menu System**: 
- **No JDKs installed**: Shows all available versions for installation
- **Some JDKs installed**: Displays which versions are already installed, shows only uninstalled versions for installation, and includes a "Skip to change defaults" option
- **All JDKs installed**: Automatically skips to default version selection

**Smart Default Selection**: When multiple JDK versions are installed, the script presents an interactive menu to choose your default Java version, automatically recommending the latest (highest numbered) version. You can simply press Enter to accept the recommended default or choose any other installed version.

Usage
=====

The script supports both **interactive mode** and **environment variable mode** for version selection.

### **Interactive Mode (Recommended for new users):**
Simply run the script without specifying a version, and it will present an interactive menu:

```bash
git clone https://github.com/BlackCorsair/install-jdk-on-steam-deck.git && \
./install-jdk-on-steam-deck/scripts/install-jdk.sh
```

The script will show:
```
=== JDK Installer for Steam Deck ===

Please select which JDK version you would like to install:

  1) JDK 8 (Eclipse Temurin)
  2) JDK 16 (OpenJDK)
  3) JDK 17 (OpenJDK)
  4) JDK 21 (Oracle)
  5) JDK 23 (OpenJDK)
  6) JDK 24 (Oracle - recommended)
  7) Install All Remaining JDK Versions (8, 16, 17, 21, 23, 24)

Enter your choice (1-7) [default: 6 for JDK 24]:
```

**If some JDKs are already installed**, the script will show which ones are installed and only list uninstalled versions:
```
=== JDK Installer for Steam Deck ===

Already installed JDK versions: 24 8

Please select which JDK version you would like to install:

  1) JDK 16 (OpenJDK)
  2) JDK 17 (OpenJDK)
  3) JDK 21 (Oracle)
  4) JDK 23 (OpenJDK)
  5) Install All Remaining JDK Versions (16 17 21 23)
  6) Skip installation and change default Java version

Enter your choice (1-6) [default: 4 for JDK 23]:
```

**If all JDKs are already installed**, the script will automatically proceed to default version selection without showing an installation menu.

### **Environment Variable Mode (For automation/scripts):**
You can choose which version to install by setting the variable `JDK_VERSION` before executing the script, you can
even do it on the same command! This method is perfect for automated installations and CI/CD pipelines.

**When using environment variables:**
- **No interactive prompts**: The script runs completely automated
- **Smart default selection**: Automatically sets the latest (highest numbered) installed JDK version as the default
- **Install all versions**: Use `JDK_VERSION=ALL` to install all supported JDK versions at once
- **Install remaining versions**: Use `JDK_VERSION=REMAINING` to install only uninstalled versions
- **Skip to defaults**: Use `JDK_VERSION=SKIP_TO_DEFAULT` to skip installation and just change the default version

**Install multiple versions for different projects:**

To install **jdk-8** (Eclipse Temurin):
```bash
git clone https://github.com/BlackCorsair/install-jdk-on-steam-deck.git && \
JDK_VERSION=8 ./install-jdk-on-steam-deck/scripts/install-jdk.sh
```

To install **jdk-16** (OpenJDK):
```bash
git clone https://github.com/BlackCorsair/install-jdk-on-steam-deck.git && \
JDK_VERSION=16 ./install-jdk-on-steam-deck/scripts/install-jdk.sh
```

To install **jdk-17** (OpenJDK):
```bash
git clone https://github.com/BlackCorsair/install-jdk-on-steam-deck.git && \
JDK_VERSION=17 ./install-jdk-on-steam-deck/scripts/install-jdk.sh
```

To install **jdk-21** (Oracle):
```bash
git clone https://github.com/BlackCorsair/install-jdk-on-steam-deck.git && \
JDK_VERSION=21 ./install-jdk-on-steam-deck/scripts/install-jdk.sh
```

To install **jdk-23** (OpenJDK):
```bash
git clone https://github.com/BlackCorsair/install-jdk-on-steam-deck.git && \
JDK_VERSION=23 ./install-jdk-on-steam-deck/scripts/install-jdk.sh
```

To install **jdk-24** (Oracle):
```bash
git clone https://github.com/BlackCorsair/install-jdk-on-steam-deck.git && \
JDK_VERSION=24 ./install-jdk-on-steam-deck/scripts/install-jdk.sh
```

**To install ALL JDK versions at once** (8, 16, 17, 21, 23, 24):
```bash
git clone https://github.com/BlackCorsair/install-jdk-on-steam-deck.git && \
JDK_VERSION=ALL ./install-jdk-on-steam-deck/scripts/install-jdk.sh
```

**To install only remaining (uninstalled) JDK versions**:
```bash
git clone https://github.com/BlackCorsair/install-jdk-on-steam-deck.git && \
JDK_VERSION=REMAINING ./install-jdk-on-steam-deck/scripts/install-jdk.sh
```

**To skip installation and just change the default Java version** (automatically sets latest as default):
```bash
git clone https://github.com/BlackCorsair/install-jdk-on-steam-deck.git && \
JDK_VERSION=SKIP_TO_DEFAULT ./install-jdk-on-steam-deck/scripts/install-jdk.sh
```

**Which Mode Should You Use?**
- **Interactive Mode**: Best for most users, especially first-time installations. Provides clear options and guidance. Automatically detects installed versions and shows relevant options.
- **Environment Variable Mode**: Perfect for automation, scripts, CI/CD pipelines, or when you know exactly which version you need. Automatically sets the latest version as default without prompting.

**Using specific versions in your projects:**
After installation, you can reference specific versions using:
- `$JAVA_8_HOME/bin/java` for JDK 8
- `$JAVA_16_HOME/bin/java` for JDK 16
- `$JAVA_17_HOME/bin/java` for JDK 17  
- `$JAVA_21_HOME/bin/java` for JDK 21
- `$JAVA_23_HOME/bin/java` for JDK 23
- `$JAVA_24_HOME/bin/java` for JDK 24

Or simply use `java` which will use the default `JAVA_HOME` (your chosen default version).

**Default Java Version Selection:**
After installing multiple JDK versions, the behavior depends on how you run the script:

**Interactive Mode**: The script will prompt you to choose which version should be the default:

```
Multiple Java versions detected. Please choose which one should be the default:
  1) JDK 8
  2) JDK 16
  3) JDK 17
  4) JDK 21
  5) JDK 24 (recommended - latest version)

Enter your choice (1-5) [default: 5 for JDK 24]: 
```

- **Press Enter**: Accept the recommended latest version (JDK 24 in this example)
- **Choose a number**: Select any specific version as your default
- **Latest is recommended**: The script automatically identifies and recommends the highest version number

**Environment Variable Mode**: The script automatically sets the latest (highest numbered) installed JDK version as the default without prompting (defaults to latest). This ensures automated installations work smoothly without user interaction.

**Re-running with existing versions:**
The script intelligently handles scenarios when you already have JDK versions installed:

1. **Detects existing installations**: Automatically scans for installed JDK versions and displays them
2. **Shows only relevant options**: Only displays uninstalled versions in the installation menu
3. **Skip installation option**: Provides a "Skip installation and change default Java version" option when versions are already installed
4. **Automatic behavior for complete installations**: If all supported versions are installed, automatically proceeds to default version selection
5. **Updates environment variables**: Refreshes your `.profile` with all currently installed JDKs
6. **Preserves existing installations**: Never overwrites or damages existing JDK installations

This means you can re-run the script at any time to:
- Install additional JDK versions alongside existing ones
- Change your default Java version
- Refresh your environment setup
- Use the "Skip to defaults" option to quickly change defaults without installing anything

How to uninstall it
===================

**Interactive Uninstall Script (Recommended):**
The repository now includes a dedicated uninstall script that provides an interactive menu for safe removal:

```bash
# Run the interactive uninstall script
./install-jdk-on-steam-deck/scripts/uninstall-jdk.sh
```

The uninstall script will:
1. **Detect all installed JDK versions** automatically
2. **Present an interactive menu** with options to:
   - Remove individual JDK versions
   - Remove all JDK installations at once
   - Cancel the operation
3. **Safely clean up environment variables** from your `.profile`
4. **Update remaining installations** if you only remove some versions
5. **Require confirmation** before any destructive operations

Example menu:
```
=== JDK Uninstaller for Steam Deck ===

Found the following JDK installations:
  1) JDK 8 (/home/deck/.local/jdk/jdk8u422-b05)
  2) JDK 17 (/home/deck/.local/jdk/jdk-17.0.1)
  3) JDK 21 (/home/deck/.local/jdk/jdk-21.0.5)
  4) JDK 24 (/home/deck/.local/jdk/jdk-24.0.1)
  5) Remove ALL JDK installations
  6) Cancel

Enter your choice (1-6):
```

**Manual Uninstall (Alternative):**

**Manual Uninstall (Alternative):**

**To remove a specific JDK version:**
```bash
# Remove JDK 17 installation (replace with actual directory name)
rm -rf ~/.local/jdk/jdk-17.0.1

# Remove JDK 21 installation (replace with actual directory name)
rm -rf ~/.local/jdk/jdk-21.0.5

# Remove JDK 24 installation (replace with actual directory name)
rm -rf ~/.local/jdk/jdk-24.0.1

# Or find the exact directory names first:
ls ~/.local/jdk/
```

**To remove all JDK installations:**
```bash
# Remove the entire installation directory
rm -rf ~/.local/jdk
```

**To clean up environment variables:**
```bash
# Edit ~/.profile and remove the JDK-related lines:
# export JAVA_8_HOME=...
# export JAVA_16_HOME=...
# export JAVA_17_HOME=...  
# export JAVA_HOME=...
# export PATH=$PATH:...jdk.../bin
nano ~/.profile

# Optionally, remove the line added to your bashrc:
# [[ -f ~/.profile ]] && source ~/.profile
# (This line is harmless and will simply do nothing if ~/.profile doesn't exist)
```

**Switching default Java version:**
- **Easy method**: Re-run the installer script for any installed version - it will prompt you to choose a new default
- **Manual method**: Edit `~/.profile` and modify the `export JAVA_HOME=` line to point to your preferred version's `JAVA_{VERSION}_HOME`

**Safe Installation Process:**
The script includes improved error handling that only cleans up files related to the current installation attempt, preserving all your existing JDK installations if something goes wrong.

## Troubleshooting

**Debug Mode:**
If you encounter issues with JDK detection (e.g., installed JDKs not being recognized), you can run the script in debug mode to get detailed information about what's happening:

```bash
DEBUG=1 ./scripts/install-jdk.sh
```

This will show:
- Which directories are being checked for JDK installations
- Java version output from each detected installation
- Detection results for each JDK version  
- Any errors encountered during the detection process
- Installation directory status and contents

**Common Issues:**
1. **JDKs not detected**: This can happen if:
   - Java executables are corrupted or incomplete
   - Directory permissions are incorrect
   - The Java version string format is unexpected
   
   Run with `DEBUG=1` to see exactly what's happening during detection.

2. **Installation fails**: Make sure you have enough disk space and proper write permissions to `~/.local/jdk/`

3. **Environment variables not working**: After installation, make sure to either:
   - Log out and log back in, OR
   - Run `source ~/.profile` in your current terminal

4. **Script shows wrong installed versions**: The detection relies on executable Java binaries. If a JDK installation is incomplete or corrupted, it may not be detected properly.

**Getting Help:**
If debug mode shows unexpected behavior, please include the debug output when reporting issues. This helps identify platform-specific detection problems and makes troubleshooting much faster.

**Standalone Debug Script:**
For more detailed troubleshooting, you can create a debug script to check the detection system:

```bash
# Create a debug script to test detection
DEBUG=1 bash -c 'source ./scripts/install-jdk.sh; check_installed_versions'
```

This provides comprehensive information about:
- Installation directory status and contents
- Java executable availability and permissions
- Version detection pattern matching
- System information and environment variables

Share the output when reporting detection issues for faster troubleshooting.

TO-DO
=====

* ~~Add an uninstall script or option~~ ✅ **COMPLETED**
* ~~Add support for java 8~~ ✅ **COMPLETED**
* ~~Add support for multiple JDK versions~~ ✅ **COMPLETED**
* ~~Add interactive default Java version selection~~ ✅ **COMPLETED**
* ~~Improve error handling to preserve existing installations~~ ✅ **COMPLETED**
* ~~Add support for switching between installed JDK versions easily~~ ✅ **COMPLETED**
* ~~Add intelligent version detection to avoid reinstalling existing versions~~ ✅ **COMPLETED**
* ~~Add smart menu system that only shows relevant installation options~~ ✅ **COMPLETED**
* ~~Add "Skip to change defaults" option for existing installations~~ ✅ **COMPLETED**
* If you want anything added, just let me know by opening an [issue][3]

[1]: https://partner.steamgames.com/doc/steamdeck/faq
[2]: https://www.flatpak.org/
[3]: https://github.com/BlackCorsair/install-jdk-on-steam-deck/issues/new
[4]: https://man.freebsd.org/cgi/man.cgi?query=sh&manpath=Unix+Seventh+Edition
[5]: https://www.gnu.org/savannah-checkouts/gnu/bash/manual/bash.html#Bash-Startup-Files
