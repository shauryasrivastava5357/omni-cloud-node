import sqlite3
import requests
from bs4 import BeautifulSoup
import feedparser
import datetime

# Database Initialization
def init_vault():
    """Ensures the SQLite vault and history table exist before ingestion."""
    conn = sqlite3.connect('vault.db')
    cursor = conn.cursor()
    cursor.execute('''CREATE TABLE IF NOT EXISTS history 
                      (id INTEGER PRIMARY KEY AUTOINCREMENT, 
                       source TEXT, 
                       title TEXT, 
                       raw_summary TEXT, 
                       url TEXT)''')
    conn.commit()
    conn.close()

def connect_vault():
    return sqlite3.connect('vault.db')

# 1. The Open Gates: Global News
def ingest_news():
    print("Scanning Global News Trends...")
    # Google News RSS feed for Top Stories tailored to the Indian market
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
            
            cursor.execute("INSERT INTO history (source, title, raw_summary, url) VALUES (?, ?, ?, ?)", 
                           ("GOOGLE NEWS", title, summary, link))
            count += 1
            
        conn.commit()
        conn.close()
        print(f"Successfully vaulted {count} global news trends.")
    except Exception as e:
        print(f"News infiltration failed: {e}")

# 2. The Open Gates: YouTube Viral Trends
def ingest_youtube():
    print("Scanning YouTube Viral Trends...")
    # YouTube's RSS feed for the "Popular on YouTube" playlist
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
            
            cursor.execute("INSERT INTO history (source, title, raw_summary, url) VALUES (?, ?, ?, ?)", 
                           ("YOUTUBE", title, summary, link))
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
            
            if title_element and link_element:
                title = title_element.text.strip()
                link = "https://www.nykaa.com" + link_element.get('href')
                summary = "Trending luxury item discovered in the Indian market."
                
                cursor.execute("INSERT INTO history (source, title, raw_summary, url) VALUES (?, ?, ?, ?)", 
                               ("NYKAA", title, summary, link))
                count += 1
                
        conn.commit()
        conn.close()
        print(f"Successfully extracted and vaulted {count} trending products.")
    except Exception as e:
        print(f"E-commerce infiltration failed: {e}")

# 4. The Fortresses: Social Media (X, Instagram, Facebook)
def ingest_social_fortresses():
    print("Preparing infrastructure to infiltrate X, Instagram, and Facebook...")
    # Next phase: This will require Selenium or specialized web-drivers to bypass login walls.
    pass

# The Master Switch
def run_full_omnichannel_scan():
    print(f"[{datetime.datetime.now()}] Initiating Omnichannel Data Ingestion...")
    init_vault()  
    ingest_news()
    ingest_youtube()
    ingest_ecommerce()
    ingest_social_fortresses()
    print("Ingestion Complete. The Vault is updated and ready for Gemini analysis.")

if __name__ == "__main__":
    run_full_omnichannel_scan()