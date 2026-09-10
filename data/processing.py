import sys
from pathlib import Path
import pandas as pd

"""
This Script Assumes:
* we can run this script on the Viritual Machine
* We already have uploaded the data unprocessed

Run:
> python processing.py <Dataset_folder> <Target_Folder>

args:
    <Dataset_folder> - Relative Location of all files from the Niche 100 Dataset in our IBM VM
    <Target_folder> - Relative Location of where to place all formated files

returns:
    Adds Stock Name(Extracted from file) as a column 
    Adds change column as a column. 
    * The change Column finds the difference between current minute and previous minute
    * It uses the difference to categroize wheater the current row has either "increased", "decreased" or "none"

Note:
    We still need to merge all the files into after this processing step
    We also have to find a way to upload the files to IBM VM. 
    We can create another python script and used the Kaggle API for that tho.  


Example Format:
- Before Processing:
| date | open | high | low | close| volume |

- Post Processing

| name | date | open | high | low | close | volume | change(categorical) |

"""

folder_name = sys.argv[1]
target_location = sys.argv[2]

cur = Path.cwd()

path = Path(cur / folder_name)
target_path = Path(cur/target_location)

target_path.mkdir(parents=True, exist_ok=True)



files = [f for f in path.iterdir() if f.is_file()]

eps = 1e-9
bins = [-float("inf"), -eps, eps,float("inf")]
labels = ["Decreased", "None", "Increased"]

def calcuate_change(df):
    diff = df['close'].diff()
    df["change"] = pd.cut(diff, bins=bins, labels=labels, include_lowest=True, right=True)
    return df



for file in files:
    # We can limit the amount of files processed if you guys want 
    file_name = (file.name)
    stock_name = file_name[:-11] # Extracts the stock name from the file name

    df = pd.read_csv(file)
    df['name'] = stock_name

    df = calcuate_change(df)
    df = df.iloc[:, [6, 0, 1,2,3,4,5,7]]
    file_loc = Path(target_path / file_name)
    df.to_csv(file_loc, index=False)