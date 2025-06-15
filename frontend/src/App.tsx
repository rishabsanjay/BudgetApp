import React, { useState } from 'react';
import axios from 'axios';

interface Transaction {
  [key: string]: any;
}

function App() {
  const [transactions, setTransactions] = useState<Transaction[]>([]);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);

  const handleFileUpload = async (event: React.ChangeEvent<HTMLInputElement>) => {
    const file = event.target.files?.[0];
    if (!file) return;

    const formData = new FormData();
    formData.append('file', file);

    setLoading(true);
    setError(null);

    try {
      const response = await axios.post('http://localhost:8000/api/upload', formData, {
        headers: {
          'Content-Type': 'multipart/form-data',
        },
      });
      setTransactions(response.data.transactions);
    } catch (err) {
      setError('Error uploading file. Please try again.');
      console.error(err);
    } finally {
      setLoading(false);
    }
  };

  return (
    <div className="min-h-screen bg-gray-100 py-6 flex flex-col justify-center sm:py-12">
      <div className="relative py-3 sm:max-w-xl sm:mx-auto">
        <div className="relative px-4 py-10 bg-white shadow-lg sm:rounded-3xl sm:p-20">
          <div className="max-w-md mx-auto">
            <div className="divide-y divide-gray-200">
              <div className="py-8 text-base leading-6 space-y-4 text-gray-700 sm:text-lg sm:leading-7">
                <h1 className="text-3xl font-bold text-center mb-8">Budget App</h1>
                
                <div className="mb-8">
                  <label className="block text-sm font-medium text-gray-700">
                    Upload Transaction File (CSV or Excel)
                  </label>
                  <input
                    type="file"
                    accept=".csv,.xlsx,.xls"
                    onChange={handleFileUpload}
                    className="mt-1 block w-full"
                    disabled={loading}
                  />
                </div>

                {loading && (
                  <div className="text-center">
                    <div className="animate-spin rounded-full h-8 w-8 border-b-2 border-gray-900 mx-auto"></div>
                    <p className="mt-2">Loading...</p>
                  </div>
                )}

                {error && (
                  <div className="text-red-500 text-center">
                    {error}
                  </div>
                )}

                {transactions.length > 0 && (
                  <div className="mt-8">
                    <h2 className="text-xl font-semibold mb-4">Transactions</h2>
                    <div className="overflow-x-auto">
                      <table className="min-w-full divide-y divide-gray-200">
                        <thead className="bg-gray-50">
                          <tr>
                            {Object.keys(transactions[0]).map((header) => (
                              <th
                                key={header}
                                className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider"
                              >
                                {header}
                              </th>
                            ))}
                          </tr>
                        </thead>
                        <tbody className="bg-white divide-y divide-gray-200">
                          {transactions.map((transaction, index) => (
                            <tr key={index}>
                              {Object.values(transaction).map((value, i) => (
                                <td
                                  key={i}
                                  className="px-6 py-4 whitespace-nowrap text-sm text-gray-500"
                                >
                                  {String(value)}
                                </td>
                              ))}
                            </tr>
                          ))}
                        </tbody>
                      </table>
                    </div>
                  </div>
                )}
              </div>
            </div>
          </div>
        </div>
      </div>
    </div>
  );
}

export default App;
