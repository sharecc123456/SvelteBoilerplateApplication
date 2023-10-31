import { iacDelEsign, iacGetAssignedFieldsRequestor } from "../../api/IAC";

export const stateToText = (s, x) => {
  switch (s) {
    case 0:
      if (!x) return "Fill & Sign";
      return "Fill/ Sign";
    case 1:
      if (!x) return "Review & Submit";
      return "Review";
    case 2:
      if (!x) return "View Submission";
      return "View";
    case 4:
      if (!x) return "View Submission";
      return "View";
    case 3:
      return "Revise";
  }
};

export const resetRequestorSignatureFields = async (
  iacDocId,
  contentsId,
  recipientId
) => {
  const reply = await iacGetAssignedFieldsRequestor(
    iacDocId,
    contentsId,
    recipientId
  );
  let fields = await reply.json();

  const _fieldIds = fields.reduce((filtered, field) => {
    console.log(field);
    if (field.type === 3 && (field.fill_type === 0 || field.fill_type === 1)) {
      filtered.push(field.id);
    }
    return filtered;
  }, []);

  if (_fieldIds.length > 0) await iacDelEsign(iacDocId, _fieldIds, "requestor");
};
