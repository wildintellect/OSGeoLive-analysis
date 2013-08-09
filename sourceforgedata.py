#!/usr/bin/env python
# -*- coding: utf_8 -*
#
# Script to pull download statistics from sourceforge OSGeo Live project and insert them into sqlite
#
# Alex Mandel 2013
# tech@wildintellect.com

import urllib2
import simplejson
import sqlite3
import datetime

def tables(connection):
    '''Create database table to hold information imported from sourceforge'''
    cleardata= '''DROP TABLE if exists sfcountries'''
    connection.execute(cleardata)
    sourceforgecountrydata = '''CREATE TABLE if not exists sfcountries
        (version DOUBLE,
        type TEXT,
        country TEXT,
        downloads INTEGER,
        startdate TIMESTAMP,
        enddate TIMESTAMP,
        lastupdate TIMESTAMP
        )
        '''
    connection.execute(sourceforgecountrydata)
    
    cleardata= '''DROP TABLE if exists sfbymonth'''
    connection.execute(cleardata)
    sourceforgebymonth = '''CREATE TABLE if not exists sfbymonth
        (version DOUBLE,
        type TEXT,
        month TIMESTAMP,
        downloads INTEGER,
        lastupdate TIMESTAMP
        )
        '''
    connection.execute(sourceforgebymonth)
    
    #Cheat, only count Windows, Mac, Linux, All others
    cleardata= '''DROP TABLE if exists sfosbycountry'''
    connection.execute(cleardata)
    sourceforgeosbycountry = '''CREATE TABLE if not exists sfosbycountry
        (version DOUBLE,
        type TEXT,
        country TEXT,
        win INTEGER,
        mac INTEGER,
        lin INTEGER,
        other INTEGER,
        lastupdate TIMESTAMP
        )
        '''
    connection.execute(sourceforgeosbycountry)
    
    connection.commit()
    return

def tableOsByCountry(oses):
    '''idea to dynamically add fields to table if a new OS pops up in the data'''
    # Too difficult
    return

def fetchData(connection):
    '''Using sourceforge api grab the download numbers for each file by release'''
    #each version by start date until next release
    versions = [
                ["6.0","2012-08-19",datetime.date.today().isoformat(),
                 [["osgeo-live-vm-6.0.7z","7z"],
                  ["osgeo-live-6.0-1.iso","iso"],
                  ["osgeo-live-mini-6.0.iso","mini"]]],
                ["6.5","2013-02-22",datetime.date.today().isoformat(),
                 [["osgeo-live-vm-6.5.7z","7z"],
                 ["osgeo-live-6.5.iso","iso"],
                 ["osgeo-live-mini-6.5.iso","mini"]],
                ]]
    #hard coded order to match above
    type = ["7z","iso","mini"]
    # Doesn't work because files are not identically named between versions due to point release
    #files = [
    #         "osgeo-live-vm-6.0.7z",
    #         "osgeo-live-6.0-1.iso",
    #         "osgeo-live-mini-6.0.iso",
    #         "osgeo-live-vm-6.5.7z",
    #         "osgeo-live-6.5.iso",
    #         "osgeo-live-mini-6.5.iso"
    #         ]
    baseurl = "http://sourceforge.net/projects/osgeo-live/files"
    # Make a list of all the file urls to hit
    # Make a list of date ranges per release to hit
    # repeat urls for relevant data ranges
    for version in versions:
        for file in version[3]:
            gettext = "stats/json?start_date=%s&end_date=%s" % (version[1],version[2])
            fullurl = "/".join([baseurl,version[0],file[0],gettext])
            print fullurl
            data = urllib2.urlopen(fullurl)
            #example with known url
            #data = urllib2.urlopen("http://sourceforge.net/projects/osgeo-live/files/6.5/osgeo-live-vm-6.5.7z/stats/json?start_date=2013-02-20&end_date=2013-08-08")
            jsondata = simplejson.load(data)
            #replace the following with database inserts
            #for item in jsondata['countries'][:5]:
            #    print(tuple([version[0],file[1]]+item+[version[1],version[2],datetime.date.today().isoformat()]))
            #call the data import
            importCountries([tuple([version[0],file[1]]+item+[version[1],version[2],jsondata['stats_updated']]) for item in jsondata['countries']],connection)
            importByMonth([tuple([version[0],file[1]]+item+[jsondata['stats_updated']]) for item in jsondata['downloads']],connection)
            #get list of countries
            #jsondbyc = jsondata['oses_by_country']
            prepdata = []
            for item in jsondata['oses_by_country'].keys():
                #for each country get Win, Lin, Mac and Other as sum
                win = jsondata['oses_by_country'][item].pop("Windows",0)
                mac = jsondata['oses_by_country'][item].pop("Macintosh",0)
                lin = jsondata['oses_by_country'][item].pop("Linux",0)
                other = sum(jsondata['oses_by_country'][item].values())
                prepdata.append(tuple([version[0],file[1],item,win,mac,lin,other,jsondata['stats_updated']]))
            importOS(prepdata,connection)
    return
    

def importCountries(data,connection):
    '''import json data into database table'''
    # TODO: if data exists clear records and update with newer data, based on newest date?
    connection.executemany("INSERT INTO sfcountries VALUES(?,?,?,?,?,?,?)",data)
    connection.commit()
    return    

def importByMonth(data,connection):
    '''import json data into database table'''
    # TODO: if data exists clear records and update with newer data, based on newest date?
    connection.executemany("INSERT INTO sfbymonth VALUES(?,?,?,?,?)",data)
    connection.commit()
    return

def importOS(data,connection):
    '''import json data into database table'''
    # TODO: if data exists clear records and update with newer data, based on newest date?
    connection.executemany("INSERT INTO sfosbycountry VALUES(?,?,?,?,?,?,?,?)",data)
    connection.commit()
    return  

if __name__ == '__main__':
    #base url http://sourceforge.net/projects/osgeo-live/files
    #version 6.5
    #format osgeo-live-vm-6.5.7z
    #standard ending stats/json?start_date=?&end_date=?
    #date format 2013-08-02
    connection = sqlite3.connect("test.db")
    try:
        tables(connection)
        fetchData(connection)
    except Exception as e:
        print(" ".join(["Something failed because of",str(e)]))
    finally:
        '''clean up db before exiting'''
        connection.execute("VACUUM")
        connection.close()
        
        
    
    
    