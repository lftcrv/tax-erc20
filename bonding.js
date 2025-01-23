import { create, all } from "mathjs";
const math = create(all);

const MANTISSA_1E9 = math.bignumber("1000000000");
const SCALING_FACTOR = math.bignumber("1000000000");
const STEP = math.bignumber("1000000"); // Example step value

function calculatePrice(supply, baseNormalized, exponentNormalized) {
  // Normalize supply (assuming 6 decimals)
  const supplyFixed = math.divide(supply, math.pow(10, 6));

  // Calculate y_calc = supply/step * exponent
  const yCalc = math.multiply(
    math.divide(supplyFixed, STEP),
    exponentNormalized
  );

  // Calculate exp(y_calc)
  const expResult = math.exp(yCalc);

  // Calculate final price with scaling
  const priceFixed = math.multiply(baseNormalized, expResult);
  const priceScaled = math.round(
    math.multiply(math.multiply(priceFixed, MANTISSA_1E9), MANTISSA_1E9)
  );

  // Return price in u256 format (18 decimals)
  return math.divide(priceScaled, SCALING_FACTOR).toString();
}

// Test values
const supply = math.bignumber("1000000000000"); // 1M tokens with 6 decimals
const baseNormalized = math.bignumber("0.00001");
const exponentNormalized = math.bignumber("0.0001");

console.log(
  "Price for 1M tokens:",
  calculatePrice(supply, baseNormalized, exponentNormalized)
);

// Test multiple supply points
const testSupplies = [
  "100000000", // 0.1 tokens
  "1000000000", // 1 token
  "10000000000", // 10 tokens
  "100000000000", // 100 tokens
  "1000000000000", // 1000 tokens
];

testSupplies.forEach((supply) => {
  console.log(
    `Supply: ${math.divide(supply, math.pow(10, 6))} tokens ->`,
    `Price: ${calculatePrice(
      math.bignumber(supply),
      baseNormalized,
      exponentNormalized
    )}`
  );
});
