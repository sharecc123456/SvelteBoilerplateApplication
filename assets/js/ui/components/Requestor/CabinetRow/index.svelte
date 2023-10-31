<script>
  import Button from "Atomic/Button.svelte";
  import FAIcon from "Atomic/FAIcon.svelte";
  import Dropdown from "Components/Dropdown.svelte";
  import { isImage, getFileDownloadUrl } from "Helpers/fileHelper";
  import DashboardStatus from "../../DashboardStatus.svelte";
  export let document = {};
  export let recipientId = null;
  export let handleItemPopup = (a) => {};
  export let handleCabinetClick = (a, b) => {};
</script>

<div class="document">
  <div
    class="document-inner"
    on:click|stopPropagation={() => handleItemPopup(document)}
  >
    <div class="td chevron" />
    <div class="td name">
      <div>
        <div class="filerequest">
          <span>
            <FAIcon icon="file-alt" iconStyle="regular" />
          </span>
          <div
            class="filerequest-name clickable"
            on:click|stopPropagation={() => handleItemPopup(document)}
          >
            <span>{document.name}</span>
          </div>
        </div>
      </div>
    </div>
    <div class="td status">
      <DashboardStatus state={document.status} />
      <div />
    </div>
    <div class="td next ">
      <div />
    </div>
    <div class="td border-end actions-btn">
      <span
        on:click|stopPropagation={() => {
          const specialId = 3;
          if (isImage) {
            window.location = `#submission/view/${specialId}/${recipientId}/${document.id}`;
          } else {
            window.location = getFileDownloadUrl({
              specialId,
              parentId: recipientId,
              documentId: document.id,
            });
          }
        }}
      >
        <Button color="white" text="View" />
      </span>
      <Dropdown
        triggerType="vellipsis"
        clickHandler={(ret) => {
          handleCabinetClick(document, ret);
        }}
        elements={[
          {
            ret: 2,
            icon: "download",
            text: "Download",
          },
          {
            ret: 1,
            icon: "trash-alt",
            text: "Delete",
          },
          {
            ret: 3,
            icon: "exchange",
            text: "Replace",
          },
        ]}
      />
    </div>
  </div>
</div>

<style>
  .filerequest {
    display: flex;
    flex-flow: row nowrap;
  }

  .filerequest:nth-child(1) {
    font-size: 24px;
    align-items: center;
    color: #606972;
  }

  .filerequest-name {
    display: flex;
    flex-flow: column nowrap;
    padding-left: 0.5rem;
  }

  .filerequest-name > *:nth-child(1) {
    font-style: normal;
    font-weight: 500;
    font-size: 14px;
    line-height: 24px;
    letter-spacing: 0.15px;
    color: #2a2f34;
  }

  .filerequest-name > *:nth-child(2) {
    font-style: normal;
    font-weight: normal;
    font-size: 12px;
    line-height: 24px;
    color: #76808b;
  }

  .actions-btn :global(button) {
    z-index: 10;
    margin-bottom: 0;
  }

  .actions-btn {
    width: 100%;
  }
  .actions-btn > span {
    width: 75%;
  }

  .document {
    display: flex;
    flex-flow: row nowrap;
    align-items: center;
    width: 100%;
    padding: 0.5rem;
    border: 0.5px solid #b3c1d0;
    box-sizing: border-box;
    border-radius: 10px;

    padding-top: 0.5rem;
    padding-bottom: 0.5rem;
    margin-bottom: 1rem;
  }

  .document-inner {
    /* display: flex;
    flex-flow: row nowrap;
    align-items: center;
    width: calc(100% - 14px);

    background: #ffffff;
    
    display: grid;
    grid-template-columns: 2fr 130px;
    grid-template-rows: 1fr 1fr;
    grid-template-areas:
      "a a "
      "b b"
      "c c"
      "d d";
    padding-right: 0.3rem;
    width: 100%;
     */
    display: grid;
    width: 100%;
  }

  /* .document-force-pad {
    width: calc(1rem + 40px);
  } */

  .td {
    display: flex;
    flex-flow: row nowrap;
    flex-grow: 1;
    flex-basis: 0;
    min-width: 0px;
  }

  .td.name {
    flex-grow: 3;
    display: flex;
    flex-flow: row nowrap;
    align-items: center;
  }

  .clickable {
    cursor: pointer;
  }
  .td.border-end {
    display: flex;
    justify-content: end;
  }
  @media only screen and (min-width: 640px) {
    .td.status {
      display: grid;
      justify-items: start;
    }
    .document-inner {
      grid-template-columns: 40px 1.7fr 1fr 1fr 145px;
      grid-template-areas: "a b c d e";
      grid-template-rows: 1fr;
    }
    .document-inner .td.name {
      grid-area: b;
    }
    .document-inner .td.status {
      grid-area: c;
    }
    .document-inner .td.next {
      grid-area: d;
    }
    .document-inner .td.border-end {
      grid-area: e;
      display: flex;
      padding-right: 0.5rem;
      justify-self: start;
      align-items: center;
    }
  }

  @media only screen and (min-width: 780px) {
    .document-inner {
      padding-right: 0.2rem;
    }
  }
</style>
