#!/usr/bin/env python
# -*- coding: utf_8 -*
#
# Script to reformat xlsx tables from Akamai State of the Internet into a single SQL table
#
# Alex Mandel 2014
# tech@wildintellect.com
# requires pandas, xlrd

import pandas as pd
import sqlite3


def importdata(infile,table,connection):
    # Get list of sheets or count of sheets
    xfile = pd.ExcelFile(infile)
    names = xfile.sheet_names
    
    # create empty dataframe to merge other data worth
    df = pd.DataFrame()
    
    for sheet in names:
    # Import each worksheet from excel file
        df1 = pd.read_excel('/space/logs/akamai/2013/Q3 2013 map data viz.xlsx', sheet, index_col=None, na_values=['NA'],header=None)
        
        # Split the single column by ; into 2 columns, col 1 country iso is the key field
        lista = [item.split(';')[1] for item in df1[0]]
        # Has to be a series in order for the update to work
        listb = pd.Series([item.split(';')[0] for item in df1[0]])
        df1[0].update(listb)
        df1[1] = lista
        #Convert column type to int or float
        if df[1][0].isdigit():
            df[1] = df[1].astype(int)
        else:
            df[1] = df[1].astype(float)
        #rename columns for easier merging    
        df1.columns = ['iso_a2',sheet.replace(' ','')]
        
        # Merge all the sheets together by the key
        if len(df) == 0:
            df = df1
        else:
            df = pd.merge(df,df1,on='iso_a2')

    df.to_sql(table,connection,flavor='sqlite',if_exists='replace')
    return()
    # export to a csv or write to sqlite table in database
    #print(df)

    

if __name__ == '__main__':
    #update the infile and the table if doing more data or getting it from a different path
    connection = sqlite3.connect("osgeolivedata.sqlite")
    infile = '/space/logs/akamai/2013/Q3 2013 map data viz.xlsx'
    table = 'akamai2013'
    try:
        importdata(infile,table,connection)
    except Exception as e:
        print(" ".join(["Something failed because of",str(e)]))
    finally:
        '''clean up db before exiting'''
        connection.execute("VACUUM")
        connection.close()

