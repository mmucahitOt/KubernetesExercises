#!/usr/bin/env bash
set -euo pipefail

# Configuration
PROJECT_ID="${GCP_PROJECT:-dwk-gke-475010}"
GSA_NAME="todo-backup-sa"
KSA_NAME="todo-backup-sa"
NAMESPACE="project"
BUCKET_NAME="todo-app-db-backup-bucket"
METHOD="${1:-key}"  # "key" or "workload-identity"

echo "Setting up GCS permissions for backup CronJob..."
echo "Method: ${METHOD}"
echo "Project: ${PROJECT_ID}"
echo "Bucket: ${BUCKET_NAME}"
echo ""

# Step 1: Create GCP Service Account
echo "📝 Creating GCP Service Account..."
gcloud iam service-accounts create "${GSA_NAME}" \
  --project="${PROJECT_ID}" \
  --display-name="Todo App Backup Service Account" \
  --description="Service account for todo app database backups" \
  2>/dev/null || echo "  ✓ Service account already exists"

# Step 2: Grant Storage permissions
echo "🔐 Granting Storage permissions..."
gcloud projects add-iam-policy-binding "${PROJECT_ID}" \
  --member="serviceAccount:${GSA_NAME}@${PROJECT_ID}.iam.gserviceaccount.com" \
  --role="roles/storage.objectCreator" \
  --condition=None \
  >/dev/null 2>&1 || echo "  ✓ Storage Object Creator role already granted"

gcloud projects add-iam-policy-binding "${PROJECT_ID}" \
  --member="serviceAccount:${GSA_NAME}@${PROJECT_ID}.iam.gserviceaccount.com" \
  --role="roles/storage.objectViewer" \
  --condition=None \
  >/dev/null 2>&1 || echo "  ✓ Storage Object Viewer role already granted"

if [[ "${METHOD}" == "key" ]]; then
  # Service Account Key Method
  echo ""
  echo "🔑 Setting up Service Account Key method..."
  
  # Create key
  KEY_FILE="backup-sa-key.json"
  echo "  Creating service account key..."
  gcloud iam service-accounts keys create "${KEY_FILE}" \
    --iam-account="${GSA_NAME}@${PROJECT_ID}.iam.gserviceaccount.com" \
    --project="${PROJECT_ID}"
  
  # Create Kubernetes Secret
  echo "  Creating Kubernetes Secret..."
  kubectl create secret generic backup-sa-key \
    --from-file=service-account.json="${KEY_FILE}" \
    --namespace="${NAMESPACE}" \
    --dry-run=client -o yaml | kubectl apply -f -
  
  # Clean up local key
  rm -f "${KEY_FILE}"
  echo "  ✓ Service Account Key method setup complete!"
  echo ""
  echo "⚠️  Remember to update the CronJob manifest to mount the secret:"
  echo "   See: todo_app_db_backup_cronjob/manifests/todo_app_db_backup_cronjob.yaml"
  
elif [[ "${METHOD}" == "workload-identity" ]]; then
  # Workload Identity Method
  echo ""
  echo "🔗 Setting up Workload Identity method..."
  
  # Enable Workload Identity on cluster
  echo "  Enabling Workload Identity on cluster..."
  gcloud container clusters update dwk-cluster \
    --zone=europe-west1-b \
    --workload-pool="${PROJECT_ID}.svc.id.goog" \
    --project="${PROJECT_ID}" || echo "  ⚠️  Workload Identity may already be enabled"
  
  # Create IAM policy binding
  echo "  Creating IAM policy binding..."
  gcloud iam service-accounts add-iam-policy-binding \
    "${GSA_NAME}@${PROJECT_ID}.iam.gserviceaccount.com" \
    --role roles/iam.workloadIdentityUser \
    --member "serviceAccount:${PROJECT_ID}.svc.id.goog[${NAMESPACE}/${KSA_NAME}]" \
    --project="${PROJECT_ID}" || echo "  ⚠️  Binding may already exist"
  
  echo "  ✓ Workload Identity setup complete!"
  echo ""
  echo "⚠️  Remember to update backup-serviceaccount.yaml with annotation:"
  echo "   iam.gke.io/gcp-service-account: ${GSA_NAME}@${PROJECT_ID}.iam.gserviceaccount.com"
fi

echo ""
echo "✅ Setup complete!"
echo ""
echo "Next steps:"
echo "1. Apply the updated manifests: kubectl apply -k todo_app/"
echo "2. Test the backup: kubectl create job --from=cronjob/todo-app-backup-cronjob test-backup -n ${NAMESPACE}"

