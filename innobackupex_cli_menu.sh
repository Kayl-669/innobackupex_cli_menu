#!/bin/bash
# SCRIPT SETTINGS
VERSION=20170214
logfile="$(basename $0).log-$(date +%y%m%d%H%M%S)" # $0 is path to script

# SCHEDULE
# Format example 
# sch_full_backup_time=2230
# takes a full backup at 10:30pm 
sch_full_backup_time=0846
# Format example 
# sch_incr_bu_interval=0130
# takes an incremental backup 1 hour 30 minutes after the last backup
sch_incr_bu_interval=0002
sch_backups_to_keep=3

# BACKUP SETTINGS
target_mysql_host=localhost
target_host_sys_user=mysql # This user needs access to the server's datadir
backup_location=/var/lib/mysql_cache/bu
compaction=NO # (skip secondary index pages) DONT USE THIS - UNABLE TO RESTORE SUCCESSFULLY
compression=YES
encryption=YES
encrypt_key="32CHARACTERENCRYPTIONKEY"

# MySQL Login Credentials
username=mysqlbackup
password='topsecret'

main() {
    _exit=0
    tables_list_analysis_recheck=1
    do_backup_menu=0
    while [ $_exit -eq 0 ]
    do
        #clear
        echo "*********************************************"
        echo "*  MySQL Backup Manager - version $VERSION  *"
        echo "*                                           *"
        echo "*********************************************"
        echo
        echo "****     Settings    ****"
        echo -e "Backup location:\t$backup_location"
        echo -e "Target MySQL host:\t$target_mysql_host"
        echo -e "Target host sys user:\t$target_host_sys_user"
        echo -e "Using compaction:\t${compaction:0:1}"
        echo -e "Using compression:\t${compression:0:1}"
        echo -e "Using encryption:\t${encryption:0:1}"
        echo
        echo "****     Status      ****"
        print_server_connection_status
        print_tables_list_analysis
        print_free_space_at_backup_location
        echo
        echo "****  Backup Content ****"
        print_backup_location_content_main
        get_menu_switches
        echo
        echo "****     Actions     ****"
        echo "(0) Exit"
        echo "(1) Change local backup location"
        echo "(2) Change target MySQL host"
        if [[ $ms_can_do_bu == 1 ]]; then
            echo "(3) Perform backup..."
        fi
        if [[ $do_backup_menu == 1 ]]; then
            if [[ $ms_fresh_bu_location == 1 ]]; then
                echo
                echo "New backup options..."
                echo "  (a) Do a full binary backup"
                echo "  (b) Do a full partial binary backup with tables.list"
                echo
                echo "  ** Scheduling Service **"
        	echo "   Scheduled time for full backups: $sch_full_backup_time"
        	echo "   Scheduled delay between incrementals: $sch_incr_bu_interval"
        	echo "   How many days of backups to keep: $sch_backups_to_keep"
		echo
                echo "  (c) Change time of day to perform full backup"
                echo "  (d) Change time delay between incremental backups"
                echo "  (e) Change number of days of backups to keep"
                echo "  (f) Schedule a backup routine - backup entire server"
                echo "  (g) Schedule a backup routine - backup tables listed in tables.list"
                echo
            else if [[ $ms_can_do_incr_bbu == 1 ]]; then
                echo "  (a) Do an incremental binary backup"
            else if [[ $ms_can_do_part_incr_bbu == 1 ]]; then
                echo "  (a) Do an incremental partial binary backup"
            fi fi fi
        fi
        if [[ $ms_fresh_bu_location -eq 1 ]] && \
            [[ $have_mysql_server_access == 1 ]]; then
            echo "(4) Generate tables.list from all databases/tables"
            echo "(5) Generate tables.list from ./repl.cnf"
        fi
        if [[ $ms_can_summarise_bu_content == 1 ]]; then
            echo "(4) Summarise backup's content [feature not created]"
        fi
        if test $ms_can_prepare_redo_only -eq 1; then
            echo "(5) Prepare binary backup(s) - redo-only (leave encrypted and/or compressed)"
            echo "(6) Prepare binary backup(s) - redo-only (leave ready to use)"
        else if test $ms_can_prepare_rolled_back -eq 1; then
            echo "(5) Prepare binary backup - rollback uncommitted (leave encrypted and/or compressed)"
            echo "(6) Prepare binary backup - rollback uncommitted (leave ready to use)"
        fi fi
        if test $ms_can_restore_complete_bbu -eq 1; then
            echo "(7) Restore full binary backup"
        fi
        if [[ $ms_can_restore_partial_bbu -eq 1 ]]; then
            echo "(8) Restore parts of binary backup using tables.list"
        fi
        echo
        printf "Choice: "

        read _input
        echo
        case $_input in
            0)
                _exit=1
            ;;
            1)
                change_backup_location
            ;;
            2)
                change_target_mysql_host
            ;;
            3)
                do_backup_menu=1
            ;;
            a)
                if [[ $ms_can_do_bu == 1 ]]; then
                    if [[ $ms_fresh_bu_location == 1 ]]; then
                        do_full_bbu FULL
                    else if [[ $ms_can_do_incr_bbu == 1 ]]; then
                        do_incr_bbu FULL
                    else if [[ $ms_can_do_part_incr_bbu == 1 ]]; then
                        do_incr_bbu PARTIAL
                    fi fi fi
                fi
                do_backup_menu=0
            ;;
            b)
                if [[ $ms_fresh_bu_location == 1 ]]; then
                    do_full_bbu PARTIAL
                fi
                do_backup_menu=0
            ;;
            c)
                if [[ $ms_can_do_bu == 1 ]]; then
                    if [[ $ms_fresh_bu_location == 1 ]]; then
                        change_sch_full_backup_time
                    fi
		fi 
            ;;            
            d)
                if [[ $ms_can_do_bu == 1 ]]; then
                    if [[ $ms_fresh_bu_location == 1 ]]; then
                        change_sch_incr_bu_interval
                    fi
		fi 
            ;;
            e)
                if [[ $ms_can_do_bu == 1 ]]; then
                    if [[ $ms_fresh_bu_location == 1 ]]; then
                        change_sch_backups_to_keep
                    fi
		fi 
            ;;
            f)
                if [[ $ms_can_do_bu == 1 ]]; then
                    if [[ $ms_fresh_bu_location == 1 ]]; then
                	prepare_schedule FULL
                    fi
		fi 
            ;;
            g)
                if [[ $ms_can_do_bu == 1 ]]; then
                    if [[ $ms_fresh_bu_location == 1 ]]; then
                	prepare_schedule PARTIAL
                    fi
		fi 
            ;;
            4)
                if [[ $ms_fresh_bu_location -eq 1 ]] && \
                    [[ $have_mysql_server_access == 1 ]]; then
                    populate_table_list "--all-tables"
                fi
            ;;
            5)
                if [[ $ms_fresh_bu_location -eq 1 ]] && \
                    [[ $have_mysql_server_access == 1 ]]; then
                    populate_table_list
                fi
                if test $ms_can_prepare_redo_only -eq 1; then
                    prepare_bbu "redo params"
                else if test $ms_can_prepare_rolled_back -eq 1; then
                    prepare_bbu "rollback params"
                fi fi
            ;;
            6)
                if test $ms_can_prepare_redo_only -eq 1; then
                    prepare_bbu "redo no params"
                else if test $ms_can_prepare_rolled_back -eq 1; then
                    prepare_bbu "rollback no params"
                fi fi
            ;;
            7)
                if test $ms_can_restore_complete_bbu -eq 1; then
                    restore_complete_bbu
                fi
            ;;
            8)
                if [[ $ms_can_restore_partial_bbu -eq 1 ]]; then
                    restore_partial_bbu
                fi
            ;;
        esac
    done
}

