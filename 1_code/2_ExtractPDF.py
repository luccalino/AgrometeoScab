#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Created on Tue Jun 29 13:39:21 2021

@author: laz
"""

import camelot.io as camelot
import pandas as pd
import glob, os 

# Set working directory (= the location of ../agrometeo-main/pdf_extract/)
os.chdir('/Users/laz/AgrometeoScab/')

# Get pdfs
df = []

for file in glob.glob("2_data/1_pdf/*.pdf"):
    #file = file[4:]
    df.append(file)        

# Extract date and infection intensity for every pdf
for pdf in range(1,len(df)):#

    # Read pdf and make separate tables per pdf pages
    tab = camelot.read_pdf(df[pdf], flavor='stream', pages='all')

    # Extract number of pages
    num_pages = tab.n

    app_data = []

    # Loop trough every page
    for infile in range(0, num_pages):
    
        # Read table
        data = tab[infile].df
        
        # Skip iteration if there is only one page 
        one_pager = data.apply(lambda col: col.astype(str).str.contains('Page 1 de 1|Seite 1 von 1').any(), axis=0)
        op = [i for i, x in enumerate(one_pager) if x]
        
        if len(op) > 0:
            print("Skipped " + df[pdf] + " (=One pager!)")
            continue
        
        # Harmonize date format if needed (e.g. replace '/' with '.')
        data[0] = data[0].str.replace('/', '.')
         
        # Seach for columns where specific terms appear   
        cols_inf = data.apply(lambda col: col.astype(str).str.contains('Simscab|simscab').any(), axis=0)
        cols_dat = data.apply(lambda col: col.astype(str).str.contains('Datum|Date').any(), axis=0)
        cols_temp = data.apply(lambda col: col.astype(str).str.contains('Avg.|Moy.').any(), axis=0)
        cols_preci = data.apply(lambda col: col.astype(str).str.contains('Nieder|Préci').any(), axis=0)

        ci = [i for i, x in enumerate(cols_inf) if x]
        cd = [i for i, x in enumerate(cols_dat) if x]
        ct = [i for i, x in enumerate(cols_temp) if x]
        cp = [i for i, x in enumerate(cols_preci) if x]

        # Identiy date, infection, temperature and precipitation columns (general case)
        if len(cd) == 1 and len(ci) == 1 and len(ct) == 1 and len(cp) == 1:
            ci = ci[0]
            cd = cd[0]
            cp = cp[0]
            ct = ct[0]
        else:
            print("Skipped " + df[pdf] + " (Error in column identification on page " + str(infile) + ")" )
            break

        # Subset data with only relevant columns and name accordingly
        data = data.iloc[:, [cd,ci,ct,cp]]
        data.columns = ['date','simscab','temp','preci']
   
        # Subset only rows that are in dd.dd format
        data = data[data.date.str.contains('\d{1,2}\.\d{1,2}', regex = True, na = False)]
                      
        # Subset if length of date (dd.dd) is smaller or equal to 30
        data = data[data['date'].str.contains('[A-Za-z]') == False]
                
        # Replace , with. in precipitation. Fill empty cells with 0 if needed.  
        data['preci'] = data['preci'].str.replace(',', '.')
        data.loc[data['preci'].str.len() == 0, ['preci']] = '0'
            
        # Append data to list
        app_data.append(data)
    
    # Concatenate data if
    if infile == 0:
        print("Skipped " + df[pdf] + " " + str(pdf) + " (Error in concatenate)")
        continue
    else:
       app_data = pd.concat(app_data)
    
    # Keep unique values based on date
    app_data = app_data.drop_duplicates(subset=['date'], keep='last')
    
    # Reset index
    app_data = app_data.reset_index()
    
    # Add station name as additional column and year to date
    nod = df[pdf][13:len(df[pdf])].count('-')
    
    if nod == 2:
        app_data['station'] = df[pdf][13:len(df[pdf])].split('-')[0]
    elif nod == 3:
        app_data['station'] = df[pdf][13:len(df[pdf])].split('-')[0] + '_' + df[pdf][13:len(df[pdf])].split('-')[1] 
    elif nod == 4:
        app_data['station'] = df[pdf][13:len(df[pdf])].split('-')[0] + '_' + df[pdf][13:len(df[pdf])].split('-')[1] + '_' + df[pdf][13:len(df[pdf])].split('-')[2]
    elif nod == 5:
        app_data['station'] = df[pdf][13:len(df[pdf])].split('-')[0] + '_' + df[pdf][13:len(df[pdf])].split('-')[1] + '_' + df[pdf][13:len(df[pdf])].split('-')[1] + df[pdf][13:len(df[pdf])].split('-')[2] 
                   
    # Save as .csv insto /csv/ folder
    app_data.to_csv('2_data/2_csv' + str(df[pdf][12:-4]) + '.csv')

    # Print iteration and progress (in %)
    print(df[pdf][:-4] + ' (' + str(round(pdf/len(df)*100,1)) + '%)')
    
  