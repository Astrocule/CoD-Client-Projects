#!/bin/bash
set -e

# Script directory and log file
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG_FILE="$SCRIPT_DIR/plutonium_install_$(date +%Y-%m-%d_%I.%M%p).log"
ERROR_LOG="$SCRIPT_DIR/plutonium_errors_$(date +%Y-%m-%d_%I.%M%p).log"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Set version info
VERSION="1.0-4"

# Logging function

log_Ts()
{
    date '+%Y-%m-%d_%I.%M%p'
}

log_Info() 
{
    echo "[$(log_Ts)] INFO: $1" >> "$LOG_FILE"
}

log_Success() 
{
    echo "[$(log_Ts)] SUCCESS: $1" >> "$LOG_FILE"
}

log_Warning() 
{
    echo "[$(log_Ts)] WARNING: $1" >> "$LOG_FILE"
}

log_Error() 
{
    echo "[$(log_Ts)] ERROR: $1" >> "$ERROR_LOG"
}

log_Header() 
{
    echo "[$(log_Ts)] ===== $1 =====" >> "$LOG_FILE"
}


# Functions
print_Header() {
    local message="$1"
    echo -e "${BLUE}========================================${NC}"
    echo -e "${BLUE}$message${NC}"
    echo -e "${BLUE}========================================${NC}"
    log_Header "$message"
}

print_Success() {
    echo -e "${GREEN}✓ $1${NC}"
    log_Success "$1"
}

print_Error() {
    echo -e "${RED}✗ $1${NC}"
    log_Error "$1"
}

print_Warning() {
    echo -e "${YELLOW}⚠ $1${NC}"
    log_Warning "$1"
}

print_Info() {
    echo -e "${BLUE}ℹ $1${NC}"
    log_Info "$1"
}

print_Step() 
{
    echo -e "${CYAN}➜ $1${NC}"
    log_Info "STEP: $1"
}

# Initialize log files
echo "Plutonium Linux Installer - Log started at $(date)" > "$LOG_FILE"
echo "Plutonium Linux Installer - Error Log started at $(date)" > "$ERROR_LOG"

print_Info "Installation log: $LOG_FILE"
print_Info "Error log: $ERROR_LOG"
echo ""


# Prompt user for confirmation
prompt_Continue() 
{
    local message="$1"
    local default="${2:-N}"
    
    
    echo ""
    print_Step "$message"
    
    if [ "$default" = "Y" ]; then
        read -p "Continue? (Y/n): " -n 1 -r
    else
        read -p "Continue? (y/N): " -n 1 -r
    fi
    

    echo
    

    if [ "$default" = "Y" ]; then
        [[ $REPLY =~ ^[Nn]$ ]] && return 1 || return 0
    else
        [[ $REPLY =~ ^[Yy]$ ]] && return 0 || return 1
    fi
}

# Check for immutable system (SteamOS, Bazzite, etc.)
check_Immutable_System() {
    local is_Immutable=false
    

    # Check for SteamOS
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        if [[ "$ID" == "steamos" ]] || [[ "$ID_LIKE" == *"steamos"* ]]; then
            is_Immutable=true
            print_Warning "SteamOS detected - immutable system used"
        fi
        
        # Check for Bazzite
        if [[ "$ID" == "bazzite" ]] || [[ "$NAME" == *"Bazzite"* ]]; then
            is_Immutable=true
            print_Warning "Bazzite detected - immutable system used"
        fi
    fi
    

    # Check for cachyos handheld version
    if [ -f /usr/share/libalpm/hooks/steam-handheld.hook ]; then
        . /usr/share/libalpm/hooks/steam-handheld.hook
        if [[ "$TARGET" == "cachyos-handheld" ]]; then
            is_Immutable=true
            print_Warning "CachyOS Handheld detected - immutable system used"
        fi
    fi

    # Return based on detection
    if [ "$is_Immutable" = true ]; then
        print_Warning "Immutable systems cannot install Wine via package managers, Wine will be provided by your chosen Launcher automatically"
        return 0  # Return success to indicate immutable system
    fi
    

    return 1  # Return failure to indicate regular system
}



# Check if user is in sudoers
check_Sudo() 
{
    print_Header "Checking sudo privileges"
    
    # Check if user already has sudo privileges
    if sudo -n true 2>/dev/null; then
        print_Success "User has sudo privileges"
        return 0
    fi
    

    # Try with password
    if sudo -v 2>/dev/null; then
        print_Success "Sudo privileges confirmed after password prompt"
        return 0
    fi
    

    # User is not in sudoers
    print_Error "Current user '$USER' is not in the sudoers group!"
    echo ""
    print_Error "You most likely need sudo privileges to install dependencies."
    echo ""
    print_Info "To add yourself to sudoers, run these commands:"
    echo ""
    echo -e "${CYAN}su -${NC}"
    echo -e "${CYAN}sudo adduser $USER sudo${NC}"
    echo ""
    print_Info "Then restart your computer and run this script again."
    echo ""
    exit 1
}

# Check if running as root
if [ "$EUID" -eq 0 ]; then 
    print_Error "Do not run this script as root!"
    print_Info "Run as a normal user. You will be prompted for sudo when needed."
    exit 1
fi

# Detect distribution
detect_Distro() 
{
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        DISTRO=$ID
        VERSION=$VERSION_ID
        VERSION_CODENAME=${VERSION_CODENAME:-}
        UBUNTU_CODENAME=${UBUNTU_CODENAME:-}
        print_Info "Detected: $NAME $VERSION"
    else
        print_Error "Cannot detect distribution - /etc/os-release not found"
        exit 1
    fi
}

