from flask import Flask, jsonify, render_template, request, send_from_directory
import psycopg2
from psycopg2.extras import RealDictCursor
import google.generativeai as genai
import os
import ingestion
from apscheduler.schedulers.background import BackgroundScheduler

app = Flask(__name__, static_folder='static')

# 1. AI Configuration
genai.configure(api_key=os.environ.get("GEMINI_API_KEY"))
target_model = os.environ.get("GEMINI_MODEL_VERSION", "gemini-1.5-flash")
ai_model = genai.GenerativeModel(target_model)

# 2. Permanent Cloud Database Connection
def get_db_connection():
    db_url = os.environ.get("DATABASE_URL")
    # Automatically connects to the Render PostgreSQL instance
    conn = psycopg2.connect(db_url)
    return conn

# 3. Autonomous Background Scheduler
def scheduled_ingestion():
    print("Initiating automatic background sync to PostgreSQL...")
    ingestion.run_full_omnichannel_scan()

scheduler = BackgroundScheduler()
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
    try:
        ingestion.run_full_omnichannel_scan()
        return jsonify({"status": "success", "message": "Manual sync forced. All platforms securely vaulted in PostgreSQL."}), 200
    except Exception as e:
        return jsonify({"status": "error", "message": str(e)}), 500

@app.route('/history', methods=['GET'])
def get_history():
    try:
        conn = get_db_connection()
        # RealDictCursor converts PostgreSQL rows into JSON-ready dictionaries
        cursor = conn.cursor(cursor_factory=RealDictCursor)
        cursor.execute('SELECT source, title, raw_summary, url, image_url FROM history ORDER BY id DESC LIMIT 50')
        items = cursor.fetchall()
        
        cursor.close()
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
        cursor = conn.cursor(cursor_factory=RealDictCursor)
        cursor.execute('SELECT source, title, raw_summary FROM history ORDER BY id DESC LIMIT 20')
        items = cursor.fetchall()
        
        cursor.close()
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