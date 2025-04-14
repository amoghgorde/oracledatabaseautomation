# oracledatabaseautomation

These scripts are written to automate the database and listener startup and shut down procedure with selections. 

Pre-requisite - 

1. Entry for the all the database is present in /etc/oratab and all enabled databases unhashed. 
2. Directory strcutre present for logs
3. Execute permission for all the files 

The main script is db_master_menu.sh in which there are total 3 scripts - 

DB MASTER MENU - 
  1. start_selected_dbs.sh
  2. stop_selected_dbs.sh
  3. restart_selected_dbs.sh

Functions - 

1. All scripts will automatically fetch the db home path and SID from /etc/oratab and will give option based on how many DB's are present on the DB server. 
2. It will automatically ignore Db's with # (comment) and +ASM.
3. Logging is enabled for all the scripts. It will create log in the directory where script is run or you can specify the location.
4. The scipts are working for Linux Based OS with Bash. Woriking on scripts for IBM AIX based systems. 

1. start_selected_dbs.sh -

This script will give startup options 
1. Mount
2. Open

It will also give prompt to start DB listeners. Fetching listeners names from - $ORACLE_HOME/network/admin/listener.ora
It will print once the DB and Listeners are up and running. 
Also, added one more check to look if the database is open in READ ONLY. If the condition is met it will automatically start the MRP process. 

2. stop_selected_dbs.sh -

It will give prompt to stop DB as well as listerners. It gives shut down options I for Immediate and A for Abort. 
Added prompt to kill local sessions through ps -ef|grep LOCAL=NO for faster shut down process. It will print on screen once the DB's and listeners are down. 

3. restart_selected_dbs -

It will give prompt to stop DB as well as listerners. It gives shut down options I for Immediate and A for Abort. 
Added prompt to kill local sessions through ps -ef|grep LOCAL=NO for faster shut down process. 
Once the DB's and listeners are down it will automatically startup the databases. Again giving option to start the database in - 
1. Mount
2. Open

After confirmation the database instance will be started. Listeners are started before bringing up the databases. 
On successful execution of the script it will print on screen and exit to main menu. 

Feel free to use the script and do let me know if any improvments can be done in the sripts. 
Don't have a good day, have a great day!