# Check available disk space
check_Disk_Space() 
{
    local required_space=5242880  # 5GB in KB
    local available_space=$(df "$HOME" | awk 'NR==2 {print $4}')
    
    print_Step "Checking available disk space..."
    
    if [ "$available_space" -lt "$required_space" ]; then
        print_Warning "Low disk space detected"
        print_Warning "Available: $((available_space / 1024 / 1024))GB | Required: 5GB"
        if ! prompt_Continue "Continue anyway? (Installation may fail)"; then
            print_Info "Installation cancelled due to low disk space"
            exit 1
        fi
    else
        print_Success "Sufficient disk space available ($((available_space / 1024 / 1024))GB)"
        log_Info "Disk space check passed"
    fi
}

# Enable contrib repository for Debian-based systems
enable_Debian_Contrib() 
{
    local sources_file="$1"
    
    print_Step "Checking for contrib repository in $sources_file..."
    
    # Check if contrib is already enabled
    if grep -Eq '^[[:space:]]*deb .* contrib( |$)' "$sources_file"; then
        print_Info "Contrib repository already enabled in $sources_file"
        return 0
    fi
    

    print_Warning "Contrib repository not enabled (required for winetricks)"
    
    # Prompt to enable contrib
    if prompt_Continue "Enable contrib repository in $sources_file?"; then
        print_Info "Enabling contrib repository in $sources_file..."

        # Backup original sources file
        sudo cp "$sources_file" "${sources_file}.backup"
        
        sudo sed -Ei '
            /^[[:space:]]*deb / {
                / contrib( |$)/! {
                    s/( main( |$))/\1contrib\2/
                }
            }
        ' "$sources_file"

        # Verify change
        if [ $? -eq 0 ]; then
            print_Success "Contrib repository enabled (backup saved as ${sources_file}.backup)"
            return 0
        else
            print_Error "Failed to enable contrib repository in $sources_file"
            return 1
        fi
    else
        print_Warning "Skipping contrib repository - winetricks may not be available"
        return 1
    fi
}

# Install dependencies for Ubuntu
install_Ubuntu() 
{
    print_Header "Installing dependencies for Ubuntu"
    

    # Determine codename
    if [ -n "$UBUNTU_CODENAME" ]; then
        CODENAME=$UBUNTU_CODENAME
    else
        CODENAME=$VERSION_CODENAME
    fi
    
    print_Info "Using Ubuntu codename: $CODENAME"
    

    # Enable 32-bit architecture
    if ! prompt_Continue "Enable 32-bit architecture support? (Required for Wine)"; then
        print_Error "32-bit architecture is required. Exiting."
        exit 1
    fi
    
    print_Info "Enabling 32-bit architecture..."
    if sudo dpkg --add-architecture i386; then
        print_Success "32-bit architecture enabled for Ubuntu $CODENAME"
    else
        print_Error "Failed to enable 32-bit architecture for Ubuntu $CODENAME"
        exit 1
    fi
    

    # Add WineHQ repository
    if prompt_Continue "Add WineHQ official repository? (Recommended for latest Wine)"; then
        print_Info "Adding WineHQ repository for $CODENAME..."
        
        sudo mkdir -pm755 /etc/apt/keyrings
        
        if wget -O - https://dl.winehq.org/wine-builds/winehq.key | sudo gpg --dearmor -o /etc/apt/keyrings/winehq-archive.key - 2>/dev/null; then
            print_Success "WineHQ key added for Ubuntu $CODENAME"
        else
            print_Error "Failed to add WineHQ key for Ubuntu $CODENAME"
            exit 1
        fi
        
        # Add WineHQ repository for the detected codename
        if sudo wget -NP /etc/apt/sources.list.d/ https://dl.winehq.org/wine-builds/ubuntu/dists/${CODENAME}/winehq-${CODENAME}.sources 2>/dev/null; then
            print_Success "WineHQ repository added for Ubuntu $CODENAME"
        else
            print_Warning "Failed to add WineHQ repository - will try Ubuntu $CODENAME repos instead"
        fi
    fi
    

    # Update package lists
    print_Info "Updating package lists..."
    if sudo apt update 2>&1 | tee -a "$LOG_FILE"; then
        print_Success "Package lists updated for Ubuntu $CODENAME"
    else
        print_Warning "Some $CODENAME repository updates failed (non-critical)"
    fi
    

    # Install Wine
    if prompt_Continue "Install Wine Staging? (Recommended version with latest features)"; then
        print_Info "Installing Wine Staging and winetricks..."
        
        if sudo apt install --install-recommends winehq-staging winetricks -y 2>&1 | tee -a "$LOG_FILE"; then
            print_Success "Wine Staging installed for Ubuntu $CODENAME"
        else
            print_Warning "Wine Staging installation failed, trying wine package from Ubuntu repos..."
            if sudo apt install wine winetricks -y 2>&1 | tee -a "$LOG_FILE"; then
                print_Success "Wine installed from Ubuntu $CODENAME repositories"
            else
                print_Error "Failed to install Wine for Ubuntu $CODENAME"
                exit 1
            fi
        fi
    else
        print_Warning "Wine Installation denied, Plutonium will not work if wine is not installed. Rerun and install unless you know what you are doing."
        read -n 1 -p "Press any key to continue..."
    fi
    

    print_Success "Ubuntu $CODENAME dependencies installed"
}

