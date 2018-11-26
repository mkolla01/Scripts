#!/usr/bin/python
import sys

import argparse

parser = argparse.ArgumentParser()
parser.add_argument("--inFile", required=True, help="Schema Inputfile" )
parser.add_argument("--outDir", required=True, help="Output Directory" )
parser.add_argument("--schema", default="ALL", help="Output Directory" )
args = parser.parse_args()

fo = open (args.inFile, 'r' )
sk = open (args.outDir + '/SingleKey.txt', 'w' )
ck = open (args.outDir +'/CompositeKey.txt', 'wb' )
mv = open (args.outDir +'/MVKey.txt', 'wb' )

#s="fsdfsf (dfg ( sdf ) sdf)"
#print s[s.find("("):]

#sys.exit()
wrtToFile = 0
mvFlg = 0
for ln in fo :
       # if "CREATE KEYSPCE" in ln:
#		ks=ln.split()[2] + "\n"
#		sk.write( ks )
#		ck.write( ks )	

	if "CREATE TABLE" in  ln and (ln.split()[2].split(".")[0] == args.schema or args.schema == "ALL" ):
		tab=ln.split()[2]
		wrtToFile = 1
	if "PRIMARY KEY" in ln and ln.split()[2] == "PRIMARY" and wrtToFile == 1: 
		#print tab, ln.split()[0] > singlekey
		if mvFlg == 1 :
			s = tab + ";" + ln.split()[0]+ "\n"
			mv.write( s )
			mvFlg = 0
		else:
			s = tab + ";" + ln.split()[0]+ "\n"
               		sk.write( s  )
		wrtToFile = 0
       	if "PRIMARY KEY" in ln and ln.split()[0] == "PRIMARY" and wrtToFile == 1:
		#print tab, ln[ln.index("("):] > comositkey
		if mvFlg == 1 :
			s = tab + ";" + ln[ln.index("("):]
			mv.write( s)
			mvFlg = 0
		else: 
			s = tab + ";" + ln[ln.index("("):]
               		ck.write( s )
		wrtToFile = 0
	
	if "CREATE MATERIALIZED VIEW" in ln and "PRIMARY KEY" in ln :
	  	s = ln.split()[3] + ";" + ln.split("PRIMARY KEY")[ 1 ].split("WITH")[0] + "\n"
         	mv.write( s)	
        elif "CREATE MATERIALIZED VIEW" in ln and (ln.split()[3].split(".")[0] == args.schema or args.schema == "ALL" ):
		tab=ln.split()[3]
		mvFlg = 1		
          	wrtToFile = 1

fo.close()
sk.close()
ck.close()
mv.close()
