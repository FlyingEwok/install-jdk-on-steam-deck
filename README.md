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

**Multi-Version Support**: You can install multiple JDK versions side-by-side. Each version gets its own directory and environment variables, allowing you to easily switch between Java versions for different projects.

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

**Version Detection**: The script intelligently detects if a specific JDK version is already installed and skips reinstallation, while allowing you to install other versions side-by-side. If the requested version is already installed, the script proceeds directly to the default version selection menu.

**Smart Default Selection**: When multiple JDK versions are installed, the script presents an interactive menu to choose your default Java version, automatically recommending the latest (highest numbered) version. You can simply press Enter to accept the recommended default or choose any other installed version.

Usage
=====

You can choose which version to install by setting the variable `JDK_VERSION` before executing the script, you can
even do it on the same command! If you don't select any version, `jdk-24` will be installed by default.

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

To install **jdk-24** (Oracle - default):
```bash
git clone https://github.com/BlackCorsair/install-jdk-on-steam-deck.git && \
./install-jdk-on-steam-deck/scripts/install-jdk.sh
```

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
After installing multiple JDK versions, the script will prompt you to choose which one should be the default:

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

**Re-running with existing versions:**
If you run the script to install a JDK version that's already installed, the script will:

1. **Detect existing installation**: Skip the download and installation process
2. **Update environment variables**: Refresh your `.profile` with all currently installed JDKs
3. **Prompt for default selection**: Allow you to change which version is your default

This means you can re-run the script at any time to change your default Java version or refresh your environment setup.

How to uninstall it
===================

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

TO-DO
=====

* Add an uninstall script or option
* ~~Add support for java 8~~ ✅ **COMPLETED**
* ~~Add support for multiple JDK versions~~ ✅ **COMPLETED**
* ~~Add interactive default Java version selection~~ ✅ **COMPLETED**
* ~~Improve error handling to preserve existing installations~~ ✅ **COMPLETED**
* Add support for switching between installed JDK versions easily
* If you want anything added, just let me know by opening an [issue][3]

[1]: https://partner.steamgames.com/doc/steamdeck/faq
[2]: https://www.flatpak.org/
[3]: https://github.com/BlackCorsair/install-jdk-on-steam-deck/issues/new
[4]: https://man.freebsd.org/cgi/man.cgi?query=sh&manpath=Unix+Seventh+Edition
[5]: https://www.gnu.org/savannah-checkouts/gnu/bash/manual/bash.html#Bash-Startup-Files
