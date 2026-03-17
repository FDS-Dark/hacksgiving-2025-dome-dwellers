import pandas as pd

plant_data = pd.read_csv('../Plants_Formatted.csv', encoding='utf-8')

print(len(plant_data))