get_menu_switches() {
    ms_fresh_bu_location=0
    if [[ "$content_at_bu_location" == *"New directory"* ]] || \
        [[ "$content_at_bu_location" == *"Empty"* ]]; then
        ms_fresh_bu_location=1
    fi
    ms_can_do_part_incr_bbu=0
    ms_can_do_incr_bbu=0
    if [[ $have_mysql_server_access == 1 ]] && \
        [[ "$content_at_bu_location" == "Binary" ]] && \
        [[ "$last_backup_preparedness" != *"RB"* ]]; then
            if [[ "$full_backup_partial" == "Y" ]]; then
                ms_can_do_part_incr_bbu=1
            else
                ms_can_do_incr_bbu=1
            fi
    fi
    ms_can_do_bu=0
    if ([[ $ms_fresh_bu_location == 1 ]] \
        || [[ $ms_can_do_incr_bbu == 1 ]] \
        || [[ $ms_can_do_part_incr_bbu == 1 ]]) \
        && [[ $have_pwless_sys_access == 1 ]]; then
        ms_can_do_bu=1
    fi
    ms_can_summarise_bu_content=0
    if [[ $ms_fresh_bu_location -eq 0 ]] \
        && [[ "$content_at_bu_location" != *"not a backup"* ]]; then
        ms_can_summarise_bu_content=1
    fi
    ms_can_prepare_redo_only=0
    if [[ "$content_at_bu_location" == "Binary" ]] \
        && [[ "$last_backup_preparedness" != *"RB"* ]]; then
        ms_can_prepare_redo_only=1
    fi
    ms_can_prepare_rolled_back=0
    if [[ "$last_backup_preparedness" == *"RO"* ]]; then
        ms_can_prepare_redo_only=0
        ms_can_prepare_rolled_back=1
    fi
    ms_can_restore_complete_bbu=0
    # the following check is dodgy because invalid details don't mean
    # the server isn't running
    if ([[ "$last_backup_preparedness" == *"RO"* ]] || [[ "$last_backup_preparedness" == *"RB"* ]]) && [[ $have_mysql_server_access -eq 0 ]]; then
        ms_can_restore_complete_bbu=1
    fi
    ms_can_restore_partial_bbu=0
    if [[ $content_at_bu_location == *"Binary"* ]] && \
        [[ $have_pwless_sys_access == 1 ]] && \
        [[ $have_mysql_server_access == 1 ]]; then
        # Don't allow partial restore until increments applied
        if [[ "$last_backup_preparedness" == *"RO"* ]] || [[ "$last_backup_preparedness" == *"RB"* ]]; then
            ms_can_restore_partial_bbu=1
        else
            ms_can_restore_partial_bbu=0
        fi
    fi
}

