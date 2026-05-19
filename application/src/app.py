"""Sample HTTP service used to demonstrate the CI/CD evolution patterns.

The application is intentionally tiny: the goal is to give the build, test, and
deploy scripts something real to operate on, not to demonstrate Flask itself.
"""

import os
import socket

from flask import Flask, jsonify

VERSION = os.environ.get("APP_VERSION", "0.0.0-dev")
ENVIRONMENT = os.environ.get("APP_ENVIRONMENT", "local")
GREETING = os.environ.get("APP_GREETING", "hello")

app = Flask(__name__)


@app.route("/")
def index():
    return jsonify(
        message=GREETING,
        environment=ENVIRONMENT,
        version=VERSION,
        host=socket.gethostname(),
    )


@app.route("/healthz")
def healthz():
    return jsonify(status="ok"), 200


@app.route("/readyz")
def readyz():
    return jsonify(status="ready"), 200


if __name__ == "__main__":
    app.run(host="0.0.0.0", port=int(os.environ.get("PORT", "8080")))
