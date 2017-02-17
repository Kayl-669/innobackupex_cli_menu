#!/usr/bin/env python
# coding=utf-8
from __future__ import print_function
import mysql.connector as mysql
import sys, contextlib, getopt, os, subprocess
from mysql.connector import errorcode

class ErrorWrap(Exception):
    """ Exception handler, simply formats the exception """
    def __init__(self, errno, strerror):
        super(ErrorWrap, self).__init__(self, errno, strerror)
        self.errno = errno
        self.strerror = strerror

    def __str__(self):
        return self.strerror

def create_conn(conn, **connargs):
    try:
        conn=mysql.connect(**connargs)
    except mysql.Error as err:
        if err.errno == errorcode.ER_ACCESS_DENIED_ERROR:
            raise ErrorWrap(errorcode.ER_ACCESS_DENIED_ERROR
                             ,"Invalid connection details provided")
        elif err.errno == errorcode.ER_BAD_DB_ERROR:
            raise ErrorWrap(errorcode.ER_BAD_DB_ERROR, "Database "
                + connargs['db'] + " does not exist on host " + connargs['host'])
        else:
            raise (err)
    return conn

def fetch_all_db_res(db_conn, sql):
    try:
        with contextlib.closing(db_conn.cursor()) as curs:
            curs.execute(sql)
            return (curs.fetchall())
    except RuntimeError as e:
        print(e.strerror)
        return None

def main(argv):
    # get options
    username=None
    password=None
    host='localhost'
    include_sys_tables=False
    all_tables=False

    try:
        opts,args = getopt.getopt(argv,'' , [
            'username=',
            'password=',
            'host=',
            'include-sys-tables',
            'all-tables'
        ])
    except getopt.GetoptError as Gerr:
        print(Gerr)
        sys.exit()

    for opt,arg in opts:
        if opt == '--username':
            username=arg
        elif opt == '--password':
            password=arg
        elif opt == '--host':
            host=arg
        elif opt == '--include-sys-tables':
           include_sys_tables=True
        elif opt == '--all-tables':
           all_tables=True

    with open("./repl.cnf") as f:
        repl_lines = f.readlines()

    conn_conf = {
        'user':username,
        'password':password,
        'db': None,
        'host': host,
        'raw': True,
        'port': 3306
    }

    db_conn = None
    db_conn = create_conn(db_conn, **conn_conf)

    if include_sys_tables:
        repl_lines += ['replicate-wild-do-table=mysql.%\n']
        repl_lines += ['replicate-wild-do-table=sys.%\n']
        repl_lines += ['replicate-wild-do-table=performance_schema.%\n']

    contents = {}
    if all_tables:
        sql = "select table_schema,table_name from information_schema.tables "
        sql += "where table_schema != 'information_schema' "
        if not include_sys_tables:
            sql += "AND table_schema NOT IN ('mysql','sys','performance_schema')"
        all_table_names = fetch_all_db_res(db_conn, sql)
        for [ db_name, tab_name ] in all_table_names:
            db_name_decode = db_name.decode('utf-8') if type(db_name) == bytearray else db_name
            tab_name_decode = tab_name.decode('utf-8') if type(tab_name) == bytearray else tab_name
            db_contents = contents.setdefault(db_name_decode,[])
            db_contents += [tab_name_decode]
    else:
        for i in range(len(repl_lines)):
            repl_conf = repl_lines[i].split('=')
            if (
                len(repl_conf) == 2
                and (repl_conf[0] == 'replicate-do-table'
                or repl_conf[0] == 'replicate-wild-do-table')
            ):
                do_table_line = repl_conf[1][:-1]
                do_table_db,do_table_table = do_table_line.split('.')
                sql = "select table_name from information_schema.tables "
                sql += "where table_schema like '" + do_table_db + "' and table_name like '" + do_table_table + "'"
                #if innodb_only:
                #    sql += " and engine = 'innoDB'"
                matched_table_names = fetch_all_db_res(db_conn, sql)
                if len(matched_table_names) > 0:
                    db_contents = contents.setdefault(do_table_db,[])
                    for tab_name in matched_table_names:
                        tab_name_decode = tab_name[0].decode('utf-8') if type(tab_name[0]) == bytearray else tab_name[0]
                        db_contents += [tab_name_decode]

    # ensure no duplicates
    for db in contents:
        contents[db] = set(contents[db])

    with open("./tables.list","w") as tables_list_file:
        for db in contents:
            for table in contents[db]:
                print(db + "." + table, file=tables_list_file)

if __name__ == "__main__":
    main(sys.argv[1:])
