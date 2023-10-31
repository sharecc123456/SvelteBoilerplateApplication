<script>
  import ConfirmationDialog from "../../components/ConfirmationDialog.svelte";
  import RepeatSubmissionItemsList from "./RepeatSubmissionItemsList.svelte";
  import { clickOutside } from "../../../helpers/clickOutside";
  import Button from "../../atomic/Button.svelte";
  import { showToast } from "../../../helpers/ToastStorage.js";
  import { recipientChecklistCreate } from "../../../api/Checklist";

  let showPopUp = false;
  let showCreateChecklist = false;
  let checklistContents;
  export let contents = [];

  const repeatContents = contents?.filter(
    (content) => content.flags != 5 && content.allow_duplicate_submission
  );

  async function createNewChecklist(event) {
    let uniqueIdentifier = event.detail.text;
    if (uniqueIdentifier) {
      let request = await recipientChecklistCreate(
        checklistContents,
        uniqueIdentifier
      );

      showCreateChecklist = false;
      if (request.ok) {
        showToast(`Success! New Submission created.`, 1500, "default", "MM");
        window.location.reload();
      } else {
        showToast(
          `Could create new submission. Please try again later!.`,
          1500,
          "error",
          "MM"
        );
      }
    } else {
      showToast(
        `Please add a unique reference to tell this new submission apart from previous ones.`,
        2500,
        "warning",
        "MM"
      );
    }
  }

  const handleCreateChecklist = (event) => {
    checklistContents = event.detail.clickedContent;
    showPopUp = false;
    showCreateChecklist = true;
  };
</script>

<div class="header-dashboard__notification" on:click={() => (showPopUp = true)}>
  <Button
    text="Create New Submission"
    color="white"
    disabled={repeatContents.length == 0}
  />
</div>

{#if showPopUp}
  <div
    class="header"
    use:clickOutside
    on:click_outside={() => {
      showPopUp = false;
    }}
  >
    <div class="header__heading"><h2>Checklists</h2></div>
    <ul class="header-checklist__list">
      <div
        class="List"
        style="position: relative; height: 400px; width: 471px; overflow: auto; direction: ltr;"
      >
        <div style="height: 100%; width: 100%;">
          {#each repeatContents as content}
            <RepeatSubmissionItemsList
              {content}
              on:clickedCreateChecklist={handleCreateChecklist}
            />
          {/each}
        </div>
      </div>
    </ul>
  </div>
{/if}

{#if showCreateChecklist}
  <ConfirmationDialog
    title={"Create New Submission"}
    question={"Checklist Name: " + checklistContents.name}
    details={"Submission Reference"}
    responseBoxEnable="true"
    responseBoxDemoText="Enter Unique Identifier for the checklist"
    yesText="Start"
    noText="Cancel"
    yesColor="primary"
    on:message={createNewChecklist}
    noColor="gray"
    on:yes={""}
    on:close={() => {
      showCreateChecklist = false;
    }}
  />
{/if}

<style>
  * {
    margin: 0;
    padding: 0;
    box-sizing: border-box;
  }

  .header-dashboard__notification {
    margin-left: auto;
    cursor: pointer;
    margin-right: -2.5rem;
  }

  .header {
    width: 471px;
    position: fixed;
    right: 40px;
    top: 130px;
    color: #000;
    background: #fff;
    box-shadow: 0 4px 20px;
    border-radius: 10px;
    font-family: "Lato", sans-serif;
    z-index: 100;
  }

  .header__heading {
    display: flex;
    flex-direction: row;
    align-items: center;
    padding: 16px 20px;
    border-bottom: #dae2ee 1px solid;
    font-size: 14px;
  }

  .header-checklist__list {
    font-size: 14px !important;
    overflow-y: auto;
  }

  /* width */
  ::-webkit-scrollbar {
    width: 10px;
  }

  /* Track */
  ::-webkit-scrollbar-track {
    background: #f1f1f1;
    box-shadow: inset 0 0 6px rgba(0, 0, 0, 0.3);
  }

  /* Handle */
  ::-webkit-scrollbar-thumb {
    background: #b6b6b6;
  }

  /* Handle on hover */
  ::-webkit-scrollbar-thumb:hover {
    background: #555;
  }
  .List {
    overflow-x: hidden !important;
  }
  @media only screen and (max-width: 767px) {
    .header-dashboard__notification {
      margin: 0;
      padding: 0;
    }
    .List {
      height: 100% !important;
      width: 100% !important;
    }

    .header {
      width: 90% !important;
      right: 25px !important;
    }
  }
  @media only screen and (max-width: 320px) {
    .header {
      width: 85% !important;
      right: 25px !important;
    }
  }
</style>
