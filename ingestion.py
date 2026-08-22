import psycopg2
import requests
from bs4 import BeautifulSoup
import feedparser
import datetime
import os

def connect_vault():
    db_url = os.environ.get("DATABASE_URL")
    return psycopg2.connect(db_url)

def init_vault():
    conn = connect_vault()
    cursor = conn.cursor()
    cursor.execute('DROP TABLE IF EXISTS history')
    cursor.execute('''CREATE TABLE history 
                      (id SERIAL PRIMARY KEY, 
                       source TEXT, 
                       title TEXT, 
                       raw_summary TEXT, 
                       url TEXT,
                       image_url TEXT)''')
    conn.commit()
    cursor.close()
    conn.close()

# --- 1. THE OPEN FEEDS (Stable, No API Key Needed) ---

def ingest_news():
    print("Scanning Global News Trends...")
    try:
        feed = feedparser.parse("https://news.google.com/rss?hl=en-IN&gl=IN&ceid=IN:en")
        conn = connect_vault()
        cursor = conn.cursor()
        for entry in feed.entries[:3]:
            cursor.execute("INSERT INTO history (source, title, raw_summary, url, image_url) VALUES (%s, %s, %s, %s, %s)", 
                           ("NEWS", entry.title, f"Published: {entry.published}", entry.link, "https://cdn-icons-png.flaticon.com/512/2965/2965879.png"))
        conn.commit()
        cursor.close()
        conn.close()
    except Exception as e:
        print(f"News failed: {e}")

def ingest_youtube():
    print("Scanning YouTube Viral Trends...")
    try:
        feed = feedparser.parse("https://www.youtube.com/feeds/videos.xml?playlist_id=PLrEnWoR732-BHrPp_Pm8_VleD68f9s14-")
        conn = connect_vault()
        cursor = conn.cursor()
        for entry in feed.entries[:3]:
            video_id = entry.link.split('v=')[-1]
            image_url = f"https://img.youtube.com/vi/{video_id}/hqdefault.jpg"
            cursor.execute("INSERT INTO history (source, title, raw_summary, url, image_url) VALUES (%s, %s, %s, %s, %s)", 
                           ("YOUTUBE", entry.title, f"Trending video by {entry.author.strip()}", entry.link, image_url))
        conn.commit()
        cursor.close()
        conn.close()
    except Exception as e:
        print(f"YouTube failed: {e}")

def ingest_nykaa():
    print("Scanning Nykaa Trends...")
    headers = {'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36'}
    try:
        response = requests.get("https://www.nykaa.com/sp/trending-now/trending-now", headers=headers)
        soup = BeautifulSoup(response.text, 'html.parser')
        conn = connect_vault()
        cursor = conn.cursor()
        for item in soup.find_all('div', class_='css-xrzmfa')[:3]:
            title_el = item.find('div', class_='css-x3m3vd')
            link_el = item.find('a')
            img_el = item.find('img')
            if title_el and link_el:
                link = "https://www.nykaa.com" + link_el.get('href')
                img = img_el.get('src') if img_el else ""
                cursor.execute("INSERT INTO history (source, title, raw_summary, url, image_url) VALUES (%s, %s, %s, %s, %s)", 
                               ("NYKAA", title_el.text.strip(), "Trending item on Nykaa.", link, img))
        conn.commit()
        cursor.close()
        conn.close()
    except Exception as e:
        print(f"Nykaa failed: {e}")

# --- 2. THE STEALTH APIS (Requires RapidAPI Keys in Render Environment) ---

def ingest_amazon():
    print("Scanning Live Amazon India Trends via Stealth API...")
    api_key = os.environ.get("RAPIDAPI_KEY")
    if not api_key:
        print("Amazon Bypass Failed: RAPIDAPI_KEY missing.")
        return
    try:
        url = "https://real-time-amazon-data.p.rapidapi.com/search"
        querystring = {"query":"trending products","page":"1","country":"IN","sort_by":"REVIEWS"}
        headers = {"x-rapidapi-key": api_key, "x-rapidapi-host": "real-time-amazon-data.p.rapidapi.com"}
        
        response = requests.get(url, headers=headers, params=querystring)
        products = response.json().get('data', {}).get('products', [])[:3]
        
        conn = connect_vault()
        cursor = conn.cursor()
        for item in products:
            cursor.execute("INSERT INTO history (source, title, raw_summary, url, image_url) VALUES (%s, %s, %s, %s, %s)", 
                           ("AMAZON", item.get('product_title', 'Unknown'), f"Live Price: {item.get('product_price', 'N/A')}", item.get('product_url', ''), item.get('product_photo', '')))
        conn.commit()
        cursor.close()
        conn.close()
    except Exception as e:
        print(f"Amazon failed: {e}")

def ingest_flipkart():
    print("Scanning Flipkart...")
    # To make this live, duplicate the Amazon logic above and plug in a Flipkart RapidAPI endpoint
    # For now, it fails gracefully without crashing the server if no API is connected.
    pass

def ingest_myntra():
    print("Scanning Myntra...")
    # To make this live, duplicate the Amazon logic above and plug in a Myntra RapidAPI endpoint
    # For now, it fails gracefully without crashing the server if no API is connected.
    pass

# --- THE MASTER SWITCH ---
def run_full_omnichannel_scan():
    print(f"[{datetime.datetime.now()}] Initiating Final Universal Platform Sync...")
    init_vault()  
    ingest_news()
    ingest_youtube()
    ingest_nykaa()
    ingest_amazon()
    ingest_flipkart()
    ingest_myntra()
    print("Sync Complete. Database updated.")

if __name__ == "__main__":
    run_full_omnichannel_scan()