# Install dependencies for Linux Mint
install_Mint() {
    print_Header "Installing dependencies for Linux Mint"
    
    # Detect Mint version and Ubuntu base
    if [ -f /etc/linuxmint/info ]; then
        MINT_VERSION=$(grep RELEASE /etc/linuxmint/info | cut -d'=' -f2)
        MINT_CODENAME=$(grep CODENAME /etc/linuxmint/info | cut -d'=' -f2)
        print_Info "Linux Mint version: $MINT_VERSION ($MINT_CODENAME)"
    fi
    
    # Determine Ubuntu base codename
    if [ -n "$UBUNTU_CODENAME" ]; then
        BASE_CODENAME=$UBUNTU_CODENAME
    else
        # Mint version to Ubuntu base mapping
        case $MINT_CODENAME in
            wilma|virginia)
                BASE_CODENAME="noble"  # Mint 22.x -> Ubuntu 24.04
                print_Info "Mapping Mint codename $MINT_CODENAME to Ubuntu noble (24.04 base)"
                ;;
            virginia|vera|victoria|vanessa)
                BASE_CODENAME="jammy"  # Mint 21.x -> Ubuntu 22.04
                print_Info "Mapping Mint codename $MINT_CODENAME to Ubuntu jammy (22.04 base)"
                ;;
            una|uma|ulyssa)
                BASE_CODENAME="focal"  # Mint 20.x -> Ubuntu 20.04
                print_Info "Mapping Mint codename $MINT_CODENAME to Ubuntu focal (20.04 base)"
                ;;
            *)
                BASE_CODENAME="noble"  # Default to latest
                print_Warning "Unknown Mint codename $MINT_CODENAME, defaulting to noble (24.04 base)"
                ;;
        esac
    fi
    
    print_Info "Using Ubuntu base codename: $BASE_CODENAME"
    
    # Enable 32-bit architecture
    if ! prompt_Continue "Enable 32-bit architecture support? (Required for Wine)"; then
        print_Error "32-bit architecture is required. Exiting."
        exit 1
    fi

    print_Info "Enabling 32-bit architecture..."
    if sudo dpkg --add-architecture i386; then
        print_Success "32-bit architecture enabled"
    else
        print_Error "Failed to enable 32-bit architecture"
        exit 1
    fi
    
    # Add WineHQ repository
    if prompt_Continue "Add WineHQ official repository? (Recommended for latest Wine)"; then
        print_Info "Adding WineHQ repository for Mint $MINT_VERSION $MINT_CODENAME..."

        sudo mkdir -pm755 /etc/apt/keyrings
        
        if wget -O - https://dl.winehq.org/wine-builds/winehq.key | sudo gpg --dearmor -o /etc/apt/keyrings/winehq-archive.key - 2>/dev/null; then
            print_Success "WineHQ key added for Mint $MINT_VERSION $MINT_CODENAME"
        else
            print_Error "Failed to add WineHQ key for Mint $MINT_VERSION $MINT_CODENAME"
            exit 1
        fi
        
        # Use Ubuntu base codename for WineHQ repository
        if sudo wget -NP /etc/apt/sources.list.d/ https://dl.winehq.org/wine-builds/ubuntu/dists/${BASE_CODENAME}/winehq-${BASE_CODENAME}.sources 2>/dev/null; then
            print_Success "WineHQ repository added (using Ubuntu ${BASE_CODENAME} base)"
        else
            print_Warning "Failed to add WineHQ repository - will try Mint $MINT_CODENAME repos instead"
        fi
    fi
    
    # Update package lists
    print_Info "Updating package lists..."
    if sudo apt update 2>&1 | tee -a "$LOG_FILE"; then
        print_Success "$MINT_CODENAME Package lists updated"
    else
        print_Warning "Some $MINT_CODENAME repository updates failed (non-critical)"
    fi
    
    # Install Wine
    if prompt_Continue "Install Wine Staging? (Recommended version with latest features)"; then
        print_Info "Installing Wine Staging and winetricks..."
        print_Warning "This may take several minutes..."
        
        if sudo apt install --install-recommends winehq-staging winetricks -y 2>&1 | tee -a "$LOG_FILE"; then
            print_Success "Wine Staging installed"
        else
            print_Warning "Wine Staging installation failed, trying wine package from $MINT_CODENAME repos..."

            if sudo apt install wine winetricks -y 2>&1 | tee -a "$LOG_FILE"; then
                print_Success "Wine installed from $MINT_CODENAME repositories"

            else
                print_Error "Failed to install Wine"
                exit 1
            fi
        fi
    else
        print_Info "Installation cancelled"
        exit 0
    fi

    print_Success "Linux Mint $MINT_CODENAME dependencies installed"
}



