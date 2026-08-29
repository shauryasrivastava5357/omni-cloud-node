import os
import requests
import feedparser
from bs4 import BeautifulSoup
from flask import Flask, jsonify, request
import psycopg2
from psycopg2.extras import RealDictCursor
import google.generativeai as genai
import ingestion

# --- SCHEDULER IMPORTS ---
from apscheduler.schedulers.background import BackgroundScheduler
import atexit

app = Flask(__name__)

# --- CONFIGURATIONS ---
genai.configure(api_key=os.environ.get("GEMINI_API_KEY"))
ai_model = genai.GenerativeModel('gemini-pro')

def get_db_connection():
    return psycopg2.connect(os.environ.get("DATABASE_URL"))

def spicy_ai_summary(text, source):
    """Generates an attention-grabbing hook and a 1-sentence viral summary."""
    try:
        prompt = f"""
        You are an elite, entertaining cultural commentator and data analyst.
        Analyze this raw {source} transmission:
        "{text}"

        Format your response EXACTLY like this:
        [HOOK] • Summary

        Guidelines:
        1. [HOOK] must be a funny, dramatic, or attention-grabbing 2-to-3 word phrase with an emoji.
           Examples: [🍿 Spill The Tea], [💅 Main Character], [👀 Caught in 4K], [🧠 Galaxy Brain], [💸 Wallet Hazard], [🚀 Bull Run], [📉 Blood in the Streets], [⚡ Internet Meltdown], [💀 Unhinged Move], [💎 Pure Flex].
        2. Summary must be punchy, crisp, and exactly 1 sentence.
        """
        response = ai_model.generate_content(prompt)
        return response.text.strip().replace("\n", " ")
    except Exception:
        return "[⚡ Live Signal] • Intel transmission logged from the network."

# --- API ROUTES ---

@app.route('/trending', methods=['GET'])
def get_trending():
    try:
        ingestion.run_full_omnichannel_scan()
        return jsonify({"status": "success", "message": "Manual omnichannel scan initiated"}), 200
    except Exception as e:
        return jsonify({"status": "error", "message": str(e)}), 500

@app.route('/history', methods=['GET'])
def get_history():
    try:
        conn = get_db_connection()
        cursor = conn.cursor(cursor_factory=RealDictCursor)
        cursor.execute('SELECT source, title, raw_summary, url, image_url FROM history ORDER BY id DESC LIMIT 100')
        items = cursor.fetchall()
        cursor.close()
        conn.close()
        return jsonify([dict(ix) for ix in items]), 200
    except Exception as e:
        return jsonify({"status": "error", "message": str(e)}), 500

