#!/bin/bash

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[1;36m'
NC='\033[0m' # white


DO_PULL=true
VERBOSE=false
FORCE_INSTALL=false
BACKUP=true

for arg in "$@"; do
    case $arg in
        --no-pull)
            DO_PULL=false
            ;;
        --no-backup)
            BACKUP=false
            ;;
        -v|--verbose)
            VERBOSE=true
            ;;
        --force-install)
            FORCE_INSTALL=true
            ;;
        *)
            echo -e "${RED}Unknown flag: $arg${NC}"
            echo "Usage: $0 [OPTIONS]"
            echo ""
            echo "Options:"
            echo "  --no-pull          Skip git pull operation"
            echo "  --no-backup        Skip backup of existing config"
            echo "  --force-install    Skip illogical-impulse check"
            echo "  -v, --verbose      Enable verbose output"
            exit 1
            ;;
    esac
done

log_verbose() {
    if [ "$VERBOSE" = true ]; then
        echo -e "${BLUE}[VERBOSE] $1${NC}"
    fi
}

echo ""
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${CYAN}          ii-vynx setup     ${NC}"
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

echo -e "${NC}Welcome to the ii-vynx setup script!${NC}"
echo -e "${NC}This script will install ii-vynx on your system.${NC}"
echo ""

log_verbose "Verbose mode enabled"
log_verbose "DO_PULL=$DO_PULL"
log_verbose "FORCE_INSTALL=$FORCE_INSTALL"
log_verbose "BACKUP=$FORCE_INSTALL"

if [ "$DO_PULL" = false ]; then
    echo -e "${YELLOW}--no-pull flag used, skipping git pull.${NC}"
fi

echo -e "${BLUE}Your current Quickshell configuration will be backed up and overwritten.${NC}"
if [ "$BACKUP" = false ]; then
    echo ""
    echo -e "${RED}WARNING: You've used --no-backup flag, skipping the backup process.${NC}"
fi
echo -e "${RED}Do you want to continue? (y/n): ${NC}"
read -r response

if [[ ! "$response" =~ ^[Yy]$ ]]; then
    echo -e "${RED}Operation cancelled.${NC}"
    exit 0
fi

echo ""

CONFIG_DIR="$HOME/.config"
CHECK_DIR="$CONFIG_DIR/illogical-impulse"
TARGET_DIR="$CONFIG_DIR/quickshell/ii"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
SOURCE_DIR="$SCRIPT_DIR/dots/.config/quickshell/ii"

log_verbose "CONFIG_DIR=$CONFIG_DIR"
log_verbose "CHECK_DIR=$CHECK_DIR"
log_verbose "TARGET_DIR=$TARGET_DIR"
log_verbose "SCRIPT_DIR=$SCRIPT_DIR"
log_verbose "SOURCE_DIR=$SOURCE_DIR"

if [ "$DO_PULL" = true ]; then
    echo -e "${NC}• Checking for updates...${NC}"
    
    if [ -d "$SCRIPT_DIR/.git" ]; then
        log_verbose "Git repository found at $SCRIPT_DIR/.git"
        cd "$SCRIPT_DIR"
        git pull
        if [ $? -ne 0 ]; then
            echo -e "${RED}An error occurred while running git pull!${NC}"
            exit 1
        fi
        echo -e "${GREEN}✓ Repository updated${NC}"
        echo ""
    else
        log_verbose "Git repository not found"
        echo -e "${YELLOW}WARNING: Couldn't find the repository, you may have to run git pull manually or clone the repository again.${NC}"
        echo ""
    fi
else
    echo -e "${YELLOW}Skipping git pull (--no-pull flag used)${NC}"
    echo ""
fi

if [ "$FORCE_INSTALL" = false ]; then
    log_verbose "Checking for illogical-impulse directory"
    if [ ! -d "$CHECK_DIR" ]; then
        echo -e "${RED}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        echo -e "${RED}  ERROR: Couldn't find illogical-impulse!${NC}"
        echo -e "${RED}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        echo ""

        if [ -f "$SCRIPT_DIR/setup" ]; then
            echo -e "${NC}You may want to install the original dots seperately before installing ii-vynx.${NC}"
            echo -e "${RED}[EXPERIMENTAL] Original dots are not installed! Do you want to install them? (y/n): ${NC}"
            read -r setup_response
            
            if [[ "$setup_response" =~ ^[Yy]$ ]]; then
                printf "${GREEN}