# Install dependencies for Debian
install_Debian() 
{
    print_Header "Installing dependencies for Debian"
    

    CODENAME=$VERSION_CODENAME
    print_Info "Using Debian codename: $CODENAME"
    
    # Enable 32-bit architecture
    if ! prompt_Continue "Enable 32-bit architecture support? (Required for Wine)"; then
        print_Error "32-bit architecture is required. Exiting."
        exit 1
    fi

    print_Info "Enabling 32-bit architecture..."
    echo ""

    if sudo dpkg --add-architecture i386; then
        print_Success "32-bit architecture enabled"
    else
        print_Error "Failed to enable 32-bit architecture"
        exit 1
    fi
    

    # Check and enable contrib repository
    print_Step "Checking for contrib repository in Debian $CODENAME (required for winetricks)..."
    
    # Check main sources.list
    if [ -f /etc/apt/sources.list ]; then
        enable_Debian_Contrib "/etc/apt/sources.list"
    fi
    

    # Install prerequisites
    if prompt_Continue "Install prerequisite packages? (curl, wget, gnupg)"; then
        print_Info "Installing prerequisites for Debian $CODENAME..."
        if sudo apt update && sudo apt install -y curl gnupg wget 2>&1 | tee -a "$LOG_FILE"; then
            print_Success "Prerequisites installed for Debian $CODENAME"
        else
            print_Warning "Some prerequisites failed to install for Debian $CODENAME (may continue)"
        fi
    fi
    

    # Add WineHQ repository
    if prompt_Continue "Add WineHQ official repository? (Recommended for latest Wine)"; then
        print_Info "Adding WineHQ repository..."
        
        sudo mkdir -pm755 /etc/apt/keyrings
        
        if wget -O - https://dl.winehq.org/wine-builds/winehq.key | sudo gpg --dearmor -o /etc/apt/keyrings/winehq-archive.key - 2>/dev/null; then
            print_Success "WineHQ key added for Debian $CODENAME"
        else
            print_Error "Failed to add WineHQ key for Debian $CODENAME"
            exit 1
        fi
        
        echo "deb [signed-by=/etc/apt/keyrings/winehq-archive.key] https://dl.winehq.org/wine-builds/debian/ ${CODENAME} main" | sudo tee /etc/apt/sources.list.d/winehq.list
        print_Success "WineHQ repository added for Debian $CODENAME"
    fi
    

    # Update package lists
    print_Info "Updating package lists..."
    if sudo apt update 2>&1 | tee -a "$LOG_FILE"; then
        print_Success "Package lists updated for Debian $CODENAME"
    else
        print_Warning "Some repository updates failed for Debian $CODENAME (non-critical)"
    fi
    

    # Install Wine
    if prompt_Continue "Install Wine Staging? (Recommended version with latest features)"; then
        print_Info "Installing Wine Staging for Debian $CODENAME..."
        print_Warning "This may take several minutes..."
        
        if sudo apt install --install-recommends winehq-staging wine32 libwine fonts-wine winetricks -y 2>&1 | tee -a "$LOG_FILE"; then
            print_Success "Wine Staging installed for Debian $CODENAME"
        else
            print_Warning "Wine Staging installation failed for Debian $CODENAME, trying wine package from Debian repos..."
            if sudo apt install wine wine32 winetricks -y 2>&1 | tee -a "$LOG_FILE"; then
                print_Success "Wine installed from Debian $CODENAME repositories"
            else
                print_Error "Failed to install Wine for Debian $CODENAME"
                exit 1
            fi
        fi
    else
        print_Warning "Wine Installation cancelled, Plutonium will not work if wine is not installed. Rerun and install unless you know what you are doing."
        read -n 1 -p "Press any key to continue..."
    fi
    
    # Prompt user to update system
    if prompt_Continue "Update system packages? (Optional)"; then
        print_Info "Updating Debian $CODENAME system..."
        echo ""

        if sudo apt upgrade -y 2>&1 | tee -a "$LOG_FILE"; then
            print_Success "Debian $CODENAME system updated"
            echo ""
        else
            print_Warning "Debian $CODENAME system update had some issues (may continue)"
            echo ""
        fi
    fi


    print_Success "Debian $CODENAME dependencies installed"
}

# Install dependencies for Arch
install_Arch() 
{
    print_Header "Installing dependencies for Arch Linux"
    

    # Enable multilib
    print_Step "Checking multilib repository..."
    if ! grep -q "^\[multilib\]" /etc/pacman.conf; then
        print_Warning "Multilib repository not enabled (required for 32-bit support)"
        echo ""
        print_Info "To enable multilib, uncomment these lines in /etc/pacman.conf:"
        echo -e "${CYAN}[multilib]${NC}"
        echo -e "${CYAN}Include = /etc/pacman.d/mirrorlist${NC}"
        echo ""
        
        if prompt_Continue "Would you like to edit /etc/pacman.conf now?"; then
            sudo ${EDITOR:-nano} /etc/pacman.conf
            
            if grep -q "^\[multilib\]" /etc/pacman.conf; then
                print_Success "Multilib enabled"
            else
                print_Error "Multilib still not enabled. Please enable it manually and run this script again."
                exit 1
            fi
        else
            print_Error "Multilib is required. Exiting."
            exit 1
        fi
    else
        print_Success "Multilib already enabled for Arch Linux"
    fi
    
    # Update system
    if prompt_Continue "Update system packages? (Recommended)"; then
        print_Info "Updating Arch Linux system..."
        if sudo pacman -Syu --noconfirm 2>&1 | tee -a "$LOG_FILE"; then
            print_Success "Arch Linux system updated"
        else
            print_Warning "Arch Linux system update had some issues (may continue)"
        fi
    fi
    

    # Install Wine
    if prompt_Continue "Install Wine and core dependencies?"; then
        print_Info "Installing Wine(staging), wine-mono, wine-gecko, and winetricks for Arch Linux..."
        if sudo pacman -S --noconfirm wine-staging wine-mono wine-gecko winetricks 2>&1 | tee -a "$LOG_FILE"; then
            print_Success "Wine core packages installed for Arch Linux"
        else
            print_Error "Failed to install Wine core packages for Arch Linux"
            exit 1
        fi
    else
        print_Warning "Wine Installation cancelled, Plutonium will not work if wine is not installed. Rerun and install unless you know what you are doing."
        read -n 1 -p "Press any key to continue..."
    fi
    

    # Install full dependencies
    if prompt_Continue "Install complete Wine dependencies? (Recommended for full compatibility)"; then
        print_Info "Installing complete dependency set for Arch Linux..."
        print_Warning "This may take several minutes..."
        
        if sudo pacman -S --noconfirm --needed \
            giflib lib32-giflib libpng lib32-libpng libldap lib32-libldap \
            gnutls lib32-gnutls mpg123 lib32-mpg123 openal lib32-openal \
            v4l-utils lib32-v4l-utils libpulse lib32-libpulse alsa-plugins \
            lib32-alsa-plugins alsa-lib lib32-alsa-lib libjpeg-turbo \
            lib32-libjpeg-turbo libxcomposite lib32-libxcomposite libxinerama \
            lib32-libxinerama ncurses lib32-ncurses opencl-icd-loader \
            lib32-opencl-icd-loader libxslt lib32-libxslt libva lib32-libva \
            gtk3 lib32-gtk3 gst-plugins-base-libs lib32-gst-plugins-base-libs \
            vulkan-icd-loader lib32-vulkan-icd-loader gst-plugins-bad \
            gst-plugins-base gst-plugins-good gst-plugins-ugly sdl2 \
            lib32-gst-plugins-good lib32-gst-plugins-base lib32-gstreamer 2>&1 | tee -a "$LOG_FILE"; then
            print_Success "Complete dependencies installed for Arch Linux"
        else
            print_Warning "Some Arch Linux dependencies failed to install (may not be critical)"
        fi
    fi
    

    # Install DXVK
    if command -v yay &> /dev/null || command -v paru &> /dev/null; then
        if prompt_Continue "Install DXVK from AUR? (Recommended for better performance)"; then
            if command -v yay &> /dev/null; then
                print_Info "Installing DXVK with yay for Arch Linux..."
                yay -S --noconfirm dxvk-bin 2>&1 | tee -a "$LOG_FILE"
            elif command -v paru &> /dev/null; then
                print_Info "Installing DXVK with paru for Arch Linux..."
                paru -S --noconfirm dxvk-bin 2>&1 | tee -a "$LOG_FILE"
            fi
            print_Success "DXVK installed for Arch Linux"
        fi
    else
        print_Warning "No AUR helper (yay/paru) found - DXVK not installed for Arch Linux"
        print_Info "Install an AUR helper and run: yay -S dxvk-bin"
    fi
    

    print_Success "Arch Linux dependencies installed"
}

