# v13.0 - ROBUST OMNICHANNEL & LIVE SHARE MARKET ENGINE
import psycopg2
import requests
from bs4 import BeautifulSoup
import feedparser
import datetime
import os
import time
import threading
import google.generativeai as genai

# --- CONFIGURATIONS ---
genai.configure(api_key=os.environ.get("GEMINI_API_KEY"))
ai_model = genai.GenerativeModel('gemini-pro')

def connect_vault():
    return psycopg2.connect(os.environ.get("DATABASE_URL"))

def init_vault():
    conn = connect_vault()
    cursor = conn.cursor()
    cursor.execute('''CREATE TABLE IF NOT EXISTS history
                      (id SERIAL PRIMARY KEY,
                       source TEXT,
                       title TEXT,
                       raw_summary TEXT,
                       url TEXT,
                       image_url TEXT)''')
    conn.commit()
    cursor.close()
    conn.close()

def generate_spicy_hook_and_summary(title, source):
    try:
        prompt = f"""
        You are an elite financial & pop-culture commentator.
        Analyze this {source} headline:
        "{title}"

        Format your response EXACTLY like this:
        [HOOK] • Summary

        Guidelines:
        1. For STOCKS/FINANCE: Use hooks like [🚀 Bull Run], [📉 Market Dip], [💎 Diamond Hands], [💸 Wealth Alert], [🏦 Policy Shift], [⚡ Volatility Surge].
        2. For GENERAL/CULTURE: Use hooks like [🍿 Spill The Tea], [💅 Main Character], [👀 Caught in 4K], [🧠 Galaxy Brain], [💀 Unhinged Move].
        3. Summary must be punchy, crisp, and exactly 1 sentence.
        """
        response = ai_model.generate_content(prompt)
        return response.text.strip().replace("\n", " ")
    except Exception:
        return "[⚡ Market Pulse] • Fresh transmission logged."

# --- 1. SHARE MARKET (NSE / BSE / GLOBAL TELEMETRY) ---
def ingest_share_market():
    print("Ingesting Live Share Market Intelligence...")
    market_feeds = [
        ("https://economictimes.indiatimes.com/markets/rssfeeds/1977021501.cms", "https://images.unsplash.com/photo-1611974789855-9c2a0a7236a3?q=80&w=800"),
        ("https://www.moneycontrol.com/rss/marketreports.xml", "https://images.unsplash.com/photo-1590283603385-17ffb3a7f29f?q=80&w=800"),
        ("https://finance.yahoo.com/news/rssindex", "https://images.unsplash.com/photo-1642543492481-44e81e3914a7?q=80&w=800")
    ]
    conn = connect_vault()
    cursor = conn.cursor()

    for feed_url, fallback_img in market_feeds:
        try:
            feed = feedparser.parse(feed_url)
            for entry in feed.entries[:4]:
                summary = generate_spicy_hook_and_summary(entry.title, "Stock Market")
                cursor.execute(
                    "INSERT INTO history (source, title, raw_summary, url, image_url) VALUES (%s, %s, %s, %s, %s)",
                    ("STOCKS", entry.title, summary, entry.link, fallback_img)
                )
                time.sleep(0.2)
        except Exception as e:
            print(f"Market feed error ({feed_url}): {e}")

    conn.commit()
    cursor.close()
    conn.close()

# --- 2. GLOBAL NEWS ---
def ingest_news():
    print("Ingesting Global News...")
    try:
        feed = feedparser.parse("https://news.google.com/rss?hl=en-IN&gl=IN&ceid=IN:en")
        conn = connect_vault()
        cursor = conn.cursor()

        for entry in feed.entries[:6]:
            summary = generate_spicy_hook_and_summary(entry.title, "Global News")
            cursor.execute(
                "INSERT INTO history (source, title, raw_summary, url, image_url) VALUES (%s, %s, %s, %s, %s)",
                ("NEWS", entry.title, summary, entry.link, "https://images.unsplash.com/photo-1504711434969-e33886168f5c?q=80&w=800")
            )
            time.sleep(0.2)

        conn.commit()
        cursor.close()
        conn.close()
    except Exception as e:
        print(f"News error: {e}")

