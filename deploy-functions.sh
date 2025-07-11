#!/bin/bash

# Deploy Supabase Edge Functions
echo "Deploying Supabase Edge Functions..."

# Deploy create-link-token function
echo "Deploying create-link-token function..."
supabase functions deploy create-link-token

# Deploy exchange-token function
echo "Deploying exchange-token function..."
supabase functions deploy exchange-token

# Deploy get-transactions function
echo "Deploying get-transactions function..."
supabase functions deploy get-transactions

echo "All functions deployed successfully!"
echo ""
echo "Don't forget to set your environment variables:"
echo "supabase secrets set PLAID_CLIENT_ID=your_client_id"
echo "supabase secrets set PLAID_SECRET=your_secret_key"
echo "supabase secrets set PLAID_ENV=sandbox"