# Install dependencies for Fedora
install_Fedora() 
{
    print_Header "Installing dependencies for Fedora"
    
    # Detect Fedora Version
    FEDORA_VERSION=$VERSION_ID
    print_Info "Fedora Version: $FEDORA_VERSION"

    # Check if Nobara
    if [ -f /usr/bin/nobara-sync ]; then
        print_Info "Nobara Linux detected"
        print_Warning "Nobara comes with wine pre-installed"
        
        if prompt_Continue "Update system with nobara-sync?"; then
            print_Info "Running nobara-sync..."
            if sudo nobara-sync cli 2>&1 | tee -a "$LOG_FILE"; then
                print_Success "System updated"
            else
                print_Warning "System update had issues (may continue)"
            fi
        fi

        # Check for wine (Nobara)
        if command -v wine &> /dev/null; then
            print_Success "Wine already installed on Nobara"
            print_Info "Wine version $(wine --version)"
        else
            print_Warning "Wine not found on Nobara (unexpected, broken system?)"
            if prompt_Continue "Install Wine for Nobara?"; then
                print_Info "Installing Wine for Nobara..."
                sudo dnf install -y wine winetricks 2>&1 | tee -a "$LOG_FILE"
            fi
        fi

        print_Success "Nobara dependencies verified"
        return 0
    fi


    # WoW 64-bit support for Fedora 40+
    if [ "$FEDORA_VERSION" -ge 40 ]; then
        print_Info "Fedora $FEDORA_VERSION: WoW 64-bit support available (no 32-bit deps needed)"
    fi

    # Update system packages (Fedora Only)
    if prompt_Continue "Update system packages? (Recommended)"; then
        print_Info "Updating Fedora $FEDORA_VERSION system..."
        if sudo dnf upgrade -y 2>&1 | tee -a "$LOG_FILE"; then
            print_Success "Fedora $FEDORA_VERSION system updated"
        else
            print_Warning "Fedora $FEDORA_VERSION system update had issues (may continue)"
        fi
    fi

    # Add WineHQ repository
    if prompt_Continue "Add WineHQ official repository? (Recommended for latest Wine)"; then
        print_Info "Adding WineHQ repository for Fedora $FEDORA_VERSION..."

        # Quick check to ensure the repo file URL is correct
        local repo_url="https://dl.winehq.org/wine-builds/fedora/${FEDORA_VERSION}/winehq.repo"

        if sudo dnf config-manager addrepo --from-repofile="$repo_url" 2>&1 | tee -a "$LOG_FILE"; then
            print_Success "WineHQ repository added for Fedora $FEDORA_VERSION"
        else
            print_Warning "Failed to add WineHQ repository for Fedora $FEDORA_VERSION"
            print_Info "Will try standard Fedora $FEDORA_VERSION Wine package instead"
        fi
    fi


    # Install Wine
    if prompt_Continue "Install Wine and winetricks?"; then
        print_Info "Installing Wine and dependencies for Fedora $FEDORA_VERSION..."
        print_Warning "This may take several minutes..."
        
        if sudo dnf install -y --allowerasing wine-common winetricks 2>&1 | tee -a "$LOG_FILE"; then
            print_Success "Wine installed for Fedora $FEDORA_VERSION"
        else
            print_Error "Failed to install Wine for Fedora $FEDORA_VERSION"
            exit 1
        fi
    else
        print_Warning "Wine Installation cancelled, Plutonium will not work if wine is not installed. Rerun and install unless you know what you are doing."
        read -n 1 -p "Press any key to continue..."
    fi
    

    # Install additional dependencies
    if prompt_Continue "Install additional 32-bit dependencies? (Recommended for compatibility)"; then
        print_Info "Installing 32-bit dependencies for Fedora $FEDORA_VERSION..."
        print_Warning "Some packages may not be available - this is normal"
        
        sudo dnf install -y --skip-unavailable alsa-plugins-pulseaudio.i686 glibc-devel.i686 glibc-devel \
            libgcc.i686 libX11-devel.i686 freetype-devel.i686 libXcursor-devel.i686 \
            libXi-devel.i686 libXext-devel.i686 libXxf86vm-devel.i686 \
            libXrandr-devel.i686 libXinerama-devel.i686 mesa-libGLU-devel.i686 \
            mesa-libOSMesa-devel.i686 libXrender-devel.i686 libpcap-devel.i686 \
            ncurses-devel.i686 libzip-devel.i686 lcms2-devel.i686 zlib-devel.i686 \
            libv4l-devel.i686 libgphoto2-devel.i686 cups-devel.i686 \
            libxml2-devel.i686 openldap-devel.i686 libxslt-devel.i686 \
            gnutls-devel.i686 libpng-devel.i686 mesa-vulkan-drivers \
            vulkan-loader 2>&1 | tee -a "$LOG_FILE" || print_Warning "Some optional Fedora $FEDORA_VERSION dependencies failed (non-critical)"
        
        print_Success "Additional dependencies installed for Fedora $FEDORA_VERSION"
    fi
    
    print_Success "Fedora $FEDORA_VERSION dependencies installed"
}

