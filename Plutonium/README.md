# Plutonium Automated Installer v1.0-1

## Supported Distributions

- Ubuntu 22.04+ (Jammy, Noble)
- Mint 20.0+ (Noble, Jammy, Focal)
- Debian 11+ (Bullseye, Bookworm, Trixie)
- Arch Linux (including Manjaro, EndeavourOS, CachyOS)
- Fedora 40+ (including Nobara)
- Solus
- SteamOS/Bazzite/CachyOS-Handheld

## System Requirements
- Linux system
- Active internet connection
- User account with sudo privileges
- At least 5GB free disk space for packages, plutonium, and wine prefix
- Terminal (Konsole, Alacritty, Kitty, etc.)

## Not Supported/Unknown Status

- Really anything not mentioned, open issue request to request Distro support.


## Quick Start

### Download and Run

```bash
# Install script
wget https://github.com/Astrocule/CoD-Client-Projects/blob/main/Plutonium/plutonium_install.sh

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

### 2. Install Heroic Games Launcher (or use another viable launcher)
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

### Launch Args / Environment Variables
These options will HEAVILY boost performance on these CoD titles, I highly recommend using these, and if not able to, configuring your system to be able to use them. If you are unaware of how to use/where to put these, simply google [Launcher name how to add launch arguments]

Some launchers may not respect certain name schemes (~/wine/plutonium, /home/$USER/wine/plutonium, etc.), if you realize something isn't working, try using different schemas.

```
DXVK_ASYNC=0
DXVK_STATE_CACHE=1
DXVK_STATE_CACHE_PATH=/home/$USER/wine/plutonium
__GL_SHADER_DISK_CACHE=1
__GL_SHADER_DISK_CACHE_PATH=/home/$USER/wine/plutonium
__GL_SHADER_DISK_CACHE_SKIP_CLEANUP=1
__GL_THREADED_OPTIMIZATIONS=1
PROTON_NO_ESYNC=1
PROTON_NO_FSYNC=1
PROTON_USE_NTSYNC=1
PROTON_ENABLE_WAYLAND=1
PROTON_PRIORITY_HIGH=1
PROTON_USE_WOW64=1
STAGING_SHARED_MEMORY=1
```
> ! Note
>
> Some of these args may be deprecated in certain proton builds, that is ok. The point is to keep the prefix under a static configuration so users can use any (reasonably up-to-date) runtime, and expect the same performance.
---
### User Experience Features
- **Interactive Prompts**: Step-by-step confirmation before each major action
- **Comprehensive Logging**: All operations logged to timestamped files
- **Error Tracking**: Separate error log for troubleshooting
- **Sudo Verification**: Checks if user has sudo privileges before starting
- **Better Feedback**: Color-coded output with clear status indicators

### Distribution-Specific Enhancements
- **Automatic Distro Detection**: Detects Linnux distro, installs appropriate packages (Wine) and 32-bit libraries
- **Debian**: Automatic contrib repository detection and enabling
- **Arch**: Interactive multilib configuration with editor support
- **All Distros**: Improved package installation with fallback options

### Quality of Life Features
- **Detailed Summary**: Complete installation report at the end
- **Error Handling**: Graceful error recovery with helpful messages
- **Skip Options**: Can skip non-critical installation steps
- **Progress Indicators**: Clear indication of long-running operations
- **Dedicated Wine Prefix**: Sets up dedicated Wine prefix



### Comprehensive Logging
Two log files are created in the script directory:
- `plutonium_install_YYYY-MM-DD_HH.MM.AM/PM.log` - Complete installation log
- `plutonium_errors_YYYY-MM-DD_HH.MM.AM/PM.log` - Error-specific log

Example log entry:
```
[2026-01-17_12.06AM] INFO: Detected: Ubuntu 24.04
[2026-01-17_12.06AM] SUCCESS: Wine Staging installed
[2026-01-17_12.06AM] WARNING: Some optional dependencies failed
```
Example error entry:
```
[Error here] Sat Jan 17 12:06:27 AM EST 2026
[Error here] Sat Jan 17 12:06:34 AM EST 2026
```

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
sudo apt remove wine  # Example for Ubuntu
```

## Uninstallation

### Remove Wine Prefix Only
```bash
# This only removes only Plutonium wine prefix
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
sudo pacman -Rns wine-staging wine-mono wine-gecko winetricks
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
Make an issue on Github
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
- Anti-cheat will not work on Steam deck (LAN mode only)
- Always keep backups of important data (mods/textures/etc)

(``cp ~/wine/plutonium/drive_c/users/steamuser/AppData/Local/Plutonium/``)


Extra troubleshooting/steps for games can be found on my written guide for Plutonium forumns https://forum.plutonium.pw/topic/37097/plutonium-on-linux-ultimate-cross-distro-guide
