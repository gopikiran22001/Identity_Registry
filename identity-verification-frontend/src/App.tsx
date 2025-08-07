import { useState } from 'react';

const MODULE_ADDRESS = 'fb14cdb419be0c25d7fedc872a0de109cc71e30617f7430712a7409844a0c39e';
const MODULE_NAME = 'identity';
const FUNCTION_NAME = 'register_identity';
const VIEW_FUNCTION = 'get_identity';

declare global {
  interface Window {
    aptos: any;
  }
}

function App() {
  const [account, setAccount] = useState<string | null>(null);
  const [identity, setIdentity] = useState<{
    name: string;
    verified: boolean;
    timestamp: number;
    verifier: string;
  } | null>(null);

  const connectWallet = async () => {
    if (!window.aptos) {
      alert('Petra Wallet not found');
      return;
    }
    try {
      const res = await window.aptos.connect();
      setAccount(res.address);
      fetchIdentity(res.address);
    } catch (err) {
      console.error(err);
    }
  };

  const registerIdentity = async () => {
    if (!window.aptos || !account) return;

    const name = prompt('Enter your name to register:');
    if (!name || name.trim().length === 0) {
      alert('Name is required.');
      return;
    }

    try {
      const payload = {
        type: "entry_function_payload",
        function: `${MODULE_ADDRESS}::${MODULE_NAME}::${FUNCTION_NAME}`,
        type_arguments: [],
        arguments: [name],
      };

      const response = await window.aptos.signAndSubmitTransaction(payload);

      alert(`Transaction submitted! Hash: ${response.hash}`);
      setTimeout(() => fetchIdentity(account), 5000);
    } catch (error: any) {
      console.error('Registration failed:', error);
      alert(`Transaction failed: ${error.message || 'Unknown error'}`);
    }
  };

  const fetchIdentity = async (address: string) => {
    try {
      const response = await fetch('https://fullnode.devnet.aptoslabs.com/v1/view', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          function: `${MODULE_ADDRESS}::${MODULE_NAME}::${VIEW_FUNCTION}`,
          type_arguments: [],
          arguments: [address],
        }),
      });

      const json = await response.json();

      if (json.error) throw new Error(json.error);

      const [name, verified, timestamp, verifier] = json[0];

      setIdentity({
        name,
        verified,
        timestamp: parseInt(timestamp),
        verifier,
      });
    } catch (err) {
      console.error(err);
      setIdentity(null);
    }
  };

  return (
    <div style={{ padding: 20, fontFamily: 'Arial' }}>
      <h1>Aptos Identity DApp</h1>

      {!account ? (
        <button onClick={connectWallet}>Connect Wallet</button>
      ) : (
        <>
          <p><strong>Connected as:</strong> {account}</p>
          <button onClick={registerIdentity}>Register Identity</button>
          <button onClick={() => fetchIdentity(account)}>Refresh Identity</button>

          {identity ? (
            <div style={{ marginTop: 20 }}>
              <p><strong>Name:</strong> {identity.name}</p>
              <p><strong>Verified:</strong> {identity.verified ? '✅ Yes' : '❌ No'}</p>
              <p><strong>Verified By:</strong> {identity.verifier}</p>
              <p><strong>Timestamp:</strong> {new Date(identity.timestamp * 1000).toLocaleString()}</p>
            </div>
          ) : (
            <p>No identity registered.</p>
          )}
        </>
      )}
    </div>
  );
}

export default App;