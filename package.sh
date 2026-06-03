#!/bin/bash
set -e

# Colors for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${BLUE}=== WordPress Multisite Manager Packaging Tool ===${NC}"

# Check for Python 3
if ! command -v python3 > /dev/null; then
  echo -e "${RED}Error: Python 3 is required to build this project.${NC}"
  exit 1
fi

# Step 1: Compile Standalone Binary using PyInstaller
echo -e "${YELLOW}Setting up temporary Python virtual environment...${NC}"
python3 -m venv build_venv
source build_venv/bin/activate

echo -e "${YELLOW}Installing PyInstaller inside venv...${NC}"
pip install --upgrade pip
pip install pyinstaller

echo -e "${YELLOW}Compiling manager.py into a standalone binary...${NC}"
pyinstaller --onefile --noconsole --name "wp-manager" --add-data "manager_ui.html:." manager.py

deactivate
rm -rf build_venv

echo -e "${GREEN}Standalone binary compiled successfully!${NC}"
echo -e "Location: ${GREEN}./dist/wp-manager${NC}"

# Step 2: Try to build RPM if rpmbuild is available
if command -v rpmbuild > /dev/null; then
  echo -e "${YELLOW}Detected rpmbuild. Preparing to build RPM package...${NC}"
  
  # Set up RPM build workspace directories
  RPM_DIR="$HOME/rpmbuild"
  mkdir -p "$RPM_DIR"/{BUILD,RPMS,SOURCES,SPECS,SRPMS}
  
  # Archive current project files for rpmbuild
  TAR_FILE="$RPM_DIR/SOURCES/wp-manager-1.0.0.tar.gz"
  echo -e "${YELLOW}Creating project archive for rpmbuild...${NC}"
  tar --exclude='./dist' --exclude='./build' --exclude='./build_venv' --exclude='./src' --exclude='./.git' -czf "$TAR_FILE" -C .. wordpress-docker
  
  # Copy spec file to SPECS
  cp wp-manager.spec "$RPM_DIR/SPECS/"
  
  # Run rpmbuild
  echo -e "${YELLOW}Running rpmbuild...${NC}"
  rpmbuild -ba "$RPM_DIR/SPECS/wp-manager.spec"
  
  echo -e "${GREEN}RPM package built successfully!${NC}"
  echo -e "Location: ${GREEN}$RPM_DIR/RPMS/x86_64/wp-manager-1.0.0-1.x86_64.rpm${NC}"
else
  echo -e "${YELLOW}Note: 'rpmbuild' not found on this system. Skipped building RPM package.${NC}"
  echo -e "To compile an RPM, install build tools on your host: ${BLUE}sudo dnf install rpm-build rpm-devel${NC} and re-run this script."
fi
