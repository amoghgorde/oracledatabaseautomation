#!/bin/bash
######################################################################################
######################################################################################
##              DATABASE START,STOP,RESTART MENU SCRIPT - BY AMOGH GORDE            ##
######################################################################################
######################################################################################
 
# === Terminal Colors ===
GREEN="\e[32m"
YELLOW="\e[33m"
RED="\e[31m"
NC="\e[0m"
 
# === Function to display menu ===
show_menu() {
  echo -e "${GREEN}"
  echo "=============================="
  echo " Oracle DB Management Menu"
  echo "=============================="
  echo -e "${NC}"
  echo "1) Start Database(s)"
  echo "2) Stop Database(s)"
  echo "3) Restart Database(s)"
  echo "4) Exit"
  echo ""
}
 
# === Main Loop ===
while true; do
  show_menu
  read -p "Enter your choice [1-4]: " CHOICE
 
  case $CHOICE in
    1)
echo -e "${YELLOW}Running start_selected_dbs.sh...${NC}"
./start_selected_dbs.sh
      ;;
    2)
echo -e "${YELLOW}Running stop_selected_dbs.sh...${NC}"
./stop_selected_dbs.sh
      ;;
    3)
echo -e "${YELLOW}Running restart_selected_dbs.sh...${NC}"
./restart_selected_dbs.sh
      ;;
    4)
      echo -e "${GREEN}Exiting. Bye!${NC}"
      exit 0
      ;;
    *)
      echo -e "${RED}Invalid choice. Please select between 1-4.${NC}"
      ;;
  esac
 
  echo -e "\nPress Enter to continue..."
  read
  clear
done
