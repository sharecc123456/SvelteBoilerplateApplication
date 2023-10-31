export const setReviewHistory = (checklistId, itemId, reviewType) => {
  const fullUrl = window.location.origin + window.location.pathname + "#review";
  window.history.replaceState(
    {},
    "Boilerplate Portals for Form, File and E-Sign Requests",
    `${fullUrl}/${checklistId}/${reviewType}/${itemId}`
  );
  window.location.reload();
};

const REVIEW_TYPE_TO_ITEMS_MAPPER = {
  document: { key: "documents", id: "base_document_id" },
  request: { key: "requests", id: "request_id" },
  form: { key: "forms", id: "id" },
};

export const navigateToNextItem = ({
  item,
  checklistId,
  reviewType,
  itemId,
}) => {
  let nextItemId;
  let type;
  let found = false;

  for (const rType of Object.keys(REVIEW_TYPE_TO_ITEMS_MAPPER)) {
    if (found) break;
    const reviewTypeMapper = REVIEW_TYPE_TO_ITEMS_MAPPER[rType];
    const { key, id } = reviewTypeMapper;
    const items = item[key];
    const itemsLeft =
      reviewType == rType
        ? items.filter((rItem) => rItem[id] != itemId)
        : items.length
        ? items
        : [];

    if (itemsLeft.length > 0) {
      nextItemId = itemsLeft[0][id];
      type = rType;
      found = true;
    }
  }

  setReviewHistory(checklistId, nextItemId, type);
};
