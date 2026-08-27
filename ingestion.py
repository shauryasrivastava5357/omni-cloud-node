# v4.0 - SOCIAL MEDIA INTEGRATION (X/TWITTER)
import psycopg2
import requests
from bs4 import BeautifulSoup
import feedparser
import datetime
import os
import time
import google.generativeai as genai

# --- AI CONFIGURATION ---
genai.configure(api_key=os.environ.get("GEMINI_API_KEY"))
ai_model = genai.GenerativeModel('gemini-pro')

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

def extract_real_image(url):
    try:
        headers = {'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36'}
        response = requests.get(url, headers=headers, timeout=8)
        soup = BeautifulSoup(response.text, 'html.parser')
        og_image = soup.find("meta", property="og:image")
        if og_image and og_image.get("content"):
            return og_image["content"]
    except:
        pass
    return "https://images.unsplash.com/photo-1504711434969-e33886168f5c?q=80&w=800&auto=format&fit=crop"

def get_ai_tag(title):
    try:
        prompt = f"Categorize this trend in EXACTLY two words with an appropriate emoji at the start (e.g., '🚨 Breaking', '🎬 Cinema', '💻 Tech', '👔 Style', '💄 Beauty', '📉 Deal', '🔥 Viral'). Trend: {title}"
        response = ai_model.generate_content(prompt)
        tag = response.text.strip().replace("\n", "")
        if len(tag) > 20: 
            return "🔥 Trending"
        return tag
    except Exception as e:
        return "🔥 Trending"

# --- EXISTING SCRAPERS ---
def ingest_news():
    print("Scanning Global News Trends...")
    try:
        feed = feedparser.parse("https://news.google.com/rss?hl=en-IN&gl=IN&ceid=IN:en")
        conn = connect_vault()
        cursor = conn.cursor()
        for entry in feed.entries[:3]:
            real_image = extract_real_image(entry.link)
            ai_tag = get_ai_tag(entry.title)
            smart_summary = f"[{ai_tag}] • Published: {entry.published}"
            cursor.execute("INSERT INTO history (source, title, raw_summary, url, image_url) VALUES (%s, %s, %s, %s, %s)",
                           ("NEWS", entry.title, smart_summary, entry.link, real_image))
            time.sleep(1)
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
            ai_tag = get_ai_tag(entry.title)
            smart_summary = f"[{ai_tag}] • Trending video by {entry.author.strip()}"
            cursor.execute("INSERT INTO history (source, title, raw_summary, url, image_url) VALUES (%s, %s, %s, %s, %s)",
                           ("YOUTUBE", entry.title, smart_summary, entry.link, image_url))
            time.sleep(1)
        conn.commit()
        cursor.close()
        conn.close()
    except Exception as e:
        print(f"YouTube failed: {e}")

def ingest_amazon():
    print("Scanning Live Amazon India Trends...")
    api_key = os.environ.get("RAPIDAPI_KEY")
    if not api_key:
        print("Amazon Bypass Failed: RAPIDAPI_KEY missing.")
        return
    try:
        url = "https://real-time-amazon-data.p.rapidapi.com/search"
        querystring = {"query":"trending products","page":"1","country":"IN","sort_by":"RELEVANCE"}
        headers = {"x-rapidapi-key": api_key, "x-rapidapi-host": "real-time-amazon-data.p.rapidapi.com"}
        
        response = requests.get(url, headers=headers, params=querystring)
        products = response.json().get('data', {}).get('products', [])
        
        if not products: return
            
        conn = connect_vault()
        cursor = conn.cursor()
        for item in products[:3]:
            price = item.get('product_price', 'Unknown')
            title = item.get('product_title', 'Unknown')
            ai_tag = get_ai_tag(title)
            smart_summary = f"[{ai_tag}] • Live Price: {price}"
            cursor.execute("INSERT INTO history (source, title, raw_summary, url, image_url) VALUES (%s, %s, %s, %s, %s)",
                           ("AMAZON", title, smart_summary, item.get('product_url', ''), item.get('product_photo', '')))
            time.sleep(1)
        conn.commit()
        cursor.close()
        conn.close()
    except Exception as e:
        print(f"Amazon failed: {e}")

# --- THE NEW SOCIAL MEDIA ENGINE ---
def ingest_x_twitter():
    print("Scanning X (Twitter) Celebrity Posts...")
    api_key = os.environ.get("RAPIDAPI_KEY")
    if not api_key:
        print("X Bypass Failed: RAPIDAPI_KEY missing.")
        return
        
    try:
        # We are using a RapidAPI Twitter API endpoint. 
        # Example: Pulling posts from a major tech/cinema personality
        url = "https://twitter-api45.p.rapidapi.com/timeline.php"
        querystring = {"screenname": "iamsrk"} # Shah Rukh Khan as a test target
        headers = {
            "x-rapidapi-key": api_key,
            "x-rapidapi-host": "twitter-api45.p.rapidapi.com"
        }
        
        response = requests.get(url, headers=headers, params=querystring)
        data = response.json()
        
        # If the API endpoint fails or requires a subscription, we catch it safely
        if 'timeline' not in data:
            print("X API response did not contain timeline data. Check RapidAPI limits.")
            return

        conn = connect_vault()
        cursor = conn.cursor()
        
        for tweet in data.get('timeline', [])[:3]:
            text = tweet.get('text', 'No text')
            tweet_url = f"https://x.com/i/web/status/{tweet.get('id', '')}"
            
            # Grab the image if the tweet has one, otherwise use a sleek X placeholder
            image = "https://images.unsplash.com/photo-1611605698335-8b1569810432?q=80&w=800"
            if 'media' in tweet and tweet['media']:
                image = tweet['media'][0].get('media_url_https', image)
                
            ai_tag = get_ai_tag(text[:50])
            smart_summary = f"[{ai_tag}] • Viral on X"
            
            cursor.execute("INSERT INTO history (source, title, raw_summary, url, image_url) VALUES (%s, %s, %s, %s, %s)",
                           ("X", text, smart_summary, tweet_url, image))
            time.sleep(1)
            
        conn.commit()
        cursor.close()
        conn.close()
        print("X data successfully vaulted!")
    except Exception as e:
        print(f"X (Twitter) failed: {e}")

def run_full_omnichannel_scan():
    print(f"[{datetime.datetime.now()}] Initiating Cognitive Omnichannel Sync...")
    init_vault()
    ingest_news()
    ingest_youtube()
    ingest_amazon()
    ingest_x_twitter() # <-- Social Media added to the brain!
    print("Sync Complete. Intelligence applied and Database updated.")

if __name__ == "__main__":
    run_full_omnichannel_scan()