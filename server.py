import requests
import sqlite3
from flask import Flask, jsonify

app = Flask(__name__)

# 1. Helper function to connect to our local vault
def get_db_connection():
    conn = sqlite3.connect('telemetry.db')
    conn.row_factory = sqlite3.Row
    return conn

# 2. Initialize the database and ensure our table exists
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

# Run this once when the server starts
init_db()

@app.route('/')
def home():
    return jsonify({"message": "Graviton API is Live! The gravitational pull is active."})

@app.route('/trending', methods=['GET'])
def get_trending():
    # Reach out to the public API
    api_url = "https://api.spaceflightnewsapi.net/v4/articles/?limit=5"
    response = requests.get(api_url)
    
    if response.status_code != 200:
        return jsonify({"error": "Failed to pull data from the web"}), 500

    raw_data = response.json()
    structured_news = []
    
    # Open the vault
    conn = get_db_connection()

    for article in raw_data.get('results', []):
        title = article.get("title")
        source = article.get("news_site")
        url = article.get("url")
        summary = article.get("summary")
        published_at = article.get("published_at")
        
        structured_news.append({
            "title": title,
            "source": source,
            "url": url,
            "raw_summary": summary,
            "published_at": published_at
        })
        
        # Insert the clean data into SQLite
        conn.execute('''
            INSERT INTO articles (title, source, url, raw_summary, published_at)
            VALUES (?, ?, ?, ?, ?)
        ''', (title, source, url, summary, published_at))

    conn.commit()
    conn.close()

    return jsonify({
        "status": "success",
        "message": "Data successfully fetched and stored in telemetry.db",
        "article_count": len(structured_news),
        "data": structured_news
    })

if __name__ == '__main__':
    app.run(debug=True)