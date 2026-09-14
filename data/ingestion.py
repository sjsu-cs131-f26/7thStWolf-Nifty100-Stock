import kagglehub
import os
import sys
import shutil
try:
    folder_name = sys.argv[1]
except:
    raise ValueError("Missing Argument")

raw_data_dir = os.path.join(os.getcwd(), folder_name)
os.makedirs(raw_data_dir, exist_ok=True)

path = kagglehub.dataset_download("debashis74017/stock-market-data-nifty-50-stocks-1-min-data")

shutil.copytree(path, raw_data_dir, dirs_exist_ok=True)
