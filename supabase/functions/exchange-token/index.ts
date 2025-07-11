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
    const { public_token } = await req.json()
    
    if (!public_token) {
      return new Response(
        JSON.stringify({
          error: 'Missing public_token in request body',
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
    
    console.log('Exchanging public token for access token...')
    
    const response = await client.itemPublicTokenExchange({
      public_token,
    })

    console.log('Token exchange successful')
    
    return new Response(
      JSON.stringify({
        access_token: response.data.access_token,
        item_id: response.data.item_id,
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
    console.error('Error exchanging token:', error)
    
    return new Response(
      JSON.stringify({
        error: 'Failed to exchange token',
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