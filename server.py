import requests
from flask import Flask, jsonify

app = Flask(__name__)

@app.route('/')
def home():
    return jsonify({"message": "Graviton API is Live! The gravitational pull is active."})

@app.route('/trending', methods=['GET'])
def get_trending():
    # 1. Reach out to the public API to pull live data
    api_url = "https://api.spaceflightnewsapi.net/v4/articles/?limit=5"
    response = requests.get(api_url)
    
    # Check if the request was successful
    if response.status_code != 200:
        return jsonify({"error": "Failed to pull data from the web"}), 500

    raw_data = response.json()

    # 2. Data Analytics Pipeline: Clean and structure the chaotic raw data
    structured_news = []
    for article in raw_data.get('results', []):
        structured_news.append({
            "title": article.get("title"),
            "source": article.get("news_site"),
            "url": article.get("url"),
            "raw_summary": article.get("summary"), # We will pass this to our AI later!
            "published_at": article.get("published_at")
        })

    # 3. Return the clean, centralized data to the user
    return jsonify({
        "status": "success",
        "article_count": len(structured_news),
        "data": structured_news
    })

if __name__ == '__main__':
    app.run(debug=True)