# Install dependencies for Solus
install_Solus() 
{
    print_Header "Installing dependencies for Solus"
    

    # Update repository
    if prompt_Continue "Update repository database?"; then
        print_Info "Updating Solus repository..."
        if sudo eopkg update-repo 2>&1 | tee -a "$LOG_FILE"; then
            print_Success "Solus repository updated"
        else
            print_Warning "Solus repository update had issues (may continue)"
        fi
    fi


    # Update System
    if prompt_Continue "Update your Solus system?"; then
        print_Info "Updating Solus system..."
        sudo eopkg upgrade 2>&1 | tee -a "$LOG_FILE" || print_Warning "Some Solus upgrades may have failed (non-critical)"
        
        print_Success "Solus system updated, continuing..."
    fi
    

    # Install Wine
    if prompt_Continue "Install Wine with 32-bit support and accessories?"; then
        print_Info "Installing Wine packages for Solus..."
        print_Warning "This may take several minutes..."
        
        if sudo eopkg install -y wine wine-32bit wine-devel winetricks 2>&1 | tee -a "$LOG_FILE"; then
            print_Success "Wine installed for Solus"
        else
            print_Error "Failed to install Wine for Solus"
            exit 1
        fi
    else
        print_Warning "Wine Installation cancelled, Plutonium will not work if wine is not installed. Rerun and install unless you know what you are doing."
        read -n 1 -p "Press any key to continue..."
    fi
    
    print_Success "Solus dependencies installed"
}

# Install dependencies for Immutable distros
install_Immutable() 
{
    print_Warning "Distro is immutable - using Flatpak for installation"
    
    print_Header "Installing dependencies for $DISTRO"

    # Install Heroic Games Launcher or Lutris
    if prompt_Continue "Install a game launcher? (Required to run Plutonium)"; then
        print_Step "Which launcher would you like to install?"
        echo ""
        echo "  1) Heroic Games Launcher (Recommended)"
        echo "  2) Lutris"
        echo "  3) Skip"
        echo ""
        read -p "Enter choice (1-3): " choice
        
        # Check user response for launcher choice
        case $choice in
            1)
                print_Info "Installing Heroic Games Launcher via Flatpak for $DISTRO..."
                print_Warning "This may take several minutes..."
                if flatpak install flathub com.heroicgameslauncher.hgl -y 2>&1 | tee -a "$LOG_FILE"; then
                    print_Success "Heroic Games Launcher installed for $DISTRO"
                else
                    print_Error "Failed to install Heroic Games Launcher for $DISTRO"
                    return 1
                fi
                ;;
            2)
                print_Info "Installing Lutris via Flatpak for $DISTRO..."
                print_Warning "This may take several minutes..."
                if flatpak install flathub net.lutris.Lutris -y 2>&1 | tee -a "$LOG_FILE"; then
                    print_Success "Lutris installed for $DISTRO"
                else
                    print_Error "Failed to install Lutris for $DISTRO"
                    return 1
                fi
                ;;
            3)
                print_Warning "Skipping launcher installation for $DISTRO"
                ;;
            *)
                print_Error "Invalid choice for $DISTRO"
                return 1
                ;;
        esac
    else
        print_Warning "Launcher installation skipped for $DISTRO"
    fi

    if prompt_Continue "Install Protontricks via flatpak?"; then
        print_Info "Installing Protontricks via Flatpak for $DISTRO..."
        if flatpak install flathub com.github.Matoking.protontricks -y 2>&1 | tee -a "$LOG_FILE"; then
            print_Success "Protontricks installed for $DISTRO"
        else
            print_Error "Failed to install Protontricks for $DISTRO"
        fi
    else
        print_Warning "Protontricks installation skipped for $DISTRO"
    fi

    print_Success "$DISTRO dependencies installed"
}




