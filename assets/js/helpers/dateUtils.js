import dayjs from "dayjs";
import relativeTime from "dayjs/plugin/relativeTime";
import { isNullOrUndefined } from "./util";
dayjs.extend(relativeTime);

const DATE_FORMAT_YYYY_MM_DD = "YYYY-MM-DD";
const DATE_FORMAT_YYYY_MM_DD_TIME = "YYYY-MM-DD HH:mm:ss";
const HUMAN_DATE_FORMAT_YYYY_MM_DD = "ddd, DD MMM YYYY";

export function subtractDate(date, period) {
  let from = date;
  const { range, offset } = period;
  switch (range) {
    case "day":
      from = from.subtract(offset, "days");
      break;
    case "weeks":
      from = from.subtract(offset, "weeks");
      break;
    case "month":
      from = from.subtract(offset, "month");
      break;
    case "year":
      from = from.subtract(offset, "year");
      break;
  }
  return from;
}

export function getDateObject(dateString) {
  return dayjs(dateString, DATE_FORMAT_YYYY_MM_DD);
}

export function getDateString(
  momentDate,
  displayFormat = DATE_FORMAT_YYYY_MM_DD
) {
  return momentDate.format(displayFormat);
}

export function getDateStringWithTime(
  momentDate,
  displayFormat = DATE_FORMAT_YYYY_MM_DD_TIME
) {
  return momentDate.format(displayFormat);
}

// Quick fix [#8781]
export function iacGetDateString(
  momentDate,
  displayFormat = DATE_FORMAT_YYYY_MM_DD
) {
  return momentDate.format(displayFormat);
}

/**
 * @description returns relative days from the current date
 * @param {string} dateString
 * @returns {string} "x days ago"
 */
export function getXdaysFrom(dateString) {
  return dayjs().to(getDateObject(dateString));
}

/**
 * @description convert user date to UTC date
 * @param {Date} date
 * @returns {Date} UTC Date
 */
function toUtcFormat(date) {
  return new Date(
    Date.UTC(date.getUTCFullYear(), date.getUTCMonth(), date.getUTCDate())
  );
}

export function getutcFormatDateString(dateString) {
  const utcDateFormat = toUtcFormat(new Date(dateString));
  return utcDateFormat.toISOString().split("T")[0];
}

export function calculateDateRanges(period) {
  const currentDate = new Date();
  const fromDate = subtractDate(getDateObject(currentDate), period);
  return {
    from: getDateString(fromDate),
    to: getDateString(getDateObject(currentDate)),
  };
}

export function todayDate() {
  let now = new Date(),
    today,
    month,
    day,
    year;

  (month = "" + (now.getMonth() + 1)),
    (day = "" + now.getDate()),
    (year = now.getFullYear());

  if (month.length < 2) month = "0" + month;
  if (day.length < 2) day = "0" + day;

  today = [year, month, day].join("-");
  return today;
}

export function addDates(date, offset) {
  const newDate = getDateObject(date).add(offset, "day");
  return getDateString(newDate, HUMAN_DATE_FORMAT_YYYY_MM_DD);
}

export function getDaysDiff(startdate, enddate) {
  return getDateObject(enddate).diff(getDateObject(startdate), "day") + 1;
}

/**
 *
 * @param {String} utcDateString UTC Date String "2022-07-18T23:53:10Z"
 * @returns {String} user datetime "2022-07-19"
 */
export function convertUTCToLocalDateString(utcDateString) {
  if (isNullOrUndefined(utcDateString)) {
    return undefined;
  }
  if (!validateDateString(utcDateString)) throw "Not a valid date string";
  const utcDateTime = utcDateString;
  const localDateTimeString = new Date(utcDateTime);
  return getDateString(getDateObject(localDateTimeString));
}

export function convertUTCToLocalDateStringWithTime(utcDateString) {
  if (isNullOrUndefined(utcDateString)) {
    return undefined;
  }
  if (!validateDateString(utcDateString)) throw "Not a valid date string";
  const utcDateTime = utcDateString;
  const localDateTimeString = new Date(utcDateTime);
  return getDateStringWithTime(getDateObject(localDateTimeString));
}

export const getTomorrowDate = () => {
  const tomorrow = dayjs().add(1, "days");
  return getDateString(tomorrow, DATE_FORMAT_YYYY_MM_DD);
};

/**
 * @description validate given string is a valid date string
 * @param {string} dateString
 * @returns {Boolean} True if the arg is a valid date string
 */
export const validateDateString = (dateString) => {
  const isDateStringType = Date.parse(dateString);
  return isNaN(isDateStringType) === false;
};

export function isInThePast(date) {
  const today = new Date();
  today.setHours(0, 0, 0, 0);

  return date < today;
}