print_server_connection_status() {
    have_mysql_server_access=0
    printf "Connection to target MySQL server: "
    _version=`mysql --host=$target_mysql_host \
        --user=$username \
        --password="$password" \
        --batch \
        --skip-column-names \
        -e "select @@version" 2>&1 | awk 'FNR==2{print}'`
    if [ ${#_version} -lt 20 ]; then
        echo -e "\t\tOK (Version: $_version)"
        have_mysql_server_access=1
    else
        echo "Error: Ensure $username user is usable from this host and that server is running OK and reachable!"
        echo $_running
    fi
    printf "$target_host_sys_user pwless access @ $target_mysql_host:\t\t"
    have_pwless_sys_access=0
    ssh $sshp -oPreferredAuthentications=publickey \
	 $target_host_sys_user@$target_mysql_host 2>/dev/null exit
    if [[ $? -eq 0 ]]; then
        have_pwless_sys_access=1
        echo "Yes"
    else
        echo "No"
    fi
}

print_tables_list_analysis() {
    if [ $tables_list_analysis_recheck -eq 1 ]; then
        # python script requires SHOW DATABASES priv
        _tl_analysis=`$script_dir/dependencies/tables_list_analyser.py \
            --username=$username \
            --password="$password" \
            --tables-list-file="$script_dir/tables.list" \
            --host=$target_mysql_host`
        tables_list_analysis_recheck=0
    fi
    printf "Content of tables.list file:\t\t\t"
    echo -e "$_tl_analysis"
}

print_free_space_at_backup_location() {
    _parent_dir=$backup_location
    _error=`df -Ph $_parent_dir 2>&1`
    while [[ "$_error" == *"such"* ]]
    do
        _parent_dir=${_parent_dir%*/*}
        _error=`df -Ph $_parent_dir 2>&1`
    done
    _free_space=`df -Ph $_parent_dir  2>&1 | tail -1 | awk '{print $4}'`
    _mount_point=`df -Ph $_parent_dir  2>&1 | tail -1 | awk '{print $6}'`
    printf "Free space @ ${_mount_point}:\t\t\t$_free_space"  
    echo
}

print_backup_location_content_main() {
    if ! [ -d $backup_location ]; then
        content_at_bu_location="[New directory]"
    else 
        if [ "$(ls -A $backup_location)" ]; then
            _dir_list=($backup_location/full_backup*)
            _prefix_len=$((${#backup_location}+15))
            if [ ${#_dir_list} -gt $_prefix_len ]; then
                content_at_bu_location="Binary"
            else 
                content_at_bu_location="Directory in use - not a backup"
            fi 
        else
            content_at_bu_location="[Empty]"
        fi
    fi
    echo "Content @ $backup_location: $content_at_bu_location"
    echo
    if [ "$content_at_bu_location" == "Binary" ]; then
        print_backup_location_content_binary
    fi
}

print_backup_location_content_binary() {
    get_last_full_bbu
    get_date_from_bbu_path $last_full_bbu_path
    if [ ${#extracted_bbu_date_string} -gt 1 ]; then
        get_bbu_details $last_full_bbu_path
        last_backup_preparedness=$bbu_prepared
        full_backup_partial=$bbu_partial
        _encrypted=$bbu_encrypted
        _compact=$bbu_compact
        _compressed=$bbu_compressed
        echo -e "Last full backup: $extracted_bbu_date_string (0000000\t\t-> $to_lsn)"
        get_next_incr_bbu_path $last_full_bbu_path
        incr_bbu_count=0
        while [ $next_incr_bbu_date -ne 0 ]; do
            (( incr_bbu_count += 1 ))
            get_date_from_bbu_path $next_incr_bbu_path
            get_bbu_details $next_incr_bbu_path
            printf "     Incremental: $extracted_bbu_date_string "
            echo -e "($from_lsn\t-> $to_lsn)"
            last_backup_preparedness=$bbu_prepared
            get_next_incr_bbu_path $next_incr_bbu_path
        done
        echo
        echo -e "Encrypted:\t$_encrypted"
        echo -e "Compact:\t$_compact"
        echo -e "Compressed:\t$_compressed"
        echo -e "Partial:\t$full_backup_partial"
        echo
        echo -e "Prepared:\t$last_backup_preparedness"
    fi
}

get_last_full_bbu() {
    last_full_bbu_date=$(date -d 2010-01-01 +%s)
    full_bbu_exists=0
    for i in ${backup_location}/* ; do # for all paths in this directory
         if [ -d $i ]; then  # if the path is a director        y
             if case $i in *"full_backup"*) true;; *) false;; esac; then
                 get_date_from_bbu_path $i
                 if [ $extracted_bbu_date -ge $last_full_bbu_date ]; then
                     last_full_bbu_date=$extracted_date
                     last_full_bbu_path=$i
                     full_bbu_exists=1
                 fi
             fi
         fi
     done
}

get_date_from_bbu_path() {
    _bu_loc_path_len=${#backup_location}
    (( _bu_loc_path_len += 1 ))
    _bu_dir=${1:$_bu_loc_path_len}
    extracted_bbu_date_string=${_bu_dir:12}
    _dt_day_str=${extracted_bbu_date_string:0:8}
    _dt_time_str=$(echo "${extracted_bbu_date_string:9:8}" | tr "-" ":")
    extracted_bbu_date=$(date -d "$_dt_day_str $_dt_time_str" +%s)
}

get_bbu_details() {
    from_lsn=`cat $1/xtrabackup_info | grep innodb_from_lsn`
    to_lsn=`cat $1/xtrabackup_info | grep innodb_to_lsn`
    from_lsn=${from_lsn:18}
    to_lsn=${to_lsn:16}
    # TODO
    bbu_binlog=`cat $1/xtrabackup_binlog_info | cut -f1`
    bbu_prepared=`cat $1/xtrabackup_info | grep prepared`
    bbu_prepared=${bbu_prepared:11}
    bbu_partial=`cat $1/xtrabackup_info | grep partial`
    bbu_partial=${bbu_partial:10}
    bbu_encrypted=`cat $1/xtrabackup_info | grep encrypted`
    bbu_encrypted=${bbu_encrypted:12}
    bbu_compact=`cat $1/xtrabackup_info | grep "compact ="`
    bbu_compact=${bbu_compact:10}
    bbu_compressed=`cat $1/xtrabackup_info | grep compressed`
    bbu_compressed=${bbu_compressed:13}
    if [[ $bbu_compressed == "compressed" ]]; then
        bbu_compressed=Y
    else
        bbu_compressed=N
    fi
}

get_next_incr_bbu_path() {
    _last_backup=$1
    get_date_from_bbu_path $_last_backup
    _last_backup_date=$extracted_bbu_date
    next_incr_bbu_date=$(date -d 2099-12-31 +%s)
    for i in ${backup_location}/* ; do # for all paths in this directory
        if [ -d "$i" ]; then  # if the path is a directory
            #if case $i in *"incr_backup"*) true;; *) false;; esac; then
            if [[ "$i" == *"incr_backup"* ]]; then
                get_date_from_bbu_path $i
                if [ $extracted_bbu_date -gt $_last_backup_date -a $extracted_bbu_date -lt $next_incr_bbu_date ]; then
                    next_incr_bbu_date=$extracted_bbu_date
                    next_incr_bbu_path=$i
                fi
            fi
        fi
    done
    if [ $next_incr_bbu_date -eq $(date -d 2099-12-31 +%s) ]; then
        next_incr_bbu_date=0
        next_incr_bbu_path=0
    fi
} 

change_backup_location() {
    df -h
    echo
    printf "Enter the new path for backup location: "
    read _newdir
    _newdir=$(echo $_newdir | sed 's/\//\\\//g')
    sed -i -- "s/^backup_location=.*/backup_location="${_newdir}"/" $0
    $0
    exit
}

change_sch_full_backup_time() {
    echo
    printf "Enter the time of day to perform full backups (format HHMM): "
    read _newtime
    sed -i -- "s/^sch_full_backup_time=.*/sch_full_backup_time="$_newtime"/" $0
    sch_full_backup_time=$_newtime
}

change_sch_incr_bu_interval() {
    echo
    printf "Enter the time delay between incremental backups (format HHMM): "
    read _newtime
    sed -i -- "s/^sch_incr_bu_interval=.*/sch_incr_bu_interval="$_newtime"/" $0
    sch_incr_bu_interval=$_newtime
}

change_sch_backups_to_keep() {
    echo
    printf "Enter the number of days of backups to keep (backups older than this are automatically deleted): "
    read _newdays
    sed -i -- "s/^sch_backups_to_keep=.*/sch_backups_to_keep="$_newdays"/" $0
    sch_backups_to_keep=$_newdays
}

change_target_mysql_host() {

    printf "Enter an IP or hostname for the target MySQL server: "
    read _newhost
    _newhost=$(echo $_newhost | sed 's/\//\\\//g')
    sed -i -- "s/^target_mysql_host=.*/target_mysql_host="${_newhost}"/" $0
    $0
    exit

}

do_full_bbu() {
    get_date_string_for_path
    _bu_path=$backup_location/full_backup_$current_date_string
    if [[ $1 == FULL ]]; then
        echo "Full backup selected - populating tables.list with all tables" >>$logfile
        populate_table_list "--all-tables"
        _tab_list_param=""
    else
        echo "Partial backup selected - copying ${script_dir}/tables.list to $target_host_sys_user@$target_mysql_host:~/tables.list" >>$logfile
        scp ${script_dir}/tables.list $target_host_sys_user@$target_mysql_host:~/tables.list
        if [[ $target_host_sys_user == "root" ]]; then
            _tab_list_param="--tables-file=/root/tables.list"
        else 
            _tab_list_param="--tables-file=/home/$target_host_sys_user/tables.list"
        fi
    fi
    echo "Creating directory $_bu_path" >>$logfile
    mkdir -p $_bu_path 
    ssh $sshp $target_host_sys_user@$target_mysql_host "innobackupex \
        --user=$username \
        --password=$password \
        $encryption_param \
        $compaction_param \
        $compression_param \
        $_tab_list_param \
        --parallel=8 \
        --stream=xbstream \
        /var/lib/mysql" > >(xbstream -x -C $_bu_path) 2> >(tee -a ${logfile} >&2)
    
    if [[ $encryption == YES ]]; then
        echo "Decrypting xtrabackup log files..." >>$logfile
        decrypt_path $_bu_path/xtrabackup_info.xbcrypt 2>>$logfile
        decrypt_path $_bu_path/xtrabackup_info.qp.xbcrypt 2>>$logfile
        decrypt_path $_bu_path/xtrabackup_binlog_info.xbcrypt 2>>$logfile
        decrypt_path $_bu_path/xtrabackup_binlog_info.qp.xbcrypt 2>>$logfile
    fi
    if [[ $compression == YES ]]; then
        echo "Uncompressing xtrabackup log files..." >>$logfile
        uncompress_path $_bu_path/xtrabackup_info.qp
        uncompress_path $_bu_path/xtrabackup_binlog_info.qp
    fi
    if [[ $encryption == YES ]]; then
        add_encrypted_note_to_path $_bu_path
    else
        add_unencrypted_note_to_path $_bu_path
    fi
    echo "prepared = N" >> $_bu_path/xtrabackup_info
    echo "Copying ${script_dir}/tables.list to $_bu_path" >>$logfile
    cp ${script_dir}/tables.list $_bu_path/
    echo "Dumping table_ddl (based on tables in $_bu_path/tables.list) to $_bu_path/table_ddl" >>$logfile
    dump_table_ddl $_bu_path
}

do_incr_bbu() {
    get_last_full_bbu
    if [[ $full_bbu_exists -eq 0 ]]; then
        echo "skipping incremental - no full backup exists"
        return 1
    fi
    _base_backup_path=$last_full_bbu_path
    # should never be left in state where the below is nec
    get_next_incr_bbu_path $last_full_bbu_path
    if [ $next_incr_bbu_date -ne 0 ];  then
        _base_backup_path=$next_incr_bbu_path
    fi
    while [ $next_incr_bbu_date -ne 0 ] ; do
        get_next_incr_bbu_path $next_incr_bbu_path
        if [ $next_incr_bbu_date -ne 0 ]; then
            _base_backup_path=$next_incr_bbu_path
        else
            break
        fi
    done
    echo "Performing incremental backup from base backup $_base_backup_path" >>$logfile
    get_bbu_details $_base_backup_path
    _incremental_from_lsn=$to_lsn
    _incremental_from_binlog=$bbu_binlog
    get_date_string_for_path
    _bu_path=$backup_location/incr_backup_$current_date_string
    echo "Creating backup directory $_bu_path" >>$logfile
    mkdir -p $_bu_path
    if [[ $1 == FULL ]]; then
        echo "Nonpartial backup selected - populating tables.list with all tables" >>$logfile
        populate_table_list "--all-tables"
        _tab_list_param=""
    else
        echo "Partial backup selected" >>$logfile
        echo "Copying $_base_backup_path/tables.list to $target_host_sys_user@$target_mysql_host:~/tables.list" >>$logfile
        scp $_base_backup_path/tables.list $target_host_sys_user@$target_mysql_host:~/
        echo "Copying $_base_backup_path/tables.list to $script_dir" >>$logfile
        cp $_base_backup_path/tables.list $script_dir
        if [[ $target_host_sys_user == "root" ]]; then
            _tab_list_param="--tables-file=/root/tables.list"
        else 
            _tab_list_param="--tables-file=/home/$target_host_sys_user/tables.list"
        fi
    fi
    ssh $sshp $target_host_sys_user@$target_mysql_host "innobackupex \
        --user=$username \
        --password=$password \
        --incremental \
        --incremental-lsn=$_incremental_from_lsn \
        --stream=xbstream \
        $_tab_list_param \
        $encryption_param \
        $compression_param \
        /var/lib/mysql" > >(xbstream -x -C $_bu_path) 2> >(tee -a $logfile >&2)
    echo "Copying binlogs since last backup to $_bu_path/binlogs/" >>$logfile
    mkdir $_bu_path/binlogs
    mysqlbinlog --read-from-remote-server \
        --host=$target_mysql_host \
        --user=$username \
        --password=$password \
        --raw \
        --to-last-log \
        --result-file=$_bu_path/binlogs/ \
        $_incremental_from_binlog 2>$logfile

    if [[ $encryption == YES ]]; then
        echo "Decrypting xtrabackup log files..." >>$logfile
        decrypt_path $_bu_path/xtrabackup_info.xbcrypt
        decrypt_path $_bu_path/xtrabackup_info.qp.xbcrypt
        decrypt_path $_bu_path/xtrabackup_binlog_info.xbcrypt
        decrypt_path $_bu_path/xtrabackup_binlog_info.qp.xbcrypt
        uncompress_path $_bu_path/xtrabackup_binlog_info.qp
    fi
    if [[ $compression == YES ]]; then
        echo "Uncompressing xtrabackup log files..." >>$logfile
        uncompress_path $_bu_path/xtrabackup_info.qp
        add_compressed_note_to_path $_bu_path
    else
        add_uncompressed_note_to_path $_bu_path
    fi
    if [[ $encryption == YES ]]; then
        add_encrypted_note_to_path $_bu_path
    else
        add_unencrypted_note_to_path $_bu_path
    fi
    echo "prepared = N" >> $_bu_path/xtrabackup_info
    echo "Copying $_base_backup_path/tables.list to $_bu_path/"
    cp $_base_backup_path/tables.list $_bu_path/
    dump_table_ddl $_bu_path
    echo "Dumping table_ddl (based on tables in $_bu_path/tables.list) to $_bu_path/table_ddl" >>$logfile
    return 0
}

get_date_string_for_path() {
    current_date_string=$(date +%y-%m-%d_%H-%M-%S)
}

prepare_bbu () {
    get_last_full_bbu
    echo "Preparing backup - decrypting/decompressing full backup" >>$logfile
    decrypt_path $last_full_bbu_path
    uncompress_path $last_full_bbu_path
    # replay committed only and leave uncommitted on full backup
    if [[ "$1" == *"redo"* ]]; then
        # do not prepare redo-only more than once!
        echo "Preparing redo-only $last_full_bbu_path" >>$logfile
        get_bbu_details $last_full_bbu_path
        if [[ "$bbu_prepared" == "N" ]]; then
           innobackupex --apply-log \
               --export \
               --redo-only $last_full_bbu_path
            sed -i -- "s/^prepared.*/prepared\ =\ RO/" $last_full_bbu_path/xtrabackup_info
        fi
    else
        echo "Preparing rolled back $last_full_bbu_path" >>$logfile
        innobackupex --apply-log \
            $uncompact_param \
            --export $last_full_bbu_path
        sed -i -- "s/^prepared.*/prepared\ =\ RB/" \
            $last_full_bbu_path/xtrabackup_info

        # not the most efficient way to do this but simple to understand
        # if backup_location is /var/lib/mysql then just move out of subdir
        # with timestamp and remove table dumps and tables.list
        if [[ $backup_location == "/var/lib/mysql" ]] \
            || [[ $backup_location == "/var/lib/mysql/" ]]; then
            echo "Looks like your populating /v/l/m directly; will automatically move out of timestamped subdirectory and clean up and chown..." | tee -a $logfile
            echo "Hit enter"
            read _
            rm $last_full_bbu_path/tables.list
            rm -r $last_full_bbu_path/table_ddl
            mv $last_full_bbu_path/* $backup_location/
            rm -r $last_full_bbu_path
            chown -R mysql: /var/lib/mysql
            exit
        fi
    fi
    get_next_incr_bbu_path $last_full_bbu_path
    while [ $next_incr_bbu_date -ne 0 ] ; do
        echo "Preparing backup - decrypting/decompressing incremental backup" >>$logfile
        decrypt_path $next_incr_bbu_path
        uncompress_path $next_incr_bbu_path
        if [[ "$1" == *"redo"* ]]; then
            sed -i -- "s/^prepared.*/prepared\ =\ RO/" $next_incr_bbu_path/xtrabackup_info
        else
            sed -i -- "s/^prepared.*/prepared\ =\ RB/" $next_incr_bbu_path/xtrabackup_info
        fi
        echo "Applying incremental $next_incr_bbu_path to $last_full_bbu_path" >>$logfile
        innobackupex --apply-log \
            --export \
            --redo-only $last_full_bbu_path \
            --incremental-dir=$next_incr_bbu_path
        cp $next_incr_bbu_path/tables.list $last_full_bbu_path/
        cp -R $next_incr_bbu_path/table_ddl $last_full_bbu_path
        # once full backup contains incr then incr becomes pointless
        rm -r $next_incr_bbu_path
        get_next_incr_bbu_path $next_incr_bbu_path
    done
    if [[ $encryption == YES ]] && [[ "$1" != *"no params"* ]]; then
        add_encrypted_note_to_path $last_full_bbu_path
    else
        add_unencrypted_note_to_path $last_full_bbu_path
    fi
    if [[ $compression == YES ]] && [[ "$1" != *"no params"* ]]; then
        add_compressed_note_to_path $last_full_bbu_path
        echo "Compressing backup $last_full_bbu_path" >>$logfile
        compress_path $last_full_bbu_path
    else
        add_uncompressed_note_to_path $last_full_bbu_path
    fi
    if [[ $encryption == YES ]] && [[ "$1" != *"no params"* ]]; then
        echo "Encrypting backup $last_full_bbu_path" >>$logfile
        encrypt_path $last_full_bbu_path
    fi
}

restore_complete_bbu() {
    _datadir_contents=`ssh $sshp $target_host_sys_user@$target_mysql_host "ls /var/lib/mysql"`
    if [ ${#_datadir_contents} -gt 0 ]; then
        echo "Datadir is not empty! Do you want to delete its contents? (YES - deletes)"
        read _choice
        if [[ $_choice == "YES" ]]; then
            echo "Restoring: datadir emptied" >>$logfile
            ssh $sshp $target_host_sys_user@$target_mysql_host "rm -r /var/lib/mysql/*"
        else
            exit
        fi
    fi
    get_last_full_bbu
    echo "Decrypting/Decompressing $last_full_bbu_path" >>$logfile
    decrypt_path $last_full_bbu_path
    uncompress_path $last_full_bbu_path
    echo "Copying backup from $last_full_bbu_path to $target_host_sys_user@$target_mysql_host:/var/lib/mysql/" >>$logfile
    scp -r $last_full_bbu_path/* $target_host_sys_user@$target_mysql_host:/var/lib/mysql/
    ssh $sshp $target_host_sys_user@$target_mysql_host "chown -R mysql: /var/lib/mysql"
    ssh $sshp $target_host_sys_user@$target_mysql_host "[[ -d /var/lib/mysql/table_ddl ]] && rm -r /var/lib/mysql/table_ddl"
    ssh $sshp $target_host_sys_user@$target_mysql_host / 
    for _i in `find /var/lib/mysql -iname *.exp`; do rm $_i ; done
    echo
    echo "Do you want to start the server? (YES - start server)"
    read _choice
    echo
    if [[ $_choice == "YES" ]]; then
        echo "Starting MySQL service" 2>>$logfile
        ssh $sshp $target_host_sys_user@$target_mysql_host "/etc/init.d/mysql start"
        tables_list_analysis_recheck=1
        echo
    fi
    echo "Return backup to a compressed/encrypted state? (YES to compress and/or encrypt)"
    read _choice
    if [[ $encryption == YES ]] && [[ $_choice == YES ]]; then
        add_encrypted_note_to_path $last_full_bbu_path
    else
        add_unencrypted_note_to_path $last_full_bbu_path
    fi
    if [[ $compression == YES ]] && [[ $_choice == YES ]]; then
        add_compressed_note_to_path $last_full_bbu_path
        echo "Compressing $last_full_bbu_path" >>$logfile
        compress_path $last_full_bbu_path
    else
        add_uncompressed_note_to_path $last_full_bbu_path
    fi
    if [[ $encryption == YES ]] && [[ $_choice == YES ]]; then
        echo "Encrypting $last_full_bbu_path" >>$logfile
        encrypt_path $last_full_bbu_path
    fi
}

restore_partial_bbu() {
    while read _tab_name; do
        _tab_name_clean=${_tab_name#*"."}
        _dot_pos=$(( ${#_tab_name}  - ${#_tab_name_clean} - 1))
        _db_name=${_tab_name:0:$_dot_pos}
        _ddl_path=$last_full_bbu_path/table_ddl/${_db_name}/${_tab_name_clean}_DDL.sql
        echo "Partial restore" >>$logfile
        echo "Decrypting / Uncompressing $last_full_bbu_path/$_db_name/$_tab_name_clean" >>$logfile
        decrypt_path $last_full_bbu_path/$_db_name/${_tab_name_clean}
        uncompress_path $last_full_bbu_path/$_db_name/${_tab_name_clean}
        _tab_engine=`grep -o MyISAM $_ddl_path`
        if [[ $_db_name == "sys" ]] || \
            [[ $_db_name == "performance_schema" ]] || \
            [[ $_db_name == "information_schema" ]] || \
            [[ $_db_name == "mysql" ]]; then
        continue
        fi
        echo "entering restore loop for $_tab_name" | tee -a $logfile
        if [[ $_tab_engine == *"MyISAM"* ]]; then 
            mysql --user=$username \
            --password=$password \
            --host=$target_mysql_host \
            -e "create database if not exists bum_switch_db;" 2>>$logfile
            if [[ $? -ne 0 ]]; then
		echo "FAILED: Creating bum_switch_db database"
		continue
	    fi
            echo "SUCCESS: Creating bum_switch_db database"
            _existing_table=$(mysql --user=$username \
                --password=$password --host=$target_mysql_host \
                --batch --skip-column-names \
                -e  "show tables in $_db_name like \"$_tab_name_clean\"" 2>/dev/null)
            scp $last_full_bbu_path/$_db_name/${_tab_name_clean}.{frm,MYD,MYI} \
                $target_host_sys_user@$target_mysql_host:/var/lib/mysql/bum_switch_db/
            if [[ $? -ne 0 ]]; then
                echo "FAILED: Moving ${_db_name}/${_tab_name_clean}.{frm,MYD,MYI}" | tee -a $logfile
                continue
            fi
            echo "SUCCESS: Moving ${_db_name}/${_tab_name_clean}.{frm,MYD,MYI}" | tee -a $logfile
            
            if [[ ${#_existing_table} -gt 0 ]]; then
                _rename_existing=" ${_db_name}.$_tab_name_clean to bum_switch_db.deleteme,"
            else
                _rename_existing=""
            fi
            mysql --user=$username \
                --password=$password \
                --host=$target_mysql_host \
                -e "create database if not exists $_db_name;rename table$_rename_existing bum_switch_db.$_tab_name_clean to ${_db_name}.$_tab_name_clean;drop database bum_switch_db" 2>>$logfile
            if [[ $? -ne 0 ]]; then
                echo "FAILED: Renaming bum_switch_db.$_tab_name_clean to ${_db_name}.$_tab_name_clean" | tee -a $logfile
                continue
            fi
            echo "SUCCESS: Renaming bum_switch_db.$_tab_name_clean to ${_db_name}.$_tab_name_clean" | tee -a $logfile
        else
            mysql --user=$username \
                --password=$password \
                --host=$target_mysql_host \
                -e "create database if not exists $_db_name" 2>>$logfile
            if [[ $? -ne 0 ]]; then
		echo "FAILED: Creating $_db_name database"
		continue
            fi
	    echo "SUCCESS: Creating $_db_name database"
            mysql --user=$username \
                --password=$password \
                --host=$target_mysql_host \
                $_db_name <$_ddl_path 2>>$logfile
            if [[ $? -ne 0 ]]; then
                echo "FAILED: Executing table DDL on remote host for ${_db_name}.$_tab_name_clean" | tee -a $logfile
                continue
            fi
            echo "SUCCESS: Executing table DDL on remote host for ${_db_name}.$_tab_name_clean" | tee -a $logfile
            mysql --user=$username \
                --password=$password \
                --host=$target_mysql_host \
                $_db_name \
                -e "alter table $_tab_name_clean discard tablespace;" \
                2>>$logfile
            if [[ $? -ne 0 ]]; then
                echo "FAILED: Discarding tablespace for ${_db_name}.$_tab_name_clean" | tee -a $logfile
                continue
            fi
            echo "SUCCESS: Discarding tablespace for ${_db_name}.$_tab_name_clean" | tee -a $logfile
            scp $last_full_bbu_path/$_db_name/${_tab_name_clean}.{ibd,cfg,exp} \
                $target_host_sys_user@$target_mysql_host:/var/lib/mysql/$_db_name
            if [[ $? -ne 0 ]]; then
                echo "FAILED: transfer of {ibd,cfg,exp} files for ${_db_name}.$_tab_name_clean" | tee -a $logfile
                continue
            fi
            echo "SUCCESS: transfer of {ibd,cfg,exp} files for ${_db_name}.$_tab_name_clean" | tee -a $logfile
            # must use -n option or the while loop runs once and exits
            ssh $sshp -n $target_host_sys_user@$target_mysql_host chown -R mysql: /var/lib/mysql/$_db_name
            mysql --host=$target_mysql_host \
                --password=$password \
                --user=$username $_db_name \
                -e "alter table $_tab_name_clean import tablespace;" 2>>$logfile
            if [[ $? -ne 0 ]]; then
                echo "FAILED: importing tablespace for ${_db_name}.$_tab_name_clean" | tee -a $logfile
            fi
            echo "SUCCESS: importing tablespace for ${_db_name}.$_tab_name_clean" | tee -a $logfile
            ssh $sshp -n $target_host_sys_user@$target_mysql_host rm /var/lib/mysql/$_db_name/$_tab_name_clean.exp
            if [[ $? -ne 0 ]]; then
                echo "FAILED: Removing .exp file from remote datadir" | tee -a $logfile
            else
                echo "SUCCESS: Removing .exp file from remote datadir" | tee -a $logfile
            fi
        fi
        if [[ $encryption == YES ]]; then
            add_encrypted_note_to_path $last_full_bbu_path
        fi
        if [[ $compression == YES ]]; then
            add_compressed_note_to_path $last_full_bbu_path
            echo "Compressing $last_full_bbu_path/$_db_name/${_tab_name_clean}.*" | tee -a $logfile
            compress_path $last_full_bbu_path/$_db_name/${_tab_name_clean}.*
        fi
        if [[ $encryption == YES ]]; then
            echo "Encrypting $last_full_bbu_path/$_db_name/${_tab_name_clean}.*" | tee -a $logfile
            encrypt_path $last_full_bbu_path/$_db_name/${_tab_name_clean}.*
        fi
    	echo "SUCCESS: Partial restore of $_db_name.$_tab_name_clean"
    done <${script_dir}/tables.list
}

dump_table_ddl() {
    _tab_done_count=0
    #ls -l $1 >/tmp/log
    mkdir $1/table_ddl
    while read _tab_name; do
        _tab_done_count=$((_tab_done_count+1))
        _tab_name_clean=${_tab_name#*"."}
        _dot_pos=$(( ${#_tab_name}  - ${#_tab_name_clean} - 1))
        _db_name=${_tab_name:0:$_dot_pos}
        if ! [[ -d $1/table_ddl/$_db_name ]]; then
            mkdir $1/table_ddl/$_db_name
        fi
        mysqldump -d --user=$username \
            --lock-tables=false \
            --password=$password \
            --host=$target_mysql_host \
            $_db_name $_tab_name_clean \
            >$1/table_ddl/${_db_name}/${_tab_name_clean}_DDL.sql 2>>$logfile
    done <$1/tables.list
}

populate_table_list() {       
     echo "Include the system databases sys, mysql, performance_schema? (YES to include)"
     read _choice
     if [[ $_choice == YES ]]; then
        _sys_tabs_param="--include-sys-tables"
     else
        _sys_tabs_param=""
     fi

    if [[ $1 == "--all-tables" ]]; then
       $script_dir/dependencies/repl_ripper_bu_manager.py --user=$username \
         --password=$password \
         --host=$target_mysql_host \
         --all-tables \
         $_sys_tabs_param
    else
       $script_dir/dependencies/repl_ripper_bu_manager.py --user=$username \
         --password=$password \
         --host=$target_mysql_host \
         $_sys_tabs_param
    fi
    tables_list_analysis_recheck=1
}

encrypt_path() {
    for i in `find $1/ -iname "*"`; do
        if [[ "$i" == *"xtrabackup"* ]] || [[ -d $i ]] \
           || [[ "$i" == *"tables.list"* ]] \
           || [[ "$i" == *"table_ddl"* ]]; then
            continue
        fi
        echo "Encrypting $i ..."
        xbcrypt --encrypt-key=$encrypt_key --encrypt-algo=AES256 <$i \
            > $(dirname $i)/$(basename ${i}.xbcrypt) && rm $i
    done
}

decrypt_path() {
    for i in `find "$1"* -iname "*.xbcrypt"`; do
        if ! [[ -d $i ]]; then
            echo "Decrypting $i ..."
            xbcrypt -d --encrypt-key=$encrypt_key \
                --encrypt-algo=AES256 <$i \
            > $(dirname $i)/$(basename $i .xbcrypt) && rm $i
        fi
    done
}

compress_path() {
    for i in `find $1/ -iname "*"`; do
        if [[ "$i" == *"xtrabackup"* ]] || [[ -d $i ]] \
           || [[ "$i" == *"tables.list"* ]] \
           || [[ "$i" == *"table_ddl"* ]]; then
            continue
        fi
        echo "Compressing $i ..."
        ${script_dir}/dependencies/qpress -vfoT4 $i >${i}.qp && rm $i
    done
}
uncompress_path() {
    for i in `find "$1"* -iname "*.qp"`; do
        if ! [[ -d $i ]]; then
            _out_file=${i::-3}
            echo "Uncompressing $i to $_out_file..."
            ${script_dir}/dependencies/qpress -dvoT4 $i >$_out_file && rm $i
        fi
    done
}

add_encrypted_note_to_path() {
    _note_present=`grep -o encrypted $1/xtrabackup_info`
    if [[ $_note_present == "encrypted" ]]; then
        sed -i -- "s/^encrypted.*/encrypted\ =\ Y/"  $1/xtrabackup_info
    else
        echo "encrypted = Y" >>$1/xtrabackup_info
    fi
}

add_compressed_note_to_path() {
    _note_present=`grep -o compressed $1/xtrabackup_info`
    if [[ "$_note_present" == *"compressed"* ]]; then
        sed -i -- "s/^compressed.*/compressed\ =\ compressed/"  $1/xtrabackup_info
    else
        echo "note added because $_note_present != compressed" > /tmp/log3
        echo "compressed = compressed" >>$1/xtrabackup_info
    fi
}

add_unencrypted_note_to_path() {
    _note_present=`grep -o encrypted $1/xtrabackup_info`
    if [[ $_note_present == "encrypted" ]]; then
        sed -i -- "s/^encrypted.*/encrypted\ =\ N/" \
            $1/xtrabackup_info
    else
        echo "encrypted = N" >>$1/xtrabackup_info
    fi
}

add_uncompressed_note_to_path() {
    _note_present=`grep -o compressed $1/xtrabackup_info`
    if [[ "$_note_present" == *"compressed"* ]]; then
        sed -i -- "s/^compressed.*/compressed\ =\ N/"  $1/xtrabackup_info
    else
        echo "compressed = N" >>$1/xtrabackup_info
    fi
}

prepare_schedule() {
    mkdir -p $backup_location
    cp $script_dir/$0 $backup_location/ 
    cp $script_dir/tables.list $backup_location/ 
    cp -R $script_dir/dependencies $backup_location/ 
    _session_name=`echo $target_mysql_host | sed -e 's/\./-/g'`
    if [[ $1 == FULL ]]; then
	tmux new-session -d -s $_session_name "$backup_location/$0 --schedule-full"
    else
	tmux new-session -d -s $_session_name "$backup_location/$0 --schedule-partial"
    fi
    #_du="'du -sh $backup_location/*/*/'"
    #tmux split-window -t $_session_name "watch -n 10 ""${_du:1:-1}"
    echo "TO VIEW SCHEDULE: tmux attach -t $_session_name"
    exit
}

schedule() {
    _sch_exit=0
    if [[ $1 == "--schedule-full" ]]; then
	_type=FULL
    else if [[ $1 == "--schedule-partial" ]]; then
	_type=PARTIAL
    else
        exit
    fi fi
    # need to trap CTRL+C
    _parent_backup_location=$backup_location
    _incr_elapsed_seconds_threshold=$(( (${sch_incr_bu_interval:2} * 60) + (${sch_incr_bu_interval:0:2}*60*60) ))
    SECONDS=0 # SECONDS is a special bash variable with special behaviour
        while [[ $_sch_exit -eq 0 ]]; do
    	_current_hour=`date +%H`
    	_current_minute=`date +%M`
    	# on trigger of new full backup
    	if [ $_current_hour -eq ${sch_full_backup_time:0:2} ] && \
    	    [ $_current_minute -eq ${sch_full_backup_time:2} ] && \
    	    [ $SECONDS -gt 60 ]; then
    	    get_date_string_for_path
    	    backup_location=$_parent_backup_location/$current_date_string
    	    _newdir=$(echo $backup_location | sed 's/\//\\\//g')
    	    sed -i -- "s/^backup_location=.*/backup_location="${_newdir}"/" $_parent_backup_location/$(basename $0)
    	    do_full_bbu $_type
            if [[ ${#_session_name} -eq 0 ]]; then
            	_session_name=`echo $target_mysql_host | sed -e 's/\./-/g'`
            	tmux split-window -t $_session_name "watch -n 10 du -sh $_parent_backup_location"
            fi
    	    SECONDS=0
    	else if [[ $SECONDS -ge $_incr_elapsed_seconds_threshold ]]; then
    	    do_incr_bbu $_type
    	    if [[ $? -eq 0 ]]; then
    		SECONDS=0
    	    fi
    	else
    	    echo "Full backups @ ${sch_full_backup_time:0:2}:${sch_full_backup_time:2}"
    	    echo "Incremental backups every $_incr_elapsed_seconds_threshold seconds"
    	    echo "Seconds since the last backup: $SECONDS"
    	fi fi
	_num_full_bu=`ls -dl $_parent_backup_location/*/ | wc -l`
	((_num_full_bu--)) # dependencies subfolder to be accounted for
	if [[ $_num_full_bu -gt $sch_backups_to_keep ]]; then
        	_to_delete=`ls -ld $_parent_backup_location/*/ | awk 'FNR==1 {print $9}'`
        	echo "$_to_delete will be deleted" | tee -a $logfile
        	rm -r $_to_delete
	fi
    	sleep 1
    	clear
        done
}

init() {
    script_dir="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
    sshp="-oStrictHostKeyChecking=no" # ssh parameter used for brevity
    if [[ $compaction == YES ]]; then
        compaction_param="--compact"
        uncompact_param="--rebuild-indexes"
    else
        compaction_param=""
        uncompact_param=""
    fi
    if [[ $compression == YES ]]; then
        compression_param="--compress --compress-threads=4"
    else
        compression_param=""
    fi
    encryption_param=""
    if [[ $encryption == YES ]]; then
        encryption_param="--encrypt=AES256 --encrypt-key=$encrypt_key"
    else
        encryption_param=""
    fi
    logfile=$backup_location/$logfile
    echo "Logfile: $logfile"
}

init
if [[ $# -eq 0 ]]; then
    main "$@"
else
    schedule "$@"
fi
