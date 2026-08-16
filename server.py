from flask import Flask, jsonify
import random
import sqlite3
import datetime
import math

app = Flask(__name__)
DB_NAME = "telemetry.db"

def init_db():
    conn = sqlite3.connect(DB_NAME)
    cursor = conn.cursor()
    cursor.execute('''
        CREATE TABLE IF NOT EXISTS server_logs (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            timestamp TEXT,
            node TEXT,
            status TEXT,
            cpu_load INTEGER,
            latency INTEGER,
            active_streams INTEGER
        )
    ''')
    conn.commit()
    conn.close()

@app.route('/api/telemetry', methods=['GET'])
def get_telemetry():
    cpu = random.randint(10, 85)
    latency = random.randint(15, 45)
    streams = random.randint(100, 999)
    now = datetime.datetime.now().strftime("%Y-%m-%d %H:%M:%S")
    
    conn = sqlite3.connect(DB_NAME)
    cursor = conn.cursor()
    cursor.execute('''
        INSERT INTO server_logs (timestamp, node, status, cpu_load, latency, active_streams)
        VALUES (?, ?, ?, ?, ?, ?)
    ''', (now, 'Node 01 (Mumbai-A)', 'ONLINE', cpu, latency, streams))
    conn.commit()
    conn.close()

    return jsonify({
        'node': 'Node 01 (Mumbai-A)',
        'status': 'ONLINE',
        'cpu_load': cpu,
        'latency': latency,
        'active_streams': streams,
        'timestamp': now
    })

@app.route('/api/history', methods=['GET'])
def get_history():
    conn = sqlite3.connect(DB_NAME)
    cursor = conn.cursor()
    cursor.execute('SELECT timestamp, cpu_load, latency FROM server_logs ORDER BY id DESC LIMIT 5')
    rows = cursor.fetchall()
    conn.close()
    
    return jsonify([{'timestamp': r[0], 'cpu_load': r[1], 'latency': r[2]} for r in rows])

# --- NEW: THE AI/ML ANALYTICS BRAIN ---
@app.route('/api/analyze', methods=['GET'])
def analyze_data():
    conn = sqlite3.connect(DB_NAME)
    cursor = conn.cursor()
    # Fetch all historical CPU loads
    cursor.execute('SELECT cpu_load FROM server_logs')
    rows = cursor.fetchall()
    conn.close()
    
    if len(rows) < 2:
        return jsonify({"error": "Not enough data to run ML analysis."}), 400
        
    cpu_loads = [r[0] for r in rows]
    latest_load = cpu_loads[-1]
    
    # 1. Calculate Mean (Average)
    mean_cpu = sum(cpu_loads) / len(cpu_loads)
    
    # 2. Calculate Standard Deviation (Volatility)
    variance = sum((x - mean_cpu) ** 2 for x in cpu_loads) / len(cpu_loads)
    std_dev = math.sqrt(variance)
    
    # 3. Anomaly Detection Logic (Spikes > 1.5 standard deviations from the norm)
    anomaly_threshold = mean_cpu + (1.5 * std_dev)
    is_anomaly = latest_load > anomaly_threshold
    
    return jsonify({
        "total_records_analyzed": len(cpu_loads),
        "historical_mean": round(mean_cpu, 2),
        "standard_deviation": round(std_dev, 2),
        "latest_cpu": latest_load,
        "anomaly_detected": is_anomaly
    })

if __name__ == '__main__':
    init_db() 
    app.run(host='0.0.0.0', port=5000)