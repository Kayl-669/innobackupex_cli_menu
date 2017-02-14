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
        # SILENTLY FAIL with reduced functionality
        pass
    return conn

def fetch_all_db_res(db_conn, sql):
    try:
        with contextlib.closing(db_conn.cursor()) as curs:
            curs.execute(sql)
            return (curs.fetchall())
    except RuntimeError as e:
        print(e.strerror)
        return None

def fetch_single_res(db_conn, sql):
    """ Fetch a single result from the database returns only the result """
    try:
        with contextlib.closing(db_conn.cursor()) as curs:
            curs.execute(sql)
            return curs.fetchone()
    except RuntimeError as e:
        print(e.strerror)

def main(argv):
    # get options
    username=None
    password=None
    host="localhost"
    tables_list_file=None

    try:
        opts,args = getopt.getopt(argv,'' , [
            'username=',
            'host=',
            'password=',
            'tables-list-file='
        ])
        #'tables_list_file='
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
        elif opt == '--tables-list-file':
           tables_list_file=arg

    with open(tables_list_file) as f:
        tables_list = f.readlines()

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

    results = []
    db_set = set()

    for i in range(len(tables_list)):
        db,table = tables_list[i].split('.')
        db_set.add(db)
        table=table[:-1]
        if db_conn != None:
            sql = "select (data_length+index_length)/1024/1024 as size_mb "
            sql +="from information_schema.tables "
            sql += "where table_schema = '" + db + "' "
            sql += "and table_name like '" + table + "'"
            result  = fetch_single_res(db_conn, sql)
            if result != None and result[0] != None:
                results += [float(result[0])]
    if db_conn != None:
        total = "%.0f" % round(sum(results))
        print(str(len(tables_list)) \
              + " tables from " + str(len(db_set)) + " databases")
        print("\t\t\t\t\t\t(approx size: " + total + "MB)")
        db_conn.close
    else:
        print(str(len(tables_list)) \
              + " tables from " + str(len(db_set)) + " databases")
        print("\t\t\t\t\t\t(approx size: [connection error])")


if __name__ == "__main__":
    main(sys.argv[1:])
