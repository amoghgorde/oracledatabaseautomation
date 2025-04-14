#!/bin/bash
######################################################################################
##  DB & LISTENER STOP SCRIPT with Session Kill - BY AMOGH GORDE                   ##
######################################################################################
 
ORATAB=/etc/oratab
LOGFILE="stop_dbs.log"
GREEN="\e[32m"; YELLOW="\e[33m"; RED="\e[31m"; NC="\e[0m"
 
echo "===== DB Shutdown Started: $(date) =====" >> "$LOGFILE"
 
[[ ! -f "$ORATAB" ]] && echo -e "${RED}ERROR: $ORATAB not found.${NC}" | tee -a "$LOGFILE" && exit 1
 
# Get eligible DBs (excluding ASM)
DB_LIST=($(grep -v '^#' "$ORATAB" | grep -v '+ASM' | grep ':Y' | cut -d':' -f1))
[[ ${#DB_LIST[@]} -eq 0 ]] && echo -e "${YELLOW}No eligible DBs found.${NC}" | tee -a "$LOGFILE" && exit 0
 
echo -e "${GREEN}Available Databases:${NC}"
for i in "${!DB_LIST[@]}"; do printf "%2d) %s\n" $((i+1)) "${DB_LIST[$i]}"; done
 
read -p "Enter DB numbers to stop (e.g. 1 2): " -a SELECTED
 
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
 
for idx in "${SELECTED[@]}"; do
  SID="${DB_LIST[$((idx-1))]}"
  [[ -z "$SID" ]] && echo -e "${RED}Invalid selection: $idx${NC}" | tee -a "$LOGFILE" && continue
 
  echo ""
  read -p "Do you want to shut down $SID? (y/n): " confirm
  [[ "$confirm" != [Yy] ]] && echo -e "${YELLOW}Skipped $SID.${NC}" | tee -a "$LOGFILE" && continue
 
  read -p "Shutdown mode for $SID � IMMEDIATE (I) or ABORT (A)? [I/A]: " mode
  SHUT_CMD="SHUTDOWN IMMEDIATE;"
  [[ "$mode" =~ ^[Aa]$ ]] && SHUT_CMD="SHUTDOWN ABORT;"
 
  echo -e "${YELLOW}Shutting down DB: $SID using ${mode^^} mode...${NC}" | tee -a "$LOGFILE"
 
  export ORACLE_SID=$SID
  ORACLE_HOME=$(grep "^$SID:" "$ORATAB" | cut -d':' -f2)
  [[ -z "$ORACLE_HOME" ]] && echo -e "${RED}ORACLE_HOME not found for $SID. Skipping...${NC}" | tee -a "$LOGFILE" && continue
  export ORACLE_HOME PATH=$ORACLE_HOME/bin:$PATH
 
  # Kill DB sessions
  echo -e "${YELLOW}Killing active DB sessions for $SID...${NC}" | tee -a "$LOGFILE"
  sqlplus -s / as sysdba <<EOF >> "$LOGFILE"
SET HEADING OFF FEEDBACK OFF
BEGIN
FOR c IN (SELECT sid, serial# FROM v\$session WHERE type = 'USER' AND status = 'ACTIVE') LOOP
EXECUTE IMMEDIATE 'ALTER SYSTEM KILL SESSION ''' || c.sid || ',' || c.serial# || ''' IMMEDIATE';
END LOOP;
END;
/
$SHUT_CMD
EXIT;
EOF
 
  # Kill OS sessions with LOCAL=NO
  read -p "Kill OS processes with LOCAL=NO for $SID? (y/n): " killos
  if [[ "$killos" =~ ^[Yy]$ ]]; then
    echo -e "${YELLOW}Killing OS processes with LOCAL=NO for $SID...${NC}" | tee -a "$LOGFILE"
    for PID in $(ps -ef | grep "[o]ra_.*${SID}" | grep "LOCAL=NO" | awk '{print $2}'); do
      echo "Killing PID $PID" | tee -a "$LOGFILE"
      kill -9 "$PID" >> "$LOGFILE" 2>&1
    done
  fi
 
  # Detect listener names
  LSN_FILE="$ORACLE_HOME/network/admin/listener.ora"
  LISTENERS=($(get_listener_names "$LSN_FILE"))
 
  # Prompt and stop listeners
  for LSN in "${LISTENERS[@]}"; do
    read -p "Stop listener $LSN for $SID? (y/n): " stoplsnr
    if [[ "$stoplsnr" =~ ^[Yy]$ ]]; then
      echo -e "${YELLOW}Stopping Listener: $LSN${NC}" | tee -a "$LOGFILE"
      lsnrctl stop "$LSN" >> "$LOGFILE" 2>&1
    else
      echo -e "${YELLOW}Skipped stopping $LSN for $SID.${NC}" | tee -a "$LOGFILE"
    fi
  done
 
  echo -e "${GREEN}$SID and related components processed.${NC}" | tee -a "$LOGFILE"
done
 
echo -e "${GREEN}===== Shutdown script completed: $(date) =====${NC}" | tee -a "$LOGFILE"