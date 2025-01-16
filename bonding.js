function simulateBondingCurve(exponent, startingPrice, precision = 0.1) {
  let totalEthSpent = 5;
  const step = 0.1;
  const max_supply = 8e8;
  const pool_amount = 2e8;
  function getPrice(mcap) {
    return startingPrice * Math.exp(mcap * exponent);
  }

  const priceAt0 = getPrice(0);
  while (totalEthSpent < 10) {
    totalEthSpent += step;
    const price = getPrice(totalEthSpent);
    const avPrice = price / 2;
    const ts = a;
  }

  console.log("Début de la simulation...");
  console.log(
    `Exponent : ${exponent}, Prix initial : ${startingPrice}, Précision : ${precision} ETH`
  );
  console.log("---------------------------------------------------");

  console.log("---------------------------------------------------");
  console.log("Simulation terminée.");
  console.log(`Total ETH dépensé : ${totalEthSpent.toFixed(2)}`);
  console.log(`Total Tokens émis : ${totalTokensMinted}`);
  const poolPrice = totalEthSpent / 2e8;
  console.log(`\nPool price: ${poolPrice.toFixed(10)}`);
  const priceDiff = poolPrice - currentPrice;
  const percentDiff = (priceDiff / startingPrice) * 100;
  console.log(
    `Price diff : ${priceDiff.toFixed(10)} -> ${percentDiff.toFixed(1)}%`
  );
}

// Exemple d'utilisation :
simulateBondingCurve(0.0000000003, 0.01);
