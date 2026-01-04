# Plutonium Automated Installer v1.0

## Supported Distributions

- Ubuntu 22.04+ (Jammy, Noble)
- Debian 11+ (Bullseye, Bookworm, Trixie)
- Arch Linux (including Manjaro, EndeavourOS, CachyOS)
- Fedora 40+ (including Nobara)
- Solus

## System Requirements
- 64-bit Linux system
- Active internet connection
- User account with sudo privileges
- At least 5GB free disk space for packages, plutonium, and wine prefix
- Terminal (Konsole, Alacritty, Kitty, etc.)

## Not Supported/Unknown Status

- Bazzite
- SteamOS
- Really anything else not mentioned


## Quick Start

### Download and Run
Install the plutonium_installer.sh script from the [github repository](https://github.com/Astrocule/CoD-Client-Projects/blob/main/Plutonium/plutonium_install.sh) (Download arrow, top right)
```bash
# Make it executable
chmod +x plutonium_install.sh

# Run the installer
./plutonium_install.sh
```

### What to Expect

The script will:
1. Show welcome message and overview
2. Ask for confirmation to start
3. Check sudo privileges
4. Detect your distribution
5. Prompt before each installation step
6. Create logs in the same directory as script is run in
7. Set up Wine prefix with your approval
8. Display detailed summary at the end


## Post-Installation Steps

After successful installation:

### 1. Download Plutonium
```bash
cd ~/wine/plutonium
wget https://cdn.plutonium.pw/updater/plutonium.exe
# Or download from: https://plutonium.pw/ and place file in location above
```

### 2. Install Heroic Games Launcher
```bash
# Flatpak (recommended)
flatpak install flathub com.heroicgameslauncher.hgl

# Or download from: https://heroicgameslauncher.com/
```
---
### 3. Configure Heroic
1. Open Heroic Games Launcher
2. Click **Library** → **Add Game** → **Add Non-Steam Game**
3. Fill in details:
   - **Title**: Plutonium
   - **Executable**: `/home/YOUR_USERNAME/wine/plutonium/plutonium.exe`
4. Click **Wine Settings** tab:
   - **Wine Prefix**: `/home/YOUR_USERNAME/wine/plutonium`
   - **Wine Version**: Select **GE-Proton-Latest** (GE-Proton RECOMMENDED!!!)
5. Click **Save**

---

### 4. Launch and Configure
1. Launch Plutonium from Heroic
2. When prompted, navigate to your Steam game folder
3. Default location: `~/.steam/steam/steamapps/common/[Game Name]`
4. Examples:
   - Black Ops II: `~/.steam/steam/steamapps/common/Call of Duty Black Ops II`
   - Modern Warfare 3: `~/.steam/steam/steamapps/common/Call of Duty Modern Warfare 3`

---
### User Experience Features
- **Interactive Prompts**: Step-by-step confirmation before each major action
- **Comprehensive Logging**: All operations logged to timestamped files
- **Error Tracking**: Separate error log for troubleshooting
- **Sudo Verification**: Checks if user has sudo privileges before starting
- **Better Feedback**: Color-coded output with clear status indicators

### Distribution-Specific Enhancements
- **Debian**: Automatic contrib repository detection and enabling
- **Arch**: Interactive multilib configuration with editor support
- **All Distros**: Improved package installation with fallback options

### Quality of Life Features
- **Detailed Summary**: Complete installation report at the end
- **Error Handling**: Graceful error recovery with helpful messages
- **Skip Options**: Can skip non-critical installation steps
- **Progress Indicators**: Clear indication of long-running operations


# Features

### Automatic Detection & Installation
- Detects Linux distribution automatically
- Installs appropriate Wine version
- Configures all required 32-bit libraries
- Sets up dedicated Wine prefix

### Sudo Privilege Verification
The script checks if your user has sudo privileges and provides instructions if not:


### Comprehensive Logging
Two log files are created in the script directory:
- `plutonium_install_YYYYMMDD_HHMMSS.log` - Complete installation log
- `plutonium_errors_YYYYMMDD_HHMMSS.log` - Error-specific log

Example log entry:
```
[2026-01-03 14:23:45] INFO: Detected: Ubuntu 24.04
[2026-01-03 14:24:12] SUCCESS: Wine Staging installed
[2026-01-03 14:25:33] WARNING: Some optional dependencies failed
```

# Log Files

### Installation Log
Contains complete record of:
- All commands executed
- Package installations
- Success/failure status
- User choices
- Timestamps for every action

Location: `plutonium_install_YYYYMMDD_HHMMSS.log`

### Error Log
Contains only:
- Error messages
- Failed operations
- Exception details
- Troubleshooting information

Location: `plutonium_errors_YYYYMMDD_HHMMSS.log`

# Troubleshooting

### Script Says I'm Not in Sudoers

**Solution**:
```bash
# Switch to root
su -

# Add your user to sudo group (replace 'username' with your actual username)
sudo adduser username sudo

# On some systems, use:
sudo usermod -aG sudo username

# Restart your computer
reboot

# Run the script again
./plutonium_install_v2.sh
```

### Contrib Repository Issues (Debian)

**Problem**: winetricks not available on Debian

**Solution**: The script will automatically detect this and offer to enable contrib repository. If you declined or it failed:

```bash
# Manual method
sudo sed -i.backup 's/^deb(.*)$/deb\1 contrib/g' /etc/apt/sources.list
sudo apt update
sudo apt install winetricks
```

### Multilib Not Enabled (Arch)

**Problem**: 32-bit packages unavailable

**Solution**: The script will prompt you to edit `/etc/pacman.conf`. Uncomment:
```
[multilib]
Include = /etc/pacman.d/mirrorlist
```

Save file and continue with the script.

### Installation Hangs During Winetricks

**Problem**: Winetricks appears frozen

**Solution**: 
- Wait at least 5 minutes (some components are large)
- Check the log file for progress
- Error dialogs are normal - don't close them manually
- If truly frozen (10+ minutes), Ctrl+C and check error log

### Package Not Found Errors

**Problem**: Some packages fail to install

**Solution**:
- Check if you're using the latest distribution version
- Update your system first: `sudo apt update && sudo apt upgrade`
- Check the error log for specific package names
- Some optional packages failing is normal and won't affect Plutonium

### Wine Version Conflicts

**Problem**: Multiple Wine versions installed

**Solution**:
```bash
# List installed Wine packages
dpkg -l | grep wine    # Debian/Ubuntu
pacman -Q | grep wine  # Arch
dnf list installed | grep wine  # Fedora

# Remove old versions if needed
sudo apt remove wine-stable  # Example for Ubuntu
```

## Extra Usage


### View Logs During Installation

Open a second terminal:
```bash
# Watch installation log in real-time
tail -f plutonium_install_*.log

# View errors only
tail -f plutonium_errors_*.log
```

### Retry Failed Components

If some components failed:
```bash
# Check error log for failed component names
cat plutonium_errors_*.log

# Retry individual component
WINEPREFIX=~/wine/plutonium winetricks [component_name]

# Example:
WINEPREFIX=~/wine/plutonium winetricks vcrun2019
```

### Custom Wine Prefix Location

To use a different location, modify the script:
```bash
# Edit the script
nano plutonium_install_v2.sh

# Find line:
WINE_PREFIX="$HOME/wine/plutonium"

# Change to your preferred location:
WINE_PREFIX="/path/to/your/prefix"
```

## Uninstallation

### Remove Wine Prefix Only
```bash
# This preserves Wine installation, removes only Plutonium prefix
rm -rf ~/wine/plutonium
```

### Remove Wine and Dependencies

**Ubuntu/Debian:**
```bash
sudo apt remove winehq-staging wine wine32 winetricks
sudo apt autoremove
```

**Arch:**
```bash
sudo pacman -Rns wine wine-mono wine-gecko winetricks
```

**Fedora:**
```bash
sudo dnf remove wine winetricks dxvk
```

**Solus:**
```bash
sudo eopkg remove wine wine-32bit winetricks dxvk
```

### Clean Up Logs
```bash
# Remove all installation logs from script directory
rm plutonium_install_*.log plutonium_errors_*.log
```

## Distribution-Specific Notes

### Ubuntu
- Uses WineHQ repository for latest Wine Staging
- Falls back to Ubuntu repository if WineHQ unavailable
- Automatically handles codename detection (noble, jammy, etc.)

### Debian
- Checks and enables contrib repository for winetricks
- Creates backup of sources.list before modification
- Supports Bookworm (12) and Trixie (13)
- Falls back to Debian Wine if WineHQ unavailable

### Arch Linux
- Interactive multilib configuration
- Offers to open pacman.conf in editor
- AUR support for DXVK (requires yay or paru)

### Fedora
- Detects Nobara and uses appropriate update command
- Includes WoW64 support for Fedora 40+
- Handles optional 32-bit dependencies gracefully
- Some packages may not exist in newer versions (expected), will skip if packages are not found

### Solus
- Uses native Solus repositories
- wine-32bit package includes 64-bit Wine
- Simplified installation process

## Color Code Reference

The script uses colors for easy reading:

- 🔵 **Blue** (Info): General information
- 🟢 **Green** (Success): Completed successfully
- 🟡 **Yellow** (Warning): Non-critical issues
- 🔴 **Red** (Error): Critical problems
- 🔷 **Cyan** (Step): Action prompts

## Support

### Check Logs First
Always review your log files before asking for help:
```bash
# View installation log
cat plutonium_install_*.log

# View errors only
cat plutonium_errors_*.log

# Search for specific error
grep -i "error\|fail" plutonium_install_*.log
```

### Getting Help
Contact me on Discord or Make an issue on Github
- Include your distribution name and version
- Attach relevant portions of error log
- List steps you've already tried

### Bug Reports
When reporting issues, include:
1. Distribution and version (`cat /etc/os-release`)
2. Script version (top of log file)
3. Full error log
4. Steps to reproduce
5. Wine version (`wine --version`)

## License

This script is provided as-is for the Plutonium community.

## Disclaimer

- Plutonium officially supports Windows only
- Use on Linux at your own risk
- Requires legitimate game ownership
- Anti-cheat will not work on Linux (LAN mode only)
- Always keep backups of important data


Extra troubleshooting/steps for games can be found on my written guide for Plutonium forumns https://forum.plutonium.pw/topic/37097/plutonium-on-linux-ultimate-cross-distro-guide
