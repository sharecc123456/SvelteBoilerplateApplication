import {getIacDocumentId, setupIac } from "BoilerplateAPI/IAC";

/* Sets IAC up for the type/base_id combo */
async function iacSetup(type, base_id) {
    let iacIdReply = await getIacDocumentId(type, base_id);
    if (iacIdReply.ok) {
        let r = await iacIdReply.json();
        let iacId = r.iacDocumentId;

        let setupReply = await setupIac(iacId);
        if (setupReply.ok) {
            return iacId;
        } else {
            throw new Error("failed to setup IAC");
        }
    } else {
        throw new Error("failed to retrieve iacId");
    }
}

export { iacSetup };