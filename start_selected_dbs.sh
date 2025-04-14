#!/bin/ksh
###############################################################################
##           DATABASE AND LISTENER STARTUP SCRIPT  - BY AMOGH GORDE          ##
###############################################################################
 
ORATAB=/etc/oratab
LOGFILE="start_dbs.log"
DATE=$(date '+%Y-%m-%d %H:%M:%S')
 
# Terminal colors using tput
GREEN=$(tput setaf 2)
YELLOW=$(tput setaf 3)
RED=$(tput setaf 1)
NC=$(tput sgr0)
 
echo "===== [$DATE] Starting Oracle DB startup script =====" >> "$LOGFILE"
 
if [ ! -f "$ORATAB" ]; then
  echo "${RED}ERROR: $ORATAB not found.${NC}" | tee -a "$LOGFILE"
  exit 1
fi
 
# Extract enabled DBs
set -A DB_LIST $(grep -v '^#' "$ORATAB" | grep -v '+ASM' | cut -d':' -f1)
 
if [ ${#DB_LIST[@]} -eq 0 ]; then
  echo "${YELLOW}No eligible databases found.${NC}" | tee -a "$LOGFILE"
  exit 0
fi
 
echo "${GREEN}Available Databases:${NC}"
i=1
for DB in "${DB_LIST[@]}"; do
  echo " $i) $DB"
  i=$((i + 1))
done
 
echo ""
echo "Enter the numbers of the databases to start (e.g., 1 2 3): \c"
read SELECTED_LINE
set -A SELECTED_INDICES $SELECTED_LINE
 
echo ""
echo "Choose startup mode:"
echo "1) MOUNT"
echo "2) OPEN"
echo "Enter choice [1/2]: \c"
read MODE_CHOICE
 
case "$MODE_CHOICE" in
  1) MODE="MOUNT" ;;
  2) MODE="OPEN" ;;
  *) echo "${RED}Invalid mode selected. Exiting.${NC}" | tee -a "$LOGFILE"; exit 1 ;;
esac
 
for index in "${SELECTED_INDICES[@]}"; do
  SID="${DB_LIST[$((index-1))]}"
 
  if [ -z "$SID" ]; then
    echo "${YELLOW}Invalid selection: $index${NC}" | tee -a "$LOGFILE"
    continue
  fi
 
  echo ""
  echo "${YELLOW}Processing database $SID...${NC}" | tee -a "$LOGFILE"
 
  export ORACLE_SID=$SID
  ORACLE_HOME=$(grep "^$SID:" "$ORATAB" | cut -d':' -f2)
 
  if [ -z "$ORACLE_HOME" ]; then
    echo "${RED}ORACLE_HOME not found for $SID. Skipping...${NC}" | tee -a "$LOGFILE"
    continue
  fi
 
  export ORACLE_HOME
  export PATH=$ORACLE_HOME/bin:$PATH
 
  STATUS_OUTPUT=$(sqlplus -s / as sysdba <<EOF
SET HEADING OFF FEEDBACK OFF PAGESIZE 0
SELECT status FROM v\\$instance;
EXIT;
EOF
)
  DB_STATUS=$(echo "$STATUS_OUTPUT" | tr -d '[:space:]')
  echo "Current status of $SID: $DB_STATUS" | tee -a "$LOGFILE"
 
  if [ "$MODE" = "MOUNT" -a "$DB_STATUS" = "MOUNTED" ]; then
    echo "${YELLOW}$SID is already in MOUNT mode. Skipping...${NC}" | tee -a "$LOGFILE"
    continue
  elif [ "$MODE" = "OPEN" -a "$DB_STATUS" = "OPEN" ]; then
    echo "${YELLOW}$SID is already in OPEN mode. Skipping...${NC}" | tee -a "$LOGFILE"
    continue
  fi
 
  echo "${GREEN}Starting $SID in $MODE mode...${NC}" | tee -a "$LOGFILE"
  if [ "$MODE" = "MOUNT" ]; then
    sqlplus -s / as sysdba <<EOF >> "$LOGFILE"
STARTUP MOUNT;
EXIT;
EOF
  else
    sqlplus -s / as sysdba <<EOF >> "$LOGFILE"
STARTUP;
EXIT;
EOF
  fi
 
  echo "${GREEN}$SID startup completed.${NC}" | tee -a "$LOGFILE"
 
  # === Start All Listeners from listener.ora ===
  LISTENER_ORA="$ORACLE_HOME/network/admin/listener.ora"
 
  if [ -f "$LISTENER_ORA" ]; then
    echo "${YELLOW}Checking for all listeners in $LISTENER_ORA...${NC}" | tee -a "$LOGFILE"
    LISTENERS=$(awk '/SID_LIST_/ {
      gsub(/[ \t=]/, "", $1);
      gsub("SID_LIST_", "", $1);
      print $1
    }' "$LISTENER_ORA" | sort -u)
 
    if [ -z "$LISTENERS" ]; then
      echo "${YELLOW}No custom listeners found. Using default: LISTENER${NC}" | tee -a "$LOGFILE"
      LISTENERS="LISTENER"
    fi
  else
    echo "${YELLOW}listener.ora not found. Using default: LISTENER${NC}" | tee -a "$LOGFILE"
    LISTENERS="LISTENER"
  fi
 
  for LSN in $LISTENERS; do
    echo "${YELLOW}Checking status of listener $LSN...${NC}" | tee -a "$LOGFILE"
    lsnrctl status "$LSN" | grep "STATUS of the" >/dev/null 2>&1
    if [ $? -eq 0 ]; then
      echo "${GREEN}Listener $LSN already running. Skipping start.${NC}" | tee -a "$LOGFILE"
    else
      echo "${YELLOW}Starting listener $LSN...${NC}" | tee -a "$LOGFILE"
      lsnrctl start "$LSN" >> "$LOGFILE" 2>&1
      echo "${GREEN}Listener $LSN started.${NC}" | tee -a "$LOGFILE"
    fi
  done
 
done
 
echo ""
echo "${GREEN}===== Script completed at $(date '+%Y-%m-%d %H:%M:%S') =====${NC}" >> "$LOGFILE"
echo "${GREEN}All selected databases and listeners processed. See $LOGFILE for details.${NC}"