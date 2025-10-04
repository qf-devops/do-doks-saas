import os
import time
import redis
from flask import Flask, jsonify

app = Flask(__name__)
redis_host = os.getenv("REDIS_HOST", "redis")
redis_port = int(os.getenv("REDIS_PORT", "6379"))
r = redis.Redis(host=redis_host, port=redis_port)

def get_hit_count():
    retries = 5
    while True:
        try:
            return r.incr("hits")
        except redis.exceptions.ConnectionError as exc:
            if retries == 0:
                raise exc
            retries -= 1
            time.sleep(0.5)

@app.route("/")
def hello():
    count = get_hit_count()
    return f"Hello from DOKS! I have been seen {count} times.\n"

@app.route("/healthz")
def health():
    return jsonify(status="ok")

if __name__ == "__main__":
    app.run(host="0.0.0.0", port=5000)
