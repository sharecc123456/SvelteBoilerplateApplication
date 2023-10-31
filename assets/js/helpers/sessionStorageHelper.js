/**
 * Check if key exists in session storage
 * @param  string key
 * @return boolean
 */
export function sessionStorageHas(key) {
  const item = sessionStorage.getItem(key);

  return item !== null;
}

/**
 * Retrive an object from session storage.
 * @param  string key
 * @return mixed
 */
export function sessionStorageGet(key) {
  const item = sessionStorage.getItem(key);

  if (!item) return;

  if (item[0] === "{" || item[0] === "[") return JSON.parse(item);

  return item;
}

/**
 * Save some value to session storage.
 * @param string key
 * @param string value
 */
export function sessionStorageSave(key, value) {
  if (value === undefined) throw "Can't store undefinded value";

  if (typeof value === "object" || typeof value === "array") {
    value = JSON.stringify(value);
  }

  if (typeof value !== "string") throw "Can't store unrecognized format value";

  sessionStorage.setItem(key, value);
}

/**
 * Remove element from session storage.
 * @param string key
 */
export function sessionStorageRemove(key) {
  sessionStorage.removeItem(key);
}

/**
 * Retrive an object from session storage and remove from session storage.
 * @param  string key
 * @return mixed
 */
export function sessionStoragePop(key) {
  const item = sessionStorageGet(key);

  sessionStorageRemove(key);

  return item;
}
