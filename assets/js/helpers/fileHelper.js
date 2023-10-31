import { isNullOrUndefined } from "./util";

export const allowedIACImageTypes =
  /(\.jpg|\.jpeg|\.png|\.heif|\.heic|\.heifs|\.avif|\.avifs)$/i;
export const unSupportedImagePreviewType = /(\.heif|\.heic|\.heifs)$/i;
export const allowedIACFileTypes = /(\.pdf|\.pdfa)$/i;
export const allowedNonIACDocExtensions =
  /(\.xls|\.xlsx|\.txt|\.csv|\.doc|\.docx|\.dotx|\.qbx|\.qba|\.qby|\.qbj|\.tiff|\.tif)$/i;

export const allowedTurboTaxExtensions = ".tax";
const MAXFILESIZEBYTE = 1048576;
const MAXFILESIZEMB = 18;

// Browser preview unsupported formats for templates and cabinets
export const requestorTemplateNonIACExtensions = ["xlsx", "xls", "tif", "tiff"];

/**
 * @description checks if the file size is within the 18mb limit
 * @param {number} size
 * @returns Bool
 */
export const checkFileSizeLimit = ({ size }) => {
  return size / MAXFILESIZEBYTE < MAXFILESIZEMB;
};

/**
 * @description checks if files uploaded are boilerplate allowed file types
 * @param {String} fname
 * @returns bool
 */
export const isAllowedFileExtensionType = ({ name }) => {
  return (
    allowedIACImageTypes.exec(name) ||
    allowedIACFileTypes.exec(name) ||
    name.includes(allowedTurboTaxExtensions) ||
    allowedNonIACDocExtensions.exec(name)
  );
};

/**
 * @description is file extension turbo tax
 * @param {String} fname
 * @returns bool
 */
export const isTurboTaxExtensionType = ({ name }) => {
  return name.includes(allowedTurboTaxExtensions);
};

/**
 * @description checks if the file is pdf or image
 * @param {String} fname
 * @returns
 */
export const isFileTypeMergeable = ({ name }) => {
  return allowedIACImageTypes.exec(name);
};

/**
 * @description checks if the file is same extension
 * @param {String} fname
 * @param {String} ext
 * @returns bool
 */
export const isSameFileType = ({ name }, ext) => {
  return name.includes(ext);
};

/**
 * @param  {string} filename
 */
export const isImage = (filename) => {
  if (allowedIACImageTypes.exec(filename)) {
    return true;
  }
  return false;
};

/**
 * @param  {string} filename
 */
export const isHeicImageType = (filename) => {
  if (unSupportedImagePreviewType.exec(filename)) {
    return true;
  }
  return false;
};

/**
 * @description checks if files uploaded are boilerplate IAC Compatible Files
 * @param {String} name
 * @returns bool
 */
export const isIACCompatibleType = ({ name }) => {
  if (allowedIACImageTypes.exec(name) || allowedIACFileTypes.exec(name))
    return true;
  else return false;
};

/**
 * @description checks if file can be preived in the browwser
 * only IAC compatible files are viewable in App
 * @param {String} name
 * @returns bool
 */
export const isFileTypeViewable = ({ name }) => {
  return isIACCompatibleType({ name });
};

/**
 * @param  {string} specialId - signifies the doctype
 * @param  {string} parentId - parent of the document, recipeint/assignment/checklist
 * @param  {string} documentId - documentId in question
 * @returns {string} download url of the file
 */
export const getFileDownloadUrl = ({ specialId, parentId, documentId }) => {
  let url = "";
  switch (specialId) {
    case 1:
      url = `/completeddocument/${parentId}/${documentId}/download`;
      break;
    case 2:
      url = `/reviewrequest/${documentId}/download/completed`;
      break;
    case 3:
      url = `/user/${parentId}/storage/${documentId}/download`; // Cabinet Download
      break;
    // TODO: add case 4
    // ? case 4:
    // ?  url = `/n/api/v1/dproxy/${x.file_name}`;
    // ? break;
    case 5:
      url = `/rawdocument/${documentId}/download`;
      break;
  }
  return url;
};

/**
 *
 * @param {number} status
 * @param {number} checklistId
 * @returns string URL
 */
export const getChecklistDownloadUrl = (status, checklistId) => {
  switch (status) {
    default:
      return `/completedchecklist/${checklistId}/download`;
  }
};

export const getRecipientChecklistDownloadUrl = (status, recipientId) => {
  switch (status) {
    default:
      return `/checklists/recipient/${recipientId}/download`;
  }
};

/**
 *
 * @param {Object} assignment - package assignment
 * @param {Object} req - template object
 * @returns {string} download url of the document
 */
export function getDocumentDownloadUrl(assignment, req) {
  const { state } = req;
  let url;
  if (!isNullOrUndefined(req.type) && req.type === "file") {
    const fileType = state.status === 4 ? "completed" : "not";
    return `/completedrequest/${assignment.id}/${req.completion_id}/download/${fileType}`;
  }
  switch (state.status) {
    case 0:
      // assigned doc
      url = `/document/${assignment.id}/${req.id}/download`;
      break;
    case 4:
      // completed doc
      url = `/completeddocument/${assignment.id}/${req.completion_id}/download`;
      break;
    default:
      // review doc(Review or returned for update)
      url = `/reviewdocument/${req.completion_id}/download/requestor`;
  }
  return url;
}

export function getCabinetDownloadUrl(uid, document) {
  return `/user/${uid}/storage/${document.id}/download`;
}

/**
 * @description returns preview link based for open documents on the document type
 * @param {Object} assignment - package assignment
 * @param {Object} req - template object
 * @returns {string} preview link of the document
 */
export function getRequestorOpenDocPreviewLink(
  assignment,
  { id, is_iac, is_rspec, customization }
) {
  const isRdcType =
    customization?.customization_id && (is_iac || is_rspec) ? true : false;

  if (isRdcType) {
    const { customization_id } = customization;
    return `#submission/view/6/${assignment.id}/${customization_id}?newTab=true&filePreview=true`;
  } else {
    return `#view/template/${id}?newTab=true&filePreview=true`;
  }
}

export function recipientDashboardDownloadUrl(assignment, request) {
  const { is_rspec, is_iac, customization } = request;
  let url;
  if (is_iac && is_rspec && customization.customization_id) {
    if (request.state.status == 4 || request.state.status == 2) {
      url = `/completeddocument/${assignment.id}/${request.completion_id}/download`;
    } else {
      url = `/package/customize/${assignment.contents_id}/${assignment.recipient_id}/${customization.customization_id}/download`;
    }
  } else if (request.state.status != 2 && request.state.status != 4) {
    const dispName = request.name;
    url = `/n/api/v1/dproxy/${request.base_filename}?dispName=${dispName}`;
  } else if (request.state.status == 4 || request.state.status == 2) {
    url = `/completeddocument/${assignment.id}/${request.completion_id}/download`;
  }
  console.log(url);
  return url;
}

export const printOptionMenu = (url, filename) => {
  if (isImage(filename)) printJS(url, "image");
  else printJS(url);
};
