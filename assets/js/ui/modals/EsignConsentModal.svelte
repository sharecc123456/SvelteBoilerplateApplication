<script>
  import ConfirmationDialog from "../components/ConfirmationDialog.svelte";
  import { createEventDispatcher } from "svelte";
  const dispatch = createEventDispatcher();

  export let iacModel;
  export let consentHandler;
  export let fieldId;

  function consentProvided() {
    consentHandler(iacModel, true, fieldId);
    close();
  }

  function close() {
    // lol wtf
    let container = document.getElementById("boilerplate-error-container");
    container.innerHTML = "";
    dispatch("close");
  }
</script>

<ConfirmationDialog
  title="Electronic Signature Consent"
  question="To satisfy regulatory requirements Boilerplate requires you to consent to using your electronic signature. If you provide consent by pressing the Yes button below, all documents you sign on Boilerplate will be equal to ink-based signatures, including being legally binding. You can always decline to provide consent and coordinate with your Requestor on how to use paper and ink-based signatures."
  yesText="Yes, consent"
  noText="No, don't consent"
  yesColor="secondary"
  noColor="danger"
  noLeftAlign={true}
  details="Type your FULL name."
  esignConsent={true}
  on:close={close}
  on:yes={consentProvided}
/>
