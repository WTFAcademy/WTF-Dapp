ethereum
  .request({ method: "eth_chainId" })
  .then((chainId) => {
    console.log(`hexadecimal string: ${chainId}`);
    console.log(`decimal number: ${parseInt(chainId, 16)}`);
  })
  .catch((error) => {
    console.error(`Error fetching chainId: ${error.code}: ${error.message}`);
  });
