export const isMobile = () => {
  return /Android|webOS|iPhone|iPad|iPod|BlackBerry|IEMobile|Opera Mini/i.test(
    navigator.userAgent
  );
};

// NaN is the only value that is not equal to itself
export const isNaN = (x) => {
  return x != x;
};

export const isAndroidMobile = () => {
  return /Android|BlackBerry|IEMobile|Opera Mini/i.test(navigator.userAgent);
};
export const capitalizeFirstLetter = (string) => {
  if (isNullOrUndefined(string)) {
    return "";
  }
  return string.charAt(0).toUpperCase() + string.slice(1);
};

export const isBrowserTypeSafari = () => {
  return (
    /constructor/i.test(window.HTMLElement) ||
    (function (p) {
      return p.toString() === "[object SafariRemoteNotification]";
    })(
      !window["safari"] ||
        (typeof safari !== "undefined" && safari.pushNotification)
    )
  );
};

export const getSearchParams = () => {
  if (location.hash.includes("?")) {
    const result = decodeURIComponent(location.hash.split("?")[1])
      .split("&")
      .map((item) => {
        const tmp = item.split("=");
        let dict_ = {};
        dict_[tmp[0]] = tmp[1];
        return dict_;
      });
    return result;
  }
  return [];
};

export const searchParamObject = () => {
  const searchParams = getSearchParams();
  const searchParamsObj = searchParams.reduce((pv, cv) => {
    return { ...pv, ...cv };
  }, {});
  return searchParamsObj;
};

export function convertTime(date, time) {
  let LocalTime = new Date(`${date.replace(/-/g, "/")} ${time} UTC`);

  let hours = LocalTime.getHours();
  let minutes = LocalTime.getMinutes();
  let ampm = hours >= 12 ? "PM" : "AM";

  hours = hours % 12;
  hours = hours ? hours : 12; // the hour '0' should be '12'
  minutes = minutes < 10 ? "0" + minutes : minutes;
  let strTime = "[" + hours + ":" + minutes + " " + ampm + "]";

  return strTime;
}

export function convertDateTime(date, time) {
  let LocalTime = new Date(`${date.replace(/-/g, "/")} ${time} UTC`);
  let dateObj = new Date(`${date.replace(/-/g, "/")}`);

  let hours = LocalTime.getHours();
  let minutes = LocalTime.getMinutes();
  let ampm = hours >= 12 ? "PM" : "AM";

  let _day = dateObj.getDate();
  let _month = dateObj.getMonth() + 1;
  let _year = dateObj.getFullYear();

  hours = hours % 12;
  hours = hours ? hours : 12; // the hour '0' should be '12'
  minutes = minutes < 10 ? "0" + minutes : minutes;
  let strTime = hours + ":" + minutes + " " + ampm;

  return `${_year}-${_month}-${_day} ${strTime}`;
}
export function getOnlyDate(date) {
  let dateObj = new Date(`${date.replace(/-/g, "/")}`);
  let _day = dateObj.getDate();
  let _month = dateObj.getMonth() + 1;
  let _year = dateObj.getFullYear();
  return `${_year}-${_month}-${_day}`;
}

export const createQueryParams = (params) => {
  return Object.keys(params).reduce((acc, key) => {
    const val = params[key];
    if (val != undefined && val != "")
      acc += acc ? `&${key}=${val}` : `?${key}=${val}`;
    return acc;
  }, "");
};

export const debounce = function (fn, d = 500) {
  let timer;
  return function () {
    if (timer) clearTimeout(timer);
    timer = setTimeout(fn, d);
  };
};

// export const debounce = (func, timeout = 300) => {
//   let timer;
//   return (...args) => {
//     clearTimeout(timer);
//     timer = setTimeout(() => { func.apply(this, args); }, timeout);
//   };
// }

