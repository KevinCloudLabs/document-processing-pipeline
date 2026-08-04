resource "aws_s3_bucket" "uploads" {
  bucket = "${var.project_name}-uploads-v38"
  force_destroy = true
  tags = { Name = "${var.project_name}-uploads"}
}

resource "aws_sqs_queue" "document_queue" {
  name = "${var.project_name}-queue"
  visibility_timeout_seconds = 300
  tags = { Name = "${var.project_name}-queue"}
}

resource "aws_sqs_queue_policy" "allow_s3" {
  queue_url = aws_sqs_queue.document_queue.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "s3.amazonaws.com" }
      Action    = "sqs:SendMessage"
      Resource  = aws_sqs_queue.document_queue.arn
      Condition = {
        ArnLike = {
          "aws:SourceArn" = aws_s3_bucket.uploads.arn
        }
      }
    }]
  })
}

resource "aws_s3_bucket_notification" "upload_notification" {
  bucket = aws_s3_bucket.uploads.id

  queue {
    queue_arn     = aws_sqs_queue.document_queue.arn
    events        = ["s3:ObjectCreated:Put"]
    filter_suffix = ".pdf"
  }

  depends_on = [aws_sqs_queue_policy.allow_s3]
}