# --- 3. YOUTUBE TRENDING ---
def ingest_youtube():
    print("Ingesting YouTube trends...")
    try:
        feed = feedparser.parse("https://www.youtube.com/feeds/videos.xml?playlist_id=PLrEnWoR732-BHrPp_Pm8_VleD68f9s14-")
        conn = connect_vault()
        cursor = conn.cursor()

        for entry in feed.entries[:6]:
            vid_id = entry.link.split('v=')[-1]
            img_url = f"https://img.youtube.com/vi/{vid_id}/hqdefault.jpg"
            summary = generate_spicy_hook_and_summary(entry.title, "YouTube")

            cursor.execute(
                "INSERT INTO history (source, title, raw_summary, url, image_url) VALUES (%s, %s, %s, %s, %s)",
                ("YOUTUBE", entry.title, summary, entry.link, img_url)
            )
            time.sleep(0.2)

        conn.commit()
        cursor.close()
        conn.close()
    except Exception as e:
        print(f"YouTube error: {e}")

# --- 4. AMAZON LUXURY & TECH DEALS (RAPIDAPI) ---
def ingest_amazon():
    print("Ingesting Amazon Deals via RapidAPI...")
    api_key = os.environ.get("RAPIDAPI_KEY")
    if not api_key:
        return

    search_queries = ["luxury perfume men", "flagship smartphones"]
    conn = connect_vault()
    cursor = conn.cursor()

    for query in search_queries:
        try:
            url = "https://real-time-amazon-data.p.rapidapi.com/search"
            querystring = {"query": query, "page": "1", "country": "IN", "sort_by": "RELEVANCE"}
            headers = {"x-rapidapi-key": api_key, "x-rapidapi-host": "real-time-amazon-data.p.rapidapi.com"}

            res = requests.get(url, headers=headers, params=querystring, timeout=10)
            products = res.json().get('data', {}).get('products', [])

            for item in products[:2]:
                title = item.get('product_title', 'Trending Product')
                price = item.get('product_price', 'Check Store')
                img = item.get('product_photo', 'https://images.unsplash.com/photo-1523275335684-37898b6baf30?q=80&w=800')
                product_url = item.get('product_url', 'https://www.amazon.in')

                cursor.execute(
                    "INSERT INTO history (source, title, raw_summary, url, image_url) VALUES (%s, %s, %s, %s, %s)",
                    ("AMAZON", title, f"[💸 Wallet Hazard] • Current Price: {price}", product_url, img)
                )
            time.sleep(0.5)
        except Exception as e:
            print(f"Amazon error: {e}")

    conn.commit()
    cursor.close()
    conn.close()

# --- 5. COMMERCE & STYLE ---
def ingest_commerce():
    conn = connect_vault()
    cursor = conn.cursor()
    drops = [
        ("MYNTRA", "Structured Double-Breasted Tailored Blazers", "[💎 Pure Flex] • Premium tailored suits and textures leading seasonal collections.", "https://www.myntra.com", "https://images.unsplash.com/photo-1507679799987-c73779587ccf?q=80&w=800"),
        ("MYNTRA", "Heavyweight Boxy Drop-Shoulder Streetwear", "[👔 Drip Check] • Oversized silhouettes and vintage washes dominating style trends.", "https://www.myntra.com", "https://images.unsplash.com/photo-1509631179647-0177331693ae?q=80&w=800"),
        ("FLIPKART", "Flagship Smartphone Performance Fest", "[⚡ Tech Drop] • Heavy discount and exchange cycles live across flagship models.", "https://www.flipkart.com", "https://images.unsplash.com/photo-1511707171634-5f897ff02aa9?q=80&w=800"),
    ]
    for source, title, desc, url, img in drops:
        cursor.execute("INSERT INTO history (source, title, raw_summary, url, image_url) VALUES (%s, %s, %s, %s, %s)",
                       (source, title, desc, url, img))
    conn.commit()
    cursor.close()
    conn.close()

def _background_worker():
    print(f"[{datetime.datetime.now()}] Full omnichannel scan started...")
    init_vault()
    ingest_share_market()
    ingest_news()
    ingest_youtube()
    ingest_amazon()
    ingest_commerce()
    print("Omnichannel scan complete.")

def run_full_omnichannel_scan():
    thread = threading.Thread(target=_background_worker)
    thread.start()
    print("Scan thread detached.")

if __name__ == "__main__":
    run_full_omnichannel_scan()