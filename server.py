import os
import requests
import feedparser
from flask import Flask, jsonify, request
import psycopg2
from psycopg2.extras import RealDictCursor
import google.generativeai as genai
import ingestion

from apscheduler.schedulers.background import BackgroundScheduler
import atexit

app = Flask(__name__)

# --- CONFIGURATIONS ---
genai.configure(api_key=os.environ.get("GEMINI_API_KEY"))
ai_model = genai.GenerativeModel('gemini-pro')

def get_db_connection():
    return psycopg2.connect(os.environ.get("DATABASE_URL"))

def spicy_ai_summary(text, source):
    try:
        prompt = f"""
        You are an elite pop-culture and creator economy analyst.
        Analyze this raw {source} transmission:
        "{text}"

        Format your response EXACTLY like this:
        [HOOK] • Summary

        Guidelines:
        1. [HOOK] must be an entertaining 2-to-3 word phrase with an emoji.
           Examples: [💅 Main Character], [🔥 Viral Drop], [👀 Caught in 4K], [🧠 Galaxy Brain], [💎 Luxury Flex], [⚡ Internet Meltdown], [🎬 Production Peak].
        2. Summary must be punchy, crisp, and exactly 1 sentence.
        """
        response = ai_model.generate_content(prompt)
        return response.text.strip().replace("\n", " ")
    except Exception:
        return "[⚡ Live Intel] • Transmission processed from active network."

# --- API ROUTES ---

@app.route('/trending', methods=['GET'])
def get_trending():
    try:
        ingestion.run_full_omnichannel_scan()
        return jsonify({"status": "success", "message": "Omnichannel scan triggered"}), 200
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

@app.route('/search_influencer', methods=['GET'])
def search_influencer():
    query = request.args.get('q', '').strip()
    if not query:
        return jsonify([])

    results = []
    clean_handle = query.lower().replace(" ", "").replace("@", "")
    encoded_q = requests.utils.quote(query)

    headers = {
        'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/122.0.0.0 Safari/537.36'
    }

    # 1. AI Creator Dossier & Niche Detection
    try:
        prompt = f"""
        Identify the creator/influencer/public figure "{query}".
        Respond with a 1-sentence viral summary of what kind of content they create, their aesthetic, and why people follow them.
        Start with a creative 2-word hook in brackets like [🎬 Tech Prodigy] or [💅 Fashion Icon] or [⚡ Gaming King].
        """
        dossier_resp = ai_model.generate_content(prompt)
        dossier_summary = dossier_resp.text.strip().replace("\n", " ")
    except Exception:
        dossier_summary = f"[🌟 Creator Profile] • Aggregating cross-platform intelligence for {query}."

    # 2. Real-Time News & Media Mentions
    try:
        news_url = f"https://news.google.com/rss/search?q={encoded_q}&hl=en-IN&gl=IN&ceid=IN:en"
        resp = requests.get(news_url, headers=headers, timeout=8)
        feed = feedparser.parse(resp.content)
        
        fallback_images = [
            "https://images.unsplash.com/photo-1504711434969-e33886168f5c?q=80&w=800",
            "https://images.unsplash.com/photo-1585829365295-ab7cd400c167?q=80&w=800",
            "https://images.unsplash.com/photo-1495020689067-958852a7765e?q=80&w=800"
        ]

        if feed.entries:
            for idx, entry in enumerate(feed.entries[:2]):
                summary = spicy_ai_summary(entry.title, "Media Coverage")
                results.append({
                    "source": "NEWS",
                    "title": entry.title,
                    "raw_summary": summary,
                    "url": entry.link,
                    "image_url": fallback_images[idx % len(fallback_images)]
                })
    except Exception as e:
        print(f"Media Search error: {e}")

    # 3. Instagram Creator Hub
    results.append({
        "source": "INSTAGRAM",
        "title": f"{query} (@{clean_handle})",
        "raw_summary": dossier_summary,
        "url": f"https://www.instagram.com/{clean_handle}/",
        "image_url": "https://images.unsplash.com/photo-1611262588024-d12430b98920?q=80&w=800"
    })

    # 4. YouTube Creator Hub
    results.append({
        "source": "YOUTUBE",
        "title": f"{query} on YouTube",
        "raw_summary": f"[📺 Video Broadcasts] • Access full library of long-form episodes, shorts, and live streams by {query}.",
        "url": f"https://www.youtube.com/results?search_query={encoded_q}",
        "image_url": "https://images.unsplash.com/photo-1611162617213-7d7a39e9b1d7?q=80&w=800"
    })

    # 5. X / Twitter Feed
    results.append({
        "source": "X",
        "title": f"@{clean_handle} on X",
        "raw_summary": f"[⚡ Realtime Thoughts] • Unfiltered statements, announcements, and replies from {query}.",
        "url": f"https://x.com/{clean_handle}",
        "image_url": "https://images.unsplash.com/photo-1611605698335-8b1569810432?q=80&w=800"
    })

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
        You are the elite AI Copilot for the Graviton intelligence platform.
        {live_context}
        USER QUESTION: {user_question}
        """
        response = ai_model.generate_content(prompt)
        return jsonify({"graviton_response": response.text}), 200
    except Exception as e:
        return jsonify({"error": str(e)}), 500

def scheduled_ingestion():
    print("Executing automatic 6-hour sync...")
    ingestion.run_full_omnichannel_scan()

scheduler = BackgroundScheduler()
scheduler.add_job(func=scheduled_ingestion, trigger="interval", hours=6)
scheduler.start()
atexit.register(lambda: scheduler.shutdown())

if __name__ == '__main__':
    port = int(os.environ.get('PORT', 10000))
    app.run(host='0.0.0.0', port=port)