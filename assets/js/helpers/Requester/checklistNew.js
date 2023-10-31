const SENDBUTTONLABEL = "send";
const FINISHBUTTONLABEL = "finish";
const SAVENEXTBUTTONLABEL = "Save & Next";

/**
 * calculate steady finish button disable state
 * @param {Object} checklist
 * @param {boolean} showFillModal
 * @param {boolean} showUploadModal
 * @param {boolean} isEmptyRequest
 * @param {string} new_file_request
 * @returns Boolean
 */
export const calculateSteadyFinishState = (
  checklist,
  showFillModal,
  showUploadModal,
  isEmptyRequest,
  new_file_request
) => {
  const isChecklistInvalid = inValidChecklistData(checklist);

  return (
    showFillModal ||
    (isEmptyRequest && new_file_request != "") ||
    showUploadModal ||
    isChecklistInvalid
  );
};

/**
 * calculate Next button disable state
 * @param {Object} checklist
 * @param {Number} current_tab
 * @param {Number} max_tab
 * @param {boolean} showUploadModal
 * @returns boolean
 */
export const calculateNextState = (
  checklist,
  current_tab,
  max_tab,
  showUploadModal,
  showFillModal
) => {
  const isChecklistInvalid = inValidChecklistData(checklist);
  return (
    current_tab == max_tab ||
    showUploadModal ||
    isChecklistInvalid ||
    showFillModal
  );
};

/**
 * calculate finish button disable state
 * @param {Object} checklist
 * @param {boolean} showFillModal
 * @param {boolean} isEmptyFileRequest
 * @param {string} new_file_request
 * @param {boolean} showUploadModal
 * @param {boolean} isFormEdit
 * @param {boolean} isFormCreate
 * @param {boolean} editID
 *
 * @returns Boolean
 */
export const calculateFinishState = (
  checklist,
  showFillModal,
  isEmptyFileRequest,
  new_file_request,
  showUploadModal,
  isFormEdit,
  isFormCreate,
  editID
) => {
  const isChecklistInvalid = inValidChecklistData(checklist);
  return (
    showFillModal ||
      (isEmptyFileRequest && new_file_request != "") ||
      showUploadModal ||
      isChecklistInvalid ||
      isFormEdit ||
      isFormCreate,
    editID
  );
};

/**
 *
 * @param {Object} checklist
 * @returns
 */
export const inValidChecklistData = ({ name, description }) => {
  return (
    name.length > 60 ||
    description.length > 60 ||
    (name.replace(/\s/g, "").length < 1 && name.length >= 1)
  );
};
