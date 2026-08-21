from flask import Flask, jsonify, render_template, request, send_from_directory
import sqlite3
import google.generativeai as genai
import os
import ingestion
from apscheduler.schedulers.background import BackgroundScheduler

app = Flask(__name__, static_folder='static')

# 1. AI Configuration
genai.configure(api_key=os.environ.get("GEMINI_API_KEY"))
target_model = os.environ.get("GEMINI_MODEL_VERSION", "gemini-1.5-flash")
ai_model = genai.GenerativeModel(target_model)

# 2. Database Connection
def get_db_connection():
    conn = sqlite3.connect('vault.db')
    conn.row_factory = sqlite3.Row
    return conn

# 3. Autonomous Background Scheduler
def scheduled_ingestion():
    print("Initiating automatic background sync...")
    ingestion.run_full_omnichannel_scan()

# Initializes the scheduler to run in the background
scheduler = BackgroundScheduler()
# Triggers the scraping script automatically every 60 minutes
scheduler.add_job(func=scheduled_ingestion, trigger="interval", minutes=60)
scheduler.start()

# 4. App Routes
@app.route('/')
def index():
    return render_template('index.html')

@app.route('/manifest.json')
def manifest():
    return send_from_directory('static', 'manifest.json', mimetype='application/manifest+json')

@app.route('/trending', methods=['GET'])
def get_trending():
    # Kept as a manual override just in case you ever want to force a refresh
    try:
        ingestion.run_full_omnichannel_scan()
        return jsonify({"status": "success", "message": "Manual sync forced. All platforms updated."}), 200
    except Exception as e:
        return jsonify({"status": "error", "message": str(e)}), 500

@app.route('/history', methods=['GET'])
def get_history():
    try:
        conn = get_db_connection()
        items = conn.execute('SELECT source, title, raw_summary, url, image_url FROM history ORDER BY id DESC LIMIT 50').fetchall()
        conn.close()
        return jsonify([dict(ix) for ix in items]), 200
    except Exception as e:
        return jsonify({"status": "error", "message": str(e)}), 500

@app.route('/ask', methods=['POST'])
def ask_graviton():
    try:
        data = request.get_json()
        user_question = data.get('question', '')
        conn = get_db_connection()
        items = conn.execute('SELECT source, title, raw_summary FROM history ORDER BY id DESC LIMIT 20').fetchall()
        conn.close()
        context = "\n".join([f"[{item['source']}] {item['title']} - {item['raw_summary']}" for item in items])
        prompt = f"Context from the universal vault:\n{context}\n\nUser Question: {user_question}\nAnswer the user confidently as Graviton."
        response = ai_model.generate_content(prompt)
        return jsonify({"graviton_response": response.text}), 200
    except Exception as e:
        return jsonify({"status": "error", "message": str(e)}), 500

if __name__ == '__main__':
    port = int(os.environ.get('PORT', 5000))
    app.run(host='0.0.0.0', port=port)