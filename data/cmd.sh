git clone git@github.com:sjsu-cs131-f26/Team8_Wolf_of_the_7th_St..git
pip install -r 7thStWolf-Nifty100-Stock/data/requirements.txt
python 7thStWolf-Nifty100-Stock/data/ingestion.py raw_data
python 7thStWolf-Nifty100-Stock/data/processing.py raw_data processed_data
awk 'FNR==1 && NR!=1{next;}{print}' processed_data/*.csv > merged.csv 