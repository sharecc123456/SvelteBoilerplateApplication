<script>
  import RequestorHeaderNew from "../../components/RequestorHeaderNew.svelte";
  import Button from "../../atomic/Button.svelte";
</script>

<div class="page-header">
  <RequestorHeaderNew
    icon="question-circle"
    title="FAQ"
    enable_search_bar={false}
  />
</div>

<div>
  <div class="flex-center">
    <span
      class="flex-center"
      style="
            font-size: 20px;
            font-weight: bold;"
    >
      Overview
    </span>
    <br />
    <div class="flex-center" style="font-size: 18px;">
      <span> Welcome to Boilerplate. </span>
      <span>
        We’re a secure cloud platform to manage repetitive documentation and
        signature requests using digital checklists.
      </span>
    </div>

    <ol>
      <li>
        Checklists can include:
        <ul>
          <li>Personalized documents</li>
          <li>Generic forms</li>
          <li>File requests</li>
          <li>Data input fields</li>

          <li>Tasks to be completed</li>
        </ul>
      </li>

      <li>
        Checklists with personalized documents, like contracts or offer letters,
        can be personalized, pre-filled and signed in our system before sending.
        These checklists will be sent directly to the intended recipient via an
        automated email notification.
      </li>
      <li>
        If a checklist does not contain anything personalized, like generic
        forms and file requests only, they can be shared using a shareable link,
        scannable QR code, or automated email notification.
      </li>
      <li>
        The recipient will see a visual checklist of open and closed items, fill
        and sign any forms, upload file requests, and mark tasks completed.
      </li>

      <li>
        You’ll be notified once files are submitted, and can accept or reject
        them with comments from your review queue.
      </li>

      <li>
        The dashboard lets you track, remind, and access all requests in
        real-time. When you download a file, it will automatically rename it
        with the person’s name, file name, and date, so there’s no confusion.
      </li>

      <li>
        You can also manage your contacts like a CRM from your contacts page,
        and manually add files to a contact’s account by going into their
        contact details.
      </li>

      <li>
        Use the chat bot in the bottom right if you have any questions or
        suggestions.
      </li>
    </ol>

    <span>
      Now take a few deep breaths and relax. Your days of stressing over missing
      file requests, error-prone tracking sheets, and disorganized cloud folders
      are over.
    </span>

    <br />

    <span
      on:click={() => {
        window.location.href = `#directsend`;
      }}
    >
      <Button color="secondary" text="Get Started" />
    </span>
  </div>
</div>

<style>
  li {
    padding-bottom: 0.5rem;
  }
  .flex-center {
    display: flex;
    flex-direction: column;
    align-items: center;
    justify-content: center;
  }
  .page-header {
    position: sticky;
    top: 0px;
    z-index: 0;
    background: #fcfdff;
  }
</style>
