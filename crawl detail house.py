import pyodbc
import requests
import time
import random
from bs4 import BeautifulSoup
import pandas as pd


# Connection
conn_str = (
    'DRIVER={ODBC Driver 17 for SQL Server};'
    'SERVER=;'
    'DATABASE=Zillow_data;'
    'UID=;'
    'PWD=;'
)


conn = pyodbc.connect(conn_str)
cursor = conn.cursor()

query = "SELECT TOP 20 Links FROM Zillow_table_backup"
data = pd.read_sql(query, conn)
data = data.dropna(subset=['Links'])


user_agents = [
    "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/115.0.0.0 Safari/537.36",
    "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/14.0.3 Safari/605.1.15",
    "Mozilla/5.0 (iPhone; CPU iPhone OS 14_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/14.0 Mobile/15E148 Safari/604.1",
]


def extract_property_info(link):
    try:
        headers = {
            "User-Agent": random.choice(user_agents),
            "Accept-Language": "en-US,en;q=0.5",
            "Accept-Encoding": "gzip, deflate, br",
        }
        response = requests.get(link, headers=headers)
        time.sleep(random.uniform(10, 30)) 


        if response.status_code == 200:
            soup = BeautifulSoup(response.content, 'html.parser')


            try:
                property_type = soup.find("span", class_="Text-c11n-8-100-2__sc-aiai24-0 sc-bkldj bSfDch jVQhuJ")
                property_type = property_type.text if property_type else None
            except AttributeError:
                property_type = None


            try:
                year_built = soup.find_all("span", class_="Text-c11n-8-100-2__sc-aiai24-0 sc-bkldj bSfDch jVQhuJ")[1]
                year_built = year_built.text if year_built else None
            except (IndexError, AttributeError):
                year_built = None


            try:
                price_per_sqft = soup.find_all("span", class_="Text-c11n-8-100-2__sc-aiai24-0 sc-bkldj bSfDch jVQhuJ")[4]
                price_per_sqft = price_per_sqft.text if price_per_sqft else None
            except (IndexError, AttributeError):
                price_per_sqft = None


            return pd.Series([link, property_type, year_built, price_per_sqft])
        else:
            print(f"Error {response.status_code} accessing {link}")
            return pd.Series([link, None, None, None])
    except requests.exceptions.RequestException as e:
        print(f"Request error for link {link}: {str(e)}")
        return pd.Series([link, None, None, None])


df = data['Links'].apply(extract_property_info)
df.columns = ["Links", "Property_Type", "Year_Built", "Price_per_sqft"]
print(df)