Subcommands:
    install        (Re)Install/Update illogical-impulse.
                    Note: To update to the latest, manually run \"git stash && git pull\" first.
    install-deps   Run the install step \"1. Install dependencies\"
    install-setups Run the install step \"2. Setup for permissions/services etc\"
    install-files  Run the install step \"3. Copying config files\"
    resetfirstrun  Reset firstrun state.
    uninstall      Uninstall illogical-impulse.

    exp-update     (Experimental) Update illogical-impulse without fully reinstall.
    exp-merge      (Experimental) Merge upstream changes with local configs using git rebase.

    virtmon        (For dev only) Create virtual monitors for testing multi-monitors.
    checkdeps      (For dev only) Check whether pkgs exist in AUR or repos of Arch.

    help           Show this help message.
${NC}"
                echo ""
                echo -e "${RED}Enter the subcommand: ${NC}"
                read -r setup_subcommand
                bash "$SCRIPT_DIR/setup" "$setup_subcommand"
                
                if [ $? -eq 0 ]; then
                    echo ""
                    echo -e "${GREEN}✓ Setup completed successfully!${NC}"
                    echo -e "${BLUE}Continuing with ii-vynx installation...${NC}"
                    echo ""
                else
                    echo -e "${RED}✗ Setup failed! Try installing the dots manually.${NC}"
                    exit 1
                fi
            else
                echo -e "${RED}✗ Setup cancelled. Try installing the dots manually.${NC}"
                exit 1
            fi
        else
            echo -e "${YELLOW}Please run ./setup.sh first to install the original dots.${NC}"
            echo -e "${BLUE}Use --force-install flag to skip this check.${NC}"
            echo ""
            exit 1
        fi


    fi
    log_verbose "illogical-impulse directory found"
else
    echo -e "${RED}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${RED}  ⚠ Force install mode enabled${NC}"
    echo -e "${RED}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${RED}Skipping illogical-impulse check...${NC}"
    echo ""
    log_verbose "Force install mode: skipping illogical-impulse check"
fi

log_verbose "Checking source directory"
if [ ! -d "$SOURCE_DIR" ]; then
    echo -e "${RED}ERROR: Source directory not found, please run git pull manually or clone the repository again: $SOURCE_DIR${NC}"
    exit 1
fi
log_verbose "Source directory found"

log_verbose "Creating parent directory: $(dirname "$TARGET_DIR")"
mkdir -p "$(dirname "$TARGET_DIR")"

if [ "$BACKUP" = true ]; then
    log_verbose "Checking for existing directory"
    if [ -d "$TARGET_DIR" ]; then
        BACKUP_DIR="${TARGET_DIR}_backup_$(date +%Y%m%d_%H%M%S)"
        log_verbose "Existing directory found, creating backup: $BACKUP_DIR"
        echo -e "${YELLOW}Backing up the current Quickshell configuration: $BACKUP_DIR${NC}"
        mv "$TARGET_DIR" "$BACKUP_DIR"
    else
        log_verbose "No existing directory found, skipping backup"
    fi
else 
    echo -e "${RED}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${RED}      ⚠ No backup flag used${NC}"
    echo -e "${RED}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${RED}Skipping the backup process...${NC}"
fi

echo ""
echo -e "${NC}• Copying...${NC}"
log_verbose "Copying from $SOURCE_DIR to $TARGET_DIR"
cp -r "$SOURCE_DIR" "$TARGET_DIR"

if [ $? -eq 0 ]; then
    echo -e "${GREEN}✓ Successfully copied: $TARGET_DIR${NC}"
else
    echo -e "${RED}✗ An error occurred while copying!${NC}"
    exit 1
fi

echo ""
echo -e "${NC}• Restarting Hyprland & Quickshell...${NC}"
sleep 0.5

log_verbose "Killing Quickshell process"
pkill -x qs

log_verbose "Reloading Hyprland"
hyprctl reload

sleep 1.0

log_verbose "Starting Quickshell with config: ii"
nohup qs -c ii > /dev/null 2>&1 &

if [ $? -eq 0 ]; then
    echo -e "${GREEN}✓ Quickshell started${NC}"
    echo ""
    echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${GREEN}     Installation completed!    ${NC}"
    echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    log_verbose "Script completed successfully"
    echo -e "${BLUE}Please star this project on GitHub: ${NC}https://github.com/vaguesyntax/ii-vynx"
    echo -e "${BLUE}And report any issues: ${NC}https://github.com/vaguesyntax/ii-vynx/issues"
    echo ""
else
    echo -e "${RED}✗ An error occurred while starting Quickshell!${NC}"
    exit 1
fi