import sqlite3
import requests
from bs4 import BeautifulSoup
import feedparser
import datetime

# Database Initialization
def init_vault():
    """Wipes the old table and rebuilds it with the new image_url column."""
    conn = sqlite3.connect('vault.db')
    cursor = conn.cursor()
    cursor.execute('DROP TABLE IF EXISTS history')
    cursor.execute('''CREATE TABLE history 
                      (id INTEGER PRIMARY KEY AUTOINCREMENT, 
                       source TEXT, 
                       title TEXT, 
                       raw_summary TEXT, 
                       url TEXT,
                       image_url TEXT)''')
    conn.commit()
    conn.close()

def connect_vault():
    return sqlite3.connect('vault.db')

# 1. The Open Gates: Global News
def ingest_news():
    print("Scanning Global News Trends...")
    news_url = "https://news.google.com/rss?hl=en-IN&gl=IN&ceid=IN:en"
    
    try:
        feed = feedparser.parse(news_url)
        conn = connect_vault()
        cursor = conn.cursor()
        
        count = 0
        for entry in feed.entries[:5]:
            title = entry.title
            link = entry.link
            summary = f"Published: {entry.published}"
            # Standard placeholder icon for news articles
            image_url = "https://cdn-icons-png.flaticon.com/512/2965/2965879.png"
            
            cursor.execute("INSERT INTO history (source, title, raw_summary, url, image_url) VALUES (?, ?, ?, ?, ?)", 
                           ("GOOGLE NEWS", title, summary, link, image_url))
            count += 1
            
        conn.commit()
        conn.close()
        print(f"Successfully vaulted {count} global news trends.")
    except Exception as e:
        print(f"News infiltration failed: {e}")

# 2. The Open Gates: YouTube Viral Trends
def ingest_youtube():
    print("Scanning YouTube Viral Trends...")
    youtube_url = "https://www.youtube.com/feeds/videos.xml?playlist_id=PLrEnWoR732-BHrPp_Pm8_VleD68f9s14-"
    
    try:
        feed = feedparser.parse(youtube_url)
        conn = connect_vault()
        cursor = conn.cursor()
        
        count = 0
        for entry in feed.entries[:5]:
            title = entry.title
            link = entry.link
            author = entry.author.replace("\n", "").strip() 
            summary = f"Trending video by {author}"
            
            # Extract the unique video ID to generate the high-res thumbnail link
            video_id = link.split('v=')[-1]
            image_url = f"https://img.youtube.com/vi/{video_id}/hqdefault.jpg"
            
            cursor.execute("INSERT INTO history (source, title, raw_summary, url, image_url) VALUES (?, ?, ?, ?, ?)", 
                           ("YOUTUBE", title, summary, link, image_url))
            count += 1
            
        conn.commit()
        conn.close()
        print(f"Successfully vaulted {count} YouTube trends.")
    except Exception as e:
        print(f"YouTube infiltration failed: {e}")

# 3. The Marketplaces: E-Commerce
def ingest_ecommerce():
    print("Scanning E-Commerce Trends (Nykaa)...")
    headers = {
        'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36'
    }
    target_url = "https://www.nykaa.com/sp/trending-now/trending-now"
    
    try:
        response = requests.get(target_url, headers=headers)
        soup = BeautifulSoup(response.text, 'html.parser')
        
        conn = connect_vault()
        cursor = conn.cursor()
        
        count = 0
        for item in soup.find_all('div', class_='css-xrzmfa'):
            title_element = item.find('div', class_='css-x3m3vd')
            link_element = item.find('a')
            img_element = item.find('img') # Hunts for the product image
            
            if title_element and link_element:
                title = title_element.text.strip()
                link = "https://www.nykaa.com" + link_element.get('href')
                summary = "Trending luxury item discovered in the Indian market."
                
                # Extracts the image source, leaves blank if none found
                image_url = img_element.get('src') if img_element else ""
                
                cursor.execute("INSERT INTO history (source, title, raw_summary, url, image_url) VALUES (?, ?, ?, ?, ?)", 
                               ("NYKAA", title, summary, link, image_url))
                count += 1
                
        conn.commit()
        conn.close()
        print(f"Successfully extracted and vaulted {count} trending products.")
    except Exception as e:
        print(f"E-commerce infiltration failed: {e}")

# The Master Switch
def run_full_omnichannel_scan():
    print(f"[{datetime.datetime.now()}] Initiating Omnichannel Data Ingestion...")
    init_vault()  
    ingest_news()
    ingest_youtube()
    ingest_ecommerce()
    print("Ingestion Complete. The Vault is updated and ready for Gemini analysis.")

if __name__ == "__main__":
    run_full_omnichannel_scan()