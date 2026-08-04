output "s3_bucket_name" {
  value = aws_s3_bucket.uploads.id
}

output "s3_bucket_arn" {
  value = aws_s3_bucket.uploads.arn
}

output "sqs_queue_url" {
  value = aws_sqs_queue.document_queue.id
}

output "sqs_queue_arn" {
  value = aws_sqs_queue.document_queue.arn
}