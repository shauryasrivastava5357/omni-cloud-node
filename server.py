from flask import Flask, jsonify, render_template
import os
import requests
import sqlite3
import google.generativeai as genai
from flask import Flask, jsonify

app = Flask(__name__, static_folder='static')

# 1. Initialize the AI
genai.configure(api_key=os.environ.get("GEMINI_API_KEY"))

# Dynamically fetch the model version from the cloud, with a built-in safety fallback
target_model = os.environ.get("GEMINI_MODEL_VERSION", "gemini-3.6-flash")
ai_model = genai.GenerativeModel(target_model)

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
    return render_template('index.html')

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
    try: 
        conn = get_db_connection()
        # 1. Analytics Upgrade: Fetch the 10 most recent articles instead of just 1
        recent_articles = conn.execute('SELECT * FROM articles ORDER BY id DESC LIMIT 10').fetchall()
        conn.close()

        if not recent_articles:
            return jsonify({"error": "No articles in the vault. Run /trending first."})

        # 2. Compile the raw data for the AI
        compiled_data = ""
        for article in recent_articles:
            compiled_data += f"- {article['title']}: {article['raw_summary']}\n"

        # 3. Advanced Analytical Prompt
        prompt = f"""
        You are an elite data analyst. Review the following recent news articles and provide a 
        macro-trend sentiment analysis. Give me a 3-bullet point executive briefing on the overall 
        narrative of these articles, highlighting any major positive, negative, or technological trends.
        
        Raw Data:
        {compiled_data}
        """

        # Generate the response
        response = ai_model.generate_content(prompt)
        
        return jsonify({
            "status": "success",
            "articles_analyzed": len(recent_articles),
            "ai_macro_analysis": response.text
        })
    except Exception as e:
        return jsonify({"error": str(e), "type": "AI or Database Failure"}), 400

if __name__ == '__main__':
    app.run(debug=True)