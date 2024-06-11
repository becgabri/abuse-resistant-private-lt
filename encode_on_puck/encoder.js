var cCode = E.compiledC(`
// int evalPoly(int, int, int, int)
// int testEvalPoly()
// void initEvalPolyEach(int, int)
// void evalPolyEach(int)
// int getEachResult()
// int testEvalPolyEach()


unsigned long eachX;
unsigned long eachFieldSize;
unsigned long eachResult;

unsigned long customModulus(unsigned long high, unsigned long low, unsigned long divisor) {
        if (divisor == 0) {
            // Handle division by zero
            return -1;
        }
    
        // Perform modulus with bit-shifting for the high part
        unsigned long highRemainder = high % divisor;
    
        // Calculate the combined remainder using the low part
        unsigned long combinedRemainder = highRemainder;
        for (int i = 31; i >= 0; i--) {
            combinedRemainder = ((combinedRemainder << 1) | ((low >> i) & 1)) % divisor;
        }
    
        return combinedRemainder;
    }

unsigned long fieldMultiply(unsigned long a, unsigned long b, unsigned long fieldSize) {
    unsigned long long value = ((unsigned long long) a) * ((unsigned long long)b);
    
    unsigned long vHigh = (unsigned long)((value >> 32) & 0xFFFFFFFF);
    unsigned long vLow = (unsigned long)(value & 0xFFFFFFFF);

    return customModulus(vHigh, vLow, fieldSize);
}


unsigned long fieldAdd(unsigned long a, unsigned long b, unsigned long fieldSize) {
    unsigned long long value = ((unsigned long long) a) + ((unsigned long long)b);
    
    unsigned long vHigh = (unsigned long)((value >> 32) & 0xFFFFFFFF);
    unsigned long vLow = (unsigned long)(value & 0xFFFFFFFF);

    return customModulus(vHigh, vLow, fieldSize);
}

unsigned long evalPoly(int len, unsigned long *coefs, unsigned long x, unsigned long fieldSize) {
    unsigned long result = 0;

    while (len--) {
        unsigned long product = fieldMultiply(result, x, fieldSize);
        result = fieldAdd(product, *coefs, fieldSize);
        coefs++;
    }

    return result;
}

unsigned long testEvalPoly() {
    unsigned long x = 9185512;
    unsigned long fieldSize = 16777213;
    unsigned long coefs[8] = {2979233, 10470635, 374671, 14374125, 2342823, 7621171, 11221543, 7969321};

    return evalPoly(8, coefs, x, fieldSize);
}

void initEvalPolyEach(unsigned long x, unsigned long fieldSize) {
    eachX = x;
    eachFieldSize = fieldSize;
    eachResult = 0;
}

void evalPolyEach(unsigned long coef) {
    unsigned long product = fieldMultiply(eachResult, eachX, eachFieldSize);
    eachResult = fieldAdd(product, coef, eachFieldSize);
}

unsigned long getEachResult() {
    return eachResult;
}

unsigned long testEvalPolyEach() {
    unsigned long x = 9185512;
    unsigned long fieldSize = 16777213;
    unsigned long coefs[8] = {2979233, 10470635, 374671, 14374125, 2342823, 7621171, 11221543, 7969321};

    initEvalPolyEach(x, fieldSize);

    for (int i = 0; i < 8; i ++) {
        evalPolyEach(coefs[i]);
    }

    return getEachResult();
}
`);

function getRandomInt(max, shift) {
  let result = -1;
  while (result < 0 || result >= max) {
    result = E.hwRand() >>> shift;
  }
  return result;
}

function generatePolynomials(fieldSize, c, degree, id, shift) {
  let polys = [];
  for (let i = 0; i < c; i++) {
    let coefs = new Uint32Array(degree);
    for (var j in coefs) {
      coefs[j] = getRandomInt(fieldSize, shift);
    }
    coefs[coefs.length - 1] = id[i];
    polys.push(coefs);
  }
  return polys;
}

function benchmarkGenerateSecretShare(iterations, fieldSize, c, degree, shift) {
  let totalTime = 0;

  let evals = new Uint32Array(c);

  for (let i = 0; i < iterations; i++) {
    console.log(i + 1, "/", iterations);
    // Generate ID and Polynomials
    console.log("Generating Polys");
    let id = new Uint32Array(c);
    for (let j = 0; j < c; j++) id[j] = getRandomInt(fieldSize, shift);
    let polys = generatePolynomials(fieldSize, c, degree, id, shift);

    console.log("Evaluating Polys");
    let start = new Date();
    for (let j = 0; j < c; j++) {
      let poly = polys[j];
      let addr = E.getAddressOf(poly, true);
      let x = getRandomInt(fieldSize, shift);

      if (!addr) {
        console.log("Not a Flat String");
        cCode.initEvalPolyEach(x, fieldSize);
        poly.forEach(cCode.evalPolyEach);
        evals[j] = cCode.getEachResult();
      } else {
        evals[j] = cCode.evalPoly(poly.length, addr, x, fieldSize);
      }
    }
    let end = new Date();

    totalTime += end - start;
  }
  console.log(
    "Average time",
    totalTime / iterations,
    "over",
    iterations,
    "iterations"
  );
}

function benchmarkGeneratePolynomials(iterations, fieldSize, c, degree, shift) {
  let totalTime = 0;

  for (let i = 0; i < iterations; i++) {
    console.log(i + 1, "/", iterations);
    let id = new Uint32Array(c);
    for (let j = 0; j < c; j++) id[j] = getRandomInt(fieldSize, shift);

    let start = new Date();
    let polys = generatePolynomials(fieldSize, c, degree, id, shift);
    let end = new Date();

    totalTime += end - start;

    console.log(
      "Average time",
      totalTime / (i + 1),
      "over",
      i + 1,
      "iterations"
    );
  }
}

// 4 sec AE
let fieldSize = 4194301;
let shift = 32 - 22;
let degree = 591;
let c = 10;

// 60 sec AE
// let fieldSize = 16777213;
// let shift = 32 - 24;
// let degree = 41;
// let c = 9;

let iterations = 1000;

setTimeout(function () {
  benchmarkGeneratePolynomials(iterations, fieldSize, c, degree, shift);
}, 1000);
