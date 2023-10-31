import { iacGetAssignedFields, iacGetAssignedFieldsRequestor } from "BoilerplateAPI/IAC";

/* Request the API to return the slave fields */
export async function iacMakeFillable(iacDoc, recipientId, assignmentId) {
    let reply = await iacGetAssignedFields(iacDoc.id, assignmentId, recipientId);
    let iaf_fields = await reply.json();
    
    /* replace the field information in the doc with the fields from the IAF */
    iacDoc.fields = iaf_fields;
    return iacDoc;
}

/* Request the API to return the slave fields */
export async function iacMakeFillableAsRequestor(iacDoc, recipientId, contentsId) {
    let reply = await iacGetAssignedFieldsRequestor(iacDoc.id, contentsId, recipientId);
    let iaf_fields = await reply.json();
    
    /* replace the field information in the doc with the fields from the IAF */
    iacDoc.fields = iaf_fields;
    return iacDoc;
}
