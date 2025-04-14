#!/bin/bash
######################################################################################
##      ORACLE DATABASE & LISTENER RESTART SCRIPT — BY AMOGH GORDE                  ##
######################################################################################
 
ORATAB=/etc/oratab
LOGFILE="restart_dbs.log"
DATE=$(date '+%Y-%m-%d %H:%M:%S')
GREEN="\e[32m"; YELLOW="\e[33m"; RED="\e[31m"; NC="\e[0m"
 
echo -e "\n===== [$DATE] Oracle DB Restart Script Started =====\n" | tee -a "$LOGFILE"
 
[[ ! -f $ORATAB ]] && echo -e "${RED}ERROR: $ORATAB not found.${NC}" | tee -a "$LOGFILE" && exit 1
 
DB_LIST=($(grep -v '^#' "$ORATAB" | grep -v '+ASM' | cut -d':' -f1))
[[ ${#DB_LIST[@]} -eq 0 ]] && echo -e "${YELLOW}No databases found to restart.${NC}" | tee -a "$LOGFILE" && exit 0
 
echo -e "${GREEN}Available Databases:${NC}"
for i in "${!DB_LIST[@]}"; do printf "%2d) %s\n" $((i+1)) "${DB_LIST[$i]}"; done
 
echo ""
read -p "Enter DB numbers to restart (e.g. 1 2): " -a SELECTED
 
echo -e "\nStartup Mode:\n1) MOUNT\n2) OPEN"
read -p "Choose startup mode [1/2]: " MODE_CHOICE
MODE=$( [[ "$MODE_CHOICE" == "1" ]] && echo "MOUNT" || ([[ "$MODE_CHOICE" == "2" ]] && echo "OPEN") )
 
[[ -z "$MODE" ]] && echo -e "${RED}Invalid startup mode. Exiting.${NC}" && exit 1
 
# === Function to kill LOCAL=NO processes ===
kill_local_no_sessions() {
  echo -e "${YELLOW}Killing LOCAL=NO sessions for $ORACLE_SID...${NC}" | tee -a "$LOGFILE"
  for PID in $(ps -ef | grep "[o]ra_.*${ORACLE_SID}" | grep "LOCAL=NO" | awk '{print $2}'); do
    echo "Killing PID $PID" | tee -a "$LOGFILE"
    kill -9 "$PID" >> "$LOGFILE" 2>&1
  done
}
 
# === Function to extract all listener names ===
get_listener_names() {
  local lsn_file="$1"
  local lsn_list=()
  if [[ -f "$lsn_file" ]]; then
    while read -r line; do
      if [[ $line =~ ^[[:space:]]*([a-zA-Z0-9_]+)[[:space:]]*= ]]; then
        NAME="${BASH_REMATCH[1]}"
        if [[ ! "${lsn_list[*]}" =~ "$NAME" && "$NAME" != "SID_LIST" ]]; then
          lsn_list+=("$NAME")
        fi
      fi
    done < "$lsn_file"
  fi
 
  [[ ${#lsn_list[@]} -eq 0 ]] && lsn_list=("LISTENER")
  echo "${lsn_list[@]}"
}
 
# === Loop through selected databases ===
for idx in "${SELECTED[@]}"; do
  SID="${DB_LIST[$((idx-1))]}"
  [[ -z "$SID" ]] && echo -e "${YELLOW}Invalid selection: $idx${NC}" | tee -a "$LOGFILE" && continue
 
  echo -e "\n${YELLOW}Processing DB: $SID${NC}" | tee -a "$LOGFILE"
  export ORACLE_SID=$SID
  ORACLE_HOME=$(grep "^$SID:" "$ORATAB" | cut -d':' -f2)
  [[ -z "$ORACLE_HOME" ]] && echo -e "${RED}ORACLE_HOME not found. Skipping $SID.${NC}" | tee -a "$LOGFILE" && continue
  export ORACLE_HOME PATH=$ORACLE_HOME/bin:$PATH
 
  LISTENER_ORA="$ORACLE_HOME/network/admin/listener.ora"
  LISTENERS=($(get_listener_names "$LISTENER_ORA"))
 
  # === Stop all listeners ===
  for LSN in "${LISTENERS[@]}"; do
    echo -e "${YELLOW}Stopping listener $LSN...${NC}" | tee -a "$LOGFILE"
    lsnrctl stop "$LSN" >> "$LOGFILE" 2>&1
  done
 
  # === Kill LOCAL=NO processes ===
  kill_local_no_sessions
 
  # === Shutdown database ===
  read -p "Choose shutdown mode for $SID — IMMEDIATE (I) or ABORT (A)? [I/A]: " SHUT_MODE
  SHUT_CMD="SHUTDOWN IMMEDIATE;"
  [[ "$SHUT_MODE" =~ ^[Aa]$ ]] && SHUT_CMD="SHUTDOWN ABORT;"
 
  echo -e "${YELLOW}Shutting down $SID using ${SHUT_MODE^^} mode...${NC}" | tee -a "$LOGFILE"
  sqlplus -s / as sysdba <<EOF >> "$LOGFILE"
$SHUT_CMD
EXIT;
EOF
 
  # === Startup ===
  echo -e "${YELLOW}Starting $SID in $MODE mode...${NC}" | tee -a "$LOGFILE"
  if [[ "$MODE" == "MOUNT" ]]; then
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
 
  # === Start all listeners ===
  for LSN in "${LISTENERS[@]}"; do
    echo -e "${YELLOW}Starting listener $LSN...${NC}" | tee -a "$LOGFILE"
    lsnrctl start "$LSN" >> "$LOGFILE" 2>&1
    lsnrctl status "$LSN" | grep "STATUS of the" > /dev/null
    if [[ $? -eq 0 ]]; then
      echo -e "${GREEN}Listener $LSN is running.${NC}" | tee -a "$LOGFILE"
    else
      echo -e "${RED}Listener $LSN failed to start.${NC}" | tee -a "$LOGFILE"
    fi
  done
 
  # === Check DB mode and start MRP if needed ===
  DB_MODE=$(sqlplus -s / as sysdba <<EOF
SET HEAD OFF FEEDBACK OFF PAGES 0
SELECT open_mode FROM v\$database;
EXIT;
EOF
  )
  DB_MODE=$(echo "$DB_MODE" | tr -d '[:space:]')
 
  if [[ "$DB_MODE" == "READONLY" || "$DB_MODE" == "READONLYWITHAPPLY" ]]; then
    echo -e "${YELLOW}$SID is in READ ONLY mode. Attempting to start MRP...${NC}" | tee -a "$LOGFILE"
    sqlplus -s / as sysdba <<EOF >> "$LOGFILE"
ALTER DATABASE RECOVER MANAGED STANDBY DATABASE DISCONNECT FROM SESSION;
EXIT;
EOF
    echo -e "${GREEN}MRP started successfully for $SID.${NC}" | tee -a "$LOGFILE"
  fi
 
done
 
echo -e "\n${GREEN}===== Script Completed at $(date '+%Y-%m-%d %H:%M:%S') =====${NC}" | tee -a "$LOGFILE"