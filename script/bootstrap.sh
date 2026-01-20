#!/bin/bash

# ==========================================
# Terraform Backend Bootstrap Script
# ==========================================

# 変数定義
AWS_REGION="ap-northeast-1"
BUCKET_NAME="tfstate-saito-lab-202601"
TABLE_NAME="tf-lock-saito-lab-202601"

echo "Using Region: $AWS_REGION"
echo "Bucket Name : $BUCKET_NAME"
echo "Table Name  : $TABLE_NAME"
echo "------------------------------------------"

# -----------------------------------------------------------
# 1) S3バケット作成
# -----------------------------------------------------------
# Terraformの「状態（State）」を保存する場所です。
if aws s3api head-bucket --bucket "$BUCKET_NAME" 2>/dev/null; then
    echo "✅ S3 bucket '$BUCKET_NAME' already exists. Skipping creation."
else
    echo "🚀 Creating S3 bucket..."
    aws s3api create-bucket \
      --bucket "$BUCKET_NAME" \
      --region "$AWS_REGION" \
      --create-bucket-configuration LocationConstraint="$AWS_REGION"
    echo "✅ S3 bucket created."
fi

# -----------------------------------------------------------
# 2) バージョニング有効化
# -----------------------------------------------------------
# 誤ってStateファイルを削除や上書きしてしまった場合に、
# 過去の状態に戻せるように履歴管理機能（Versioning）をONにします。
echo "⚙️  Enabling versioning..."
aws s3api put-bucket-versioning \
  --bucket "$BUCKET_NAME" \
  --versioning-configuration Status=Enabled

# -----------------------------------------------------------
# 3) デフォルト暗号化 (SSE-S3)
# -----------------------------------------------------------
# 【重要】StateファイルにはDBパスワードなどが「平文」で保存されることがあります。
# 万が一の漏洩に備え、S3保存時に自動的に暗号化（AES256）される設定を入れます。
# ※SSE-S3はAWSが鍵管理を行うため、追加料金なし・管理不要で最も手軽です。
echo "🔒 Setting default encryption..."
aws s3api put-bucket-encryption \
  --bucket "$BUCKET_NAME" \
  --server-side-encryption-configuration '{
    "Rules": [{"ApplyServerSideEncryptionByDefault": {"SSEAlgorithm": "AES256"}}]
  }'

# -----------------------------------------------------------
# 4) DynamoDB (State Lock用)
# -----------------------------------------------------------
# 【重要】複数人で同時に terraform apply を実行してしまうとStateが破損します。
# 実行中にこのテーブルに「使用中」の書き込み（Lock）を行うことで、
# 事故（デッドロック/競合）を防ぐための排他制御用テーブルです。
if aws dynamodb describe-table --table-name "$TABLE_NAME" --region "$AWS_REGION" >/dev/null 2>&1; then
    echo "✅ DynamoDB table '$TABLE_NAME' already exists. Skipping creation."
else
    echo "🚀 Creating DynamoDB table..."
    aws dynamodb create-table \
      --table-name "$TABLE_NAME" \
      --attribute-definitions AttributeName=LockID,AttributeType=S \
      --key-schema AttributeName=LockID,KeyType=HASH \
      --billing-mode PAY_PER_REQUEST \
      --region "$AWS_REGION"
    echo "✅ DynamoDB table created."
fi

echo "------------------------------------------"
echo "🎉 Bootstrap completed successfully!"
