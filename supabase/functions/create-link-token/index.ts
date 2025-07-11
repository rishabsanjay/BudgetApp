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
    console.log('Creating link token for Plaid...')
    
    const response = await client.linkTokenCreate({
      user: {
        client_user_id: 'user_' + Date.now().toString(),
      },
      client_name: 'BudgetApp',
      products: ['transactions'],
      country_codes: ['US'],
      language: 'en',
      redirect_uri: undefined,
      android_package_name: undefined,
      webhook: undefined,
    })

    console.log('Link token created successfully')
    
    return new Response(
      JSON.stringify({
        link_token: response.data.link_token,
        expiration: response.data.expiration,
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
    console.error('Error creating link token:', error)
    
    return new Response(
      JSON.stringify({
        error: 'Failed to create link token',
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