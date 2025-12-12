import requests
import time
import pandas as pd
import random
from bs4 import BeautifulSoup


# DataFrame
df = pd.DataFrame(columns=["Price", "Address", "Details", "Links"])

# Header
headers = {
    "User-Agent": "Mozilla/5.0 (Macintosh; Intel Mac OS X 13_0) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/118.0.5993.89 Safari/537.36",
    "Accept-Language": "en-US,en;q=0.5",
    "Accept-Encoding": "gzip, deflate, br",
            }


# URLs
URLs_list = [
    'https://www.zillow.com/fort-collins-co/{page}_p/',
    'https://www.zillow.com/new-york-ny/{page}_p/',
    'https://www.zillow.com/los-angeles-ca/{page}_p/',
    'https://www.zillow.com/chicago-il/{page}_p/',
    'https://www.zillow.com/houston-tx/{page}_p/'
            ]       


# Crawl
for city_url in URLs_list:
    for page in range(1, 21):
        url = city_url.format(page=page) 

        response = requests.get(url, headers=headers)
        time.sleep(random.uniform(3, 7))


        if response.status_code == 200:
            soup = BeautifulSoup(response.content, 'html.parser')
            
            # In4 of the house
            property_cards = soup.find_all("div", class_="StyledPropertyCardDataWrapper-c11n-8-105-0__sc-hfbvv9-0")

            for card in property_cards:
                # Crawl price
                try:
                    price = card.find("span", {"data-test": "property-card-price"}).text
                except:
                    price = None

                # Crawl address
                try:
                    address = card.find("address", {"data-test": "property-card-addr"}).text
                except:
                    address = None
                            
            
            
            
                # Crawl bedrooms, bathrooms, sqft
                try:
                    details = card.find("ul", class_="StyledPropertyCardHomeDetailsList-c11n-8-105-0__sc-1j0som5-0").text
                except:
                    details = None

              
                    
                    

                # Crawl link of house
                try:
                    links = card.find("a", href=True)["href"]
                except:
                    links = None


                # Lưu vào DataFrame
                in4_house = pd.DataFrame({
                    "Price": [price],
                    "Address": [address],
                    "Details": [details],
                    "Links": [links]
                })
                df = pd.concat([df, in4_house], ignore_index=True)
            print(f'Crawling {page}')
        elif response.status_code == 403:
            print(f" 403: URL Forbidden.{url}.")
            break
        else:
            print(f"Khong truy cập {url}: {response.status_code}")


print(df)




import pyodbc
import pandas as pd


# connect to Azure
server = ''
database = 'Zillow_data'
username = ''
password = ''
driver = '{ODBC Driver 17 for SQL Server}'
connection_string = f"DRIVER={{ODBC Driver 17 for SQL Server}};SERVER={server};DATABASE={database};UID={username};PWD={password}"

try:
    conn = pyodbc.connect(connection_string)
    cursor = conn.cursor()


    #insert data
    for index, row in df.iterrows():
        cursor.execute("""
            INSERT INTO Zillow_table(Price, Address, Details, Links)
            VALUES (?, ?, ?, ?)
        """, row['Price'], row['Address'], row['Details'], row['Links'])


    conn.commit()
    print("Dữ liệu đã được đẩy lên Azure SQL Database thành công.")


except Exception as e:
    print("Lỗi kết nối hoặc chèn dữ liệu: ", e)


finally:
    cursor.close()
    conn.close()


