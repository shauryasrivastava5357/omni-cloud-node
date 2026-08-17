import os
import requests
import sqlite3
import google.generativeai as genai
from flask import Flask, jsonify

app = Flask(__name__)

# 1. Initialize the AI (Pulling the secret key from Render's environment)
genai.configure(api_key=os.environ.get("GEMINI_API_KEY"))
ai_model = genai.GenerativeModel('gemini-1.5-flash')

def get_db_connection():
    conn = sqlite3.connect('telemetry.db')
    conn.row_factory = sqlite3.Row
    return conn

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

# 2. THE AI ANALYTICS ROUTE
@app.route('/summarize', methods=['GET'])
def summarize_latest():
    conn = get_db_connection()
    # Grab the single newest article from the vault
    latest_article = conn.execute('SELECT * FROM articles ORDER BY id DESC LIMIT 1').fetchone()
    conn.close()

    if not latest_article:
        return jsonify({"error": "No articles in the vault. Run /trending first."})

    # Construct the prompt for the AI
    prompt = f"""
    You are an elite data analyst. Read this raw news summary and provide a 2-sentence 
    executive briefing on why this matters.
    Title: {latest_article["title"]}
    Raw Data: {latest_article["raw_summary"]}
    """

    try:
        # Generate the response
        response = ai_model.generate_content(prompt)
        ai_summary = response.text
    except Exception as e:
        return jsonify({"error": str(e)}), 500

    # Return the AI-generated analysis alongside the original data
    return jsonify({
        "status": "success",
        "original_title": latest_article["title"],
        "ai_executive_briefing": ai_summary
    })

if __name__ == '__main__':
    app.run(debug=True)