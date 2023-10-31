import {
  noEventLabel,
  DUEDATELABEL,
  ExpirationLABEL,
  REQUESTORCOMPLETEDSTATUS,
} from "./helpers/constants";
import {
  convertUTCToLocalDateString,
  validateDateString,
} from "./helpers/dateUtils";
import { isNullOrUndefined } from "./helpers/util";

const concatStr = (lstr, rstr) => {
  return `${lstr}: ${rstr}`;
};

const getExpirationEventInfo = (upcomingExpiration) => {
  if (isNullOrUndefined(upcomingExpiration)) return noEventLabel;

  return concatStr(ExpirationLABEL, upcomingExpiration);
};

const getDueEventInfo = (upcomingDue) => {
  if (isNullOrUndefined(upcomingDue)) return noEventLabel;

  return concatStr(DUEDATELABEL, upcomingDue);
};

export const getNextStatusForContacts = (upcomingDue, upcomingExpiration) => {
  if (isNullOrUndefined(upcomingDue) && isNullOrUndefined(upcomingExpiration))
    return noEventLabel;
  if (isNullOrUndefined(upcomingDue))
    return concatStr(ExpirationLABEL, upcomingExpiration);
  if (isNullOrUndefined(upcomingExpiration))
    return concatStr(DUEDATELABEL, upcomingDue);

  const isDueNearest = upcomingDue <= upcomingExpiration;
  return isDueNearest
    ? concatStr(DUEDATELABEL, upcomingDue)
    : concatStr(ExpirationLABEL, upcomingExpiration);
};

export const getNextEventForStatus = (data) => {
  const {
    state: { status },
    next_event_metadata: { nearest_due_date, nearest_expiration_date },
  } = data;
  const upcomingLocalExpiration = validateAndConvertToDateString(
    nearest_expiration_date,
    convertUTCToLocalDateString
  );
  const upcomingLocalDue = validateAndConvertToDateString(
    nearest_due_date,
    convertUTCToLocalDateString
  );

  switch (status) {
    case 0:
    case 1:
      return getDueEventInfo(upcomingLocalDue);
    case 2:
    case 7:
      return getNextStatusForContacts(
        upcomingLocalDue,
        upcomingLocalExpiration
      );
    case 3:
    case 4:
    case 5:
    case 6:
      return getExpirationEventInfo(upcomingLocalExpiration);
    default:
      return noEventLabel;
  }
};

export const getNextStatusForTemplates = (req, checklist) => {
  const checklistDue = checklist?.due_date?.date?.checklistDue;
  const tmlStatus = req?.state?.status?.tmlStatus;
  if (tmlStatus === REQUESTORCOMPLETEDSTATUS) return noEventLabel;
  return getDueEventInfo(
    validateAndConvertToDateString(checklistDue, convertUTCToLocalDateString)
  );
};

export const getNextStatusForReq = (req, checklist) => {
  const next_event_metadata = {
    nearest_due_date: validateAndConvertToDateString(
      checklist.due_date?.date,
      convertUTCToLocalDateString
    ),
    nearest_expiration_date: validateAndConvertToDateString(
      req.expiration_info?.value,
      convertUTCToLocalDateString
    ),
  };
  const reqWithMetadata = { ...req, next_event_metadata };
  return getNextEventForStatus(reqWithMetadata);
};

export const validateAndConvertToDateString = (
  dateString,
  dateConversionCallback
) => {
  if (validateDateString(dateString)) return dateConversionCallback(dateString);
  return dateString;
};
