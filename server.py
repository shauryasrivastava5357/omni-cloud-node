from flask import Flask, jsonify, render_template, request, send_from_directory
import sqlite3
import google.generativeai as genai
import os
import requests
import ingestion

# 1. App Initialization (Configured for PWA static files)
app = Flask(__name__, static_folder='static')

# 2. AI Configuration (Decoupled & dynamic)
genai.configure(api_key=os.environ.get("GEMINI_API_KEY"))
target_model = os.environ.get("GEMINI_MODEL_VERSION", "gemini-3.6-flash")
ai_model = genai.GenerativeModel(target_model)

# 3. Database Connection
def get_db_connection():
    conn = sqlite3.connect('vault.db')
    conn.row_factory = sqlite3.Row
    return conn

# Initialize Database Table
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

init_db()

# 4. Core Routes

@app.route('/')
def home():
    return render_template('index.html')

# CRITICAL PWA FIX: Force Flask to serve the manifest directly
@app.route('/manifest.json')
def serve_manifest():
    return send_from_directory('static', 'manifest.json', mimetype='application/manifest+json')

@app.route('/trending', methods=['GET'])
def get_trending():
    try:
        ingestion.run_full_omnichannel_scan()
        return jsonify({"status": "success", "message": "Omnichannel vault sync complete. E-Commerce, YouTube, and Global News data secured."}), 200
    except Exception as e:
        return jsonify({"status": "error", "message": str(e)}), 500

    # Stream 1: Global Aerospace News
    try:
        space_res = requests.get("https://api.spaceflightnewsapi.net/v4/articles/?limit=3").json()
        for article in space_res.get('results', []):
            conn.execute('INSERT INTO articles (title, source, url, raw_summary, published_at) VALUES (?, ?, ?, ?, ?)',
                         (article.get("title"), article.get("news_site"), article.get("url"), article.get("summary"), str(article.get("published_at"))))
            new_data_count += 1
    except Exception as e: print(f"Space API Error: {e}")

    # Stream 2: Hacker News (Tech & Startup Virals)
    try:
        hn_top = requests.get("https://hacker-news.firebaseio.com/v0/topstories.json").json()[:3]
        for story_id in hn_top:
            story = requests.get(f"https://hacker-news.firebaseio.com/v0/item/{story_id}.json").json()
            url = story.get("url", f"https://news.ycombinator.com/item?id={story_id}")
            conn.execute('INSERT INTO articles (title, source, url, raw_summary, published_at) VALUES (?, ?, ?, ?, ?)',
                         (story.get("title"), "Hacker News", url, f"Score: {story.get('score')} | Top Tech Trend", str(story.get("time"))))
            new_data_count += 1
    except Exception as e: print(f"HN API Error: {e}")

    # Stream 3: Reddit (Viral Social Discussions)
    try:
        headers = {'User-Agent': 'Graviton-App/1.0'}
        reddit_res = requests.get("https://www.reddit.com/r/technology/hot.json?limit=3", headers=headers).json()
        for post in reddit_res.get('data', {}).get('children', []):
            data = post['data']
            conn.execute('INSERT INTO articles (title, source, url, raw_summary, published_at) VALUES (?, ?, ?, ?, ?)',
                         (data.get("title"), "Reddit - r/technology", data.get("url"), f"Upvotes: {data.get('ups')} | Viral Discussion", str(data.get("created_utc"))))
            new_data_count += 1
    except Exception as e: print(f"Reddit API Error: {e}")

    conn.commit()
    conn.close()
    return jsonify({"status": "success", "message": f"Omnichannel ingestion complete. {new_data_count} new trends locked in the vault."})

@app.route('/history', methods=['GET'])
def get_history():
    conn = get_db_connection()
    articles = conn.execute('SELECT * FROM articles ORDER BY id DESC LIMIT 15').fetchall()
    conn.close()
    return jsonify([dict(ix) for ix in articles])

@app.route('/summarize', methods=['GET'])
def summarize_data():
    try:
        conn = get_db_connection()
        articles = conn.execute('SELECT * FROM articles ORDER BY id DESC LIMIT 10').fetchall()
        conn.close()

        if not articles:
            return jsonify({"error": "Vault is empty. Ingest data first."})

        batch_text = "\n".join([f"Source: {a['source']} | Trend: {a['title']}" for a in articles])
        
        prompt = f"""
        You are Graviton, an elite AI intelligence engine. Analyze the following trending data from global networks.
        Provide a highly professional executive briefing on the macro-trends, sentiment, and key takeaways.
        
        Data Vault:
        {batch_text}
        """
        response = ai_model.generate_content(prompt)
        
        return jsonify({"status": "success", "ai_macro_analysis": response.text})
    except Exception as e:
        return jsonify({"error": str(e)}), 500

@app.route('/ask', methods=['POST'])
def ask_ai():
    try:
        user_question = request.json.get("question")
        if not user_question:
            return jsonify({"error": "No question provided"}), 400

        conn = get_db_connection()
        recent_articles = conn.execute('SELECT * FROM articles ORDER BY id DESC LIMIT 20').fetchall()
        conn.close()

        compiled_data = "\n".join([f"[{a['source']}] {a['title']}: {a['raw_summary']}" for a in recent_articles])

        prompt = f"""
        You are Graviton. Answer the user's question using ONLY this real-time data vault telemetry. 
        If the data lacks the answer, state that current tracking lacks telemetry on that topic.
        
        Vault Data:
        {compiled_data}
        
        User Query: {user_question}
        """
        response = ai_model.generate_content(prompt)
        
        return jsonify({"status": "success", "query": user_question, "graviton_response": response.text})
    except Exception as e:
        return jsonify({"error": str(e)}), 500

if __name__ == '__main__':
    app.run(debug=True, host='0.0.0.0', port=5000)