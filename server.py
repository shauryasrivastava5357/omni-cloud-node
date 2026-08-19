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
target_model = os.environ.get("GEMINI_MODEL_VERSION", "gemini-1.5-flash")
ai_model = genai.GenerativeModel(target_model)

# 3. Database Connection
def get_db_connection():
    conn = sqlite3.connect('vault.db')
    conn.row_factory = sqlite3.Row
    return conn

# 4. Core Application Routes
@app.route('/')
def index():
    return render_template('index.html')

@app.route('/manifest.json')
def manifest():
    return send_from_directory('static', 'manifest.json', mimetype='application/manifest+json')

# 5. Intelligence Engine Routes
@app.route('/trending', methods=['GET'])
def get_trending():
    try:
        # Triggers the master switch in ingestion.py
        ingestion.run_full_omnichannel_scan()
        return jsonify({"status": "success", "message": "Omnichannel vault sync complete. E-Commerce, YouTube, and Global News data secured."}), 200
    except Exception as e:
        return jsonify({"status": "error", "message": str(e)}), 500

@app.route('/history', methods=['GET'])
def get_history():
    try:
        conn = get_db_connection()
        # Grabs the latest 20 items from the vault for the Live Radar feed
        items = conn.execute('SELECT source, title, raw_summary, url FROM history ORDER BY id DESC LIMIT 20').fetchall()
        conn.close()
        return jsonify([dict(ix) for ix in items]), 200
    except Exception as e:
        return jsonify({"status": "error", "message": str(e)}), 500

@app.route('/summarize', methods=['GET'])
def summarize_vault():
    try:
        conn = get_db_connection()
        items = conn.execute('SELECT source, title FROM history ORDER BY id DESC LIMIT 15').fetchall()
        conn.close()

        if not items:
            return jsonify({"ai_macro_analysis": "The intelligence vault is currently empty. Run Ingestion first."}), 200

        context = "\n".join([f"- [{item['source']}] {item['title']}" for item in items])
        prompt = f"Analyze these current trending topics and provide a highly professional, brief executive macro-trend briefing:\n{context}"
        
        response = ai_model.generate_content(prompt)
        return jsonify({"ai_macro_analysis": response.text}), 200
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
        prompt = f"Context from the intelligence vault:\n{context}\n\nUser Question: {user_question}\nAnswer the user confidently as Graviton, an advanced omnichannel intelligence assistant."
        
        response = ai_model.generate_content(prompt)
        return jsonify({"graviton_response": response.text}), 200
    except Exception as e:
        return jsonify({"status": "error", "message": str(e)}), 500

# 6. Server Execution
if __name__ == '__main__':
    # Binds to the port Render assigns automatically
    port = int(os.environ.get('PORT', 5000))
    app.run(host='0.0.0.0', port=port)