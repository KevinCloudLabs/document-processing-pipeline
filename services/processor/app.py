import json
import os
import time
import boto3
import psycopg2
from datetime import datetime
from urllib.parse import unquote_plus

SQS_QUEUE_URL = os.environ['SQS_QUEUE_URL']
AWS_REGION = os.environ.get('AWS_REGION', 'us-west-1')

DB_HOST = os.environ['DB_HOST']
DB_NAME = os.environ.get('DB_NAME', 'dpp')
DB_USER = os.environ.get('DB_USER', 'postgres')
DB_PASSWORD = os.environ['DB_PASSWORD']

sqs = boto3.client('sqs', region_name=AWS_REGION)
textract = boto3.client('textract', region_name=AWS_REGION)
s3 = boto3.client('s3', region_name=AWS_REGION)


def get_db_connection():
    return psycopg2.connect(
        host=DB_HOST,
        dbname=DB_NAME,
        user=DB_USER,
        password=DB_PASSWORD
    )


def insert_pending_document(file_name, s3_key):
    conn = get_db_connection()
    cur = conn.cursor()
    cur.execute(
        """
        INSERT INTO documents (file_name, s3_key, status)
        VALUES (%s, %s, 'processing')
        ON CONFLICT DO NOTHING
        RETURNING id
        """,
        (file_name, s3_key)
    )
    result = cur.fetchone()
    conn.commit()
    cur.close()
    conn.close()
    return result[0] if result else None


def update_document_results(s3_key, extracted_text, tables_json, key_value_pairs):
    conn = get_db_connection()
    cur = conn.cursor()
    cur.execute(
        """
        UPDATE documents
        SET status = 'completed',
            extracted_text = %s,
            tables_json = %s,
            key_value_pairs = %s,
            processed_at = %s
        WHERE s3_key = %s
        """,
        (extracted_text, json.dumps(tables_json), json.dumps(key_value_pairs),
         datetime.utcnow(), s3_key)
    )
    conn.commit()
    cur.close()
    conn.close()


def mark_document_failed(s3_key, error_message):
    conn = get_db_connection()
    cur = conn.cursor()
    cur.execute(
        """
        UPDATE documents
        SET status = 'failed',
            extracted_text = %s
        WHERE s3_key = %s
        """,
        (f"Error: {error_message}", s3_key)
    )
    conn.commit()
    cur.close()
    conn.close()


def extract_text_and_data(bucket, key):
    response = textract.analyze_document(
        Document={'S3Object': {'Bucket': bucket, 'Name': key}},
        FeatureTypes=['TABLES', 'FORMS']
    )

    extracted_text = []
    tables = []
    key_value_pairs = {}

    blocks = response['Blocks']
    block_map = {block['Id']: block for block in blocks}

    for block in blocks:
        if block['BlockType'] == 'LINE':
            extracted_text.append(block.get('Text', ''))

    for block in blocks:
        if block['BlockType'] == 'KEY_VALUE_SET' and block.get('EntityTypes') == ['KEY']:
            key_text = get_text_from_relationships(block, block_map)
            value_block = get_value_block(block, block_map)
            value_text = get_text_from_relationships(value_block, block_map) if value_block else ''
            if key_text:
                key_value_pairs[key_text] = value_text

    for block in blocks:
        if block['BlockType'] == 'TABLE':
            table_data = extract_table(block, block_map)
            tables.append(table_data)

    return '\n'.join(extracted_text), tables, key_value_pairs


def get_text_from_relationships(block, block_map):
    text = []
    if 'Relationships' in block:
        for rel in block['Relationships']:
            if rel['Type'] == 'CHILD':
                for child_id in rel['Ids']:
                    child = block_map.get(child_id)
                    if child and child['BlockType'] == 'WORD':
                        text.append(child.get('Text', ''))
    return ' '.join(text)


def get_value_block(key_block, block_map):
    if 'Relationships' in key_block:
        for rel in key_block['Relationships']:
            if rel['Type'] == 'VALUE':
                for value_id in rel['Ids']:
                    return block_map.get(value_id)
    return None


def extract_table(table_block, block_map):
    rows = {}
    if 'Relationships' in table_block:
        for rel in table_block['Relationships']:
            if rel['Type'] == 'CHILD':
                for cell_id in rel['Ids']:
                    cell = block_map.get(cell_id)
                    if cell and cell['BlockType'] == 'CELL':
                        row_index = cell['RowIndex']
                        col_index = cell['ColumnIndex']
                        cell_text = get_text_from_relationships(cell, block_map)
                        if row_index not in rows:
                            rows[row_index] = {}
                        rows[row_index][col_index] = cell_text

    table_rows = []
    for row_index in sorted(rows.keys()):
        row = rows[row_index]
        table_rows.append([row[col] for col in sorted(row.keys())])

    return table_rows


def process_message(message):
    body = json.loads(message['Body'])

    if body.get('Event') == 's3:TestEvent':
        print('Skipping S3 test event')
        return True

    for record in body.get('Records', []):
        bucket = record['s3']['bucket']['name']
        key = unquote_plus(record['s3']['object']['key'])
        file_name = key.split('/')[-1]

        print(f'Processing document: {key}')

        try:
            insert_pending_document(file_name, key)
            extracted_text, tables, key_value_pairs = extract_text_and_data(bucket, key)
            update_document_results(key, extracted_text, tables, key_value_pairs)
            print(f'Successfully processed: {key}')
        except Exception as e:
            print(f'Error processing {key}: {str(e)}')
            mark_document_failed(key, str(e))

    return True


def poll_queue():
    print('Worker started. Polling SQS queue...')

    while True:
        response = sqs.receive_message(
            QueueUrl=SQS_QUEUE_URL,
            MaxNumberOfMessages=1,
            WaitTimeSeconds=20
        )

        messages = response.get('Messages', [])

        if not messages:
            print('No messages in queue. Waiting...')
            continue

        for message in messages:
            success = process_message(message)

            if success:
                sqs.delete_message(
                    QueueUrl=SQS_QUEUE_URL,
                    ReceiptHandle=message['ReceiptHandle']
                )
                print('Message processed and deleted from queue')


if __name__ == '__main__':
    poll_queue()