import os
import requests
import sqlite3
import google.generativeai as genai
from flask import Flask, jsonify

app = Flask(__name__)

# 1. Initialize the AI
genai.configure(api_key=os.environ.get("GEMINI_API_KEY"))
ai_model = genai.GenerativeModel('gemini-3.5-flash')

# 2. Database Connection
def get_db_connection():
    conn = sqlite3.connect('telemetry.db')
    conn.row_factory = sqlite3.Row
    return conn

# 3. THE FIX: Re-added the database initialization!
def init_db():
    conn = get_db_connection()
    conn.execute('''
        CREATE TABLE IF NOT EXISTS articles (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            title TEXT,
            source TEXT,
            url TEXT,
            raw_summary TEXT,
            published_at TEXT
        )
    ''')
    conn.commit()
    conn.close()

init_db() # Ensure the vault exists when the server spins up

@app.route('/')
def home():
    return jsonify({"message": "Graviton API is Live! The gravitational pull is active."})

@app.route('/trending', methods=['GET'])
def get_trending():
    api_url = "https://api.spaceflightnewsapi.net/v4/articles/?limit=5"
    response = requests.get(api_url)
    
    if response.status_code != 200:
        return jsonify({"error": "Failed to pull data"}), 500

    raw_data = response.json()
    conn = get_db_connection()

    for article in raw_data.get('results', []):
        conn.execute('''
            INSERT INTO articles (title, source, url, raw_summary, published_at)
            VALUES (?, ?, ?, ?, ?)
        ''', (article.get("title"), article.get("news_site"), article.get("url"), article.get("summary"), article.get("published_at")))

    conn.commit()
    conn.close()
    return jsonify({"status": "success", "message": "5 new articles captured."})

@app.route('/history', methods=['GET'])
def get_history():
    conn = get_db_connection()
    articles = conn.execute('SELECT * FROM articles ORDER BY id DESC').fetchall()
    conn.close()
    return jsonify({"total_saved": len(articles)})

@app.route('/summarize', methods=['GET'])
def summarize_latest():
    try: # Wrapped in a try/except so we get clean error messages instead of a 500 crash
        conn = get_db_connection()
        latest_article = conn.execute('SELECT * FROM articles ORDER BY id DESC LIMIT 1').fetchone()
        conn.close()

        if not latest_article:
            return jsonify({"error": "No articles in the vault. Run /trending first."})

        prompt = f"""
        You are an elite data analyst. Read this raw news summary and provide a 2-sentence 
        executive briefing on why this matters.
        Title: {latest_article["title"]}
        Raw Data: {latest_article["raw_summary"]}
        """

        response = ai_model.generate_content(prompt)
        
        return jsonify({
            "status": "success",
            "original_title": latest_article["title"],
            "ai_executive_briefing": response.text
        })
    except Exception as e:
        # If Gemini fails (e.g., bad API key), it will output the exact error here
        return jsonify({"error": str(e), "type": "AI or Database Failure"}), 400

if __name__ == '__main__':
    app.run(debug=True)