import "jsr:@supabase/functions-js/edge-runtime.d.ts"
import { Configuration, PlaidApi, PlaidEnvironments } from "npm:plaid@14.0.0"

const PLAID_CLIENT_ID = Deno.env.get('PLAID_CLIENT_ID')
const PLAID_SECRET = Deno.env.get('PLAID_SECRET')
const PLAID_ENV = Deno.env.get('PLAID_ENV') || 'sandbox'

if (!PLAID_CLIENT_ID || !PLAID_SECRET) {
  throw new Error('Missing required environment variables: PLAID_CLIENT_ID, PLAID_SECRET')
}

const configuration = new Configuration({
  basePath: PlaidEnvironments[PLAID_ENV as keyof typeof PlaidEnvironments],
  baseOptions: {
    headers: {
      'PLAID-CLIENT-ID': PLAID_CLIENT_ID,
      'PLAID-SECRET': PLAID_SECRET,
    },
  },
})

const client = new PlaidApi(configuration)

Deno.serve(async (req) => {
  try {
    const { access_token } = await req.json()
    
    if (!access_token) {
      return new Response(
        JSON.stringify({
          error: 'Missing access_token in request body',
        }),
        {
          status: 400,
          headers: {
            'Content-Type': 'application/json',
            'Access-Control-Allow-Origin': '*',
            'Access-Control-Allow-Methods': 'POST',
            'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
          },
        }
      )
    }
    
    console.log('Fetching transactions from Plaid...')
    
    // Calculate date range (last 30 days)
    const endDate = new Date()
    const startDate = new Date()
    startDate.setDate(endDate.getDate() - 30)
    
    const response = await client.transactionsGet({
      access_token,
      start_date: startDate.toISOString().split('T')[0],
      end_date: endDate.toISOString().split('T')[0],
    })

    console.log(`Fetched ${response.data.transactions.length} transactions`)
    
    // Transform transactions to match our app's format
    const transformedTransactions = response.data.transactions.map(transaction => ({
      transaction_id: transaction.transaction_id,
      account_id: transaction.account_id,
      amount: transaction.amount,
      date: transaction.date,
      name: transaction.name,
      merchant_name: transaction.merchant_name,
      category: transaction.category,
      subcategory: transaction.subcategory,
      type: transaction.transaction_type,
      pending: transaction.pending,
      account_owner: transaction.account_owner,
    }))
    
    return new Response(
      JSON.stringify({
        transactions: transformedTransactions,
        total_transactions: response.data.total_transactions,
      }),
      {
        headers: {
          'Content-Type': 'application/json',
          'Access-Control-Allow-Origin': '*',
          'Access-Control-Allow-Methods': 'POST',
          'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
        },
      }
    )
  } catch (error) {
    console.error('Error fetching transactions:', error)
    
    return new Response(
      JSON.stringify({
        error: 'Failed to fetch transactions',
        details: error.message,
      }),
      {
        status: 500,
        headers: {
          'Content-Type': 'application/json',
          'Access-Control-Allow-Origin': '*',
          'Access-Control-Allow-Methods': 'POST',
          'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
        },
      }
    )
  }
})