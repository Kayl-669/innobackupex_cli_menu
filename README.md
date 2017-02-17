# Binary Backup Automation Script
This documentation relates to the *innobackupex_cli_menu.sh* script.

*innobackupex_cli_menu.sh* is a bash wrapper script that provides a more convenient means to perform backups using Percona's innobackupex utility. Essentially, its user selects a local backup location and doing all types of binary backup work with an arbitrary remote MySQL host to and from that directory is very straightforward. This activity includes:

* Full streaming backup
* Partial streaming backup
* Incremental (full/partial) streaming backup
* All the above types of streaming in compressed and/or encrypted states.
* Complete restore of backup
* Partial restore from backup
* Preparing backups for partial restore - allowing further incremental backups to be applied.
* Fully preparing backups for fast server startup. 
* Preparing/restoring and leaving in compressed and/or encrypted state.

## Use cases
Although innobackupex is very easy to use (it is itself a convenience script for the xtrabackup binary), the number operations required to perform an entire backup routine - including executing full and incremental backups, managing lists of tables for partial backups, storing and restoring from compressed and/or encrypted files - means that consistently performing backups in an automated fashion calls for a convenience script.

## Limitations

* Restoring *from* backups will only work when the target MySQL server is stand-alone rather than clustered. *Taking* backups from clustered nodes is supported however.
* MySQL client connection username/password and encryption key currently stored as clear text in script. No less secure than other DBA scripts.
* Point-in-time recovery is possible (based on incremental binlogs being stored with backups) but is not automated via the menu-interface. Full recovery from incremental backups is supported however.
* The scheduling functionality currently only supports doing a single full backup once every 24 hours. *innobackupex_cli_menus’s* user has to specify the time that this takes place and then specifies the period the script should wait before doing each and every incremental backup.


## System Permissions and MySQL Grants
Write permissions on the target MySQL server's datadir are required to restore backups. The easiest way to achive this is if the script is configured to login to remote hosts using the remote 'mysql' system user - this requires modifying it to give it a home directory for /home/mysql/.ssh/authorized_keys and ensuring that the backup script host's public key is in this file.

The target MySQL server needs to be setup with two sets of grants for *innobackupex_cli_menu.sh* to be able to interact with it:

~~~~
GRANT SELECT, SHOW DATABASES, CREATE, DROP, CREATE TABLESPACE, ALTER ON *.* 
TO <script_mysql_user>@<innobackupex_cli_menu script host> 
IDENTIFIED BY <script_mysql_user_pw>;

GRANT SUPER, RELOAD, PROCESS, LOCK TABLES, REPLICATION CLIENT ON *.* 
TO <script_mysql_user>@localhost 
IDENTIFIED BY <script_mysql_user_pw>;
-- Note that this grant may also need to be performed for '127.0.0.1'.
~~~~
## Dependencies
*innobackupex_cli_menu.sh* requires the following on the host where it is run:

1. percona-server-client
2. mysql-connector-python
	* If this is installed into the /usr/lib/python2.6/site-packages folder then Python2.7 can't detect it. You can resolve this issue by linking the mysql module to the Python2.7 modules directory:

    `ln -s /usr/lib/python2.6/site-packages/mysql /usr/lib/python2.7/site-packages/mysql`

3. percona-xtrabackup-24
4. tmux
5. Other dependencies kept in the *dependencies* folder:
    * *qpress* - 3rd-party utility for compressing and uncompressing in the same format that *xtrabackup* uses.
    * *repl_ripper_bu_manager.py* - Python script used by *innobackupex_cli_menu.sh* to connect to MySQL services, read their contents and populate the *tables.list* file used for partial backups.
    * *tables_list_analyser.py* - Python script used by *innobackupex_cli_menu.sh* to connect to MySQL services, and provide an (occasionally wildly inaccurate) estimate about how big a backup will be based on the content of the *tables.list* file.