# Setup Wine prefix
setup_Wine_Prefix() 
{
    print_Info "LAST STEP!!!"
    print_Header "Setting up Wine prefix"
    
    # Define Wine prefix location in home directory under ran user
    WINE_PREFIX="$HOME/wine/plutonium"

    # Supress output to avoid clogging up terminal
    export WINEDEBUG=-all
    
    # Check if prefix already exists
    if [ -d "$WINE_PREFIX" ] && [ -f "$WINE_PREFIX/system.reg" ]; then
        print_Warning "Wine prefix already exists at: $WINE_PREFIX"

        if prompt_Continue "Recreate Wine prefix? (This will delete existing prefix)"; then
            print_Info "Removing existing Wine prefix at $WINE_PREFIX..."
            echo ""
            rm -rf "$WINE_PREFIX"
        else
            print_Info "Skipping recreation of $WINE_PREFIX, will prompt again incase prefix needs to update."
            echo ""
        fi
    fi


    print_Info "Wine prefix will be used at: $WINE_PREFIX"
    echo ""
    
    if ! prompt_Continue "Create/Update Wine prefix and install Windows components?"; then
        print_Warning "Wine prefix setup skipped, Plutonium may have degraded performance or issues."
        return 0
    fi
    

    # Create prefix directory
    print_Info "Creating Wine prefix directory at $WINE_PREFIX..."
    if mkdir -p "$WINE_PREFIX"; then
        print_Success "Wine prefix directory created at $WINE_PREFIX"
    else
        print_Error "Failed to create Wine prefix directory at $WINE_PREFIX"
        exit 1
    fi
    

    # Check if winetricks is available
    if ! command -v winetricks &> /dev/null; then
        print_Error "winetricks not found! Cannot continue with Wine prefix setup."
        print_Info "Please install winetricks and rerun the script, or manually run:"
        echo "WINEPREFIX=$WINE_PREFIX winetricks -q --force d3dcompiler_47 d3dcompiler_43 \
        d3dx11_42 d3dx11_43 msasn1 \
        corefonts vcrun2005 vcrun2012 vcrun2019 \
        xact_x64 xact xinput \
        d3dx9 d3dx10"
        exit 1
    fi
    

    # Install Windows components
    print_Step "Installing Windows components via winetricks to $WINE_PREFIX..."
    print_Warning "This process may take 5-15 minutes depending on your internet connection"
    print_Warning "You may see error dialogs or windows - this is normal, install/accept any prompts that popup"
    print_Info "Do not close any windows that appear - they will close automatically"
    echo ""
    

    if ! prompt_Continue "Begin Windows component installation?" "Y"; then
        print_Warning "Windows components installation skipped for $WINE_PREFIX"
    else
        print_Info "Installing to $WINE_PREFIX: DirectX components, Visual C++ runtimes, fonts, audio, and input support..."
        
        # Set wineprefix to previous defined location and install components
        if WINEPREFIX="$WINE_PREFIX" winetricks -q \
            d3dcompiler_47 d3dcompiler_43 \
            d3dx11_42 d3dx11_43 msasn1 \
            corefonts vcrun2005 vcrun2012 vcrun2019 \
            xact_x64 xact xinput \
            d3dx9 d3dx10 2>&1 | tee -a "$LOG_FILE"; then
            print_Success "Windows components installed successfully to $WINE_PREFIX"
        else
            print_Warning "Some components may have failed to install to $WINE_PREFIX"
            print_Info "You can retry individual components with:"
            echo "WINEPREFIX=$WINE_PREFIX winetricks [component_name]"
        fi
    fi
    

    # Setup DXVK if available
    if command -v setup_dxvk &> /dev/null; then
        if prompt_Continue "Install DXVK (Vulkan-based DirectX)? (Recommended for performance)"; then
            print_Info "Installing DXVK to $WINE_PREFIX..."
            if WINEPREFIX="$WINE_PREFIX" setup_dxvk install 2>&1 | tee -a "$LOG_FILE"; then
                print_Success "DXVK installed to $WINE_PREFIX"
            else
                print_Warning "DXVK setup failed for $WINE_PREFIX (non-critical - Heroic can handle this)"
            fi
        fi
    else
        print_Info "DXVK setup command not available for $WINE_PREFIX (Launcher should handle this automatically)"
    fi
    

    # Set Windows version
    print_Info "Configuring wine prefix at $WINE_PREFIX to Windows 10 (may take a few seconds)..."
    read -n 1 -p "Press any key to continue..."
    echo ""

    if WINEPREFIX="$WINE_PREFIX" winecfg -v win10 2>&1 | tee -a "$LOG_FILE"; then
        print_Success "Windows 10 configuration applied to $WINE_PREFIX"
    else
        print_Warning "Failed to set Windows version automatically for $WINE_PREFIX"
        print_Info "You can set it manually by running: WINEPREFIX=$WINE_PREFIX winecfg"
    fi

    # Set DLL overrides for controller input
    print_Info "Setting DLL overrides for controller input in $WINE_PREFIX (may take a few seconds)..."
    read -n 1 -p "Press any key to continue..."
    echo ""

    # Setting DLL overrides using windows registry keys
    local xinput_versions=("xinput1_1" "xinput1_2" "xinput1_3" "xinput9_1_0")
    local failed=0

    for v in "${xinput_versions[@]}"; do
        if WINEPREFIX="$WINE_PREFIX" wine reg add \
            "HKCU\\Software\\Wine\\DllOverrides" \
            /v "$v" /t REG_SZ /d "builtin,native" /f 2>&1 | tee -a "$LOG_FILE"; then
            print_Success "Set DLL override for $v in $WINE_PREFIX"
        else
            print_Warning "Failed to set DLL override for $v in $WINE_PREFIX"
            ((failed++))
        fi
    done

    if [ $failed -eq 0 ]; then
        print_Success "All DLL overrides set successfully in $WINE_PREFIX"
    else
        print_Warning "Some DLL overrides failed to set in $WINE_PREFIX ($failed/${#xinput_versions[@]})"
        print_Info "Controllers still may work without these overrides, test and retry manually if needed"
        print_Error "($failed/${#xinput_versions[@]}) some or all DLL overrides failed in $WINE_PREFIX"
    fi

    print_Success "Wine prefix setup complete at $WINE_PREFIX!"
}




# Display installation summary for regular systems
show_Summary() 
{
    echo ""
    print_Header "Installation Summary"
    
    echo ""
    echo "Wine prefix location: $HOME/wine/plutonium"
    
    if command -v wine &> /dev/null; then
        echo "Wine version: $(wine --version)"
    fi
    echo ""
    
    print_Warning "Next Steps:"
    echo ""
    echo "1. Download Plutonium launcher from: https://plutonium.pw/"
    echo "   Place plutonium.exe in: $HOME/wine/plutonium/"
    echo ""
    echo "2. Install Heroic Games Launcher:"
    echo "   flatpak install flathub com.heroicgameslauncher.hgl"
    echo "   Or visit: https://heroicgameslauncher.com/"
    echo ""
    echo "3. Configure Heroic:"
    echo "   - Add Game → Add Non-Steam Game"
    echo "   - Executable: $HOME/wine/plutonium/plutonium.exe"
    echo "   - Wine Prefix: $HOME/wine/plutonium"
    echo "   - Wine Version: GE-Proton-Latest (Recommended)"
    echo ""
    echo "4. Launch Plutonium and point it to your Steam game folder:"
    echo "   Usually: ~/.steam/steam/steamapps/common/[Game Name]"
    echo ""
    
    log_Info "Installation summary displayed"
}




