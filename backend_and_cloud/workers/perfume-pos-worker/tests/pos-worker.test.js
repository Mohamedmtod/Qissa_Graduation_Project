import test from "node:test";
import assert from "node:assert/strict";

import { fromFirestoreValue, toFirestoreValue, decodeFirestoreDocument, toFirestoreFields } from "../src/firestore/codec.js";
import { isAdminByClaims, isCashierByClaims } from "../src/auth/admin.js";
import { validateSalePayload, validateItemQuantity, validateSessionOwnership } from "../src/sales/validateSalePayload.js";

test("Firestore codec maps values correctly", () => {
  const rawFields = {
    name: { stringValue: "Dior Sauvage" },
    price: { doubleValue: 120.5 },
    stock: { integerValue: "45" },
    isSellable: { booleanValue: true },
    tags: { arrayValue: { values: [{ stringValue: "fresh" }, { stringValue: "spicy" }] } },
    attributes: {
      mapValue: {
        fields: {
          gender: { stringValue: "men" },
        },
      },
    },
  };

  const decoded = decodeFirestoreDocument({ fields: rawFields });

  assert.equal(decoded.name, "Dior Sauvage");
  assert.equal(decoded.price, 120.5);
  assert.equal(decoded.stock, 45);
  assert.equal(decoded.isSellable, true);
  assert.deepEqual(decoded.tags, ["fresh", "spicy"]);
  assert.deepEqual(decoded.attributes, { gender: "men" });

  const encoded = toFirestoreFields(decoded);
  assert.equal(encoded.name.stringValue, "Dior Sauvage");
  assert.equal(encoded.price.doubleValue, 120.5);
  assert.equal(encoded.stock.integerValue, "45");
  assert.equal(encoded.isSellable.booleanValue, true);
  assert.deepEqual(encoded.tags.arrayValue.values, [{ stringValue: "fresh" }, { stringValue: "spicy" }]);
  assert.equal(encoded.attributes.mapValue.fields.gender.stringValue, "men");
});

test("Auth role mapping flags correct privileges", () => {
  assert.equal(isAdminByClaims({ admin: true }), true);
  assert.equal(isAdminByClaims({ role: "admin" }), true);
  assert.equal(isAdminByClaims({ role: "owner" }), true);
  assert.equal(isAdminByClaims({ role: "cashier" }), false);
  assert.equal(isAdminByClaims({ role: "user" }), false);

  assert.equal(isCashierByClaims({ admin: true }), true);
  assert.equal(isCashierByClaims({ role: "admin" }), true);
  assert.equal(isCashierByClaims({ role: "owner" }), true);
  assert.equal(isCashierByClaims({ role: "cashier" }), true);
  assert.equal(isCashierByClaims({ role: "user" }), false);
});

// ---- P0/P1 Validation helpers ----

test("validateSalePayload — rejects invalid paymentMethod", () => {
  assert.throws(
    () => validateSalePayload({ idempotencyKey: "k", sessionId: "s", items: [1], paymentMethod: "crypto" }),
    (err) => { assert.equal(err.status, 400); assert.match(err.message, /paymentMethod/); return true; }
  );
  assert.throws(
    () => validateSalePayload({ idempotencyKey: "k", sessionId: "s", items: [1], paymentMethod: "" }),
    (err) => { assert.equal(err.status, 400); return true; }
  );
});

test("validateSalePayload — rejects missing required params", () => {
  assert.throws(
    () => validateSalePayload({ idempotencyKey: "", sessionId: "s", items: [1], paymentMethod: "cash" }),
    (err) => { assert.equal(err.status, 400); return true; }
  );
  assert.throws(
    () => validateSalePayload({ idempotencyKey: "k", sessionId: "s", items: [], paymentMethod: "cash" }),
    (err) => { assert.equal(err.status, 400); return true; }
  );
});

test("validateSalePayload — accepts valid payload", () => {
  assert.doesNotThrow(() =>
    validateSalePayload({ idempotencyKey: "key123", sessionId: "sess1", items: [{ productId: "p1" }], paymentMethod: "cash" })
  );
  assert.doesNotThrow(() =>
    validateSalePayload({ idempotencyKey: "key123", sessionId: "sess1", items: [{ productId: "p1" }], paymentMethod: "card" })
  );
});

test("validateItemQuantity — rejects negative quantity", () => {
  assert.throws(
    () => validateItemQuantity("prod1", -1),
    (err) => { assert.equal(err.status, 400); assert.match(err.message, /quantity/); return true; }
  );
});

test("validateItemQuantity — rejects zero quantity", () => {
  assert.throws(
    () => validateItemQuantity("prod1", 0),
    (err) => { assert.equal(err.status, 400); return true; }
  );
});

test("validateItemQuantity — rejects non-numeric quantity", () => {
  assert.throws(
    () => validateItemQuantity("prod1", "abc"),
    (err) => { assert.equal(err.status, 400); return true; }
  );
});

test("validateItemQuantity — accepts valid positive quantity", () => {
  assert.doesNotThrow(() => validateItemQuantity("prod1", 3));
  assert.doesNotThrow(() => validateItemQuantity("prod1", 0.5));
  assert.equal(validateItemQuantity("prod1", "2"), 2);
});

test("validateSessionOwnership — rejects mismatched cashier", () => {
  assert.throws(
    () => validateSessionOwnership({ openedBy: "cashier-A" }, "cashier-B", "session-1"),
    (err) => { assert.equal(err.status, 403); assert.match(err.message, /does not belong/); return true; }
  );
});

test("validateSessionOwnership — accepts matching cashier", () => {
  assert.doesNotThrow(() =>
    validateSessionOwnership({ openedBy: "cashier-A" }, "cashier-A", "session-1")
  );
});