## Improvements Required
1. When the *innobackupex_cli_menu.sh* script is launched whilst configured to target a remote host that is unreachable the script will appear to fail to start properly. The solution is to CTRL-C the script to exit, edit the script and change the value of the target_mysql_host variable that appears in the first section of the script. You can run the script again and will see the full menu if the target host is reachable over the network.

## How-to: take a full streaming binary backup (compressed and encrypted)

1. Run *innobackupex_cli_menu.sh*. To take advantage of using a tmux session, use:

    `tmux new-session -d -s my_session_name ./innobackupex_cli_menu.sh && tmux attach -t my_session_name`

2. Enter **1** to configure the local backup location. 
    * This will change the backup_location variable in the currently running script and change the value stored in the script file itself - this enables the script to "remember" your choice.
    * This must be a new or empty directory.
    * You can confirm that the value you entered was correct because it is printed out in the ** Settings ** section of the menu. 
    * Note: You can string a backup directly to /var/lib/mysql - the script makes preparing a backup easier in this scenario.
3. Enter **2** to change the target MySQL server hostname or IP address.
    * You can confirm that the value you entered was correct because it is printed out in the ** Settings ** section of the menu. 
4. Check that the script reports that you have passwordless access to the target system and access to the target system’s MySQL service. The script should output the following:
    ```.
    ****     Settings    ****
    ...
    Target MySQL host:          qct-rs1.test
    Target host sys user:       mysql
    ...
    ****     Status      ****
    Connection to target MySQL server: OK (Version: 5.7.16-10-log)
    mysql pwless access @ qct-rs1.test: Yes
    ...
    ```
    
    * Note that the target host system user and MySQL user credentials can be changed by editing the *innobackup_cli_menu.sh* script itself. This is easy because this configuration appears once at the top of the script.
5. Enter **3** to see the menu options for taking backups.
6. When doing a backup to a clean directory you can choose to do a backup of the entire server or only tables listed in the tables.list file in the same directory as *innobackupex_cli_menu.sh*. Enter **a** to do a full backup.
    * Note: this will be compressed and encrypted if these settings are set to YES inside the script.
7. A log file produced by the *innobackupex_cli_menu.sh* script is stored locally at the backup path.

## How-to: Restore the entirety of a backup to the datadir of a remote host
1. Run *innobackupex_cli_menu.sh*. To take advantage of using a tmux session, use:
    `tmux new-session -d -s my_session_name ./innobackupex_cli_menu.sh && tmux attach -t my_session_name`

2. Enter **1** to change the local backup location to a directory that contains a *full_backup_YY-MM-DD_HH-mm-SS* subdirectory as generated by this script. You should see something similar to the following:
    ```. 
    ****  Backup Content ****
    Content @ /usr/tmpdumps: Binary
    .
    Last full backup: 17-02-01_11-51-06 (0000000 -> 1499052531928)
         Incremental: ...
         Incremental: ...
         ...
    ``` 
3. Enter **2** to change the target MySQL server hostname or IP address.
    * You can confirm that the value you entered was correct because it is printed out in the ** Settings ** section of the menu. 
4. Check that the script reports that you have passwordless access to the target system and access to the target system’s MySQL service. The script should output the following:
    ```.
    ****     Settings    ****
    ...
    Target MySQL host:          qct-rs1.test
    Target host sys user:       mysql
    ...
    ****     Status      ****
    Connection to target MySQL server: OK (Version: 5.7.16-10-log)
    mysql pwless access @ qct-rs1.test: Yes
    ...
    ```

  * Note that the target host system user and MySQL user credentials can be changed by editing the *innobackup_cli_menu.sh* script itself. This is easy because this configuration appears once at the top of the script.
5. Enter 6 to prepare the backup "redo-only".
6. (Optional) Enter 6 to fully prepare the backup - rolling backup uncommitted transactions. On the plus side, this reduces the startup time of the server once you’ve restored the data. On the otherhand, you can't continue to do incremental backups on top of backups that have been fully prepared.
7. (Ensuring the target server is stopped) Enter 7 to copy the backup files to the target host’s datadir, additionally changing their ownership to the *mysql* system user. *innobackupex_cli_menu.sh* then gives you the option to start the target MySQL service. **Note:** internally the script uses `service mysql start` which may not be useful for bootstrapping.

