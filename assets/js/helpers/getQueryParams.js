export const getQueryParams = () => {
  let url = window.location.href;
  const splitHashUrl = url.split("#");
  if (splitHashUrl[1]) {
    const [hash, query] = splitHashUrl[1].split("?");
    if (query) {
      const params = Object.fromEntries(new URLSearchParams(query));
      return params;
    }
  }

  return {};
};