// https://gist.github.com/cjaoude/fd9910626629b53c4d25 --(RFC 2822) format
// case insensitive regex pattern `/regexp/i`
// for case sensitive remove i from the pattern
export const VALIDEMAILFORMAT =
  /(?:[a-z0-9!#$%&'*+/=?^_`{|}~-]+(?:\.[a-z0-9!#$%&'*+/=?^_`{|}~-]+)*|"(?:[\x01-\x08\x0b\x0c\x0e-\x1f\x21\x23-\x5b\x5d-\x7f]|\\[\x01-\x09\x0b\x0c\x0e-\x7f])*")@(?:(?:[a-z0-9](?:[a-z0-9-]*[a-z0-9])?\.)+[a-z0-9](?:[a-z0-9-]*[a-z0-9])?|\[(?:(?:25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.){3}(?:25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?|[a-z0-9-]*[a-z0-9]:(?:[\x01-\x08\x0b\x0c\x0e-\x1f\x21-\x5a\x53-\x7f]|\\[\x01-\x09\x0b\x0c\x0e-\x7f])+)\])/i;
export const VALIDURLFORMAT =
  /^(?:(?:https?|ftp):\/\/)?(?:(?!(?:10|127)(?:\.\d{1,3}){3})(?!(?:169\.254|192\.168)(?:\.\d{1,3}){2})(?!172\.(?:1[6-9]|2\d|3[0-1])(?:\.\d{1,3}){2})(?:[1-9]\d?|1\d\d|2[01]\d|22[0-3])(?:\.(?:1?\d{1,2}|2[0-4]\d|25[0-5])){2}(?:\.(?:[1-9]\d?|1\d\d|2[0-4]\d|25[0-4]))|(?:(?:[a-z\u00a1-\uffff0-9]-*)*[a-z\u00a1-\uffff0-9]+)(?:\.(?:[a-z\u00a1-\uffff0-9]-*)*[a-z\u00a1-\uffff0-9]+)*(?:\.(?:[a-z\u00a1-\uffff]{2,})))(?::\d{2,5})?(?:\/\S*)?$/;

export function requestorDashboardStatus(status) {
  switch (status) {
    case 0:
      return "Open";
    case 1:
      return "In Progress";
    case 2:
      return "Ready for review";
    case 3:
      return "Returned for updates";
    case 4:
      return "Completed";
    case 5:
    case 6:
      return "Unavailable";
    case 7:
      return "Partially Completed";
    case 9:
      return "Auto Removed";
    case 10:
      return "Manually Removed";
    default:
      return "UNKNOWN";
  }
}

export function isNullOrUndefined(data) {
  if (data === undefined || data === null) return true;
  return false;
}

const DOCUMENTTAGCSS = {
  SENSITIVETAGCSS: {
    "background-color": "gray",
    color: "#fff",
    "margin-right": "4px",
  },
  CUSTOMTAGS: {
    "background-color": "#242526",
    color: "#fff",
    "margin-right": "4px",
  },
};

export function getCSSStyleTag(_type) {
  return cssVarStyles(DOCUMENTTAGCSS["CUSTOMTAGS"]);
}

function cssVarStyles(styles) {
  return Object.entries(styles)
    .map(([key, value]) => `${key}:${value}`)
    .join(";");
}

export function isUrl(str) {
  if (str.trim() === "") return true;
  let str2 = str.trim().toLowerCase();
  if (VALIDURLFORMAT.test(str2)) {
    return true;
  } else {
    return false;
  }
}

export const getValidUrlLink = (url) => {
  if (url === "") {
    return "";
  }
  const defaultProtocol = "https://";
  const httpProtocol = "http://";
  if (url.includes(defaultProtocol) || url.includes(httpProtocol)) return url;
  return `${defaultProtocol}${url}`;
};

export function saveCSV(csvData, filename) {
  const csvContent = "data:text/csv;charset=utf-8," + csvData;
  const encodedUri = encodeURI(csvContent);
  const link = document.createElement("a");
  link.setAttribute("href", encodedUri);
  link.setAttribute("download", filename);
  document.body.appendChild(link); // Required for FF
  link.click();
  document.body.removeChild(link);
}

export function savePDF(pdf_path, filename) {
  const link = document.createElement("a");
  link.setAttribute("href", pdf_path + `?dispName=${filename}`);
  link.setAttribute("download", filename);
  document.body.appendChild(link); // Required for FF
  link.click();
  document.body.removeChild(link);
}

export function getJsDateString(date = new Date()) {
  return date.toISOString().split(".")[0];
}

export async function postExperimentalHack(ticket_id, data) {
  console.log(`postExperimentalHack(${ticket_id}, XXX)`);
  let res = await fetch(`/n/api/v1/hack/${ticket_id}`, {
    method: "POST",
    credentials: "include",
    headers: {
      "Content-Type": "application/json",
    },
    body: JSON.stringify(data),
  });
  return res;
}

export function hackValidFor(ticket, unique_id) {
  // console.log(`hackValidFor(${ticket}, ${unique_id})`);
  return window.__boilerplate_features.includes(
    `experiment_${ticket}_${unique_id}`
  );
}

export function range(start, end) {
  return Array(end - start + 1)
    .fill()
    .map((_, idx) => start + idx);
}

export const incrementCount = (currentCount, maxValue, incrementStep = 1) => {
  if (currentCount + incrementStep >= maxValue) {
    return maxValue;
  }
  return currentCount + incrementStep;
};

export const decrementCount = (currentCount, minValue, decrementStep = 1) => {
  if (currentCount - decrementStep <= minValue) {
    return minValue;
  }
  return currentCount - decrementStep;
};

export const csvDownloader = (csv, filename = "file.csv") => {
  var blob = new Blob(["\ufeff", csv]);
  fileDownloader(blob, filename);
};

export const fileDownloader = (blob, filename) => {
  var url = URL.createObjectURL(blob);
  var downloadLink = document.createElement("a");
  downloadLink.href = url;
  downloadLink.download = filename;
  document.body.appendChild(downloadLink);
  downloadLink.click();
  document.body.removeChild(downloadLink);
};

export const setLocalStorage = (key, val) => {
  const stringifiedVal = JSON.stringify(val);
  localStorage.setItem(key, stringifiedVal);
};

export const getLocalStorage = (key) => {
  const stored = localStorage.getItem(key);
  return stored == null ? undefined : JSON.parse(stored);
};

export const invertObject = (obj) => {
  return Object.fromEntries(Object.entries(obj).map(([k, v]) => [v, k]));
};

export function isValidFormFields(formFields, showToast) {
  let optionsMissing = false;
  let isInvalidFormElements = false;
  formFields.forEach((e) => {
    if (e.title == "") {
      isInvalidFormElements = true;
    }
    if (e.type == "checkbox" || e.type == "radio") {
      if (
        e.options.length === 0 ||
        (e.options.length === 1 && e.options[0].trim() === "")
      ) {
        optionsMissing = true;
      }
    }
  });

  if (optionsMissing) {
    showToast("Options missing!", 2500, "error", "MM");
    return false;
  }
  if (isInvalidFormElements) {
    showToast("Ensure no blank questions!", 2500, "error", "MM");
    return false;
  }
  return true;
}