# Display installation summary for immutable systems
show_Summary_Immutable() 
{
    echo ""
    print_Header "Installation Summary ($DISTRO - Immutable System)"
    
    echo ""
    print_Warning "Immutable OS detected ($DISTRO) - Wine managed by launcher"
    echo ""
    
    echo "Installation log: $LOG_FILE"
    echo "Error log: $ERROR_LOG"
    echo ""
    
    print_Warning "Next Steps:"
    echo ""
    echo "1. Download Plutonium launcher from: https://plutonium.pw/"
    echo "   Save plutonium.exe to your Downloads folder"
    echo ""
    echo "2. Open Heroic Games Launcher or Lutris"
    echo ""
    echo "3. Add Plutonium as a game:"
    echo "   - Point to plutonium.exe"
    echo "   - Launcher will handle Wine automatically"
    echo "   - Set Wine version to GE-Proton-Latest"
    echo ""
    echo "4. Launch Plutonium and point it to your Steam game folder"
    echo "   Usually: ~/.local/share/Steam/steamapps/common/[Game Name]"
    echo ""

    print_Warning "Note: Because of immutable systems like $DISTRO, making a prefix is more challenging without changing system files that go against the immutable design. If you installed Protontricks, You can set up a prefix using Protontricks and install the required components manually."
    echo ""
    print_Info "Manual components to install via Protontricks for $DISTRO:"
    echo "  • d3dcompiler_47, d3dcompiler_43, d3dx11_42, d3dx11_43, msasn1, corefonts, vcrun2005, vcrun2012, vcrun2019, xact_x64, xact, xinput, d3dx9, d3dx10"
    echo ""
}




# Error handler
handle_Error() 
{
    local exit_code=$?
    local line_number=$1
    
    echo ""
    print_Error "An error occurred on line $line_number (exit code: $exit_code)"
    
    echo ""
    print_Info "Check the error log for details: $ERROR_LOG"
    echo ""
    
    exit $exit_code
}




# Set error trap
trap 'handle_Error $LINENO' ERR




# Main installation flow
main() 
{
    print_Header "Plutonium Linux Automated Installer $VERSION"
    echo ""
    print_Info "This script will:"
    echo "  • Detect your Linux distribution"
    echo "  • Install Wine and required dependencies"
    echo "  • Create a Wine prefix for Plutonium"
    echo "  • Install Windows components via winetricks"
    echo ""
    print_Warning "Installation requires sudo privileges"
    print_Warning "This script DOES NOT currently support all distributions"
    print_Warning "Accept any prompts from Wine to ensure compatibility with Plutonium"
    print_Info "You will be prompted before each major step"
    echo ""
    
    if ! prompt_Continue "Start installation?"; then
        print_Info "Installation cancelled by user"
        exit 0
    fi


    # Detect distribution
    echo ""
    detect_Distro

    # Check disk space
    echo ""
    check_Disk_Space

    # Check if immutable OS
    echo ""
    if check_Immutable_System; then
        # Immutable system detected - skip Wine installation
        case $DISTRO in
            steamos|bazzite|cachyos-handheld)
                install_Immutable 
                ;;
            *)
                print_Error "Immutable system detected but no specific handler available"
                print_Error "Unsupported immutable distribution: $DISTRO"
                exit 1
                ;;
        esac

        print_Warning "Skipping Wine prefix setup (managed by launcher)"
        print_Info "Please use Wine/Proton through launchers (Heroic/Lutris/Steam)"
        show_Summary_Immutable
        exit 0
    fi


    # Check sudo privileges (only for mutable systems)
    check_Sudo


    # Install based on distribution (for regular systems)
    echo ""
    case $DISTRO in
        ubuntu)
            install_Ubuntu
            ;;
        debian)
            install_Debian
            ;;
        linuxmint)
            install_Mint
            ;;
        arch|manjaro|endeavouros|cachyos)
            install_Arch
            ;;
        fedora|nobara)
            install_Fedora
            ;;
        solus)
            install_Solus
            ;;
        *)
            print_Error "Unsupported distribution: $DISTRO"
            print_Info "Supported distributions:"
            echo "  • Ubuntu"
            echo "  • Debian"
            echo "  • Linux Mint"
            echo "  • Arch Linux (and derivatives)"
            echo "  • Fedora (and Nobara)"
            echo "  • Solus"
            echo "  • SteamOS (immutable)"
            echo "  • Bazzite (immutable)"
            echo "  • CachyOS Handheld (immutable)"
            print_Error "Unsupported distribution: $DISTRO"
            print_Info "If you would like your distro to be supported, please make an issue request on Github @ Astrocule"
            exit 1
            ;;
    esac
    
    # Setup Wine prefix
    echo ""
    setup_Wine_Prefix
    
    # Show summary
    show_Summary
    
    echo ""
    print_Success "Installation complete!"
    log_Info "Installation completed successfully"
    
    echo ""
    print_Info "If you encounter issues with the installer, check the logs:"
    echo "  Installation log: $LOG_FILE"
    echo "  Error log: $ERROR_LOG"
    echo ""

    echo ""
    print_Info "Thank you for using my installer! You can contact me on Github @ Astrocule if you have any issues, concerns, or want to check out the source code and or provide feedback!"
    echo ""
}

# Run main function
main "$@"
