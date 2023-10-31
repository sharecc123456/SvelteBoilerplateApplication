<script>
  import Modal from "../components/Modal.svelte";
  import Button from "../atomic/Button.svelte";
  import { convertDateTime } from "Helpers/util";
  import { todayDate } from "../../helpers/dateUtils";

  export let checklistCompletedDialog, currentSubmittedAssignment;

  function PrintElem(elm, title) {
    var contents = document.getElementById(elm).innerHTML;
    var frame1 = document.createElement("iframe");
    frame1.name = "frame1";
    frame1.style.position = "absolute";
    frame1.style.top = "-1000000px";
    document.body.appendChild(frame1);
    var frameDoc = frame1.contentWindow
      ? frame1.contentWindow
      : frame1.contentDocument.document
      ? frame1.contentDocument.document
      : frame1.contentDocument;
    frameDoc.document.title = window.parent.document.title = title;
    frameDoc.document.open();
    frameDoc.document.write(`<html><head><title>${title}</title>`);
    frameDoc.document.write("</head><body>");
    frameDoc.document.write(
      `<h2 style="display: flex; justify-content: center; font-family: sans-serif;">
          Boilerplate Submission Confirmation
       </h2>`
    );
    frameDoc.document.write(contents);
    frameDoc.document.write("</body></html>");
    frameDoc.document.close();
    setTimeout(function () {
      window.frames["frame1"].focus();
      window.frames["frame1"].print();
      document.body.removeChild(frame1);
    }, 500);
    return false;
  }
</script>

<Modal
  on:close={() => {
    checklistCompletedDialog = false;
    window.location = `/n/recipient#dashboard`;
  }}
>
  <p slot="header">Checklist Completed!</p>

  {#if currentSubmittedAssignment}
    <div id="printIT">
      <div class="modal-subheader">
        Checklist name: {currentSubmittedAssignment?.name}
      </div>

      <div class="modal-field">
        Request ID: {currentSubmittedAssignment?.id}
      </div>
      <div class="modal-field">
        Submitter's Name: {currentSubmittedAssignment?.recipient_data?.name}
      </div>
      <div class="modal-field">
        Submitter's Email: {currentSubmittedAssignment?.recipient_data?.email}
      </div>
      <div class="modal-field">
        Requester Name: {currentSubmittedAssignment?.sender?.name}
      </div>
      <div class="modal-field">
        Requester Email: {currentSubmittedAssignment?.sender?.email}
      </div>
      <div class="modal-field">
        Requester Organization: {currentSubmittedAssignment?.sender
          ?.organization}
      </div>
      <div class="modal-field">
        Date submitted: {convertDateTime(
          currentSubmittedAssignment?.state?.date?.split(" ")[0],
          currentSubmittedAssignment?.state?.date?.split(" ")[1]
        )}
      </div>

      <div class="modal-field">
        Thank you! The requester will be notified automatically of your
        submission. You'll be notified via email of any revisions or additional
        requests. You may save copies of these files using the download buttons.
      </div>
    </div>
    <div class="modal-buttons">
      <span
        on:click={() => {
          checklistCompletedDialog = false;
          PrintElem(
            "printIT",
            `${currentSubmittedAssignment?.sender?.organization} - ${
              currentSubmittedAssignment?.name
            } Submission Confirmation - ${todayDate()}`
          );
        }}
      >
        <Button color="white" text="Print Confirmation" />
      </span>
      <span
        on:click={() => {
          checklistCompletedDialog = false;
          window.location = `/n/recipient#dashboard`;
        }}
      >
        <Button color="primary" text="Close Confirmation" />
      </span>
    </div>
  {/if}
</Modal>

<style>
  .modal-subheader {
    padding-bottom: 2rem;
    font-weight: 500;
    font-family: "Nunito", sans-serif;
    white-space: nowrap;
    overflow: hidden;
    text-overflow: ellipsis;
  }

  .modal-field {
    padding-bottom: 1rem;
    font-family: "Nunito", sans-serif;
  }

  .modal-buttons {
    display: flex;
    flex-flow: row nowrap;
    justify-content: space-between;
    width: 100%;
    align-items: center;
  }
</style>
