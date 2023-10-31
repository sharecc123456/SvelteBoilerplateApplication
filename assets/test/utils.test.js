import { invertObject } from "../js/helpers/util";

test("swap keys and values of Object", () => {
  const obj = { a: 1, b: 2 };
  const result = invertObject(obj);
  expect(result).toStrictEqual({ 1: "a", 2: "b" });
});

test("swap empty Object", () => {
  const obj = {};
  const result = invertObject(obj);
  expect(result).toStrictEqual({});
});