@app.route('/search_vip', methods=['GET'])
def search_vip():
    query = request.args.get('q', '').strip()
    if not query:
        return jsonify([])

    results = []
    clean_handle = query.lower().replace(" ", "").replace("@", "")

    # 1. Real-Time Instagram (Picuki Ghost Mirror)
    try:
        headers = {'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) Chrome/120.0.0.0 Safari/537.36'}
        res = requests.get(f"https://www.picuki.com/profile/{clean_handle}", headers=headers, timeout=6)
        if res.status_code == 200:
            soup = BeautifulSoup(res.text, 'html.parser')
            post = soup.find('ul', class_='box-photos')
            if post and post.find('li'):
                first_post = post.find('li')
                img_elem = first_post.find('img')
                text_elem = first_post.find('div', class_='photo-description')
                
                img_url = img_elem['src'] if img_elem else "https://images.unsplash.com/photo-1611262588024-d12430b98920?q=80&w=800"
                raw_text = text_elem.text.strip() if text_elem else f"Latest Instagram update from {query}"
                
                summary = spicy_ai_summary(raw_text, "Instagram")
                results.append({
                    "source": "INSTAGRAM",
                    "title": f"@{clean_handle}",
                    "raw_summary": summary,
                    "url": f"https://instagram.com/{clean_handle}",
                    "image_url": img_url
                })
    except Exception as e:
        print(f"IG Search error: {e}")

    # 2. Real-Time X / Twitter (Nitter Gateway)
    nitter_instances = ["https://nitter.poast.org", "https://nitter.privacydev.net", "https://nitter.lucabased.xyz"]
    for instance in nitter_instances:
        try:
            feed = feedparser.parse(f"{instance}/{clean_handle}/rss")
            if feed.entries:
                tweet = feed.entries[0]
                clean_text = BeautifulSoup(tweet.description, "html.parser").text
                summary = spicy_ai_summary(clean_text, "X")
                results.append({
                    "source": "X",
                    "title": f"@{clean_handle}",
                    "raw_summary": summary,
                    "url": f"https://x.com/{clean_handle}",
                    "image_url": "https://images.unsplash.com/photo-1611605698335-8b1569810432?q=80&w=800"
                })
                break
        except Exception:
            continue

    # 3. Real-Time YouTube Search
    try:
        yt_feed = feedparser.parse(f"https://www.youtube.com/feeds/videos.xml?search_query={query}")
        if yt_feed.entries:
            vid = yt_feed.entries[0]
            vid_id = vid.link.split('v=')[-1]
            summary = spicy_ai_summary(vid.title, "YouTube")
            results.append({
                "source": "YOUTUBE",
                "title": vid.title,
                "raw_summary": summary,
                "url": vid.link,
                "image_url": f"https://img.youtube.com/vi/{vid_id}/hqdefault.jpg"
            })
    except Exception as e:
        print(f"YouTube Search error: {e}")

    # 4. Real-Time Google News Dossier
    try:
        news_feed = feedparser.parse(f"https://news.google.com/rss/search?q={query}&hl=en-IN&gl=IN&ceid=IN:en")
        if news_feed.entries:
            for entry in news_feed.entries[:2]:
                summary = spicy_ai_summary(entry.title, "News")
                results.append({
                    "source": "NEWS",
                    "title": entry.title,
                    "raw_summary": summary,
                    "url": entry.link,
                    "image_url": "https://images.unsplash.com/photo-1504711434969-e33886168f5c?q=80&w=800"
                })
    except Exception as e:
        print(f"News Search error: {e}")

    return jsonify(results), 200

@app.route('/ask', methods=['POST'])
def ask_graviton():
    try:
        data = request.get_json()
        user_question = data.get('question', '')
        if not user_question:
            return jsonify({"error": "No question provided"}), 400

        conn = get_db_connection()
        cursor = conn.cursor(cursor_factory=RealDictCursor)
        cursor.execute('SELECT source, title, raw_summary FROM history ORDER BY id DESC LIMIT 50')
        items = cursor.fetchall()
        cursor.close()
        conn.close()

        live_context = "LIVE DATABASE CONTEXT:\n"
        for item in items:
            live_context += f"- [{item['source']}] {item['title']} | {item['raw_summary']}\n"
            
        prompt = f"""
        You are the elite AI Copilot for the Graviton platform. You are a witty, highly analytical intelligence system.
        {live_context}
        USER QUESTION: {user_question}
        
        INSTRUCTIONS:
        1. Answer using the LIVE DATABASE CONTEXT when relevant.
        2. Keep formatting clean, sharp, and easy to read.
        """
        response = ai_model.generate_content(prompt)
        return jsonify({"graviton_response": response.text}), 200
    except Exception as e:
        return jsonify({"error": str(e)}), 500

# --- AUTONOMOUS BACKGROUND SCHEDULER ---
def scheduled_ingestion():
    print("Executing automatic 6-hour background sync...")
    ingestion.run_full_omnichannel_scan()

scheduler = BackgroundScheduler()
scheduler.add_job(func=scheduled_ingestion, trigger="interval", hours=6)
scheduler.start()
atexit.register(lambda: scheduler.shutdown())

if __name__ == '__main__':
    port = int(os.environ.get('PORT', 10000))
    app.run(host='0.0.0.0', port=port)