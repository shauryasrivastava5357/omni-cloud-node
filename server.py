import os
import json
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
# Configure Gemini (Matching your ai_model naming convention)
genai.configure(api_key=os.environ.get("GEMINI_API_KEY"))
ai_model = genai.GenerativeModel('gemini-pro')

# Permanent Cloud Database Connection
def get_db_connection():
    db_url = os.environ.get("DATABASE_URL")
    # Automatically connects to the Render PostgreSQL instance
    conn = psycopg2.connect(db_url)
    return conn


# --- API ROUTES ---
@app.route('/trending', methods=['GET'])
def get_trending():
    try:
        ingestion.run_full_omnichannel_scan()
        return jsonify({"status": "success", "message": "Manual scan complete"}), 200
    except Exception as e:
        return jsonify({"status": "error", "message": str(e)}), 500


@app.route('/history', methods=['GET'])
def get_history():
    try:
        conn = get_db_connection()
        cursor = conn.cursor(cursor_factory=RealDictCursor)
        
        # RESTORED: Pulling url and image_url for the UI, safely avoiding timestamp
        cursor.execute('SELECT source, title, raw_summary, url, image_url FROM history')
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
        
        if not user_question:
            return jsonify({"error": "No question provided"}), 400
            
        # YOUR CUSTOM RAG PIPELINE
        conn = get_db_connection()
        cursor = conn.cursor(cursor_factory=RealDictCursor)
        cursor.execute('SELECT source, title, raw_summary FROM history')
        items = cursor.fetchall()
        
        cursor.close()
        conn.close()
        
        context = "\n".join([f"[{item['source']}] {item['title']} - {item['raw_summary']}" for item in items])
        prompt = f"Context from the universal vault:\n{context}\n\nUser Question: {user_question}"
        
        response = ai_model.generate_content(prompt)
        return jsonify({"graviton_response": response.text}), 200
        
    except Exception as e:
        return jsonify({"error": str(e)}), 500


# --- AUTONOMOUS BACKGROUND SCHEDULER ---
def scheduled_ingestion():
    print("Initiating automatic background sync to PostgreSQL...")
    ingestion.run_full_omnichannel_scan()

scheduler = BackgroundScheduler()
# Running every 6 hours to build continuous price history
scheduler.add_job(func=scheduled_ingestion, trigger="interval", hours=6)
scheduler.start()

# Ensures the scheduler shuts down cleanly if the server reboots
atexit.register(lambda: scheduler.shutdown())


# --- SERVER START ---
if __name__ == '__main__':
    port = int(os.environ.get('PORT', 10000))
    app.run(host='0.0.0.0', port=port)