/* IAC Assertions & Debug helpers */

export function iacAssert(m, x, msg) {
  if (x) {
    return;
  }

  console.error(`ASSERTION FAILURE: ${msg}`);
  iacAssertDumpModel(m);
  if (m.assert.failed == false) {
    alert(
      "IAC has encountered an Assertion Failure - a bug has been filed automatically. Further popups have been disabled."
    );
  }

  m.assert.failed = true;
}

export function iacAssertEq(m, x, y, msg) {
  if (x == y) {
    return;
  }

  iacAssert(m, false, `x != y, x = ${x}, y = ${y}, msg = ${msg}"`);
}

function iacAssertDumpModel(model) {}
