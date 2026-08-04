import os
import json
from flask import Flask, jsonify
import psycopg2
import psycopg2.extras

app = Flask(__name__)

DB_HOST = os.environ['DB_HOST']
DB_NAME = os.environ.get('DB_NAME', 'dpp')
DB_USER = os.environ.get('DB_USER', 'postgres')
DB_PASSWORD = os.environ['DB_PASSWORD']


def get_db_connection():
    return psycopg2.connect(
        host=DB_HOST,
        dbname=DB_NAME,
        user=DB_USER,
        password=DB_PASSWORD,
        cursor_factory=psycopg2.extras.RealDictCursor
    )


@app.route('/health', methods=['GET'])
def health():
    return jsonify({'status': 'healthy', 'service': 'api'})


@app.route('/documents', methods=['GET'])
def list_documents():
    conn = get_db_connection()
    cur = conn.cursor()
    cur.execute(
        """
        SELECT id, file_name, status, uploaded_at, processed_at
        FROM documents
        ORDER BY uploaded_at DESC
        """
    )
    documents = cur.fetchall()
    cur.close()
    conn.close()

    return jsonify({
        'count': len(documents),
        'documents': [dict(doc) for doc in documents]
    })


@app.route('/documents/<int:document_id>', methods=['GET'])
def get_document(document_id):
    conn = get_db_connection()
    cur = conn.cursor()
    cur.execute(
        """
        SELECT id, file_name, status, extracted_text, tables_json,
               key_value_pairs, uploaded_at, processed_at
        FROM documents
        WHERE id = %s
        """,
        (document_id,)
    )
    document = cur.fetchone()
    cur.close()
    conn.close()

    if not document:
        return jsonify({'error': 'Document not found'}), 404

    return jsonify(dict(document))


@app.route('/documents/<int:document_id>/text', methods=['GET'])
def get_document_text(document_id):
    conn = get_db_connection()
    cur = conn.cursor()
    cur.execute(
        "SELECT id, file_name, extracted_text FROM documents WHERE id = %s",
        (document_id,)
    )
    document = cur.fetchone()
    cur.close()
    conn.close()

    if not document:
        return jsonify({'error': 'Document not found'}), 404

    return jsonify(dict(document))


@app.route('/documents/<int:document_id>/tables', methods=['GET'])
def get_document_tables(document_id):
    conn = get_db_connection()
    cur = conn.cursor()
    cur.execute(
        "SELECT id, file_name, tables_json FROM documents WHERE id = %s",
        (document_id,)
    )
    document = cur.fetchone()
    cur.close()
    conn.close()

    if not document:
        return jsonify({'error': 'Document not found'}), 404

    return jsonify(dict(document))


if __name__ == '__main__':
    app.run(host='0.0.0.0', port=8000)
