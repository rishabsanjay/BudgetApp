# Main entry point for Railway deployment
import os
from flask import Flask, request, jsonify
import requests
from datetime import datetime, timedelta

app = Flask(__name__)

# Environment variable configuration
PLAID_CLIENT_ID = os.environ.get('PLAID_CLIENT_ID', '6851fb214123ce0022d42dc0')
PLAID_SECRET = os.environ.get('PLAID_SECRET', 'bdcc4a47dc8ea23362bb67bbca335d')
PLAID_ENV = os.environ.get('PLAID_ENV', 'sandbox')  # sandbox, development, or production

# ADD: Link token creation endpoint
@app.route('/create_link_token', methods=['POST'])
def create_link_token():
    try:
        print("Creating link token...")
        
        response = requests.post(
            f'https://{PLAID_ENV}.plaid.com/link/token/create',
            headers={'Content-Type': 'application/json'},
            json={
                'client_id': PLAID_CLIENT_ID,
                'secret': PLAID_SECRET,
                'client_name': 'Budget App',
                'country_codes': ['US'],
                'language': 'en',
                'user': {
                    'client_user_id': 'budget_app_user_' + str(int(datetime.now().timestamp()))
                },
                'products': ['transactions']
            }
        )
        
        result = response.json()
        print(f"Link token response: {result}")
        
        if 'link_token' not in result:
            print(f"Error creating link token: {result}")
            return jsonify({'error': 'Failed to create link token'}), 400
            
        return jsonify({'link_token': result['link_token']})
    except Exception as e:
        print(f"Error in create_link_token: {e}")
        return jsonify({'error': str(e)}), 500

@app.route('/exchange_token', methods=['POST'])
def exchange_token():
    try:
        public_token = request.json['public_token']
        print(f"Received public token: {public_token}")
        
        # Exchange public token for access token
        response = requests.post(
            f'https://{PLAID_ENV}.plaid.com/item/public_token/exchange',
            headers={'Content-Type': 'application/json'},
            json={
                'client_id': PLAID_CLIENT_ID,
                'secret': PLAID_SECRET,
                'public_token': public_token
            }
        )
        
        result = response.json()
        print(f"Exchange response: {result}")
        
        if 'access_token' not in result:
            print(f"Error in exchange: {result}")
            return jsonify({'error': 'Failed to exchange token'}), 400
            
        return jsonify({'access_token': result['access_token']})
    except Exception as e:
        print(f"Error in exchange_token: {e}")
        return jsonify({'error': str(e)}), 500

@app.route('/get_transactions', methods=['GET'])
def get_transactions():
    try:
        access_token = request.args.get('access_token')
        print(f"Fetching transactions for access token: {access_token}")
        
        # Use a wider date range to catch more transactions
        end_date = datetime.now().date()
        start_date = end_date - timedelta(days=730)  # 2 years back
        
        print(f"Requesting transactions from {start_date} to {end_date}")
        
        # Get accounts first to see what we're working with
        accounts_response = requests.post(
            f'https://{PLAID_ENV}.plaid.com/accounts/get',
            headers={'Content-Type': 'application/json'},
            json={
                'client_id': PLAID_CLIENT_ID,
                'secret': PLAID_SECRET,
                'access_token': access_token
            }
        )
        
        accounts_result = accounts_response.json()
        print(f"Accounts: {accounts_result}")
        
        # Get transactions
        response = requests.post(
            f'https://{PLAID_ENV}.plaid.com/transactions/get',
            headers={'Content-Type': 'application/json'},
            json={
                'client_id': PLAID_CLIENT_ID,
                'secret': PLAID_SECRET,
                'access_token': access_token,
                'start_date': str(start_date),
                'end_date': str(end_date)
            }
        )
        
        result = response.json()
        
        if 'error' in result:
            print(f"Plaid API error: {result}")
            return jsonify({'error': result['error']}), 400
            
        transactions = result.get('transactions', [])
        total_transactions = result.get('total_transactions', 0)
        
        print(f"Plaid returned {len(transactions)} transactions out of {total_transactions} total")
        if transactions:
            print(f"Sample transaction: {transactions[0]}")
        else:
            print("No transactions returned from Plaid")
            print(f"Full API response: {result}")
        
        # Format transactions for the iOS app
        formatted_transactions = []
        for transaction in transactions:
            formatted_transactions.append({
                'transaction_id': transaction.get('transaction_id'),
                'date': str(transaction.get('date')),
                'name': transaction.get('name'),
                'amount': transaction.get('amount'),
                'category': transaction.get('category', []),
                'account_id': transaction.get('account_id')
            })
        
        print(f"Returning {len(formatted_transactions)} formatted transactions")
        return jsonify({
            'transactions': formatted_transactions,
            'total_transactions': total_transactions,
            'accounts': accounts_result.get('accounts', [])
        })
        
    except Exception as e:
        print(f"Error in get_transactions: {e}")
        return jsonify({'error': str(e)}), 500

# Health check endpoint
@app.route('/health', methods=['GET'])
def health_check():
    return jsonify({'status': 'healthy', 'service': 'budget-app-backend'})

# CORS headers for testing
@app.after_request
def after_request(response):
    response.headers.add('Access-Control-Allow-Origin', '*')
    response.headers.add('Access-Control-Allow-Headers', 'Content-Type,Authorization')
    response.headers.add('Access-Control-Allow-Methods', 'GET,PUT,POST,DELETE,OPTIONS')
    return response

if __name__ == '__main__':
    # Use environment port for deployment
    port = int(os.environ.get('PORT', 5000))
    app.run(debug=False, host='0.0.0.0', port=port)
