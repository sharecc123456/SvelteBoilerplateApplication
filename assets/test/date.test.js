import {
  getutcFormatDateString,
  getTomorrowDate,
} from "../js/helpers/dateUtils";

test("convert user date to utc date", () => {
  expect(getutcFormatDateString("2022-01-01")).toBe("2022-01-01");
});

test("is date tomorrow", () => {
  const tomorrow = getTomorrowDate();
  const today = new Date();
  today.setDate(today.getDate() + 1);
  const dateTom = today.toISOString().split("T")[0];
  expect(tomorrow).toBe(dateTom);
});