## How-to: Create a backup routine to backup a single database
Note: the backup script currently only supports doing a full backup once every 24 hours. It’s user has to specify the time that this takes place and then specifies the period the script should wait before doing each and every incremental backup.

The easiest way to select a single database to do a partial backup from is to edit the repl.cnf file in the same directory as the innobackupex_cli_menu.sh script. This file is just like any other repl.cnf file; you use replicate-do-table and replicate-wild-do-table parameters to identify single tables and groups of tables, respectively.
For example, to enable a partial backup of the just the insuranceinitiatives database, only the following line needs to be in the repl.cnf file:

    replicate-wild-do-table=insuranceinitiatives.%

1. Run the innobackupex_cli_menu.sh script. Don’t worry about using tmux at this point because the scheduling relies upon spawning a tmux session anyway.
2. Enter **1** to configure the local backup location. 
    * This will change the backup_location variable in the currently running script and change the value stored in the script file itself - this enables the script to "remember" your choice.
    * This must be a new or empty directory.
    * You can confirm that the value you entered was correct because it is printed out in the ** Settings ** section of the menu. 
3. Enter **2** to change the target MySQL server hostname or IP address.
    * You can confirm that the value you entered was correct because it is printed out in the ** Settings ** section of the menu. 
4. Check that the script reports that you have passwordless access to the target system and access to the target system’s MySQL service. The script should output the following:
    ```.
    ****     Settings    ****
    ...
    Target MySQL host:          qct-rs1.test
    Target host sys user:       mysql
    ...
    ****     Status      ****
    Connection to target MySQL server: OK (Version: 5.7.16-10-log)
    mysql pwless access @ qct-rs1.test: Yes
    ...
    ```
    * Note that the target host system user and MySQL user credentials can be changed by editing the *innobackup_cli_menu.sh* script itself. This is easy because this configuration appears once at the top of the script.

5. Enter **5** to generate a new tables.list file from the repl.cnf file edited as documented above. You will be asked if you want to include the system tables or not. Enter **YES** to include tables from the *sys*, *performance_schema* and *mysql* databases.
    * A python script connects to the target MySQL server and generates the tables.list file based on querying the information_schema with a WHERE clause based on the repl.cnf rules.
    * For future reference when doing a partial backup, only the tables.list file matters - repl.cnf and the python script that interrogates it is just a convenience.
    *At this point the menu should report something new for the content of tables.list file. Notice how the remote MySQL server is interrogated for an estimate of the size of the backup:
    ```.
   ****     Status      ****
    ...
    Content of tables.list file:    44 tables from 1 database(s)
                                    (approx size: 3MB)
    ...
    ```
6. Enter **3** to reveal the menu options for creating a new backup.
7. Enter **c** to ensure that the daily full backup takes place at a suitable time.
8. Enter **d** to ensure that incrementals take place after a suitable interval.
9. Enter **f** to initiate a partial backup schedule based on scheduling parameters set in steps 7 and 8 and the table selections in the tables.list file.
    * A tmux session with the name of the target MySQL host has been created. Use `tmux attach -t <session_name>` to attach to it
    * Backups are created at the specified backup location in a dated subdirectory. 
    * Also a copy of the innobackupex_cli_menu script and its dependencies are are also moved here. Use this copy of the script to manage the backup because the backup location is automatically configured in it to point at the most recent full and incremental backups.


## How-to: Restore a single database from a backup to a remote MySQL server
Note: This routine has not been tested on clustered nodes - take nodes out of the cluster before bootstrapping.

1. Follow steps 1-6 from Routine: Restore the entirety of a backup to the datadir of a remote host
2. Enter **8** to restore the tables listed in the tables.list file located in the same directory as the innobackpex_cli_menu script you are running. The backup directory itself contains a tables.list file that lists the contents of the backup. You could copy this to the script directory and remove the lines of tables you’re not interested in restoring.
