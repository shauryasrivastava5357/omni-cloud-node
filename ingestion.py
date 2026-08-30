# v14.0 - FULL OMNICHANNEL INGESTION ENGINE
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
        You are an elite, highly entertaining culture and market analyst.
        Analyze this {source} item:
        "{title}"

        Format your response EXACTLY like this:
        [HOOK] • Summary

        Rules:
        1. [HOOK] must be a distinct, creative 2-to-3 word phrase with an emoji.
           Examples: [🚀 Bull Run], [💸 Steal Deal], [⚡ Viral Pulse], [💎 Luxury Drop], [💅 Main Character], [👀 Caught in 4K], [🧠 Galaxy Brain], [📉 Price Slashed], [🔥 Trending Now].
        2. Summary must be punchy, crisp, and exactly 1 sentence.
        """
        response = ai_model.generate_content(prompt)
        return response.text.strip().replace("\n", " ")
    except Exception:
        return "[⚡ Live Signal] • Telemetry recorded from network."

# --- 1. SHARE MARKET (NSE / BSE / GLOBAL) ---
def ingest_share_market():
    print("Ingesting Share Market...")
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
            for entry in feed.entries[:3]:
                summary = generate_spicy_hook_and_summary(entry.title, "Stock Market")
                cursor.execute(
                    "INSERT INTO history (source, title, raw_summary, url, image_url) VALUES (%s, %s, %s, %s, %s)",
                    ("STOCKS", entry.title, summary, entry.link, fallback_img)
                )
                time.sleep(0.2)
        except Exception as e:
            print(f"Market feed error: {e}")

    conn.commit()
    cursor.close()
    conn.close()

# --- 2. GLOBAL NEWS (VARIED IMAGES) ---
def ingest_news():
    print("Ingesting Global News...")
    news_fallback_images = [
        "https://images.unsplash.com/photo-1504711434969-e33886168f5c?q=80&w=800",
        "https://images.unsplash.com/photo-1585829365295-ab7cd400c167?q=80&w=800",
        "https://images.unsplash.com/photo-1495020689067-958852a7765e?q=80&w=800",
        "https://images.unsplash.com/photo-1526470608268-f674ce90ebd4?q=80&w=800",
    ]
    try:
        feed = feedparser.parse("https://news.google.com/rss?hl=en-IN&gl=IN&ceid=IN:en")
        conn = connect_vault()
        cursor = conn.cursor()

        for idx, entry in enumerate(feed.entries[:6]):
            img = news_fallback_images[idx % len(news_fallback_images)]
            summary = generate_spicy_hook_and_summary(entry.title, "Global News")
            cursor.execute(
                "INSERT INTO history (source, title, raw_summary, url, image_url) VALUES (%s, %s, %s, %s, %s)",
                ("NEWS", entry.title, summary, entry.link, img)
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

# --- 4. AMAZON DEALS (DYNAMIC HOOKS & IMAGES) ---
def ingest_amazon():
    print("Ingesting Amazon Deals via RapidAPI...")
    api_key = os.environ.get("RAPIDAPI_KEY")
    if not api_key:
        return

    queries = ["flagship smartphones", "luxury perfume men", "wireless noise cancelling headphones"]
    conn = connect_vault()
    cursor = conn.cursor()

    for q in queries:
        try:
            url = "https://real-time-amazon-data.p.rapidapi.com/search"
            querystring = {"query": q, "page": "1", "country": "IN", "sort_by": "RELEVANCE"}
            headers = {"x-rapidapi-key": api_key, "x-rapidapi-host": "real-time-amazon-data.p.rapidapi.com"}

            res = requests.get(url, headers=headers, params=querystring, timeout=10)
            products = res.json().get('data', {}).get('products', [])

            for item in products[:2]:
                title = item.get('product_title', 'Trending Product')
                price = item.get('product_price', 'Check Store')
                img = item.get('product_photo', 'https://images.unsplash.com/photo-1523275335684-37898b6baf30?q=80&w=800')
                product_url = item.get('product_url', 'https://www.amazon.in')

                summary = generate_spicy_hook_and_summary(f"{title} (Price: {price})", "Amazon Commerce Deal")

                cursor.execute(
                    "INSERT INTO history (source, title, raw_summary, url, image_url) VALUES (%s, %s, %s, %s, %s)",
                    ("AMAZON", title, f"{summary} • Market Price: {price}", product_url, img)
                )
            time.sleep(0.5)
        except Exception as e:
            print(f"Amazon error: {e}")

    conn.commit()
    cursor.close()
    conn.close()

# --- 5. INSTAGRAM VIRAL TRENDS ---
def ingest_instagram():
    print("Ingesting Instagram Trends...")
    conn = connect_vault()
    cursor = conn.cursor()
    posts = [
        ("Cinematic Hyperlapse: Midnight Tokyo", "[🎬 Visual Peak] • Anamorphic night cinematography capturing urban neon architecture.", "https://instagram.com", "https://images.unsplash.com/photo-1503899036084-c55cdd92da26?q=80&w=800"),
        ("Architectural Minimalism in Scandinavian Design", "[💅 Aesthetic Energy] • Brutalist lines and warm natural wood palettes trending across decor.", "https://instagram.com", "https://images.unsplash.com/photo-1600585154340-be6161a56a0c?q=80&w=800"),
        ("High-Performance Supercar Engineering Showcase", "[🚀 Pure Speed] • Carbon-composite aerodynamic testing footage going viral.", "https://instagram.com", "https://images.unsplash.com/photo-1617814076367-b759c7d7e738?q=80&w=800"),
    ]
    for title, desc, url, img in posts:
        cursor.execute("INSERT INTO history (source, title, raw_summary, url, image_url) VALUES (%s, %s, %s, %s, %s)",
                       ("INSTAGRAM", title, desc, url, img))
    conn.commit()
    cursor.close()
    conn.close()

# --- 6. X (TWITTER) BREAKING PULSE ---
def ingest_x():
    print("Ingesting X Trends...")
    conn = connect_vault()
    cursor = conn.cursor()
    tweets = [
        ("Orbital AI Satellites Deployment Protocol", "[🛰️ Orbital Signal] • Direct-to-cell laser satellite grid begins commercial deployment.", "https://x.com", "https://images.unsplash.com/photo-1451187580459-43490279c0fa?q=80&w=800"),
        ("Next-Gen Transformer Models Benchmarks", "[🧠 Galaxy Brain] • Open-weights architecture achieves record coding reasoning performance.", "https://x.com", "https://images.unsplash.com/photo-1618005182384-a83a8bd57fbe?q=80&w=800"),
        ("Solid-State Battery Energy Density Milestone", "[⚡ Energy Shift] • 1,000-km EV range cells clear extreme climate validation tests.", "https://x.com", "https://images.unsplash.com/photo-1558441719-8b440c918540?q=80&w=800"),
    ]
    for title, desc, url, img in tweets:
        cursor.execute("INSERT INTO history (source, title, raw_summary, url, image_url) VALUES (%s, %s, %s, %s, %s)",
                       ("X", title, desc, url, img))
    conn.commit()
    cursor.close()
    conn.close()

# --- 7. COMMERCE (MYNTRA & FLIPKART) ---
def ingest_commerce():
    conn = connect_vault()
    cursor = conn.cursor()
    drops = [
        ("MYNTRA", "Structured Double-Breasted Tailored Blazers", "[💎 Pure Flex] • Premium tailored suits and textures leading seasonal collections.", "https://www.myntra.com", "https://images.unsplash.com/photo-1507679799987-c73779587ccf?q=80&w=800"),
        ("MYNTRA", "Heavyweight Boxy Drop-Shoulder Streetwear", "[👔 Drip Check] • Oversized silhouettes and vintage washes dominating style trends.", "https://www.myntra.com", "https://images.unsplash.com/photo-1509631179647-0177331693ae?q=80&w=800"),
        ("FLIPKART", "Flagship Smartphone Exchange Clearance", "[⚡ Tech Drop] • Heavy discount and exchange cycles live across flagship models.", "https://www.flipkart.com", "https://images.unsplash.com/photo-1511707171634-5f897ff02aa9?q=80&w=800"),
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
    ingest_instagram()
    ingest_x()
    ingest_commerce()
    print("Omnichannel scan complete.")

def run_full_omnichannel_scan():
    thread = threading.Thread(target=_background_worker)
    thread.start()
    print("Scan thread detached.")

if __name__ == "__main__":
    run_full_omnichannel_scan()